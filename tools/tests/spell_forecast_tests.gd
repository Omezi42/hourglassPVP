extends RefCounted
## 砂術を撃った後の予測(`SpellForecast`)の検証。GameDesign.md 9章「撃った後の予測」。

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_single_target_kills()
	_test_area_damage_lists_every_hit()
	_test_forecast_leaves_match_untouched()
	_test_random_spell_has_no_forecast()


func _new_match(hand_ids: Array) -> MatchState:
	var deck: Array = []
	for i in MatchState.DECK_SIZE:
		deck.append(CardLibrary.find_by_id("sand"))
	var state := MatchState.new()
	state.start_match(deck, deck.duplicate(), MatchState.Side.A, 12345)
	state.current_turn = MatchState.Side.A
	var hand: Array = []
	for id in hand_ids:
		hand.append(CardLibrary.find_by_id(id))
	state.hand[MatchState.Side.A] = hand
	state.mana[MatchState.Side.A] = MatchState.MAX_MANA
	return state


func _place(state: MatchState, side: int, slot: int, health: int) -> CardInstance:
	var unit := CardInstance.new(CardLibrary.find_by_id("sand"))
	unit.health = health
	unit.attack = 0
	unit.summoned_this_turn = false
	state.board[side][slot] = unit
	return unit


func _test_single_target_kills() -> void:
	var state := _new_match(["shatter"])
	_place(state, MatchState.Side.B, 2, 3)
	var changes := SpellForecast.compute(
		state, MatchState.Side.A, 0, {"side": MatchState.Side.B, "slot": 2}
	)
	_assert.call(
		changes.size() == 1 and changes[0]["slot"] == 2 and changes[0]["dead"], "砕砂の予測は狙った駒の破壊を出す"
	)


func _test_area_damage_lists_every_hit() -> void:
	var state := _new_match(["tempest"])
	_place(state, MatchState.Side.B, 0, 5)
	_place(state, MatchState.Side.B, 3, 2)
	_place(state, MatchState.Side.A, 1, 4)
	var changes := SpellForecast.compute(state, MatchState.Side.A, 0)
	var by_slot := {}
	for change in changes:
		by_slot[change["slot"]] = change
	_assert.call(
		(
			changes.size() == 2
			and by_slot[0]["health"] == 3
			and not by_slot[0]["dead"]
			and by_slot[3]["dead"]
		),
		"砂塵嵐の予測は相手の駒それぞれの撃った後の体力を出し、自分の駒は出さない"
	)


func _test_forecast_leaves_match_untouched() -> void:
	var state := _new_match(["tempest"])
	var unit := _place(state, MatchState.Side.B, 0, 5)
	var mana_before: int = state.mana[MatchState.Side.A]
	SpellForecast.compute(state, MatchState.Side.A, 0)
	_assert.call(
		(
			unit.health == 5
			and state.hand[MatchState.Side.A].size() == 1
			and state.mana[MatchState.Side.A] == mana_before
			and state.graveyard[MatchState.Side.A].is_empty()
		),
		"予測は写しへ撃つだけで、本物の対局を変えない"
	)


func _test_random_spell_has_no_forecast() -> void:
	var state := _new_match(["grit_rain"])
	_place(state, MatchState.Side.B, 0, 5)
	_assert.call(
		SpellForecast.compute(state, MatchState.Side.A, 0).is_empty(), "ランダムな効果の砂術は予測を出さない"
	)
