extends RefCounted

## ランクマッチ(GameDesign.md 28章)の検証。前半は通信を伴わない部分(段位表・
## 星取り制の昇格・プラチナのレート増減・シーズンキーの計算)、後半は
## `FakeFirestoreClient`を使って`RankProgress`の読み書きを実通信なしで確かめる
## (`online_match_flow_tests.gd`と同じ流儀)。
## `run_tests.gd`が1000行の上限に近いため別ファイルへ切り出す(他のtestsと同じ流儀)。

const FakeClient = preload("res://tools/tests/fake_firestore_client.gd")


func run(assert_true: Callable) -> void:
	_test_parse_and_display(assert_true)
	_test_star_advancement(assert_true)
	_test_rating_delta(assert_true)
	_test_compare_tier(assert_true)
	_test_season_key(assert_true)
	_test_progress_score(assert_true)
	await _test_apply_result_star_progress(assert_true)
	await _test_apply_result_reaches_platinum(assert_true)
	await _test_ensure_current_season_resets_and_grants_reward(assert_true)
	await _test_ensure_current_season_first_time_has_no_ceremony(assert_true)


func _test_parse_and_display(assert_true: Callable) -> void:
	assert_true.call(RankRules.is_valid_tier("bronze1"), "bronze1 should be a valid tier")
	assert_true.call(RankRules.is_valid_tier("gold5"), "gold5 should be a valid tier")
	assert_true.call(RankRules.is_valid_tier("platinum"), "platinum should be a valid tier")
	assert_true.call(not RankRules.is_valid_tier("bronze4"), "bronze only has 3 steps")
	assert_true.call(not RankRules.is_valid_tier("mythril1"), "an unknown bracket is invalid")
	assert_true.call(
		RankRules.display_name("bronze1") == "ブロンズ1", "bronze1 should display as ブロンズ1"
	)
	assert_true.call(
		RankRules.display_name("platinum") == "プラチナ", "platinum should display as プラチナ"
	)


func _test_star_advancement(assert_true: Callable) -> void:
	# ブロンズは★2個で昇格(GameDesign.md 28章)
	var not_yet := RankRules.advance_stars("bronze1", 1)
	assert_true.call(
		not_yet["tier"] == "bronze1" and not_yet["stars"] == 1,
		"one star below the requirement should not advance"
	)
	var advanced := RankRules.advance_stars("bronze1", 2)
	assert_true.call(
		advanced["tier"] == "bronze2" and advanced["stars"] == 0,
		"reaching the star requirement should advance to the next step and reset stars"
	)
	# 帯をまたぐ昇格(ブロンズ3 → シルバー1)
	var cross_bracket := RankRules.advance_stars("bronze3", 2)
	assert_true.call(
		cross_bracket["tier"] == "silver1",
		"advancing past the top step of a bracket should move to the next bracket"
	)
	# ゴールド5から★4個でプラチナへ(GameDesign.md 28章)
	var to_platinum := RankRules.advance_stars("gold5", 4)
	assert_true.call(
		to_platinum["tier"] == RankRules.PLATINUM_KEY,
		"reaching the star requirement at gold5 should promote to platinum"
	)
	assert_true.call(RankRules.retreat_stars(0) == 0, "stars should not go below zero on a loss")
	assert_true.call(RankRules.retreat_stars(2) == 1, "a loss should remove one star")
	assert_true.call(RankRules.star_requirement("bronze1") == 2, "bronze should require 2 stars")
	assert_true.call(RankRules.star_requirement("gold3") == 4, "gold should require 4 stars")


