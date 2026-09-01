extends RefCounted
## 追加した語彙(落砂 / 被弾 / 自分1体 / 攻撃力+N / 召喚 / 付与 / 沈黙 / 攻撃できない)の検証。
## GameDesign.md 6章・Architecture.md 2〜3章に対応する。
##
## **v5_rules_tests.gd へは足さない。**あちらは既に757行あり、1000行の上限へ近づいているため
## (Architecture.md 11章)。

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_tokens_are_hidden_from_the_collection()
	_test_turn_end_trigger_fires_every_turn()
	_test_turn_end_trigger_fires_before_the_last_grain_falls()
	_test_damaged_trigger_fires_only_on_real_damage()
	_test_damaged_trigger_skips_a_unit_that_dies()
	_test_ally_target_picks_own_unit()
	_test_add_attack_leaves_health_alone()
	_test_summon_fills_one_empty_slot()
	_test_summon_does_nothing_with_a_full_board()
	_test_grant_keyword_makes_a_unit_a_guard()
	_test_silence_removes_keywords_and_effects()
	_test_cannot_attack_still_allows_flipping()


# --- 検証用のカードを組み立てる -------------------------------------------


## 効果1件だけを持つカードを作る。**`.tres` を足さずに語彙そのものを検証する**ため、
## 実カードの値付けに引きずられない。
func _effect_card(
	trigger: int,
	target: int,
	effect_type: int,
	value: int,
	total := 6,
	card_id := "",
	keyword := -1
) -> CardData:
	var effect := CardEffectData.new()
	effect.trigger = trigger
	effect.target = target
	effect.effect_type = effect_type
	effect.value = value
	effect.card_id = card_id
	effect.keyword = keyword
	var card := CardData.new()
	card.id = "test_effect"
	card.display_name = "検証用"
	card.cost = 1
	card.total_sand = total
	card.effects = [effect] as Array[CardEffectData]
	return card


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
	return state


## 手札を通さず、指定のカードを直接その枠へ置く。召喚酔いも解いておく。
func _place(state: MatchState, side: int, card: CardData, slot: int) -> CardInstance:
	var unit := CardInstance.new(card)
	unit.summoned_this_turn = false
	state.board[side][slot] = unit
	return unit


# --- トークン -------------------------------------------------------------


func _test_tokens_are_hidden_from_the_collection() -> void:
	var token := CardLibrary.find_by_id("mote")
	_assert.call(token != null, "the token card should exist")
	_assert.call(token.is_token, "mote should be flagged as a token")
	for card in CardLibrary.all_cards():
		_assert.call(card.id != "mote", "all_cards() must not return tokens")


# --- 落砂 -----------------------------------------------------------------


func _test_turn_end_trigger_fires_every_turn() -> void:
	var state := _new_match()
	var card := _effect_card(
		CardEnums.Trigger.ON_TURN_END,
		CardEnums.EffectTarget.OPPONENT_PLAYER,
		CardEnums.EffectType.DAMAGE_PLAYER,
		1
	)
	_place(state, MatchState.Side.A, card, 0)
	var before: int = state.hp[MatchState.Side.B]
	state.end_turn()
	_assert.call(state.hp[MatchState.Side.B] == before - 1, "落砂 should fire on the owner's end")
	state.end_turn()
	_assert.call(
		state.hp[MatchState.Side.B] == before - 1, "落砂 must not fire on the opponent's end"
	)
	state.end_turn()
	_assert.call(state.hp[MatchState.Side.B] == before - 2, "落砂 should fire again next turn")


## 落砂は砂を落とす**直前**に発動する(Architecture.md 3.1)。
## その1粒で砕ける駒にも、最後の1回が働かなければならない。
func _test_turn_end_trigger_fires_before_the_last_grain_falls() -> void:
	var state := _new_match()
	var card := _effect_card(
		CardEnums.Trigger.ON_TURN_END,
		CardEnums.EffectTarget.OPPONENT_PLAYER,
		CardEnums.EffectType.DAMAGE_PLAYER,
		2
	)
	var unit := _place(state, MatchState.Side.A, card, 0)
	unit.health = 1
	unit.attack = 5
	var before: int = state.hp[MatchState.Side.B]
	state.end_turn()
	_assert.call(state.hp[MatchState.Side.B] == before - 2, "落砂 fires before the unit breaks")
	_assert.call(state.board[MatchState.Side.A][0] == null, "the unit should then break")


