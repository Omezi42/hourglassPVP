extends SceneTree
## テストの入口。個々のスイートは別ファイルへ切り出し、ここは呼び出しと判定だけを持つ
## (このファイルが1000行の上限に達した経緯があるため)。
const SoundSettingsTests = preload("res://tools/tests/sound_settings_tests.gd")
const OnlineTests = preload("res://tools/tests/online_tests.gd")
const OnlineMatchFlowTests = preload("res://tools/tests/online_match_flow_tests.gd")
const AccountTests = preload("res://tools/tests/account_tests.gd")
const V5RulesTests = preload("res://tools/tests/v5_rules_tests.gd")
const V5VocabularyTests = preload("res://tools/tests/v5_vocabulary_tests.gd")
const V5OnlineTests = preload("res://tools/tests/v5_online_tests.gd")
const VersionMatchTests = preload("res://tools/tests/version_match_tests.gd")
const HourglassArtTests = preload("res://tools/tests/hourglass_art_tests.gd")
const MatchRecordTests = preload("res://tools/tests/match_record_tests.gd")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_match_clock_ticks_down_and_times_out()
	_test_match_clock_resets_only_when_the_turn_changes_sides()
	_test_local_replay_service_round_trips_and_enforces_retention()
	V5RulesTests.new().run(_assert_true)
	V5VocabularyTests.new().run(_assert_true)
	V5SpellTests.new().run(_assert_true)
	HourglassArtTests.new().run(_assert_true)
	SoundSettingsTests.new().run(_assert_true)
	OnlineTests.new().run(_assert_true)
	AccountTests.new().run(_assert_true)
	# 送受信の流れだけはawaitを挟むため、コルーチンの実行中に解放されないよう参照を持つ
	var flow_tests := OnlineMatchFlowTests.new()
	await flow_tests.run(_assert_true)
	var v5_online := V5OnlineTests.new()
	await v5_online.run(_assert_true)
	var version_match := VersionMatchTests.new()
	await version_match.run(_assert_true)
	var match_records := MatchRecordTests.new()
	await match_records.run(_assert_true)

	if _failures == 0:
		print("tests passed")
		quit(0)
	else:
		printerr("tests failed: ", _failures)
		quit(1)


func _test_match_clock_ticks_down_and_times_out() -> void:
	var clock := MatchClock.new(10.0)
	clock.start_turn(MatchState.Side.A)
	var timed_out_side := [-1]
	clock.time_out.connect(func(side: int) -> void: timed_out_side[0] = side)

	clock.tick(4.0)
	_assert_true(
		clock.get_remaining(MatchState.Side.A) == 6.0, "tick should subtract delta from remaining"
	)
	_assert_true(timed_out_side[0] == -1, "time_out should not fire before remaining reaches 0")

	clock.tick(10.0)
	_assert_true(clock.get_remaining(MatchState.Side.A) == 0.0, "remaining should clamp at 0")
	_assert_true(timed_out_side[0] == MatchState.Side.A, "time_out should fire for the active side")
	_assert_true(not clock.running, "clock should stop running after timing out")


## 持ち時間は1手番ぶん(GameDesign.md 5章)。手番が移ったときだけ戻し、
## 同じ手番のうちに何度も指しても戻さない(戻すと指し続ける限り尽きなくなる)。
func _test_match_clock_resets_only_when_the_turn_changes_sides() -> void:
	var clock := MatchClock.new(10.0)
	clock.start_turn(MatchState.Side.A)
	clock.tick(3.0)
	clock.start_turn(MatchState.Side.A)
	_assert_true(
		clock.get_remaining(MatchState.Side.A) == 7.0,
		"playing again in the same turn should not refill the clock"
	)
	clock.start_turn(MatchState.Side.B)
	_assert_true(clock.active_side == MatchState.Side.B, "the clock should follow the new turn")
	_assert_true(
		clock.get_remaining(MatchState.Side.B) == 10.0, "a new turn should refill that side"
	)
	_assert_true(
		clock.get_remaining(MatchState.Side.A) == 7.0, "the side that just moved keeps its value"
	)
	clock.tick(10.0)
	clock.start_turn(MatchState.Side.A)
	_assert_true(clock.get_remaining(MatchState.Side.A) == 10.0, "coming back around refills again")


func _test_local_replay_service_round_trips_and_enforces_retention() -> void:
	var backup: Variant = _backup_local_replay_save()

	var file := FileAccess.open(LocalReplayService.SAVE_PATH, FileAccess.WRITE)
	file.store_string("[]")
	file = null

	(
		LocalReplayService
		. mark_finished(
			{
				"deck_a": ["sand", "sword", "king", "wall", "shield"],
				"deck_b": ["dash", "echo", "mirror", "eye", "judge"],
				"placement_a": ["sand", "sword", "king"],
				"placement_b": ["dash", "echo", "mirror"],
				"actions": [{"type": "flip", "actor": 0, "side": 0, "position": 0}],
				"winner": "a",
			}
		)
	)
	var replays: Array[Dictionary] = LocalReplayService.list_replays()
	_assert_true(replays.size() == 1, "should save exactly 1 cpu replay")
	if replays.size() == 1:
		var fields: Dictionary = replays[0]["fields"]
		_assert_true(
			fields["deck_a"] == ["sand", "sword", "king", "wall", "shield"],
			"deck_a should round-trip"
		)
		_assert_true(fields["winner"] == "a", "winner should round-trip")
		_assert_true(fields["source"] == "cpu", "source should be tagged as cpu")
		var fetched: Dictionary = LocalReplayService.get_replay(str(replays[0]["id"]))
		_assert_true(
			fetched.get("actions", []).size() == 1, "get_replay should return the same actions"
		)

	for i in range(LocalReplayService.RETENTION_LIMIT + 5):
		LocalReplayService.mark_finished(
			{
				"deck_a": [],
				"deck_b": [],
				"placement_a": [],
				"placement_b": [],
				"actions": [],
				"winner": "b"
			}
		)
	var after_overflow: Array[Dictionary] = LocalReplayService.list_replays()
	_assert_true(
		after_overflow.size() == LocalReplayService.RETENTION_LIMIT,
		"should cap saved replays at RETENTION_LIMIT"
	)

	_restore_local_replay_save(backup)


func _backup_local_replay_save() -> Variant:
	if not FileAccess.file_exists(LocalReplayService.SAVE_PATH):
		return null
	var file := FileAccess.open(LocalReplayService.SAVE_PATH, FileAccess.READ)
	var content := file.get_as_text()
	file = null
	return content


func _restore_local_replay_save(backup: Variant) -> void:
	if backup == null:
		if FileAccess.file_exists(LocalReplayService.SAVE_PATH):
			DirAccess.remove_absolute(LocalReplayService.SAVE_PATH)
		return
	var file := FileAccess.open(LocalReplayService.SAVE_PATH, FileAccess.WRITE)
	file.store_string(str(backup))


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("assert failed: ", message)
