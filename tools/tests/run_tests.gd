extends SceneTree
## テストの入口。個々のスイートは別ファイルへ切り出し、ここは呼び出しと判定だけを持つ
## (このファイルが1000行の上限に達した経緯があるため)。
const SoundSettingsTests = preload("res://tools/tests/sound_settings_tests.gd")
const OnlineTests = preload("res://tools/tests/online_tests.gd")
const OnlineMatchFlowTests = preload("res://tools/tests/online_match_flow_tests.gd")
const AccountTests = preload("res://tools/tests/account_tests.gd")
const AccountServiceTests = preload("res://tools/tests/account_service_tests.gd")
const ReadFailureTests = preload("res://tools/tests/read_failure_tests.gd")
const V5RulesTests = preload("res://tools/tests/v5_rules_tests.gd")
const V5VocabularyTests = preload("res://tools/tests/v5_vocabulary_tests.gd")
const StillTimeTests = preload("res://tools/tests/still_time_tests.gd")
const GraveSandTests = preload("res://tools/tests/grave_sand_tests.gd")
const EchoTimeTests = preload("res://tools/tests/echo_time_tests.gd")
const ChaseSandTests = preload("res://tools/tests/chase_sand_tests.gd")
const EffectChainSweepTests = preload("res://tools/tests/effect_chain_sweep_tests.gd")
const V5OnlineTests = preload("res://tools/tests/v5_online_tests.gd")
const VersionMatchTests = preload("res://tools/tests/version_match_tests.gd")
const WaitingCpuTests = preload("res://tools/tests/waiting_cpu_tests.gd")
const MatchmakingFlowTests = preload("res://tools/tests/matchmaking_flow_tests.gd")
const HourglassArtTests = preload("res://tools/tests/hourglass_art_tests.gd")
const CardSkinsTests = preload("res://tools/tests/card_skins_tests.gd")
const MatchRecordTests = preload("res://tools/tests/match_record_tests.gd")
const PuzzleMissionTests = preload("res://tools/tests/puzzle_mission_tests.gd")
const EndlessPuzzleTests = preload("res://tools/tests/endless_puzzle_tests.gd")
const DailyPuzzleTests = preload("res://tools/tests/daily_puzzle_tests.gd")
const MatchFxTests = preload("res://tools/tests/match_fx_tests.gd")
const UiPaintTests = preload("res://tools/tests/ui_paint_tests.gd")
const CpuDifficultyTests = preload("res://tools/tests/cpu_difficulty_tests.gd")
const SoloModeTests = preload("res://tools/tests/solo_mode_tests.gd")
const SoloStrategyTests = preload("res://tools/tests/solo_strategy_tests.gd")
const RankTests = preload("res://tools/tests/rank_tests.gd")
const MatchStatsSyncTests = preload("res://tools/tests/match_stats_sync_tests.gd")
const FunnelTests = preload("res://tools/tests/funnel_tests.gd")
const PlayTimeTests = preload("res://tools/tests/play_time_tests.gd")
const TutorialScriptTests = preload("res://tools/tests/tutorial_script_tests.gd")
const CpuDeckTests = preload("res://tools/tests/cpu_deck_tests.gd")
const CardSetTests = preload("res://tools/tests/card_set_tests.gd")
const FirstDaysTests = preload("res://tools/tests/first_days_tests.gd")
const TurnForecastTests = preload("res://tools/tests/turn_forecast_tests.gd")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_match_clock_ticks_down_and_times_out()
	_test_match_clock_resets_only_when_the_turn_changes_sides()
	V5RulesTests.new().run(_assert_true)
	V5VocabularyTests.new().run(_assert_true)
	StillTimeTests.new().run(_assert_true)
	GraveSandTests.new().run(_assert_true)
	EchoTimeTests.new().run(_assert_true)
	ChaseSandTests.new().run(_assert_true)
	EffectChainSweepTests.new().run(_assert_true)
	TurnForecastTests.new().run(_assert_true)
	V5SpellTests.new().run(_assert_true)
	EmblemFxTests.new().run(_assert_true)
	HourglassArtTests.new().run(_assert_true)
	CardSkinsTests.new().run(_assert_true)
	PuzzleMissionTests.new().run(_assert_true)
	EndlessPuzzleTests.new().run(_assert_true)
	DailyPuzzleTests.new().run(_assert_true)
	MatchFxTests.new().run(_assert_true)
	UiPaintTests.new().run(_assert_true)
	CpuDifficultyTests.new().run(_assert_true)
	SoloModeTests.new().run(_assert_true)
	SoloStrategyTests.new().run(_assert_true)
	var rank_tests := RankTests.new()
	await rank_tests.run(_assert_true)
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
	var matchmaking_flow := MatchmakingFlowTests.new()
	await matchmaking_flow.run(_assert_true)
	var match_records := MatchRecordTests.new()
	await match_records.run(_assert_true)
	await MatchStatsSyncTests.new().run(_assert_true)
	await FunnelTests.new().run(_assert_true)
	await PlayTimeTests.new().run(_assert_true)
	var waiting_cpu := WaitingCpuTests.new()
	await waiting_cpu.run(_assert_true)
	TutorialScriptTests.new().run(_assert_true)
	CpuDeckTests.new().run(_assert_true)
	CardSetTests.new().run(_assert_true)
	var first_days := FirstDaysTests.new()
	await first_days.run(_assert_true)
	var account_service := AccountServiceTests.new()
	await account_service.run(_assert_true)
	var read_failure := ReadFailureTests.new()
	await read_failure.run(_assert_true)

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


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("assert failed: ", message)
