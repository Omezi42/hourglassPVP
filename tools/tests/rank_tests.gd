extends RefCounted

## ランクマッチ(GameDesign.md 28章)の通信を伴わない部分——段位表・星取り制の昇格・
## プラチナのレート増減・シーズンキーの計算——を検証する。
## `run_tests.gd`が1000行の上限に近いため別ファイルへ切り出す(他のtestsと同じ流儀)。


func run(assert_true: Callable) -> void:
	_test_parse_and_display(assert_true)
	_test_star_advancement(assert_true)
	_test_rating_delta(assert_true)
	_test_compare_tier(assert_true)
	_test_season_key(assert_true)


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