# --- 被弾 -----------------------------------------------------------------


func _test_damaged_trigger_fires_only_on_real_damage() -> void:
	var state := _new_match()
	var card := _effect_card(
		CardEnums.Trigger.ON_DAMAGED,
		CardEnums.EffectTarget.OPPONENT_PLAYER,
		CardEnums.EffectType.DAMAGE_PLAYER,
		1,
		8
	)
	_place(state, MatchState.Side.A, card, 0)
	var before: int = state.hp[MatchState.Side.B]
	state.damage_unit(MatchState.Side.A, 0, 2)
	_assert.call(state.hp[MatchState.Side.B] == before - 1, "被弾 should fire when sand is lost")

	var glass_card := _effect_card(
		CardEnums.Trigger.ON_DAMAGED,
		CardEnums.EffectTarget.OPPONENT_PLAYER,
		CardEnums.EffectType.DAMAGE_PLAYER,
		1,
		8
	)
	glass_card.keywords = [CardEnums.Keyword.GLASS] as Array[CardEnums.Keyword]
	_place(state, MatchState.Side.A, glass_card, 1)
	var guarded: int = state.hp[MatchState.Side.B]
	state.damage_unit(MatchState.Side.A, 1, 2)
	_assert.call(state.hp[MatchState.Side.B] == guarded, "被弾 must not fire when 硝子 absorbs the hit")


func _test_damaged_trigger_skips_a_unit_that_dies() -> void:
	var state := _new_match()
	var card := _effect_card(
		CardEnums.Trigger.ON_DAMAGED,
		CardEnums.EffectTarget.OPPONENT_PLAYER,
		CardEnums.EffectType.DAMAGE_PLAYER,
		1,
		3
	)
	_place(state, MatchState.Side.A, card, 0)
	var before: int = state.hp[MatchState.Side.B]
	state.damage_unit(MatchState.Side.A, 0, 3)
	_assert.call(state.hp[MatchState.Side.B] == before, "a shattered unit leaves 余砂 to fire")


# --- 対象・効果 -----------------------------------------------------------


func _test_ally_target_picks_own_unit() -> void:
	var state := _new_match()
	var ally := _place(state, MatchState.Side.A, _vanilla(5), 1)
	_place(state, MatchState.Side.B, _vanilla(9), 0)
	var card := _effect_card(
		CardEnums.Trigger.ON_PLAY,
		CardEnums.EffectTarget.ALLY_UNIT,
		CardEnums.EffectType.ADD_TOTAL,
		2
	)
	state.current_turn = MatchState.Side.A
	state.mana[MatchState.Side.A] = MatchState.MAX_MANA
	state.hand[MatchState.Side.A].push_front(card)
	state.play_card(MatchState.Side.A, 0, 0)
	_assert.call(ally.health == 7, "ALLY_UNIT should buff the strongest own unit")
	_assert.call(
		state.board[MatchState.Side.B][0].health == 9, "ALLY_UNIT must not touch the opponent"
	)


func _test_add_attack_leaves_health_alone() -> void:
	var state := _new_match()
	var target := _place(state, MatchState.Side.A, _vanilla(5), 1)
	target.health = 3
	target.attack = 2
	var card := _effect_card(
		CardEnums.Trigger.ON_PLAY,
		CardEnums.EffectTarget.ALLY_UNIT,
		CardEnums.EffectType.ADD_ATTACK,
		2
	)
	state.current_turn = MatchState.Side.A
	state.mana[MatchState.Side.A] = MatchState.MAX_MANA
	state.hand[MatchState.Side.A].push_front(card)
	state.play_card(MatchState.Side.A, 0, 0)
	_assert.call(target.attack == 4, "ADD_ATTACK should raise attack")
	_assert.call(target.health == 3, "ADD_ATTACK must not touch health")


func _test_summon_fills_one_empty_slot() -> void:
	var state := _new_match()
	var card := _effect_card(
		CardEnums.Trigger.ON_PLAY,
		CardEnums.EffectTarget.SELF,
		CardEnums.EffectType.SUMMON,
		0,
		6,
		"mote"
	)
	state.current_turn = MatchState.Side.A
	state.mana[MatchState.Side.A] = MatchState.MAX_MANA
	state.hand[MatchState.Side.A].push_front(card)
	state.play_card(MatchState.Side.A, 0, 0)
	_assert.call(state.units(MatchState.Side.A).size() == 2, "SUMMON should add one unit")
	var token: CardInstance = state.board[MatchState.Side.A][1]
	_assert.call(token != null and token.data.id == "mote", "the summoned unit should be the token")
	_assert.call(token.summoned_this_turn, "a summoned unit cannot act the turn it appears")


