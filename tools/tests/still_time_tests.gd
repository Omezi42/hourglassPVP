extends RefCounted
## カードセット「静止の刻」の語彙(静止 / 砂が上へ戻る / 反転できない / 攻撃力>体力)の検証。
## GameDesign.md 6章・8章、Architecture.md 10.8.2節に対応する。
##
## `v5_vocabulary_tests.gd` と同じ流儀で、`.tres` を足さずに語彙そのものを検証する。

const SET_ID := "still_time"

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_still_unit_does_not_tick_but_its_turn_end_trigger_fires()
	_test_still_unit_shatters_when_flipped_by_flip_right()
	_test_raise_sand_moves_attack_back_to_health_up_to_attack()
	_test_raise_sand_effect_targets_an_ally()
	_test_cannot_flip_refuses_flip_and_flip_right()
	_test_attack_over_health_filters_the_target()
	_test_set_is_registered_with_nine_cards()


func _vanilla(total: int) -> CardData:
	var card := CardData.new()
	card.id = "test_vanilla"
	card.display_name = "検証用バニラ"
	card.cost = 1
	card.total_sand = total
	return card


func _effect_card(trigger: int, target: int, effect_type: int, value: int, scope := 0) -> CardData:
	var effect := CardEffectData.new()
	effect.trigger = trigger
	effect.target = target
	effect.effect_type = effect_type
	effect.value = value
	effect.condition_scope = scope
	var card := _vanilla(6)
	card.id = "test_effect"
	card.effects = [effect] as Array[CardEffectData]
	return card


func _new_match() -> MatchState:
	var deck: Array = []
	for i in MatchState.DECK_SIZE:
		deck.append(CardLibrary.find_by_id("sand"))
	var state := MatchState.new()
	state.start_match(deck, deck.duplicate(), MatchState.Side.A, 12345)
	state.current_turn = MatchState.Side.A
	return state


func _place(state: MatchState, side: int, card: CardData, slot: int) -> CardInstance:
	var unit := CardInstance.new(card)
	unit.summoned_this_turn = false
	state.board[side][slot] = unit
	return unit


## 手札の先頭へ砂術を差し、マナを満たして撃つ。
func _cast(state: MatchState, spell: CardData, target: Dictionary) -> bool:
	state.hand[MatchState.Side.A].insert(0, spell)
	state.mana[MatchState.Side.A] = 5
	return state.cast_spell(MatchState.Side.A, 0, target)


# --- 静止 -----------------------------------------------------------------


func _test_still_unit_does_not_tick_but_its_turn_end_trigger_fires() -> void:
	var state := _new_match()
	var card := _effect_card(
		CardEnums.Trigger.ON_TURN_END,
		CardEnums.EffectTarget.OWN_PLAYER,
		CardEnums.EffectType.HEAL_PLAYER,
		1
	)
	card.keywords = [CardEnums.Keyword.STILL] as Array[CardEnums.Keyword]
	var still := _place(state, MatchState.Side.A, card, 0)
	var mate := _place(state, MatchState.Side.A, _vanilla(5), 1)
	state.hp[MatchState.Side.A] = 10
	var ticked: Array = []
	state.unit_ticked.connect(func(_side: int, slot: int) -> void: ticked.append(slot))
	state.end_turn()
	_assert.call(still.health == 6 and still.attack == 0, "静止 must not drop sand on turn end")
	_assert.call(mate.health == 4 and mate.attack == 1, "the other unit still ages")
	_assert.call(state.hp[MatchState.Side.A] == 11, "静止 must not stop the 落砂 trigger")
	_assert.call(ticked == [1], "unit_ticked must fire only for the unit whose sand moved")


func _test_still_unit_shatters_when_flipped_by_flip_right() -> void:
	var state := _new_match()
	var card := _vanilla(5)
	card.keywords = [CardEnums.Keyword.STILL] as Array[CardEnums.Keyword]
	_place(state, MatchState.Side.B, card, 0)
	state.flip_right_remaining[MatchState.Side.A] = 1
	_assert.call(
		state.use_flip_right(MatchState.Side.A, MatchState.Side.B, 0), "flip right applies"
	)
	_assert.call(state.board[MatchState.Side.B][0] == null, "a flipped 静止 unit (attack 0) shatters")


# --- 砂が上へ戻る ---------------------------------------------------------


