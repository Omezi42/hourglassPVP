extends SceneTree

## 音量設定まわりのテストは、このファイルが1000行の上限(gdlintのmax-file-lines)に
## 達したため別ファイルへ切り出している。判定は_assert_trueをCallableで渡して共有する。
const SoundSettingsTests = preload("res://tools/tests/sound_settings_tests.gd")
const CpuStrategyTests = preload("res://tools/tests/cpu_strategy_tests.gd")

var _failures := 0
var _hourglass_cache: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_all_hourglass_resources_load()
	_test_hourglass_instance_flip_and_advance()

	_test_positions_have_no_damage_bonus()
	_test_flip_resets_state()
	_test_move_swaps_positions()
	_test_swap_in_brings_bench_piece_upright()
	_test_start_states_differ_by_position()
	_test_first_turn_end_drops_only_the_center_slot()
	_test_no_advance_before_first_turn_ends()
	_test_advance_and_end_turn_advances_ending_side_then_switches()
	_test_advance_and_end_turn_only_advances_ending_side_across_multiple_turns()
	_test_pending_flip_skips_advance_on_that_slot()
	_test_pending_move_skips_advance_on_both_slots()
	_test_pending_swap_in_skips_advance_on_left_slot()
	_test_opponent_flip_resolves_after_own_slots_and_does_not_stop_them()
	_test_pass_advances_all_own_slots()
	_test_resolution_steps_reported_in_order()
	_test_hp_clamps_and_ends_match()
	_test_force_match_end_on_timeout()
	_test_online_match_apply_surrender_ends_match()

	_test_sword_on_flip_damage()
	_test_king_damage_reduction_and_self_damage()
	_test_judge_continuous_damage()
	_test_wall_counter_only_on_opponent_flip()
	_test_dash_force_advance_on_flip()
	_test_echo_recovers_random_ally()
	_test_mirror_syncs_adjacent_right()
	_test_eye_locks_opponent_mirror()

	_test_match_clock_ticks_down_and_times_out()
	_test_match_clock_finish_turn_switches_side_without_adding_time()

	_test_deck_save_round_trips_multiple_decks()
	_test_deck_save_migrates_legacy_single_deck_format()
	SoundSettingsTests.new().run(_assert_true)
	CpuStrategyTests.new().run(_assert_true)

	_test_local_replay_service_round_trips_and_enforces_retention()
	_test_match_cpu_replay_recorder_saves_via_local_replay_service()

	if _failures > 0:
		printerr("tests failed: ", _failures)
		quit(1)
		return

	print("tests passed")
	quit(0)


func _test_all_hourglass_resources_load() -> void:
	var all_cards: Array[HourglassData] = MatchSetup.all_hourglasses()
	_assert_true(all_cards.size() > 0, "data/hourglasses should contain at least one card")

	var seen_ids: Dictionary = {}
	for data in all_cards:
		_assert_true(data != null, "each .tres in data/hourglasses should load")
		if data == null:
			continue
		_assert_true(data.id != "", "%s id should not be empty" % data.resource_path)
		_assert_true(not seen_ids.has(data.id), "hourglass id should be unique: %s" % data.id)
		seen_ids[data.id] = true
		_assert_true(data.display_name != "", "%s display_name should not be empty" % data.id)
		_assert_true(data.fall_damage >= 0, "%s fall_damage should be >= 0" % data.id)
		_assert_true(data.icon_upright != null, "%s icon_upright should be set" % data.id)
		_assert_true(data.icon_falling != null, "%s icon_falling should be set" % data.id)
		_assert_true(data.icon_fallen != null, "%s icon_fallen should be set" % data.id)


func _test_hourglass_instance_flip_and_advance() -> void:
	var data: HourglassData = _load_hourglass("sand")
	var instance := HourglassInstance.new(data)
	_assert_true(
		instance.state == GameEnums.HourglassState.UPRIGHT, "new instance should start UPRIGHT"
	)

	instance.advance()
	_assert_true(
		instance.state == GameEnums.HourglassState.FALLING, "advance should move to FALLING"
	)

	instance.advance()
	_assert_true(instance.state == GameEnums.HourglassState.FALLEN, "advance should move to FALLEN")

	instance.advance()
	_assert_true(
		instance.state == GameEnums.HourglassState.FALLEN, "advance should clamp at FALLEN"
	)

	instance.flip()
	_assert_true(instance.state == GameEnums.HourglassState.UPRIGHT, "flip should reset to UPRIGHT")


## 位置ボーナス廃止(GameDesign.md 5章)の確認。中央の落下ダメージ加算・右の被ダメージ軽減は
## どちらも発生せず、位置によらず素の値がそのまま適用されるべき。
func _test_positions_have_no_damage_bonus() -> void:
	var gs := _make_state(["sand", "sand", "sand"], ["sand", "sand", "sand"], false)
	gs.advance_slot(GameState.PlayerSide.A, GameState.BoardPosition.CENTER)
	gs.advance_slot(GameState.PlayerSide.A, GameState.BoardPosition.CENTER)
	_assert_true(
		gs.hp[GameState.PlayerSide.B] == GameState.INITIAL_HP - 4,
		"center fall damage should equal fall_damage(4) with no position bonus"
	)

	gs.board[GameState.PlayerSide.B][GameState.BoardPosition.RIGHT].state = (
		GameEnums.HourglassState.FALLEN
	)
	gs.deal_damage(GameState.PlayerSide.B, 3)
	_assert_true(
		gs.hp[GameState.PlayerSide.B] == GameState.INITIAL_HP - 4 - 3,
		"right position (FALLEN) should not reduce incoming damage"
	)


