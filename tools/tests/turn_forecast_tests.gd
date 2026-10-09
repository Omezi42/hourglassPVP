extends RefCounted
## 反転・ターン終了の予測(GameDesign.md 9章、Architecture.md 4.0.2節)の検証。

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_flip_preview_swaps_then_drops_sand()
	_test_flip_preview_reports_death_at_turn_end()
	_test_flip_preview_leaves_board_unchanged()
	_test_doomed_slots_match_end_turn()
	_test_still_unit_is_never_doomed()
	_test_doomed_slots_follow_sand_drop_count()


func _new_match() -> MatchState:
	var deck: Array = []
	for i in MatchState.DECK_SIZE:
		deck.append(CardLibrary.find_by_id("sand"))
	var state := MatchState.new()
	state.start_match(deck, deck.duplicate(), MatchState.Side.A, 12345)
	state.current_turn = MatchState.Side.A
	return state


func _place(state: MatchState, slot: int, health: int, attack: int, still := false) -> CardInstance:
	var card := CardData.new()
	card.id = "test_forecast"
	card.display_name = "検証用"
	card.cost = 1
	card.total_sand = health + attack
	if still:
		card.keywords = [CardEnums.Keyword.STILL] as Array[CardEnums.Keyword]
	var unit := CardInstance.new(card)
	unit.health = health
	unit.attack = attack
	unit.summoned_this_turn = false
	state.board[MatchState.Side.A][slot] = unit
	return unit


func _test_flip_preview_swaps_then_drops_sand() -> void:
	var state := _new_match()
	_place(state, 0, 2, 5)
	var forecast := TurnForecast.flip(state, MatchState.Side.A, 0)
	_assert.call(forecast["health"] == 5 and forecast["attack"] == 2, "反転の予測は体力と攻撃力を入れ替える")
	_assert.call(
		forecast["health_after"] == 4 and forecast["attack_after"] == 3, "反転の予測の終了後は、反転後から砂が1粒落ちた値"
	)


func _test_flip_preview_reports_death_at_turn_end() -> void:
	var state := _new_match()
	_place(state, 0, 4, 1)
	var forecast := TurnForecast.flip(state, MatchState.Side.A, 0)
	_assert.call(forecast["health_after"] == 0, "反転後の体力が1なら、終了後は0(割れる)")


func _test_flip_preview_leaves_board_unchanged() -> void:
	var state := _new_match()
	var unit := _place(state, 0, 2, 5)
	TurnForecast.flip(state, MatchState.Side.A, 0)
	_assert.call(
		unit.health == 2 and unit.attack == 5 and state.can_flip(MatchState.Side.A, 0),
		"反転の予測は盤面を変えない"
	)


func _test_doomed_slots_match_end_turn() -> void:
	var state := _new_match()
	_place(state, 0, 1, 6)
	_place(state, 2, 3, 2)
	var doomed := TurnForecast.doomed_slots(state, MatchState.Side.A)
	_assert.call(Array(doomed) == [0], "体力1の駒だけが、ターン終了で割れると予測される")
	state.end_turn()
	_assert.call(
		state.board[MatchState.Side.A][0] == null and state.board[MatchState.Side.A][2] != null,
		"予測どおりにターン終了で割れる"
	)


func _test_still_unit_is_never_doomed() -> void:
	var state := _new_match()
	_place(state, 0, 1, 6, true)
	_assert.call(
		TurnForecast.doomed_slots(state, MatchState.Side.A).is_empty(), "静止の駒は砂が落ちないため割れない"
	)


func _test_doomed_slots_follow_sand_drop_count() -> void:
	var state := _new_match()
	state.sand_drop_count = 2
	_place(state, 0, 2, 3)
	_assert.call(
		Array(TurnForecast.doomed_slots(state, MatchState.Side.A)) == [0],
		"1度に落ちる粒数が多い規則では、そのぶん割れる駒が増える"
	)
