extends RefCounted
## カードセット「遺砂の刻」の語彙(味方の破壊への反応 / 墓地を数える / 墓地から手札へ /
## 墓地から場へ / 払う駒がいないと撃てない砂術)の検証。
## GameDesign.md 6章・8章、Architecture.md 10.8.3節に対応する。

const SET_ID := "grave_sand"
const A := MatchState.Side.A
const B := MatchState.Side.B

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_ally_death_triggers_other_allies_only()
	_test_ally_death_does_not_revive_units_dying_together()
	_test_drift_returns_itself_to_hand()
	_test_cairn_counts_grave_units_including_tokens()
	_test_relic_recovers_the_chosen_card()
	_test_awaken_revives_the_chosen_card_without_its_on_play()
	_test_awaken_needs_a_choice_and_an_empty_slot()
	_test_burial_needs_an_ally_and_draws_two()
	_test_set_is_registered_with_seven_cards()


func _card(id: String) -> CardData:
	return CardLibrary.find_by_id(id)


func _new_match() -> MatchState:
	var deck: Array = []
	for i in MatchState.DECK_SIZE:
		deck.append(_card("sand"))
	var state := MatchState.new()
	state.start_match(deck, deck.duplicate(), A, 12345)
	state.current_turn = A
	return state


func _place(state: MatchState, side: int, card: CardData, slot: int) -> CardInstance:
	var unit := CardInstance.new(card)
	unit.summoned_this_turn = false
	state.board[side][slot] = unit
	return unit


func _cast(state: MatchState, spell: CardData, target: Dictionary) -> bool:
	state.hand[A].insert(0, spell)
	state.mana[A] = 9
	return state.cast_spell(A, 0, target)


func _play(state: MatchState, card: CardData, slot: int, target: Dictionary) -> bool:
	state.hand[A].insert(0, card)
	state.mana[A] = 9
	return state.play_card(A, 0, slot, target)


# --- 味方の破壊への反応 ---------------------------------------------------------


func _test_ally_death_triggers_other_allies_only() -> void:
	var state := _new_match()
	var moss := _place(state, A, _card("moss"), 0)
	_place(state, A, _card("vigil"), 1)
	_place(state, A, _card("sand"), 2)
	_place(state, B, _card("moss"), 0)
	var foe_hp: int = state.hp[B]
	state.destroy_unit(A, 2)
	_assert.call(moss.total_sand() == 4, "moss grows when another ally is destroyed")
	_assert.call(state.hp[B] == foe_hp - 1, "vigil deals 1 when another ally is destroyed")
	var foe_moss: CardInstance = state.board[B][0]
	_assert.call(foe_moss.total_sand() == 3, "the opponent's moss does not react")
	state.destroy_unit(A, 1)
	_assert.call(state.hp[B] == foe_hp - 1, "vigil does not react to its own destruction")


func _test_ally_death_does_not_revive_units_dying_together() -> void:
	var state := _new_match()
	var moss := _place(state, A, _card("moss"), 0)
	_place(state, A, _card("sand"), 1)
	moss.health = 0
	state.board[A][1].health = 0
	state._cleanup_dead()
	_assert.call(state.board[A][0] == null, "moss dying in the same blow stays dead")


# --- 墓地 -------------------------------------------------------------------


func _test_drift_returns_itself_to_hand() -> void:
	var state := _new_match()
	_place(state, A, _card("drift"), 0)
	var hand_size: int = state.hand[A].size()
	state.destroy_unit(A, 0)
	_assert.call(state.hand[A].size() == hand_size + 1, "drift returns to hand")
	_assert.call(state.hand[A].back() == _card("drift"), "the returned card is drift itself")
	_assert.call(not state.graveyard[A].has(_card("drift")), "drift leaves the graveyard")


func _test_cairn_counts_grave_units_including_tokens() -> void:
	var state := _new_match()
	state.graveyard[A] = [_card("sand"), _card("mote"), _card("shot")]
	_assert.call(_play(state, _card("cairn"), 0, {}), "play cairn")
	var cairn: CardInstance = state.board[A][0]
	_assert.call(cairn.total_sand() == 5, "cairn counts hourglasses and tokens but not spells")