func _test_flip_resets_state() -> void:
	var gs := _make_state(["sand", "sand", "sand"], ["sand", "sand", "sand"], false)
	gs.advance_slot(GameState.PlayerSide.A, GameState.BoardPosition.LEFT)
	gs.flip(GameState.PlayerSide.A, GameState.PlayerSide.A, GameState.BoardPosition.LEFT)
	_assert_true(
		(
			gs.board[GameState.PlayerSide.A][GameState.BoardPosition.LEFT].state
			== GameEnums.HourglassState.UPRIGHT
		),
		"flip should reset the targeted slot to UPRIGHT"
	)


func _test_move_swaps_positions() -> void:
	var gs := _make_state(["sand", "sword", "sand"], ["sand", "sand", "sand"], false)
	gs.move(GameState.PlayerSide.A, GameState.BoardPosition.LEFT, GameState.BoardPosition.CENTER)
	_assert_true(
		gs.board[GameState.PlayerSide.A][GameState.BoardPosition.LEFT].data.id == "sword",
		"move should swap the two positions"
	)
	_assert_true(
		gs.board[GameState.PlayerSide.A][GameState.BoardPosition.CENTER].data.id == "sand",
		"move should swap the two positions"
	)


func _test_swap_in_brings_bench_piece_upright() -> void:
	var gs := GameState.new()
	var sand_data: HourglassData = _load_hourglass("sand")
	var board_a: Array[HourglassData] = [sand_data, sand_data, sand_data]
	var bench_a: Array[HourglassData] = [_load_hourglass("sword")]
	var board_b: Array[HourglassData] = [sand_data, sand_data, sand_data]
	var empty_bench: Array[HourglassData] = []
	gs.start_match(board_a, bench_a, board_b, empty_bench)

	gs.board[GameState.PlayerSide.A][GameState.BoardPosition.LEFT].advance()
	gs.swap_in(GameState.PlayerSide.A, 0)

	_assert_true(
		gs.board[GameState.PlayerSide.A][GameState.BoardPosition.LEFT].data.id == "sword",
		"swap_in should bring the bench piece into the LEFT slot"
	)
	_assert_true(
		(
			gs.board[GameState.PlayerSide.A][GameState.BoardPosition.LEFT].state
			== GameEnums.HourglassState.UPRIGHT
		),
		"swapped-in piece should start UPRIGHT"
	)
	_assert_true(
		gs.bench[GameState.PlayerSide.A][0].data.id == "sand",
		"the outgoing piece should move to the bench"
	)


func _test_start_states_differ_by_position() -> void:
	# 対局開始時、場は左=上向き/中央=落下中/右=落ちきりで始まる(GameDesign.md 2章・5章)。
	# 控えは従来どおり全て上向き。右マスがFALLENで始まっても、それは「到達」ではないため
	# 落下ダメージは発生せず、両者のHPは初期値のままでなければならない。
	var gs := GameState.new()
	var board_ids: Array[HourglassData] = [
		_load_hourglass("sand"), _load_hourglass("sand"), _load_hourglass("sand")
	]
	var bench_ids: Array[HourglassData] = [_load_hourglass("sand"), _load_hourglass("sand")]
	gs.start_match(board_ids, bench_ids, board_ids.duplicate(), bench_ids.duplicate())

	var expected := [
		GameEnums.HourglassState.UPRIGHT,
		GameEnums.HourglassState.FALLING,
		GameEnums.HourglassState.FALLEN,
	]
	for side in [GameState.PlayerSide.A, GameState.PlayerSide.B]:
		for position in range(GameState.BOARD_SIZE):
			_assert_true(
				gs.board[side][position].state == expected[position],
				"board slot %d should start as %d" % [position, expected[position]]
			)
		for index in range(bench_ids.size()):
			_assert_true(
				gs.bench[side][index].state == GameEnums.HourglassState.UPRIGHT,
				"bench pieces should always start UPRIGHT"
			)
		_assert_true(
			gs.hp[side] == GameState.INITIAL_HP,
			"starting the match with a FALLEN slot must not deal fall damage"
		)


