extends RefCounted

## CPU思考ロジック強化とスナップショットのテスト。


func run(assert_true: Callable) -> void:
	_test_legal_actions_include_pass(assert_true)
	_test_game_state_snapshot_round_trip(assert_true)
	_test_game_state_clone_isolation(assert_true)
	_test_smart_cpu_placement_validity(assert_true)
	_test_smart_cpu_choose_action_no_side_effects(assert_true)
	_test_smart_cpu_beats_random_cpu(assert_true)


func _test_legal_actions_include_pass(assert_true: Callable) -> void:
	var gs := GameState.new()
	var sand: HourglassData = _load_hourglass("sand")
	var board_cards: Array[HourglassData] = [sand, sand, sand]
	var bench_cards: Array[HourglassData] = [sand, sand]
	gs.start_match(board_cards, bench_cards, board_cards.duplicate(), bench_cards.duplicate())

	var actions := CpuStrategy.legal_actions(gs, GameState.PlayerSide.A)
	var has_pass := false
	for action in actions:
		if action.get("type", "") == "pass":
			has_pass = true
			break

	assert_true.call(has_pass, "legal_actions should include pass action")


func _test_game_state_snapshot_round_trip(assert_true: Callable) -> void:
	var gs := GameState.new()
	var sand: HourglassData = _load_hourglass("sand")
	var sword: HourglassData = _load_hourglass("sword")
	gs.start_match([sand, sword, sand], [sand, sand], [sand, sand, sand], [sand, sand])

	# いくつか手を適用して状態を変える
	gs.hp[GameState.PlayerSide.A] = 14
	gs.hp[GameState.PlayerSide.B] = 17
	gs.board[GameState.PlayerSide.A][0].state = GameEnums.HourglassState.FALLING
	gs.board[GameState.PlayerSide.B][1].state = GameEnums.HourglassState.FALLEN

	var snap := gs.save_snapshot()

	# さらに変更する
	gs.hp[GameState.PlayerSide.A] = 5
	gs.board[GameState.PlayerSide.A][0].state = GameEnums.HourglassState.UPRIGHT

	# 復元
	gs.restore_snapshot(snap)

	assert_true.call(gs.hp[GameState.PlayerSide.A] == 14, "snapshot should restore HP A")
	assert_true.call(gs.hp[GameState.PlayerSide.B] == 17, "snapshot should restore HP B")
	assert_true.call(
		gs.board[GameState.PlayerSide.A][0].state == GameEnums.HourglassState.FALLING,
		"snapshot should restore slot state"
	)
	assert_true.call(
		gs.board[GameState.PlayerSide.B][1].state == GameEnums.HourglassState.FALLEN,
		"snapshot should restore slot state"
	)


func _test_game_state_clone_isolation(assert_true: Callable) -> void:
	var gs := GameState.new()
	var sand: HourglassData = _load_hourglass("sand")
	gs.start_match([sand, sand, sand], [sand, sand], [sand, sand, sand], [sand, sand])

	var clone := gs.clone_state()
	clone.deal_damage(GameState.PlayerSide.A, 5)
	clone.advance_slot(GameState.PlayerSide.A, 0)

	assert_true.call(
		gs.hp[GameState.PlayerSide.A] == GameState.INITIAL_HP,
		"cloned state mutations should not affect original state HP"
	)
	assert_true.call(
		gs.board[GameState.PlayerSide.A][0].state == GameEnums.HourglassState.UPRIGHT,
		"cloned state mutations should not affect original slot state"
	)


func _test_smart_cpu_placement_validity(assert_true: Callable) -> void:
	var deck: Array[HourglassData] = [
		_load_hourglass("sand"),
		_load_hourglass("sword"),
		_load_hourglass("shield"),
		_load_hourglass("judge"),
		_load_hourglass("eye"),
	]
	var smart := SmartCpuStrategy.new()
	var placement := smart.choose_placement(deck)

	assert_true.call(
		placement.has("board") and placement.has("bench"), "placement must have board and bench"
	)
	var board_res: Array = placement["board"]
	var bench_res: Array = placement["bench"]
	assert_true.call(board_res.size() == GameState.BOARD_SIZE, "board size must be 3")
	assert_true.call(bench_res.size() == GameState.BENCH_SIZE, "bench size must be 2")


func _test_smart_cpu_choose_action_no_side_effects(assert_true: Callable) -> void:
	var gs := GameState.new()
	var sand: HourglassData = _load_hourglass("sand")
	var sword: HourglassData = _load_hourglass("sword")
	gs.start_match([sand, sword, sand], [sand, sand], [sand, sand, sand], [sand, sand])

	var orig_snap := gs.save_snapshot()
	var smart := SmartCpuStrategy.new()
	var action: Dictionary = smart.choose_action(gs, GameState.PlayerSide.A)

	assert_true.call(not action.is_empty(), "smart CPU should choose a valid action")
	assert_true.call(
		gs.hp[GameState.PlayerSide.A] == orig_snap["hp"][GameState.PlayerSide.A],
		"choose_action should not alter original state HP"
	)
	assert_true.call(
		gs.hp[GameState.PlayerSide.B] == orig_snap["hp"][GameState.PlayerSide.B],
		"choose_action should not alter original state HP"
	)


func _test_smart_cpu_beats_random_cpu(assert_true: Callable) -> void:
	var all_cards := MatchSetup.all_hourglasses()
	var smart := SmartCpuStrategy.new(1)  # テスト速度のため深さ1
	var random_cpu := RandomCpuStrategy.new()

	var smart_wins := 0
	var games := 20
	var max_turns := 100

	for g in range(games):
		var gs := GameState.new()
		gs.effect_resolver = EffectResolver.new()
		var deck_a: Array[HourglassData] = []
		var deck_b: Array[HourglassData] = []
		for i in range(5):
			deck_a.append(all_cards[(g + i) % all_cards.size()])
			deck_b.append(all_cards[(g + i + 2) % all_cards.size()])

		var place_a := smart.choose_placement(deck_a)
		var place_b := random_cpu.choose_placement(deck_b)

		var board_a: Array[HourglassData] = []
		board_a.assign(place_a["board"])
		var bench_a: Array[HourglassData] = []
		bench_a.assign(place_a["bench"])
		var board_b: Array[HourglassData] = []
		board_b.assign(place_b["board"])
		var bench_b: Array[HourglassData] = []
		bench_b.assign(place_b["bench"])

		gs.start_match(board_a, bench_a, board_b, bench_b)

		var turns := 0
		while not gs.is_match_over() and turns < max_turns:
			turns += 1
			var act: Dictionary
			if gs.current_turn == GameState.PlayerSide.A:
				act = smart.choose_action(gs, GameState.PlayerSide.A)
			else:
				act = random_cpu.choose_action(gs, GameState.PlayerSide.B)
			OnlineMatch.apply(act, gs)
			gs.advance_and_end_turn()

		if gs.is_match_over() and gs.hp[GameState.PlayerSide.B] <= 0:
			smart_wins += 1

	var win_rate := float(smart_wins) / float(games)
	(
		assert_true
		. call(
			win_rate >= 0.70,
			(
				"SmartCpu should win at least 70%% of matches against RandomCpu (actual: %d/%d = %.1f%%)"
				% [smart_wins, games, win_rate * 100.0]
			)
		)
	)


func _load_hourglass(id: String) -> HourglassData:
	return load("res://data/hourglasses/%s.tres" % id)