func _test_relic_recovers_the_chosen_card() -> void:
	var state := _new_match()
	state.graveyard[A] = [_card("lock"), _card("mote"), _card("grain")]
	var hand_size: int = state.hand[A].size()
	_assert.call(_play(state, _card("relic"), 0, {"grave_index": 2}), "play relic")
	_assert.call(state.hand[A].size() == hand_size + 1, "relic adds a card to hand")
	_assert.call(state.hand[A].back() == _card("grain"), "relic takes the chosen card")
	_assert.call(state.graveyard[A].size() == 2, "the chosen card leaves the graveyard")
	# トークンを指しても選べない。最もコストの高い1体へ向け直す。
	state.graveyard[A] = [_card("lock"), _card("mote")]
	_assert.call(_play(state, _card("relic"), 1, {"grave_index": 1}), "play relic again")
	_assert.call(state.hand[A].back() == _card("lock"), "a token cannot be recovered")


func _test_awaken_revives_the_chosen_card_without_its_on_play() -> void:
	var state := _new_match()
	state.graveyard[A] = [_card("sword"), _card("lock")]
	var foe_hp: int = state.hp[B]
	_assert.call(_cast(state, _card("awaken"), {"grave_index": 0}), "cast awaken")
	var revived: CardInstance = state.board[A][0]
	_assert.call(revived != null and revived.data == _card("sword"), "sword comes back")
	_assert.call(revived.health == revived.data.total_sand, "it returns fresh")
	_assert.call(state.hp[B] == foe_hp, "its on-play effect does not resolve")


func _test_awaken_needs_a_choice_and_an_empty_slot() -> void:
	var state := _new_match()
	state.graveyard[A] = [_card("mote"), _card("shot")]
	state.hand[A].insert(0, _card("awaken"))
	state.mana[A] = 9
	_assert.call(not state.can_cast(A, 0), "awaken needs an hourglass in the graveyard")
	state.graveyard[A].append(_card("lock"))
	_assert.call(state.can_cast(A, 0), "awaken can be cast with a choice")
	for slot in MatchState.BOARD_SIZE:
		_place(state, A, _card("sand"), slot)
	_assert.call(not state.can_cast(A, 0), "awaken needs an empty slot")


func _test_burial_needs_an_ally_and_draws_two() -> void:
	var state := _new_match()
	state.hand[A].insert(0, _card("burial"))
	state.mana[A] = 9
	_assert.call(not state.can_cast(A, 0), "burial needs an ally to pay")
	state.hand[A].remove_at(0)
	_place(state, A, _card("seed"), 0)
	var hand_size: int = state.hand[A].size()
	_assert.call(_cast(state, _card("burial"), {"side": A, "slot": 0}), "cast burial")
	_assert.call(state.hand[A].size() == hand_size + 2, "burial draws two")
	var mote: CardInstance = state.board[A][0]
	_assert.call(mote != null and mote.data.id == "mote", "the paid seed leaves its mote")


# --- セットの登録 -------------------------------------------------------------


func _test_set_is_registered_with_seven_cards() -> void:
	_assert.call(CardSetLibrary.has_set(SET_ID), "grave_sand should be registered")
	_assert.call(CardSetLibrary.price(SET_ID) == 700, "grave_sand costs 700")
	_assert.call(CardSetLibrary.purchasable_ids().has(SET_ID), "grave_sand is sold in the shop")
	var ids := CardSetLibrary.card_ids(SET_ID)
	_assert.call(ids.size() == 7, "grave_sand has 7 cards")
	for id in ids:
		var card := CardLibrary.find_by_id(id)
		_assert.call(card != null, "card %s should exist" % id)
		if card != null:
			_assert.call(card.set_id == SET_ID, "card %s should belong to grave_sand" % id)
			_assert.call(card.emblem != null, "card %s should have an emblem" % id)