func _test_first_turn_end_drops_only_the_center_slot() -> void:
	# 初期状態がずれている結果、最初の手番終了では中央だけが落ちきる(左は落下中へ進むだけ、
	# 右は既に落ちきっているので変化しない)。1手に1駒ずつ落ちることの検証。
	var gs := GameState.new()
	var board_ids: Array[HourglassData] = [
		_load_hourglass("sand"), _load_hourglass("sand"), _load_hourglass("sand")
	]
	var empty_bench: Array[HourglassData] = []
	gs.start_match(board_ids, empty_bench, board_ids.duplicate(), empty_bench)
	gs.advance_and_end_turn()

	var slots: Array = gs.board[GameState.PlayerSide.A]
	_assert_true(
		slots[GameState.BoardPosition.LEFT].state == GameEnums.HourglassState.FALLING,
		"the left slot should only advance to FALLING on the first turn end"
	)
	_assert_true(
		slots[GameState.BoardPosition.CENTER].state == GameEnums.HourglassState.FALLEN,
		"the center slot should be the only one to land on the first turn end"
	)
	_assert_true(
		slots[GameState.BoardPosition.RIGHT].state == GameEnums.HourglassState.FALLEN,
		"the right slot should stay FALLEN"
	)
	var expected_hp: int = GameState.INITIAL_HP - _load_hourglass("sand").fall_damage
	_assert_true(
		gs.hp[GameState.PlayerSide.B] == expected_hp,
		"exactly one slot worth of fall damage should be dealt on the first turn end"
	)


func _test_no_advance_before_first_turn_ends() -> void:
	# advance_and_end_turn()を一度も呼んでいない対局開始直後は、誰も1手も終えていないため
	# 全ての砂時計が自然に「上向き」のままであるべき(GameDesign.md 2章)。
	var gs := _make_state(["sand", "sand", "sand"], ["sand", "sand", "sand"], false)
	for side in [GameState.PlayerSide.A, GameState.PlayerSide.B]:
		for position in range(GameState.BOARD_SIZE):
			_assert_true(
				gs.board[side][position].state == GameEnums.HourglassState.UPRIGHT,
				"all slots should stay UPRIGHT before the first turn ends"
			)


func _test_advance_and_end_turn_advances_ending_side_then_switches() -> void:
	# Aが1手目を終える瞬間、Aの陣営だけが1段階進行してから手番がBへ交代する。
	var gs := _make_state(["sand", "sand", "sand"], ["sand", "sand", "sand"], false)
	gs.advance_and_end_turn()
	for position in range(GameState.BOARD_SIZE):
		_assert_true(
			gs.board[GameState.PlayerSide.A][position].state == GameEnums.HourglassState.FALLING,
			"advance_and_end_turn should advance the side that just finished its turn"
		)
		_assert_true(
			gs.board[GameState.PlayerSide.B][position].state == GameEnums.HourglassState.UPRIGHT,
			"the side that has not acted yet should stay UPRIGHT"
		)
	_assert_true(
		gs.current_turn == GameState.PlayerSide.B, "turn should switch to B after A ends its turn"
	)


func _test_advance_and_end_turn_only_advances_ending_side_across_multiple_turns() -> void:
	# Aが1手目を終える(Aのみ進行)→Bが1手目を終える(Bのみ進行)→Aが2手目を終える(Aが2段階目)
	# →Bが2手目を終える(Bが2段階目)。その間、進行していない側は一切状態が変わらないことを確認する。
	var gs := _make_state(["sand", "sand", "sand"], ["sand", "sand", "sand"], false)

	gs.advance_and_end_turn()  # Aが1手目を終える: Aのみ UPRIGHT -> FALLING
	for position in range(GameState.BOARD_SIZE):
		_assert_true(
			gs.board[GameState.PlayerSide.A][position].state == GameEnums.HourglassState.FALLING,
			"A should advance to FALLING when A's first turn ends"
		)
		_assert_true(
			gs.board[GameState.PlayerSide.B][position].state == GameEnums.HourglassState.UPRIGHT,
			"B should stay UPRIGHT while A is the one ending its turn"
		)

	gs.advance_and_end_turn()  # Bが1手目を終える: Bのみ UPRIGHT -> FALLING、Aは変化しない
	for position in range(GameState.BOARD_SIZE):
		_assert_true(
			gs.board[GameState.PlayerSide.B][position].state == GameEnums.HourglassState.FALLING,
			"B should advance to FALLING when B's first turn ends"
		)
		_assert_true(
			gs.board[GameState.PlayerSide.A][position].state == GameEnums.HourglassState.FALLING,
			"A should stay unchanged while B is the one ending its turn"
		)

	gs.advance_and_end_turn()  # Aが2手目を終える: Aのみ FALLING -> FALLEN、Bは変化しない
	for position in range(GameState.BOARD_SIZE):
		_assert_true(
			gs.board[GameState.PlayerSide.A][position].state == GameEnums.HourglassState.FALLEN,
			"A should reach FALLEN when A's second turn ends"
		)
		_assert_true(
			gs.board[GameState.PlayerSide.B][position].state == GameEnums.HourglassState.FALLING,
			"B should stay unchanged while A is the one ending its turn"
		)

	gs.advance_and_end_turn()  # Bが2手目を終える: Bのみ FALLING -> FALLEN、Aは既にFALLENのままクランプ
	for position in range(GameState.BOARD_SIZE):
		_assert_true(
			gs.board[GameState.PlayerSide.B][position].state == GameEnums.HourglassState.FALLEN,
			"B should reach FALLEN when B's second turn ends"
		)
		_assert_true(
			gs.board[GameState.PlayerSide.A][position].state == GameEnums.HourglassState.FALLEN,
			"A should remain FALLEN (clamped) while B is the one ending its turn"
		)


