extends RefCounted
## カードセット「詠砂の刻」の検証。Architecture.md 10.8.7節に対応する。

const SET_ID := "chant_sand"

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_scribe_grows_on_own_spell()
	_test_scribe_ignores_foe_spell()
	_test_scribe_ignores_unit_play()
	_test_scribe_broken_by_spell_does_not_react()
	_test_cpu_values_own_spell_trigger()
	_test_divine_takes_spell_from_deck()
	_test_divine_without_spells_does_nothing()
	_test_divine_is_not_a_draw()
	_test_set_is_registered()


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


func _place(state: MatchState, side: int, id: String, slot: int) -> CardInstance:
	var unit := CardInstance.new(CardLibrary.find_by_id(id))
	unit.summoned_this_turn = false
	state.board[side][slot] = unit
	return unit


func _test_scribe_grows_on_own_spell() -> void:
	var state := _new_match(["shot", "shot"])
	var scribe := _place(state, MatchState.Side.A, "scribe", 0)
	var before := scribe.health + scribe.attack
	state.cast_spell(MatchState.Side.A, 0)
	state.cast_spell(MatchState.Side.A, 0)
	_assert.call(scribe.health + scribe.attack == before + 2, "スクライブは自分が砂術を使うたび総量+1")


func _test_scribe_ignores_foe_spell() -> void:
	var state := _new_match([])
	var scribe := _place(state, MatchState.Side.B, "scribe", 0)
	var before := scribe.health + scribe.attack
	state.hand[MatchState.Side.A] = [CardLibrary.find_by_id("shot")]
	state.cast_spell(MatchState.Side.A, 0)
	_assert.call(scribe.health + scribe.attack == before, "スクライブは相手の砂術に反応しない")


func _test_scribe_ignores_unit_play() -> void:
	var state := _new_match(["sand"])
	var scribe := _place(state, MatchState.Side.A, "scribe", 0)
	var before := scribe.health + scribe.attack
	state.play_card(MatchState.Side.A, 0, 1)
	_assert.call(scribe.health + scribe.attack == before, "スクライブは砂時計を出しても育たない")


## 自分の駒を払う砂術で払われたスクライブは、解決の後に場にいないので反応しない。
func _test_scribe_broken_by_spell_does_not_react() -> void:
	var state := _new_match(["burial"])
	_place(state, MatchState.Side.A, "scribe", 0)
	state.cast_spell(MatchState.Side.A, 0, {"side": MatchState.Side.A, "slot": 0})
	_assert.call(state.board[MatchState.Side.A][0] == null, "砂葬で払ったスクライブは場に残らない")
	var grave: Array = state.graveyard[MatchState.Side.A]
	_assert.call(
		grave.any(func(card: CardData) -> bool: return card.id == "scribe"), "払われたスクライブは墓地へ行く"
	)


func _test_cpu_values_own_spell_trigger() -> void:
	var state := _new_match([])
	var cpu := CardCpuStrategy.new()
	var scribe := CardLibrary.find_by_id("scribe")
	_assert.call(
		cpu._repeating_value(state, MatchState.Side.A, scribe) > 0.0, "CPUは自分の砂術に反応する効果に価値を見る"
	)


func _test_divine_takes_spell_from_deck() -> void:
	var state := _new_match(["divine"])
	state.deck[MatchState.Side.A][7] = CardLibrary.find_by_id("shot")
	var deck_before: int = state.deck[MatchState.Side.A].size()
	state.cast_spell(MatchState.Side.A, 0)
	var hand: Array = state.hand[MatchState.Side.A]
	_assert.call(hand.size() == 1 and hand[0].id == "shot", "砂占いは山札の砂術を手札に加える")
	_assert.call(state.deck[MatchState.Side.A].size() == deck_before - 1, "砂占いで加えた砂術は山札から抜ける")


func _test_divine_without_spells_does_nothing() -> void:
	var state := _new_match(["divine"])
	var deck_before: int = state.deck[MatchState.Side.A].size()
	state.cast_spell(MatchState.Side.A, 0)
	_assert.call(
		(
			state.hand[MatchState.Side.A].is_empty()
			and state.deck[MatchState.Side.A].size() == deck_before
		),
		"山札に砂術が無ければ砂占いは何もしない"
	)


## 「引く」ではないため、相手のドローに反応する駒(ハウンド)は働かない。
func _test_divine_is_not_a_draw() -> void:
	var state := _new_match(["divine"])
	state.deck[MatchState.Side.A][3] = CardLibrary.find_by_id("shot")
	_place(state, MatchState.Side.B, "hound", 0)
	var mine := _place(state, MatchState.Side.A, "sand", 0)
	var health_before := mine.health
	state.cast_spell(MatchState.Side.A, 0)
	_assert.call(mine.health == health_before, "砂占いは相手のドローに反応する効果(ハウンド)を起こさない")


func _test_set_is_registered() -> void:
	_assert.call(CardSetLibrary.has_set(SET_ID), "詠砂の刻が登録されている")
	_assert.call(CardSetLibrary.card_ids(SET_ID).has("scribe"), "スクライブが詠砂の刻に入っている")
	_assert.call(CardSetLibrary.card_ids(SET_ID).has("divine"), "砂占いが詠砂の刻に入っている")
	_assert.call(CardSetLibrary.planned_count(SET_ID) == 8, "詠砂の刻は予定8枚")
	_assert.call(CardEnums.trigger_name(CardEnums.Trigger.ON_OWN_SPELL) == "常在", "砂術への反応は「常在」と出す")
