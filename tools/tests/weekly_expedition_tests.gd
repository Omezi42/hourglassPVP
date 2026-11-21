class_name WeeklyExpeditionTests
extends RefCounted
## 週替わりの遠征(GameDesign.md 27章「週替わりの遠征」、Architecture.md 10.15節)の検証。
## 週の区切り・同じ週と同じ選び方なら同じ道と候補・別枠の保存・深さの解放を更新しないこと。

const WEEK_A := "2026-11-16"
const WEEK_B := "2026-11-23"
const UID := "weekly_test_uid"

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_week_changes_at_monday_midnight_jst()
	_test_same_week_makes_the_same_run()
	_test_different_weeks_make_different_runs()
	_test_same_choices_get_the_same_offers()
	_test_weekly_id_round_trips_through_dict()
	_test_weekly_run_is_saved_apart_from_the_normal_run()
	_test_new_week_closes_the_unfinished_run()
	_test_weekly_run_interrupted_in_battle_ends_as_a_loss()
	_test_end_weekly_run_keeps_the_result_and_the_record_once()
	_test_weekly_clear_does_not_unlock_depth()
	_test_normal_clear_still_unlocks_depth()
	_test_board_rank_lookup()


func _utc(year: int, month: int, day: int, hour: int, minute: int, second: int) -> float:
	return Time.get_unix_time_from_datetime_dict(
		{"year": year, "month": month, "day": day, "hour": hour, "minute": minute, "second": second}
	)


func _first_open(run: SoloRun) -> int:
	return SoloRun.open_rows(run.route, run.floor, run.chosen)[0]


func _test_week_changes_at_monday_midnight_jst() -> void:
	# 日本時間の日曜23:59:59(UTC 14:59:59)はまだ前の週、月曜0:00(UTC 15:00:00)から次の週。
	_assert.call(
		WeeklyExpedition.week_of(_utc(2026, 11, 22, 14, 59, 59)) == WEEK_A,
		"Sunday 23:59:59 JST still belongs to the week of 2026-11-16"
	)
	_assert.call(
		WeeklyExpedition.week_of(_utc(2026, 11, 22, 15, 0, 0)) == WEEK_B,
		"Monday 0:00 JST starts the next week"
	)
	_assert.call(
		WeeklyExpedition.week_of(_utc(2026, 11, 16, 0, 0, 0)) == WEEK_A,
		"Monday 9:00 JST is in the week of that Monday"
	)
	_assert.call(
		WeeklyExpedition.week_of(_utc(2026, 11, 15, 15, 0, 0)) == WEEK_A,
		"Monday 0:00 JST (UTC Sunday 15:00) is already in that Monday's week"
	)
	_assert.call(
		WeeklyExpedition.week_of(_utc(2026, 11, 18, 3, 0, 0)) == WEEK_A,
		"midweek stays in the same week"
	)


func _test_same_week_makes_the_same_run() -> void:
	var first := WeeklyExpedition.create_run(WEEK_A)
	var second := WeeklyExpedition.create_run(WEEK_A)
	_assert.call(first.to_dict() == second.to_dict(), "the same week makes the same run")
	_assert.call(first.weekly_id == WEEK_A, "the run remembers its week")
	_assert.call(first.depth == WeeklyExpedition.DEPTH, "the depth is fixed at 2")
	_assert.call(
		first.theme_id == WeeklyExpedition.theme_of(WEEK_A), "the theme comes from the week"
	)
	_assert.call(not first.boss_id.is_empty(), "the week has a boss")


func _test_different_weeks_make_different_runs() -> void:
	var first := WeeklyExpedition.create_run(WEEK_A)
	var second := WeeklyExpedition.create_run(WEEK_B)
	_assert.call(first.to_dict() != second.to_dict(), "another week makes another run")
	_assert.call(
		WeeklyExpedition.seed_of(WEEK_A) != WeeklyExpedition.seed_of(WEEK_B),
		"the seed follows the week"
	)
	var a := WeeklyExpedition.rng_for(WEEK_A, "offer:0")
	var b := WeeklyExpedition.rng_for(WEEK_A, "offer:1")
	_assert.call(a.randi() != b.randi(), "the salt changes the stream")


func _test_same_choices_get_the_same_offers() -> void:
	var seen: Array = []
	for _i in 2:
		var run := WeeklyExpedition.create_run(WEEK_A)
		run.choose(_first_open(run), WeeklyExpedition.rng_for(WEEK_A, "c"))
		run.finish_battle(true, 20, WeeklyExpedition.rng_for(WEEK_A, "offer:0"))
		seen.append(run.offer.duplicate(true))
		seen.append(run.boon_offer.duplicate())
		run.pass_offer()
		run.boon_offer = []
		seen.append(run.route.duplicate(true))
	_assert.call(seen[0] == seen[3], "the same choices see the same bundles")
	_assert.call(seen[1] == seen[4], "the same choices see the same boons")
	_assert.call(seen[2] == seen[5], "the same week has the same road")


func _test_weekly_id_round_trips_through_dict() -> void:
	var run := WeeklyExpedition.create_run(WEEK_A)
	_assert.call(SoloRun.from_dict(run.to_dict()).weekly_id == WEEK_A, "weekly_id round-trips")
	var legacy := run.to_dict()
	legacy.erase("weekly_id")
	_assert.call(SoloRun.from_dict(legacy).weekly_id == "", "an old save is a normal run")
	_assert.call(
		SoloRun.create("rush", 0, RandomNumberGenerator.new()).weekly_id == "",
		"normal runs have no week"
	)