## 以下6件はフェーズ17の新ルール(GameDesign.md 2章・4.4)の検証。行動を設定したマスは
## その手番の砂が進行しない。設定は OnlineMatch.apply() 経由(実際の呼び出し経路と同じ)で行う。
func _test_pending_flip_skips_advance_on_that_slot() -> void:
	var gs := _make_state(["sand", "sand", "sand"], ["sand", "sand", "sand"], false)
	gs.advance_and_end_turn()  # A: 全マス FALLING
	gs.advance_and_end_turn()  # B: 全マス FALLING(手番はAへ戻る)
	OnlineMatch.apply(
		{
			"type": "flip",
			"actor": GameState.PlayerSide.A,
			"side": GameState.PlayerSide.A,
			"position": GameState.BoardPosition.CENTER
		},
		gs
	)
	_assert_true(
		(
			gs.board[GameState.PlayerSide.A][GameState.BoardPosition.CENTER].state
			== GameEnums.HourglassState.FALLING
		),
		"setting a flip should not change the board until the turn is resolved"
	)
	gs.advance_and_end_turn()
	_assert_true(
		(
			gs.board[GameState.PlayerSide.A][GameState.BoardPosition.CENTER].state
			== GameEnums.HourglassState.UPRIGHT
		),
		"the flipped slot should be UPRIGHT and must not advance in the same turn"
	)
	for position in [GameState.BoardPosition.LEFT, GameState.BoardPosition.RIGHT]:
		_assert_true(
			gs.board[GameState.PlayerSide.A][position].state == GameEnums.HourglassState.FALLEN,
			"slots without a set action should advance as usual"
		)


func _test_pending_move_skips_advance_on_both_slots() -> void:
	var gs := _make_state(["sand", "sword", "king"], ["sand", "sand", "sand"], false)
	gs.advance_and_end_turn()  # A: 全マス FALLING
	gs.advance_and_end_turn()  # B
	OnlineMatch.apply(
		{
			"type": "move",
			"side": GameState.PlayerSide.A,
			"from": GameState.BoardPosition.LEFT,
			"to": GameState.BoardPosition.RIGHT
		},
		gs
	)
	gs.advance_and_end_turn()
	var board: Array = gs.board[GameState.PlayerSide.A]
	_assert_true(
		board[GameState.BoardPosition.LEFT].data.id == "king",
		"move should swap the two slots at resolution time"
	)
	_assert_true(
		board[GameState.BoardPosition.RIGHT].data.id == "sand", "move should swap the two slots"
	)
	for position in [GameState.BoardPosition.LEFT, GameState.BoardPosition.RIGHT]:
		_assert_true(
			board[position].state == GameEnums.HourglassState.FALLING,
			"both slots involved in a move must not advance"
		)
	_assert_true(
		board[GameState.BoardPosition.CENTER].state == GameEnums.HourglassState.FALLEN,
		"the slot not involved in the move should advance as usual"
	)


func _test_pending_swap_in_skips_advance_on_left_slot() -> void:
	var gs := GameState.new()
	var board_a: Array[HourglassData] = [
		_load_hourglass("sand"), _load_hourglass("sand"), _load_hourglass("sand")
	]
	var bench_a: Array[HourglassData] = [_load_hourglass("sword")]
	var board_b: Array[HourglassData] = [
		_load_hourglass("sand"), _load_hourglass("sand"), _load_hourglass("sand")
	]
	var empty_bench: Array[HourglassData] = []
	gs.start_match(board_a, bench_a, board_b, empty_bench)
	gs.advance_and_end_turn()  # A: 全マス FALLING
	gs.advance_and_end_turn()  # B
	OnlineMatch.apply({"type": "swap_in", "side": GameState.PlayerSide.A, "bench_index": 0}, gs)
	gs.advance_and_end_turn()
	var left: HourglassInstance = gs.board[GameState.PlayerSide.A][GameState.BoardPosition.LEFT]
	_assert_true(left.data.id == "sword", "swap_in should bring the bench piece to the left slot")
	_assert_true(
		left.state == GameEnums.HourglassState.UPRIGHT,
		"the swapped-in piece should stay UPRIGHT and must not advance in the same turn"
	)
	_assert_true(
		(
			gs.board[GameState.PlayerSide.A][GameState.BoardPosition.CENTER].state
			== GameEnums.HourglassState.FALLEN
		),
		"the other slots should advance as usual during a swap_in turn"
	)