func _test_rating_delta(assert_true: Callable) -> void:
	assert_true.call(
		RankRules.rating_delta(1000, true) == 16, "the lowest rating band should award +16 on a win"
	)
	assert_true.call(
		RankRules.rating_delta(1000, false) == -8, "the lowest rating band should cost -8 on a loss"
	)
	assert_true.call(
		RankRules.rating_delta(1650, true) == 4, "1600+ should be capped at +4 on a win"
	)
	assert_true.call(
		RankRules.rating_delta(1650, false) == -20, "1600+ should be capped at -20 on a loss"
	)
	# レートが100上がるごとに勝利側-2・敗北側-2(絶対値では+2)
	assert_true.call(
		RankRules.rating_delta(1250, true) == 12, "the 1200-1299 band should award +12 on a win"
	)
	assert_true.call(
		RankRules.rating_delta(1250, false) == -12, "the 1200-1299 band should cost -12 on a loss"
	)
	# 降格はしないため、下限のない値でも最下段の増減を使う
	assert_true.call(
		RankRules.rating_delta(950, true) == 16, "below 1000 should still use the lowest band"
	)


func _test_compare_tier(assert_true: Callable) -> void:
	assert_true.call(
		RankRules.compare_tier("silver1", "bronze3") > 0, "silver should outrank bronze"
	)
	assert_true.call(RankRules.compare_tier("gold1", "silver4") > 0, "gold should outrank silver")
	assert_true.call(
		RankRules.compare_tier(RankRules.PLATINUM_KEY, "gold5") > 0, "platinum should outrank gold"
	)
	assert_true.call(
		RankRules.compare_tier("bronze2", "bronze2") == 0, "the same tier should compare equal"
	)
	assert_true.call(
		RankRules.compare_tier("bronze1", "bronze2") < 0, "bronze1 should rank below bronze2"
	)
	assert_true.call(
		RankRules.bracket_of("gold3") == "gold", "bracket_of should return the bracket name"
	)
	assert_true.call(
		RankRules.bracket_of(RankRules.PLATINUM_KEY) == RankRules.PLATINUM_KEY,
		"bracket_of platinum should return platinum itself"
	)


## シーズンキーはJST基準の年月("2026-09")。月をまたぐ境目を確かめる
## (SundayEventRulesのJST換算テストと同じ考え方)。
func _test_season_key(assert_true: Callable) -> void:
	var august_jst_end := Time.get_unix_time_from_datetime_string("2026-08-31T14:59:00")
	assert_true.call(
		RankProgress.current_season_key(august_jst_end) == "2026-08",
		"23:59 JST on the last day of august should still be august"
	)
	var september_jst_start := Time.get_unix_time_from_datetime_string("2026-08-31T15:00:00")
	assert_true.call(
		RankProgress.current_season_key(september_jst_start) == "2026-09",
		"00:00 JST on september 1st should already be september"
	)


## 合成スコア(GameDesign.md 28章「進行度でもランクに残る」)。ブロンズ〜ゴールドの
## 帯・階級・★とプラチナのレートが、単調に増える1本の順序として並ぶこと。
func _test_progress_score(assert_true: Callable) -> void:
	assert_true.call(
		RankRules.progress_score("bronze1", 0, 0) < RankRules.progress_score("bronze1", 1, 0),
		"more stars at the same tier should score higher"
	)
	assert_true.call(
		RankRules.progress_score("bronze3", 1, 0) < RankRules.progress_score("silver1", 0, 0),
		"the lowest silver step should outscore the highest bronze step regardless of stars"
	)
	assert_true.call(
		RankRules.progress_score("silver4", 2, 0) < RankRules.progress_score("gold1", 0, 0),
		"crossing a bracket should always outscore staying in the previous one"
	)
	assert_true.call(
		(
			RankRules.progress_score("gold5", 3, 0)
			< RankRules.progress_score(RankRules.PLATINUM_KEY, 0, 0)
		),
		"the lowest platinum score should outscore the highest gold score"
	)
	assert_true.call(
		(
			RankRules.progress_score(RankRules.PLATINUM_KEY, 0, 1000)
			< RankRules.progress_score(RankRules.PLATINUM_KEY, 0, 1200)
		),
		"a higher platinum rating should score higher"
	)


func _make_client() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var auth := FirebaseAuth.new(null)
	auth.uid = "uid-rank-test"
	var client = FakeClient.new(auth)
	tree.root.add_child(client)
	return {"client": client, "host": tree.root, "uid": auth.uid}


