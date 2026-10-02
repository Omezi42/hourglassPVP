extends RefCounted
## 段位・戦績・集計の read-modify-write が、読み取りに失敗したとき空のフィールドを土台に書かないこと
## (`AccountService.read_succeeded()`。手本は account_service_tests.gd)。
##
## 戦績の退避は `user://account.json` を直接書くため、控える → 上書き → 検証 → 戻すの往復にする
## (docs/Pitfalls.md「触ってはいけないもの」)。

const FakeClient = preload("res://tools/tests/fake_firestore_client.gd")
const UID := "uid-read-failure-rank"
const OLD_SEASON := "2000-01"
const TIER := "silver2"
const PEAK := "gold1"
const STARS := 2
const STREAK := 1
const BALANCE := 500
const MOVES := 20
const TURNS := 12
const GAMES := 7
const FUNNEL_DAY := "2000-01-01"

var _assert: Callable
var _client: FirestoreClient
var _path := AccountService.path(UID)


func run(assert_true: Callable) -> void:
	_assert = assert_true
	var backup: Variant = _backup()
	var auth := FirebaseAuth.new(null)
	auth.uid = UID
	_client = FakeClient.new(auth)
	(Engine.get_main_loop() as SceneTree).root.add_child(_client)

	await _test_rank_result_keeps_standing_on_read_failure()
	await _test_season_reset_stops_on_read_failure()
	await _test_season_reward_failure_keeps_old_season()
	await _test_match_stats_go_pending_on_read_failure()
	await _test_global_stats_untouched_on_read_failure()
	await _test_funnel_send_fails_on_read_failure()

	_client.queue_free()
	AccountService.reset()
	_restore(backup)


func _reset_state() -> void:
	if FileAccess.file_exists(AccountStore.SAVE_PATH):
		DirAccess.remove_absolute(AccountStore.SAVE_PATH)
	AccountService.reset()
	_client.store.clear()
	_client.fail_reads = 0
	_client.commit_count = 0
	_client.store[_path] = {
		"fields":
		{
			"currency": BALANCE,
			"rank_season": OLD_SEASON,
			"rank_tier": TIER,
			"rank_stars": STARS,
			"rank_win_streak": STREAK,
			"rank_peak_tier": PEAK,
			"stats_kinds": {"cpu": {"games": GAMES}},
		},
		"update_time": "t0"
	}


func _fields() -> Dictionary:
	return _client.store[_path]["fields"]


func _test_rank_result_keeps_standing_on_read_failure() -> void:
	_reset_state()
	_client.fail_reads = 1
	await RankProgress.apply_result(_client, _client, UID, true, MOVES)
	_assert.call(_client.commit_count == 0, "rank result should not write after a failed read")
	_assert.call(
		_fields()["rank_tier"] == TIER and int(_fields()["rank_stars"]) == STARS,
		"a failed read must not reset the tier and stars"
	)

	await RankProgress.apply_result(_client, _client, UID, true, MOVES)
	_assert.call(
		int(_fields()["rank_win_streak"]) == STREAK + 1,
		"the next result should build on the stored standing"
	)


## 報酬を受け取り済みにして、段位の初期化だけを確かめる。
func _test_season_reset_stops_on_read_failure() -> void:
	_reset_state()
	AccountService.apply_local_fields(
		{"rank_season": OLD_SEASON, "rank_reward_claimed_season": OLD_SEASON}
	)
	_client.fail_reads = 1
	var result: Dictionary = await RankProgress.ensure_current_season(_client, UID)
	_assert.call(not result["transitioned"], "a failed read should not report a new season")
	_assert.call(_client.commit_count == 0, "season reset should not write after a failed read")
	_assert.call(_fields()["rank_season"] == OLD_SEASON, "the stored season should be untouched")
	_assert.call(
		AccountService.rank_season() == OLD_SEASON,
		"the local season should stay old to retry later"
	)


## 報酬を渡せなかったら段位も切り替えない(切り替えると旧シーズンの報酬を受け取る機会が消える)。
func _test_season_reward_failure_keeps_old_season() -> void:
	_reset_state()
	AccountService.apply_local_fields({"rank_season": OLD_SEASON, "rank_peak_tier": PEAK})
	_client.fail_reads = 1
	var result: Dictionary = await RankProgress.ensure_current_season(_client, UID)
	_assert.call(not result["transitioned"], "a failed reward should not report a new season")
	_assert.call(_client.commit_count == 0, "nothing should be written after a failed read")
	_assert.call(int(_fields()["currency"]) == BALANCE, "the balance should be untouched")
	_assert.call(_fields()["rank_season"] == OLD_SEASON, "the season should not move on")

	result = await RankProgress.ensure_current_season(_client, UID)
	var reward := int(RankProgress.SEASON_REWARDS[RankRules.bracket_of(PEAK)])
	_assert.call(result["reward"] == reward, "the reward should be granted on the next try")
	_assert.call(int(_fields()["currency"]) == BALANCE + reward, "the reward should add to balance")
	_assert.call(
		_fields()["rank_season"] == RankProgress.current_season_key(),
		"the season should move on after the reward"
	)


func _test_match_stats_go_pending_on_read_failure() -> void:
	_reset_state()
	_client.fail_reads = 1
	await MatchStatsService.push(_client, UID, CurrencyRules.MatchKind.CPU, true, TURNS, [])
	_assert.call(_client.commit_count == 0, "match stats should not write after a failed read")
	_assert.call(
		_fields()["stats_kinds"] == {"cpu": {"games": GAMES}},
		"a failed read must not reset the stored stats"
	)
	_assert.call(
		AccountStore.get_pending_matches().size() == 1, "the match should wait in the pending store"
	)


func _test_global_stats_untouched_on_read_failure() -> void:
	_reset_state()
	var stats := {"counts": {"games": GAMES}, "cards": {}}
	_client.store[MatchRecordService.STATS_PATH] = {
		"fields": stats.duplicate(true), "update_time": "s0"
	}
	_client.fail_reads = 1
	var record := {
		"winner": "a",
		"turns": TURNS,
		"kind": "random",
		"end_reason": "hp",
		"deck_a": [],
		"deck_b": []
	}
	await MatchRecordService._bump_stats(_client, record)
	_assert.call(_client.commit_count == 0, "global stats should not write after a failed read")
	_assert.call(
		_client.store[MatchRecordService.STATS_PATH]["fields"] == stats,
		"a failed read must not reset the global stats"
	)


func _test_funnel_send_fails_on_read_failure() -> void:
	_reset_state()
	_client.fail_reads = 1
	var sent: bool = await FunnelService.send(_client, {FunnelService.HOME: FUNNEL_DAY})
	_assert.call(not sent, "funnel send should report a failed read")
	_assert.call(_client.commit_count == 0, "funnel should not write after a failed read")


func _backup() -> Variant:
	if not FileAccess.file_exists(AccountStore.SAVE_PATH):
		return null
	var file := FileAccess.open(AccountStore.SAVE_PATH, FileAccess.READ)
	var content := file.get_as_text()
	file = null
	return content


func _restore(backup: Variant) -> void:
	if backup == null:
		if FileAccess.file_exists(AccountStore.SAVE_PATH):
			DirAccess.remove_absolute(AccountStore.SAVE_PATH)
		return
	var file := FileAccess.open(AccountStore.SAVE_PATH, FileAccess.WRITE)
	file.store_string(str(backup))