func _test_opponent_flip_resolves_after_own_slots_and_does_not_stop_them() -> void:
	var gs := _make_state(["sand", "sand", "sand"], ["sand", "sand", "sand"], false)
	gs.advance_and_end_turn()  # A: FALLING
	gs.advance_and_end_turn()  # B: FALLING
	OnlineMatch.apply(
		{
			"type": "flip",
			"actor": GameState.PlayerSide.A,
			"side": GameState.PlayerSide.B,
			"position": GameState.BoardPosition.CENTER
		},
		gs
	)
	gs.advance_and_end_turn()
	for position in range(GameState.BOARD_SIZE):
		_assert_true(
			gs.board[GameState.PlayerSide.A][position].state == GameEnums.HourglassState.FALLEN,
			"flipping an opponent piece should not protect any of your own slots"
		)
	_assert_true(
		(
			gs.board[GameState.PlayerSide.B][GameState.BoardPosition.CENTER].state
			== GameEnums.HourglassState.UPRIGHT
		),
		"the opponent slot should be flipped back to UPRIGHT"
	)
	_assert_true(
		(
			gs.board[GameState.PlayerSide.B][GameState.BoardPosition.LEFT].state
			== GameEnums.HourglassState.FALLING
		),
		"the opponent's other slots must not advance on your turn"
	)


func _test_pass_advances_all_own_slots() -> void:
	var gs := _make_state(["sand", "sand", "sand"], ["sand", "sand", "sand"], false)
	OnlineMatch.apply({"type": "pass", "side": GameState.PlayerSide.A}, gs)
	gs.advance_and_end_turn()
	for position in range(GameState.BOARD_SIZE):
		_assert_true(
			gs.board[GameState.PlayerSide.A][position].state == GameEnums.HourglassState.FALLING,
			"a pass should let every own slot advance"
		)
	_assert_true(gs.pending_action.is_empty(), "the set action should be cleared after resolution")


func _test_resolution_steps_reported_in_order() -> void:
	var gs := _make_state(["sand", "sand", "sand"], ["sand", "sand", "sand"], false)
	var steps: Array = []
	gs.resolution_step_started.connect(
		func(side: int, positions: Array, kind: String) -> void:
			steps.append({"side": side, "positions": positions.duplicate(), "kind": kind})
	)
	OnlineMatch.apply(
		{
			"type": "flip",
			"actor": GameState.PlayerSide.A,
			"side": GameState.PlayerSide.B,
			"position": GameState.BoardPosition.RIGHT
		},
		gs
	)
	gs.advance_and_end_turn()
	_assert_true(
		steps.size() == GameState.BOARD_SIZE + 1,
		"own 3 slots plus the opponent flip should report 4 steps, got %d" % steps.size()
	)
	for position in range(GameState.BOARD_SIZE):
		_assert_true(
			(
				steps[position]["side"] == GameState.PlayerSide.A
				and steps[position]["positions"] == [position]
				and steps[position]["kind"] == "advance"
			),
			"own slots should be reported left to right before the opponent step"
		)
	var last: Dictionary = steps[GameState.BOARD_SIZE]
	_assert_true(
		(
			last["side"] == GameState.PlayerSide.B
			and last["positions"] == [GameState.BoardPosition.RIGHT]
			and last["kind"] == "flip"
		),
		"the opponent flip should be reported last"
	)
	# 落ちきったマスも「何も起きないステップ」として報告される(GameDesign.md 9章)。
	steps.clear()
	gs.advance_and_end_turn()  # B
	steps.clear()
	gs.advance_and_end_turn()  # A: FALLING -> FALLEN
	steps.clear()
	gs.advance_and_end_turn()  # B
	steps.clear()
	gs.advance_and_end_turn()  # A: 既に FALLEN のため全マス idle
	for step in steps:
		_assert_true(
			step["kind"] == "idle", "slots already FALLEN should report an idle step, not advance"
		)


func _test_hp_clamps_and_ends_match() -> void:
	var gs := _make_state(["sand", "sand", "sand"], ["sand", "sand", "sand"], false)
	gs.deal_damage(GameState.PlayerSide.B, 25)
	_assert_true(gs.hp[GameState.PlayerSide.B] == 0, "hp should clamp at 0")
	_assert_true(gs.is_match_over(), "match should end when hp reaches 0")

	var hp_a_before: int = gs.hp[GameState.PlayerSide.A]
	gs.deal_damage(GameState.PlayerSide.A, 5)
	_assert_true(
		gs.hp[GameState.PlayerSide.A] == hp_a_before, "deal_damage should no-op after match over"
	)


func _test_force_match_end_on_timeout() -> void:
	var gs := _make_state(["sand", "sand", "sand"], ["sand", "sand", "sand"], false)
	gs.force_match_end(GameState.PlayerSide.A)
	_assert_true(gs.is_match_over(), "match should end when a side times out")

	var hp_b_before: int = gs.hp[GameState.PlayerSide.B]
	gs.deal_damage(GameState.PlayerSide.B, 5)
	_assert_true(
		gs.hp[GameState.PlayerSide.B] == hp_b_before, "deal_damage should no-op after timeout end"
	)

	gs.force_match_end(GameState.PlayerSide.B)
	_assert_true(
		gs.is_match_over(), "force_match_end should stay a no-op once the match already ended"
	)