## 星取り制の昇格が`players/{uid}`へ正しく書き戻され、`AccountService`のキャッシュへも
## 反映されること(GameDesign.md 28章「ブロンズ1〜3はブロンズは★2個で昇格」)。
func _test_apply_result_star_progress(assert_true: Callable) -> void:
	AccountService.reset()
	var setup := _make_client()
	var client = setup["client"]
	var host: Node = setup["host"]
	var uid: String = setup["uid"]
	var path := AccountService.path(uid)

	# 手数が足りない対局は段位を動かさない(15章と同じ不正対策)。
	await RankProgress.apply_result(client, host, uid, true, RankProgress.MIN_MOVES - 1)
	assert_true.call(
		not client.store.has(path), "a match under the minimum move count should not write anything"
	)

	await RankProgress.apply_result(client, host, uid, true, RankProgress.MIN_MOVES)
	assert_true.call(
		AccountService.rank_tier() == "bronze1" and AccountService.rank_stars() == 1,
		"a first win from bronze1 should award one star without advancing yet"
	)

	await RankProgress.apply_result(client, host, uid, true, RankProgress.MIN_MOVES)
	assert_true.call(
		AccountService.rank_tier() == "bronze2" and AccountService.rank_stars() == 0,
		"reaching bronze's star requirement should advance to bronze2 and reset stars"
	)
	assert_true.call(
		AccountService.rank_peak_tier() == "bronze2",
		"the peak tier should track the highest tier reached this season"
	)
	assert_true.call(
		AccountService.rank_progress_score() == RankRules.progress_score("bronze2", 0, 0),
		"the progress score should follow the star-based tier too"
	)

	await RankProgress.apply_result(client, host, uid, false, RankProgress.MIN_MOVES)
	assert_true.call(
		AccountService.rank_tier() == "bronze2" and AccountService.rank_stars() == 0,
		"a loss with zero stars should not push the tier back down further"
	)

	client.queue_free()


## ゴールド5から★4個でプラチナへ昇格し、以後はレートが増減すること(GameDesign.md 28章)。
func _test_apply_result_reaches_platinum(assert_true: Callable) -> void:
	AccountService.reset()
	var setup := _make_client()
	var client = setup["client"]
	var host: Node = setup["host"]
	var uid: String = setup["uid"]
	var path := AccountService.path(uid)
	client.store[path] = {
		"fields": {"rank_tier": "gold5", "rank_stars": 3, "rank_peak_tier": "gold5"},
		"update_time": "1"
	}

	await RankProgress.apply_result(client, host, uid, true, RankProgress.MIN_MOVES)
	assert_true.call(
		AccountService.rank_tier() == RankRules.PLATINUM_KEY,
		"reaching gold5's star requirement should promote to platinum"
	)
	assert_true.call(
		AccountService.rank_rating() == RankRules.PLATINUM_START_RATING,
		"the first platinum rating should start at the platinum floor"
	)
	assert_true.call(
		AccountService.rank_peak_tier() == RankRules.PLATINUM_KEY, "the peak tier should follow"
	)
	assert_true.call(
		(
			AccountService.rank_progress_score()
			== RankRules.progress_score(RankRules.PLATINUM_KEY, 0, RankRules.PLATINUM_START_RATING)
		),
		"the progress score should be written alongside the platinum promotion"
	)

	await RankProgress.apply_result(client, host, uid, true, RankProgress.MIN_MOVES)
	assert_true.call(
		(
			AccountService.rank_rating()
			== RankRules.PLATINUM_START_RATING + RankRules.rating_delta(1000, true)
		),
		"a platinum win should move the rating by the table's delta"
	)

	var before_loss := AccountService.rank_rating()
	await RankProgress.apply_result(client, host, uid, false, RankProgress.MIN_MOVES)
	assert_true.call(
		AccountService.rank_rating() < before_loss, "a platinum loss should lower the rating"
	)
	assert_true.call(
		AccountService.rank_tier() == RankRules.PLATINUM_KEY,
		"platinum should never drop back to a star-based tier (no demotion)"
	)

	client.queue_free()


