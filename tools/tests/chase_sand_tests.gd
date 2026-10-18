extends RefCounted
## カードセット「追砂の刻」の検証。Architecture.md 10.8.5節に対応する。

const SET_ID := "chase_sand"

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_sling_hits_face_when_chosen()
	_test_sling_hits_chosen_unit()
	_test_sling_hits_face_without_units()
	_test_cpu_sling_prefers_fragile_unit()
	_test_cpu_sling_goes_face_on_empty_board()
	_test_set_is_staged()


func _vanilla(total: int) -> CardData:
	var card := CardData.new()
	card.id = "test_vanilla"
	card.display_name = "検証用バニラ"
	card.cost = 1
	card.total_sand = total
	return card


func _new_match() -> MatchState:
	var deck: Array = []
	for i in MatchState.DECK_SIZE:
		deck.append(CardLibrary.find_by_id("sand"))
	var state := MatchState.new()
	state.start_match(deck, deck.duplicate(), MatchState.Side.A, 12345)
	state.current_turn = MatchState.Side.A
	state.hand[MatchState.Side.A] = [CardLibrary.find_by_id("sling")]
	state.mana[MatchState.Side.A] = 1
	return state


func _place(state: MatchState, side: int, card: CardData, slot: int) -> CardInstance:
	var unit := CardInstance.new(card)
	unit.summoned_this_turn = false
	state.board[side][slot] = unit
	return unit


func _test_sling_hits_face_when_chosen() -> void:
	var state := _new_match()
	var foe := _place(state, MatchState.Side.B, _vanilla(3), 0)
	var hp := int(state.hp[MatchState.Side.B])
	state.play_card(MatchState.Side.A, 0, 0, {"side": MatchState.Side.B, "slot": -1})
	_assert.call(int(state.hp[MatchState.Side.B]) == hp - 1, "スリングで本体を選ぶと本体へ1ダメージ")
	_assert.call(foe.health == 3, "本体を選んだときは駒に当たらない")


func _test_sling_hits_chosen_unit() -> void:
	var state := _new_match()
	var foe := _place(state, MatchState.Side.B, _vanilla(3), 2)
	var hp := int(state.hp[MatchState.Side.B])
	state.play_card(MatchState.Side.A, 0, 0, {"side": MatchState.Side.B, "slot": 2})
	_assert.call(foe.health == 2, "スリングで駒を選ぶとその駒へ1ダメージ")
	_assert.call(int(state.hp[MatchState.Side.B]) == hp, "駒を選んだときは本体に当たらない")


func _test_sling_hits_face_without_units() -> void:
	var state := _new_match()
	var hp := int(state.hp[MatchState.Side.B])
	state.play_card(MatchState.Side.A, 0, 0)
	_assert.call(int(state.hp[MatchState.Side.B]) == hp - 1, "相手の場が空ならスリングは本体へ当たる")


func _test_cpu_sling_prefers_fragile_unit() -> void:
	var state := _new_match()
	var fragile := _place(state, MatchState.Side.B, _vanilla(3), 1)
	fragile.drop_sand(2)
	var cpu := CardCpuStrategy.new()
	var target: Dictionary = cpu._effect_target(
		state, MatchState.Side.A, CardLibrary.find_by_id("sling")
	)
	_assert.call(target.get("slot", -9) == 1, "CPUは1点で砕ける駒をスリングで狙う")


func _test_cpu_sling_goes_face_on_empty_board() -> void:
	var state := _new_match()
	var cpu := CardCpuStrategy.new()
	var target: Dictionary = cpu._effect_target(
		state, MatchState.Side.A, CardLibrary.find_by_id("sling")
	)
	_assert.call(target.get("slot", -9) == -1, "相手の場が空ならCPUはスリングで本体を狙う")


func _test_set_is_staged() -> void:
	_assert.call(CardSetLibrary.has_set(SET_ID), "chase_sand is registered")
	_assert.call(CardSetLibrary.price(SET_ID) == 1000, "chase_sand costs 1000")
	_assert.call(CardSetLibrary.planned_count(SET_ID) == 10, "chase_sand plans 10 cards")
	_assert.call(CardSetLibrary.card_ids(SET_ID)[0] == "sling", "chase_sand opens with sling")