## T-3: オンライン対戦の投了同期。投了actionが指し手(反転/移動/交代)と同じ
## OnlineMatch.apply()経由でGameState.surrender()を呼び出し、盤面・HPを変えずに
## 即座に相手側の勝利で終局することを検証する(実通信は行わず静的なapply()のみで確認)。
func _test_online_match_apply_surrender_ends_match() -> void:
	var gs := _make_state(["sand", "sand", "sand"], ["sand", "sand", "sand"], false)
	# GDScriptのlambdaはローカル変数を値でキャプチャするため、外側の変数へ直接代入しても
	# 反映されない。Arrayは参照型のため、要素への代入で外側から結果を観測できるようにする。
	var winner_box: Array = [null]
	gs.match_ended.connect(func(w: int) -> void: winner_box[0] = w)

	OnlineMatch.apply({"type": "surrender", "side": GameState.PlayerSide.A}, gs)
	_assert_true(
		gs.is_match_over(), "surrender action applied via OnlineMatch.apply should end the match"
	)
	_assert_true(
		winner_box[0] == GameState.PlayerSide.B,
		"the side that did not surrender (B) should be declared the winner"
	)
	_assert_true(
		(
			gs.hp[GameState.PlayerSide.A] == GameState.INITIAL_HP
			and gs.hp[GameState.PlayerSide.B] == GameState.INITIAL_HP
		),
		"surrender should end the match without dealing any damage"
	)

	# 既に終了した対局へ追加のsurrender actionが届いても、GameState.force_match_end()の
	# no-opガードにより結果が変わらないこと(投了とタイムアウトが同じ即時終了経路を
	# 共有していることの確認)。
	OnlineMatch.apply({"type": "surrender", "side": GameState.PlayerSide.B}, gs)
	_assert_true(
		winner_box[0] == GameState.PlayerSide.B,
		"applying another surrender after the match is already over should not change the winner"
	)


func _test_sword_on_flip_damage() -> void:
	var gs := _make_state(["sword", "sand", "sand"], ["sand", "sand", "sand"], true)
	gs.flip(GameState.PlayerSide.A, GameState.PlayerSide.A, GameState.BoardPosition.LEFT)
	_assert_true(
		gs.hp[GameState.PlayerSide.B] == GameState.INITIAL_HP - 1,
		"sword flip should deal 1 damage to the opponent"
	)


func _test_king_damage_reduction_and_self_damage() -> void:
	var gs := _make_state(["king", "sand", "sand"], ["sand", "sand", "sand"], true)
	gs.advance_slot(GameState.PlayerSide.A, GameState.BoardPosition.LEFT)
	_assert_true(
		gs.effect_resolver.get_damage_reduction(gs, GameState.PlayerSide.A) == 1,
		"king while falling should grant 1 damage reduction"
	)

	var hp_a_before: int = gs.hp[GameState.PlayerSide.A]
	var hp_b_before: int = gs.hp[GameState.PlayerSide.B]
	gs.advance_slot(GameState.PlayerSide.A, GameState.BoardPosition.LEFT)
	_assert_true(
		gs.hp[GameState.PlayerSide.B] == hp_b_before - 1,
		"king fall damage should deal 1 to opponent"
	)
	_assert_true(
		gs.hp[GameState.PlayerSide.A] == hp_a_before - 2, "king on_fallen should deal 2 self damage"
	)


func _test_judge_continuous_damage() -> void:
	var gs := _make_state(["judge", "sand", "sand"], ["sand", "sand", "sand"], true)
	gs.board[GameState.PlayerSide.A][GameState.BoardPosition.LEFT].state = (
		GameEnums.HourglassState.FALLEN
	)
	var hp_b_before: int = gs.hp[GameState.PlayerSide.B]
	gs.effect_resolver.resolve_turn_tick(gs)
	gs.effect_resolver.resolve_turn_tick(gs)
	_assert_true(
		gs.hp[GameState.PlayerSide.B] == hp_b_before - 2,
		"judge should deal 1 damage per turn tick while fallen"
	)


func _test_wall_counter_only_on_opponent_flip() -> void:
	var gs := _make_state(["wall", "sand", "sand"], ["sand", "sand", "sand"], true)
	gs.flip(GameState.PlayerSide.A, GameState.PlayerSide.A, GameState.BoardPosition.LEFT)
	_assert_true(
		gs.hp[GameState.PlayerSide.A] == GameState.INITIAL_HP,
		"self-flip should not trigger wall's counter"
	)

	gs.flip(GameState.PlayerSide.B, GameState.PlayerSide.A, GameState.BoardPosition.LEFT)
	_assert_true(
		gs.hp[GameState.PlayerSide.B] == GameState.INITIAL_HP - 1,
		"opponent-flip should trigger wall's counter against the flipper"
	)


func _test_dash_force_advance_on_flip() -> void:
	var gs := _make_state(["dash", "sand", "sand"], ["sand", "sand", "sand"], true)
	gs.flip(GameState.PlayerSide.A, GameState.PlayerSide.A, GameState.BoardPosition.LEFT)
	_assert_true(
		(
			gs.board[GameState.PlayerSide.A][GameState.BoardPosition.LEFT].state
			== GameEnums.HourglassState.FALLING
		),
		"dash flip should force-advance to FALLING"
	)


