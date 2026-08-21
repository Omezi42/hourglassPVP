extends RefCounted

## フェーズ22: スキル(GameDesign.md 4.3・7章)の解決を検証する。
## run_tests.gdが1000行の上限に達したため、そこから切り出したテスト。
## 判定はハーネス側の_assert_trueをCallableで受け取って共有する。


func run(assert_true: Callable) -> void:
	_test_dash_skill_advances_itself(assert_true)
	_test_mirror_skill_swaps_with_right_neighbour(assert_true)
	_test_echo_skill_swaps_itself_with_the_bench(assert_true)
	_test_skill_is_not_offered_for_pieces_without_one(assert_true)


## 加速: スキルで1段階、そのマスの通常進行でもう1段階進むため、1手で落ちきりまで到達する。
func _test_dash_skill_advances_itself(assert_true: Callable) -> void:
	var gs := _make_state(["dash", "sand", "sand"], ["sand", "sand", "sand"])
	_apply_skill(gs, GameState.BoardPosition.LEFT)
	gs.advance_and_end_turn()
	assert_true.call(
		(
			gs.board[GameState.PlayerSide.A][GameState.BoardPosition.LEFT].state
			== GameEnums.HourglassState.FALLEN
		),
		"dash skill plus the normal advance should reach FALLEN in one turn"
	)


## 位置交換: 右隣と入れ替わり、関与した2マスはそれぞれ1回ずつ進行する。
func _test_mirror_skill_swaps_with_right_neighbour(assert_true: Callable) -> void:
	var gs := _make_state(["mirror", "sand", "sword"], ["sand", "sand", "sand"])
	_apply_skill(gs, GameState.BoardPosition.LEFT)
	gs.advance_and_end_turn()
	var board: Array = gs.board[GameState.PlayerSide.A]
	assert_true.call(
		board[GameState.BoardPosition.LEFT].data.id == "sand",
		"mirror skill should swap with the slot to its right"
	)
	assert_true.call(
		board[GameState.BoardPosition.CENTER].data.id == "mirror",
		"the mirror itself should end up in the right-adjacent slot"
	)
	for position in range(GameState.BOARD_SIZE):
		assert_true.call(
			board[position].state == GameEnums.HourglassState.FALLING,
			"every slot still advances exactly once on a position-swap skill turn"
		)


## 交代: 自分自身のマス(左マス固定ではない)で、選んだ控えと入れ替わる。
func _test_echo_skill_swaps_itself_with_the_bench(assert_true: Callable) -> void:
	var gs := _make_state(["sand", "echo", "sand"], ["sand", "sand", "sand"], ["sword", "king"])
	_apply_skill(gs, GameState.BoardPosition.CENTER, 1)
	gs.advance_and_end_turn()
	var center: HourglassInstance = gs.board[GameState.PlayerSide.A][GameState.BoardPosition.CENTER]
	assert_true.call(
		center.data.id == "king",
		"the swap skill should bring the chosen bench piece into the skill user's own slot"
	)
	assert_true.call(
		center.state == GameEnums.HourglassState.FALLING,
		"the piece coming in starts UPRIGHT and then advances in the same turn"
	)
	assert_true.call(
		gs.bench[GameState.PlayerSide.A][1].data.id == "echo",
		"the skill user should be sent to the bench slot it swapped with"
	)


## スキルを持たない駒には合法手としてスキルが出ない。旧「移動」「交代」も列挙されない。
func _test_skill_is_not_offered_for_pieces_without_one(assert_true: Callable) -> void:
	var gs := _make_state(["sand", "sand", "sand"], ["sand", "sand", "sand"], ["sand", "sand"])
	var kinds: Dictionary = {}
	for action in CpuStrategy.legal_actions(gs, GameState.PlayerSide.A):
		kinds[action["type"]] = true
	assert_true.call(not kinds.has("skill"), "a board of vanilla pieces should offer no skills")
	assert_true.call(not kinds.has("move"), "move should no longer be a basic action")
	assert_true.call(not kinds.has("swap_in"), "swap_in should no longer be a basic action")

	var with_skill := _make_state(["dash", "sand", "sand"], ["sand", "sand", "sand"])
	var skill_count := 0
	for action in CpuStrategy.legal_actions(with_skill, GameState.PlayerSide.A):
		if action["type"] == "skill":
			skill_count += 1
	assert_true.call(
		skill_count == 1, "a single skill holder should offer exactly one skill action"
	)


func _apply_skill(gs: GameState, position: int, bench_index: int = -1) -> void:
	var action := {"type": "skill", "side": GameState.PlayerSide.A, "position": position}
	if bench_index >= 0:
		action["bench_index"] = bench_index
	OnlineMatch.apply(action, gs)


func _make_state(a_ids: Array, b_ids: Array, bench_ids: Array = []) -> GameState:
	var gs := GameState.new()
	gs.effect_resolver = EffectResolver.new()
	var board_a: Array[HourglassData] = []
	for id in a_ids:
		board_a.append(_load_hourglass(id))
	var board_b: Array[HourglassData] = []
	for id in b_ids:
		board_b.append(_load_hourglass(id))
	var bench_a: Array[HourglassData] = []
	for id in bench_ids:
		bench_a.append(_load_hourglass(id))
	var empty_bench: Array[HourglassData] = []
	gs.start_match(board_a, bench_a, board_b, empty_bench)
	for side in [GameState.PlayerSide.A, GameState.PlayerSide.B]:
		for position in range(GameState.BOARD_SIZE):
			gs.board[side][position].state = GameEnums.HourglassState.UPRIGHT
	return gs


func _load_hourglass(id: String) -> HourglassData:
	return load("res://data/hourglasses/%s.tres" % id)