## シーズンが変わると、未受領の月末報酬(帯に応じた額)を払ってから段位を初期化すること
## (GameDesign.md 28章)。
func _test_ensure_current_season_resets_and_grants_reward(assert_true: Callable) -> void:
	AccountService.reset()
	var setup := _make_client()
	var client = setup["client"]
	var host: Node = setup["host"]
	var uid: String = setup["uid"]
	var path := AccountService.path(uid)
	client.store[path] = {
		"fields":
		{
			"rank_season": "2026-08",
			"rank_tier": "gold3",
			"rank_stars": 2,
			"rank_peak_tier": "gold3",
			"rank_reward_claimed_season": "",
			"currency": 100
		},
		"update_time": "1"
	}
	# 実際の経路(`NetSession.sign_in()`)ではサインインの時点で`load_profile()`が
	# キャッシュを埋めてから`ensure_current_season()`が呼ばれる。`AccountService`は
	# 読み込み先をキャッシュに頼るため、テストでもこの順序を再現する。
	await AccountService.load_profile(client, uid)
	var september := Time.get_unix_time_from_datetime_string("2026-09-01T12:00:00")

	var result := await RankProgress.ensure_current_season(client, uid, september)
	assert_true.call(
		AccountService.rank_season() == "2026-09", "the season key should move to the new month"
	)
	assert_true.call(
		bool(result.get("transitioned", false)),
		"a returning player crossing into a new season should be flagged for the ceremony"
	)
	assert_true.call(
		str(result.get("peak_tier", "")) == "gold3",
		"the ceremony result should carry the peak tier reached last season"
	)
	assert_true.call(
		int(result.get("reward", 0)) == RankProgress.SEASON_REWARDS["gold"],
		"the ceremony result should carry the amount actually paid out"
	)
	assert_true.call(
		AccountService.rank_tier() == RankRules.INITIAL_TIER,
		"a new season should reset the tier to bronze1"
	)
	assert_true.call(
		AccountService.rank_stars() == 0, "a new season should reset the stars to zero"
	)
	assert_true.call(
		AccountService.rank_peak_tier() == RankRules.INITIAL_TIER,
		"a new season should reset the peak tier too"
	)
	assert_true.call(
		AccountService.rank_reward_claimed_season() == "2026-08",
		"the reward should be marked claimed for the season it was earned in"
	)
	assert_true.call(
		AccountService.currency() == 100 + RankProgress.SEASON_REWARDS["gold"],
		"a gold peak should pay out the gold season reward"
	)

	# 同じシーズン内で再度呼んでも、二重に払わない(rank_reward_claimed_seasonが
	# rank_seasonと一致しているため、次にまたがるまで何もしない)。
	await RankProgress.ensure_current_season(client, uid, september)
	assert_true.call(
		AccountService.currency() == 100 + RankProgress.SEASON_REWARDS["gold"],
		"calling ensure_current_season again within the same season should not pay twice"
	)

	client.queue_free()


## 一度もランクマッチを触ったことが無いプレイヤー(前のシーズンが存在しない)は、
## 段位こそブロンズ1へ初期化されるが、表彰演出の対象にはならない
## (GameDesign.md 28章「月初の表彰演出」。ブロンズ1到達を祝う演出は空虚なため)。
func _test_ensure_current_season_first_time_has_no_ceremony(assert_true: Callable) -> void:
	AccountService.reset()
	var setup := _make_client()
	var client = setup["client"]
	var uid: String = setup["uid"]
	var september := Time.get_unix_time_from_datetime_string("2026-09-01T12:00:00")

	var result := await RankProgress.ensure_current_season(client, uid, september)
	assert_true.call(
		AccountService.rank_season() == "2026-09",
		"a brand new player should still be initialized into the current season"
	)
	assert_true.call(
		not bool(result.get("transitioned", false)),
		"a brand new player should not be flagged for the season ceremony"
	)
	assert_true.call(
		AccountService.currency() == 0, "a brand new player should not receive a season reward"
	)

	client.queue_free()