func _test_echo_recovers_random_ally() -> void:
	var gs := _make_state(["echo", "sand", "sand"], ["sand", "sand", "sand"], true)
	gs.board[GameState.PlayerSide.A][GameState.BoardPosition.LEFT].state = (
		GameEnums.HourglassState.FALLING
	)
	gs.board[GameState.PlayerSide.A][GameState.BoardPosition.CENTER].state = (
		GameEnums.HourglassState.FALLING
	)
	gs.board[GameState.PlayerSide.A][GameState.BoardPosition.RIGHT].state = (
		GameEnums.HourglassState.FALLING
	)
	gs.advance_slot(GameState.PlayerSide.A, GameState.BoardPosition.LEFT)

	var upright_count := 0
	if (
		gs.board[GameState.PlayerSide.A][GameState.BoardPosition.CENTER].state
		== GameEnums.HourglassState.UPRIGHT
	):
		upright_count += 1
	if (
		gs.board[GameState.PlayerSide.A][GameState.BoardPosition.RIGHT].state
		== GameEnums.HourglassState.UPRIGHT
	):
		upright_count += 1
	_assert_true(
		upright_count == 1, "echo on_fallen should reset exactly one other ally to UPRIGHT"
	)


func _test_mirror_syncs_adjacent_right() -> void:
	var gs := _make_state(["mirror", "sand", "sand"], ["sand", "sand", "sand"], true)
	gs.board[GameState.PlayerSide.A][GameState.BoardPosition.CENTER].state = (
		GameEnums.HourglassState.FALLING
	)
	gs.flip(GameState.PlayerSide.A, GameState.PlayerSide.A, GameState.BoardPosition.LEFT)
	_assert_true(
		(
			gs.board[GameState.PlayerSide.A][GameState.BoardPosition.CENTER].state
			== GameEnums.HourglassState.UPRIGHT
		),
		"mirror flip should sync the right-adjacent slot's state"
	)


func _test_eye_locks_opponent_mirror() -> void:
	var gs := _make_state(["eye", "sand", "sand"], ["sand", "sand", "sand"], true)
	gs.board[GameState.PlayerSide.A][GameState.BoardPosition.LEFT].state = (
		GameEnums.HourglassState.FALLING
	)
	gs.board[GameState.PlayerSide.B][GameState.BoardPosition.LEFT].state = (
		GameEnums.HourglassState.FALLING
	)
	gs.flip(GameState.PlayerSide.B, GameState.PlayerSide.B, GameState.BoardPosition.LEFT)
	_assert_true(
		(
			gs.board[GameState.PlayerSide.B][GameState.BoardPosition.LEFT].state
			== GameEnums.HourglassState.FALLING
		),
		"eye should lock the opponent's mirror-column piece while falling, blocking its flip"
	)


func _test_match_clock_ticks_down_and_times_out() -> void:
	var clock := MatchClock.new(10.0)
	clock.start_turn(GameState.PlayerSide.A)
	var timed_out_side := [-1]
	clock.time_out.connect(func(side: GameState.PlayerSide) -> void: timed_out_side[0] = side)

	clock.tick(4.0)
	_assert_true(
		clock.get_remaining(GameState.PlayerSide.A) == 6.0,
		"tick should subtract delta from remaining"
	)
	_assert_true(timed_out_side[0] == -1, "time_out should not fire before remaining reaches 0")

	clock.tick(10.0)
	_assert_true(clock.get_remaining(GameState.PlayerSide.A) == 0.0, "remaining should clamp at 0")
	_assert_true(
		timed_out_side[0] == GameState.PlayerSide.A, "time_out should fire for the active side"
	)
	_assert_true(not clock.running, "clock should stop running after timing out")


func _test_match_clock_finish_turn_switches_side_without_adding_time() -> void:
	var clock := MatchClock.new(10.0)
	clock.start_turn(GameState.PlayerSide.A)
	clock.tick(3.0)
	clock.finish_turn(GameState.PlayerSide.B)
	_assert_true(
		clock.get_remaining(GameState.PlayerSide.A) == 7.0,
		"finish_turn should not add any time back to the side that just moved"
	)
	_assert_true(
		clock.active_side == GameState.PlayerSide.B, "finish_turn should switch active_side"
	)


func _load_hourglass(id: String) -> HourglassData:
	if not _hourglass_cache.has(id):
		_hourglass_cache[id] = load("res://data/hourglasses/%s.tres" % id)
	return _hourglass_cache[id]


## 進行・行動・効果の検証を初期状態のばらつきから切り離すため、場を全て上向きへ揃えて返す。
## 位置ごとの初期状態(GameState.START_STATES)そのものは _test_start_states_* で個別に検証する。
func _make_state(a_ids: Array, b_ids: Array, with_resolver: bool) -> GameState:
	var gs := GameState.new()
	if with_resolver:
		gs.effect_resolver = EffectResolver.new()
	var board_a: Array[HourglassData] = []
	for id in a_ids:
		board_a.append(_load_hourglass(id))
	var board_b: Array[HourglassData] = []
	for id in b_ids:
		board_b.append(_load_hourglass(id))
	var empty_bench: Array[HourglassData] = []
	gs.start_match(board_a, empty_bench, board_b, empty_bench)
	for side in [GameState.PlayerSide.A, GameState.PlayerSide.B]:
		for position in range(GameState.BOARD_SIZE):
			gs.board[side][position].state = GameEnums.HourglassState.UPRIGHT
	return gs