func _test_weekly_run_is_saved_apart_from_the_normal_run() -> void:
	SoloProgress.reset_for_test()
	var run := WeeklyExpedition.create_run(WEEK_A)
	SoloProgress.save_run(UID, run)
	_assert.call(SoloProgress.load_run(UID) == null, "the normal slot stays empty")
	var loaded := SoloProgress.weekly_run(UID, WEEK_A)
	_assert.call(
		loaded != null and loaded.to_dict() == run.to_dict(), "the weekly run is read back"
	)
	var normal := SoloRun.create("rush", 0, RandomNumberGenerator.new())
	SoloProgress.save_run(UID, normal)
	_assert.call(
		SoloProgress.weekly_run(UID, WEEK_A) != null, "saving a normal run leaves the weekly one"
	)
	_assert.call(SoloProgress.load_run(UID) != null, "and the normal run is its own")
	SoloProgress.reset_for_test()


func _test_new_week_closes_the_unfinished_run() -> void:
	SoloProgress.reset_for_test()
	var run := WeeklyExpedition.create_run(WEEK_A)
	run.wins = 2
	SoloProgress.save_run(UID, run)
	_assert.call(SoloProgress.weekly_run(UID, WEEK_B) == null, "the old run is not carried over")
	_assert.call(SoloProgress.weekly_result(UID, WEEK_B).is_empty(), "the new week starts fresh")
	_assert.call(SoloProgress.weekly_run(UID, WEEK_A) == null, "the old week's run is gone")
	SoloProgress.reset_for_test()


func _test_weekly_run_interrupted_in_battle_ends_as_a_loss() -> void:
	SoloProgress.reset_for_test()
	var run := WeeklyExpedition.create_run(WEEK_A)
	run.choose(_first_open(run), WeeklyExpedition.rng_for(WEEK_A, "c"))
	_assert.call(run.in_battle, "the run is in a battle")
	SoloProgress.save_run(UID, run)
	_assert.call(SoloProgress.weekly_run(UID, WEEK_A) == null, "an interrupted battle ends the run")
	var result := SoloProgress.weekly_result(UID, WEEK_A)
	_assert.call(
		int(result.get("wins", -1)) == 0 and int(result.get("hp", -1)) == 0, "as a loss with 0 HP"
	)
	_assert.call(
		(
			str(SoloProgress.take_weekly_finished(UID, WEEK_A).get("reason", ""))
			== SoloProgress.ABANDONED_MID_BATTLE
		),
		"and the record says why"
	)
	SoloProgress.reset_for_test()


func _test_end_weekly_run_keeps_the_result_and_the_record_once() -> void:
	SoloProgress.reset_for_test()
	var run := WeeklyExpedition.create_run(WEEK_A)
	run.wins = 3
	run.hp = 11
	run.over = true
	SoloProgress.end_run(UID, run, "")
	var result := SoloProgress.weekly_result(UID, WEEK_A)
	_assert.call(
		int(result.get("wins", -1)) == 3 and int(result.get("hp", -1)) == 11, "the result is kept"
	)
	_assert.call(SoloProgress.weekly_run(UID, WEEK_A) == null, "no run is left to continue")
	_assert.call(
		not SoloProgress.take_weekly_finished(UID, WEEK_A).is_empty(), "the record comes out once"
	)
	_assert.call(SoloProgress.take_weekly_finished(UID, WEEK_A).is_empty(), "and not twice")
	_assert.call(SoloProgress.take_finished(UID).is_empty(), "the normal record is untouched")
	_assert.call(SoloProgress.weekly_result(UID, WEEK_B).is_empty(), "the next week has no result")
	SoloProgress.reset_for_test()


func _test_weekly_clear_does_not_unlock_depth() -> void:
	SoloProgress.reset_for_test()
	var run := WeeklyExpedition.create_run(WEEK_A)
	run.wins = SoloRun.FLOOR_COUNT
	run.cleared = true
	run.over = true
	SoloProgress.record(UID, run)
	_assert.call(SoloProgress.unlocked_depth(UID) == 0, "the selectable depth is not raised")
	_assert.call(
		SoloProgress.theme_best_depth(UID, run.theme_id) == -1, "the theme's deepest clear stays"
	)
	_assert.call(SoloProgress.best_wins(UID) == SoloRun.FLOOR_COUNT, "the best win count counts")
	_assert.call(SoloProgress.clears(UID) == 1, "the clear count counts")
	SoloProgress.reset_for_test()


func _test_normal_clear_still_unlocks_depth() -> void:
	SoloProgress.reset_for_test()
	var run := SoloRun.create("rush", 0, RandomNumberGenerator.new())
	run.wins = SoloRun.FLOOR_COUNT
	run.cleared = true
	run.over = true
	SoloProgress.record(UID, run)
	_assert.call(SoloProgress.unlocked_depth(UID) == 1, "a normal clear raises the depth")
	SoloProgress.reset_for_test()


func _test_board_rank_lookup() -> void:
	var rows: Array = [{"uid": "a"}, {"uid": "b"}, {"uid": "c"}]
	_assert.call(WeeklyBoard.rank_in(rows, "b") == 2, "rank is the 1-based position")
	_assert.call(WeeklyBoard.rank_in(rows, "z") == 0, "outside the list is 0")
	_assert.call(WeeklyBoard.rank_in(rows, "") == 0, "no uid is 0")