func _test_summon_does_nothing_with_a_full_board() -> void:
	var state := _new_match()
	for slot in MatchState.BOARD_SIZE:
		_place(state, MatchState.Side.A, _vanilla(6), slot)
	# 盤面が本当に埋まっている状態で発動させるため、枠を空けない被弾で試す。
	var summoner := _effect_card(
		CardEnums.Trigger.ON_DAMAGED,
		CardEnums.EffectTarget.SELF,
		CardEnums.EffectType.SUMMON,
		0,
		6,
		"mote"
	)
	_place(state, MatchState.Side.A, summoner, 0)
	state.damage_unit(MatchState.Side.A, 0, 1)
	_assert.call(
		state.units(MatchState.Side.A).size() == MatchState.BOARD_SIZE,
		"SUMMON must do nothing when there is no empty slot"
	)


func _test_grant_keyword_makes_a_unit_a_guard() -> void:
	var state := _new_match()
	var ally := _place(state, MatchState.Side.A, _vanilla(5), 1)
	var card := _effect_card(
		CardEnums.Trigger.ON_PLAY,
		CardEnums.EffectTarget.ALLY_UNIT,
		CardEnums.EffectType.GRANT_KEYWORD,
		0,
		6,
		"",
		CardEnums.Keyword.GUARD
	)
	state.current_turn = MatchState.Side.A
	state.mana[MatchState.Side.A] = MatchState.MAX_MANA
	state.hand[MatchState.Side.A].push_front(card)
	state.play_card(MatchState.Side.A, 0, 0)
	_assert.call(ally.has_keyword(CardEnums.Keyword.GUARD), "the ally should gain 守護")
	_assert.call(
		not ally.data.has_keyword(CardEnums.Keyword.GUARD),
		"the shared CardData must not be rewritten"
	)
	_assert.call(
		state.attackable_slots(MatchState.Side.A) == [1], "the granted 守護 should force targeting"
	)


func _test_silence_removes_keywords_and_effects() -> void:
	var state := _new_match()
	var glass := _effect_card(
		CardEnums.Trigger.ON_DEATH,
		CardEnums.EffectTarget.OPPONENT_PLAYER,
		CardEnums.EffectType.DAMAGE_PLAYER,
		3
	)
	glass.keywords = [CardEnums.Keyword.GLASS] as Array[CardEnums.Keyword]
	var victim := _place(state, MatchState.Side.B, glass, 0)
	_assert.call(victim.glass_intact, "the victim starts with its 硝子 intact")
	var card := _effect_card(
		CardEnums.Trigger.ON_PLAY,
		CardEnums.EffectTarget.ENEMY_UNIT,
		CardEnums.EffectType.SILENCE,
		0
	)
	state.current_turn = MatchState.Side.A
	state.mana[MatchState.Side.A] = MatchState.MAX_MANA
	state.hand[MatchState.Side.A].push_front(card)
	state.play_card(MatchState.Side.A, 0, 0)
	_assert.call(not victim.has_keyword(CardEnums.Keyword.GLASS), "SILENCE should strip keywords")
	_assert.call(not victim.glass_intact, "SILENCE should strip the 硝子 film too")
	var before: int = state.hp[MatchState.Side.A]
	state.destroy_unit(MatchState.Side.B, 0)
	_assert.call(state.hp[MatchState.Side.A] == before, "a silenced unit must not fire its 余砂")


func _test_cannot_attack_still_allows_flipping() -> void:
	var state := _new_match()
	var card := _vanilla(6)
	card.cannot_attack = true
	var unit := _place(state, MatchState.Side.A, card, 0)
	unit.health = 2
	unit.attack = 4
	_place(state, MatchState.Side.B, _vanilla(5), 0)
	state.current_turn = MatchState.Side.A
	_assert.call(not unit.can_attack(), "a unit that cannot attack must never be able to")
	_assert.call(not state.attack(MatchState.Side.A, 0, 0), "the attack should be refused")
	_assert.call(state.flip(MatchState.Side.A, 0), "flipping should still be allowed")
	_assert.call(unit.health == 4 and unit.attack == 2, "the flip should have swapped the sand")