func _test_deck_save_round_trips_multiple_decks() -> void:
	var backup: Variant = _backup_deck_save()
	var decks: Array[Dictionary] = [
		{"name": "デッキ1", "ids": ["sand", "sword"]}, {"name": "デッキ2", "ids": ["king", "wall"]}
	]
	DeckSave.save_decks(decks)
	var loaded: Array[Dictionary] = DeckSave.load_decks()
	_assert_true(loaded.size() == 2, "should round-trip 2 decks")
	if loaded.size() == 2:
		_assert_true(loaded[0]["name"] == "デッキ1", "first deck name should round-trip")
		_assert_true(loaded[0]["ids"] == ["sand", "sword"], "first deck ids should round-trip")
		_assert_true(loaded[1]["name"] == "デッキ2", "second deck name should round-trip")
	_restore_deck_save(backup)


func _test_deck_save_migrates_legacy_single_deck_format() -> void:
	var backup: Variant = _backup_deck_save()
	var file := FileAccess.open(DeckSave.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"ids": ["sand", "sword", "king", "wall", "shield"]}))
	file = null
	var loaded: Array[Dictionary] = DeckSave.load_decks()
	_assert_true(loaded.size() == 1, "legacy save should migrate to a single deck")
	if loaded.size() == 1:
		_assert_true(loaded[0]["name"] == "デッキ1", "migrated deck should get a default name")
		_assert_true(loaded[0]["ids"].size() == 5, "migrated deck should keep all 5 ids")
	_restore_deck_save(backup)


func _backup_deck_save() -> Variant:
	if not FileAccess.file_exists(DeckSave.SAVE_PATH):
		return null
	var file := FileAccess.open(DeckSave.SAVE_PATH, FileAccess.READ)
	var content := file.get_as_text()
	file = null
	return content


func _restore_deck_save(backup: Variant) -> void:
	if backup == null:
		if FileAccess.file_exists(DeckSave.SAVE_PATH):
			DirAccess.remove_absolute(DeckSave.SAVE_PATH)
		return
	var file := FileAccess.open(DeckSave.SAVE_PATH, FileAccess.WRITE)
	file.store_string(str(backup))


## K-2: CPU戦のローカルリプレイ保存(LocalReplayService)。保存→一覧取得→個別取得の
## 往復と、保存件数上限(30件)超過時に古いものから削除されることを検証する。
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


## K-2: MatchScreenが実際に呼び出す経路(begin→record_action→save_finished)を、
## MatchScreenのシーンを起動せずにMatchCpuReplayRecorder単体で再現し、実プレイと同じ
## 手順でLocalReplayServiceへ正しく保存されることを確認する。
func _test_match_cpu_replay_recorder_saves_via_local_replay_service() -> void:
	var backup: Variant = _backup_local_replay_save()
	var file := FileAccess.open(LocalReplayService.SAVE_PATH, FileAccess.WRITE)
	file.store_string("[]")
	file = null

	var board_a: Array[HourglassData] = [
		_load_hourglass("sand"), _load_hourglass("sword"), _load_hourglass("king")
	]
	var bench_a: Array[HourglassData] = [_load_hourglass("wall"), _load_hourglass("shield")]
	var board_b: Array[HourglassData] = [
		_load_hourglass("dash"), _load_hourglass("echo"), _load_hourglass("mirror")
	]
	var bench_b: Array[HourglassData] = [_load_hourglass("eye"), _load_hourglass("judge")]

	var recorder := MatchCpuReplayRecorder.new(null)
	recorder.begin(board_a, bench_a, board_b, bench_b)
	recorder.record_action(
		{
			"type": "flip",
			"actor": GameState.PlayerSide.A,
			"side": GameState.PlayerSide.A,
			"position": 0
		}
	)
	recorder.record_action({"type": "swap_in", "side": GameState.PlayerSide.B, "bench_index": 0})
	recorder.save_finished(GameState.PlayerSide.A)

	var replays: Array[Dictionary] = LocalReplayService.list_replays()
	_assert_true(replays.size() == 1, "MatchCpuReplayRecorder should save exactly 1 cpu replay")
	if replays.size() == 1:
		var fields: Dictionary = replays[0]["fields"]
		_assert_true(
			fields["deck_a"] == ["sand", "sword", "king", "wall", "shield"],
			"deck_a should be board_a+bench_a ids"
		)
		_assert_true(
			fields["deck_b"] == ["dash", "echo", "mirror", "eye", "judge"],
			"deck_b should be board_b+bench_b ids"
		)
		_assert_true(
			fields["placement_a"] == ["sand", "sword", "king"], "placement_a should be board_a ids"
		)
		_assert_true(
			fields["placement_b"] == ["dash", "echo", "mirror"], "placement_b should be board_b ids"
		)
		_assert_true(fields["actions"].size() == 2, "recorded actions should round-trip")
		_assert_true(fields["winner"] == "a", 'winner PlayerSide.A should serialize as "a"')

	_restore_local_replay_save(backup)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("assert failed: ", message)