func _test_raise_sand_moves_attack_back_to_health_up_to_attack() -> void:
	var unit := CardInstance.new(_vanilla(6))
	unit.health = 2
	unit.attack = 4
	_assert.call(unit.raise_sand(3) == 3, "raise_sand returns the amount moved")
	_assert.call(unit.health == 5 and unit.attack == 1, "attack-3 / health+3")
	_assert.call(unit.raise_sand(3) == 1, "only the remaining attack can be moved")
	_assert.call(unit.health == 6 and unit.attack == 0, "attack never goes below 0")
	_assert.call(unit.total_sand() == 6, "the total must not change")


func _test_raise_sand_effect_targets_an_ally() -> void:
	var state := _new_match()
	var spell := _effect_card(
		CardEnums.Trigger.ON_PLAY,
		CardEnums.EffectTarget.ALLY_UNIT,
		CardEnums.EffectType.RAISE_SAND,
		2
	)
	spell.is_spell = true
	var ally := _place(state, MatchState.Side.A, _vanilla(6), 0)
	ally.health = 3
	ally.attack = 3
	var raised: Array = []
	state.unit_raised.connect(
		func(side: int, slot: int, amount: int) -> void: raised.append([side, slot, amount])
	)
	_assert.call(_cast(state, spell, {"side": 0, "slot": 0}), "cast the spell")
	_assert.call(ally.health == 5 and ally.attack == 1, "two grains moved back up")
	_assert.call(raised == [[0, 0, 2]], "unit_raised carries side / slot / amount")


# --- 反転できない -----------------------------------------------------------


func _test_cannot_flip_refuses_flip_and_flip_right() -> void:
	var state := _new_match()
	var card := _vanilla(6)
	card.cannot_flip = true
	var unit := _place(state, MatchState.Side.A, card, 0)
	unit.health = 2
	unit.attack = 4
	_assert.call(not state.can_flip(MatchState.Side.A, 0), "cannot_flip refuses the normal flip")
	_assert.call(not state.flip(MatchState.Side.A, 0), "flip() is refused")
	state.flip_right_remaining[MatchState.Side.A] = 1
	_assert.call(
		not state.use_flip_right(MatchState.Side.A, MatchState.Side.A, 0),
		"cannot_flip also refuses the flip right"
	)
	_assert.call(
		int(state.flip_right_remaining[MatchState.Side.A]) == 1, "the flip right is not spent"
	)
	_assert.call(unit.health == 2 and unit.attack == 4, "the sand is untouched")


# --- 攻撃力が体力より多い --------------------------------------------------


func _test_attack_over_health_filters_the_target() -> void:
	var state := _new_match()
	var spell := _effect_card(
		CardEnums.Trigger.ON_PLAY,
		CardEnums.EffectTarget.ENEMY_UNIT,
		CardEnums.EffectType.DESTROY_UNIT,
		0,
		CardEnums.ConditionScope.ATTACK_OVER_HEALTH
	)
	spell.is_spell = true
	var young := _place(state, MatchState.Side.B, _vanilla(6), 0)
	young.health = 5
	young.attack = 1
	var aged := _place(state, MatchState.Side.B, _vanilla(6), 1)
	aged.health = 2
	aged.attack = 4
	# 若い駒を指しても、条件を満たす老いた駒へ向く。
	_assert.call(_cast(state, spell, {"side": 1, "slot": 0}), "cast")
	_assert.call(state.board[MatchState.Side.B][0] == young, "the young unit is untouched")
	_assert.call(state.board[MatchState.Side.B][1] == null, "the aged unit is destroyed")
	# 条件を満たす駒がいなければ何も壊れない。
	_assert.call(_cast(state, spell, {"side": 1, "slot": 0}), "cast again")
	_assert.call(state.board[MatchState.Side.B][0] == young, "no eligible target: nothing dies")


# --- セットの登録 -------------------------------------------------------------


func _test_set_is_registered_with_nine_cards() -> void:
	_assert.call(CardSetLibrary.has_set(SET_ID), "still_time should be registered")
	_assert.call(CardSetLibrary.price(SET_ID) == 900, "still_time costs 900")
	_assert.call(CardSetLibrary.purchasable_ids().has(SET_ID), "still_time is sold in the shop")
	var ids := CardSetLibrary.card_ids(SET_ID)
	_assert.call(ids.size() == 9, "still_time has 9 cards")
	for id in ids:
		var card := CardLibrary.find_by_id(id)
		_assert.call(card != null, "card %s should exist" % id)
		if card != null:
			_assert.call(card.set_id == SET_ID, "card %s should belong to still_time" % id)
			_assert.call(card.emblem != null, "card %s should have an emblem" % id)
