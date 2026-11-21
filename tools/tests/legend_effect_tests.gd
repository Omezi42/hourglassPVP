extends RefCounted
## 第1弾のレジェンドの固有効果(GameDesign.md 6章「第1弾のレジェンドの固有効果」)の検証。
## カードの .tres に頼らず、効果1件だけを持つ検証用の砂時計で確かめる。

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_excess_destroys_difference()
	_test_excess_does_nothing_when_even()
	_test_set_total_fills_and_trims()
	_test_set_total_keeps_health_one()
	_test_drop_to_one_is_not_damage()
	_test_raise_all_sand_zeroes_attack()
	_test_revive_all_fills_empty_slots()
	_test_revive_all_skips_tokens_and_spells()
	_test_all_other_units_flips_both_sides_but_self()


func _vanilla(total: int, id := "test_vanilla") -> CardData:
	var card := CardData.new()
	card.id = id
	card.display_name = "検証用バニラ"
	card.cost = 1
	card.total_sand = total
	return card


func _legend(effect_type: int, target: int, value := 0) -> CardData:
	var effect := CardEffectData.new()
	effect.trigger = CardEnums.Trigger.ON_PLAY
	effect.target = target
	effect.effect_type = effect_type
	effect.value = value
	var card := _vanilla(5, "test_legend")
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


func _play(state: MatchState, card: CardData, slot: int) -> bool:
	state.hand[MatchState.Side.A] = [card]
	state.mana[MatchState.Side.A] = card.cost
	return state.play_card(MatchState.Side.A, 0, slot)


func _count(state: MatchState, side: int) -> int:
	return state.units(side).size()


func _test_excess_destroys_difference() -> void:
	var state := _new_match()
	_place(state, MatchState.Side.A, _vanilla(3), 0)
	for slot in 4:
		_place(state, MatchState.Side.B, _vanilla(3), slot)
	var card := _legend(
		CardEnums.EffectType.DESTROY_RANDOM_BY_EXCESS, CardEnums.EffectTarget.ALL_ENEMY_UNITS
	)
	_assert.call(_play(state, card, 1), "イコライザーを出せる")
	_assert.call(_count(state, MatchState.Side.B) == 2, "相手4体・自分2体(自身を含む)なら2体壊れて数がそろう")


func _test_excess_does_nothing_when_even() -> void:
	var state := _new_match()
	_place(state, MatchState.Side.A, _vanilla(3), 0)
	_place(state, MatchState.Side.B, _vanilla(3), 0)
	_place(state, MatchState.Side.B, _vanilla(3), 1)
	var card := _legend(
		CardEnums.EffectType.DESTROY_RANDOM_BY_EXCESS, CardEnums.EffectTarget.ALL_ENEMY_UNITS
	)
	_play(state, card, 1)
	_assert.call(_count(state, MatchState.Side.B) == 2, "自分(自身を含む)と同じ数なら壊さない")


func _test_set_total_fills_and_trims() -> void:
	var state := _new_match()
	var small := _place(state, MatchState.Side.A, _vanilla(2), 0)
	var big := _place(state, MatchState.Side.A, _vanilla(8), 1)
	big.drop_sand(2)
	var card := _legend(CardEnums.EffectType.SET_TOTAL, CardEnums.EffectTarget.ALL_ALLY_UNITS, 5)
	_play(state, card, 2)
	_assert.call(small.total_sand() == 5 and small.health == 5, "足りないぶんは体力へ足す")
	_assert.call(big.total_sand() == 5 and big.attack == 2 and big.health == 3, "多いぶんは体力から引く")


func _test_set_total_keeps_health_one() -> void:
	var state := _new_match()
	var aged := _place(state, MatchState.Side.A, _vanilla(8), 0)
	aged.drop_sand(7)
	var card := _legend(CardEnums.EffectType.SET_TOTAL, CardEnums.EffectTarget.ALL_ALLY_UNITS, 5)
	_play(state, card, 1)
	_assert.call(aged.health == 1 and aged.attack == 4, "体力が1未満になるぶんは攻撃力から引く")
	var legend: CardInstance = state.board[MatchState.Side.A][1]
	_assert.call(legend.total_sand() == 5, "自分自身は変えない")


func _test_drop_to_one_is_not_damage() -> void:
	var state := _new_match()
	var glass_card := _vanilla(6)
	glass_card.keywords = [CardEnums.Keyword.GLASS] as Array[CardEnums.Keyword]
	var foe := _place(state, MatchState.Side.B, glass_card, 0)
	var weak := _place(state, MatchState.Side.B, _vanilla(3), 1)
	weak.drop_sand(2)
	var card := _legend(
		CardEnums.EffectType.DROP_SAND_TO_ONE, CardEnums.EffectTarget.ALL_ENEMY_UNITS
	)
	_play(state, card, 0)
	_assert.call(foe.health == 1 and foe.attack == 5, "砂を落として体力を1にする")
	_assert.call(foe.glass_intact, "ダメージではないので硝子は割れない")
	_assert.call(weak.health == 1 and weak.attack == 2, "体力1の駒は変わらない")


func _test_raise_all_sand_zeroes_attack() -> void:
	var state := _new_match()
	var foe := _place(state, MatchState.Side.B, _vanilla(6), 0)
	foe.drop_sand(4)
	var card := _legend(CardEnums.EffectType.RAISE_ALL_SAND, CardEnums.EffectTarget.ALL_ENEMY_UNITS)
	_play(state, card, 0)
	_assert.call(foe.attack == 0 and foe.health == 6, "砂を残らず上へ戻し、総量は変わらない")


func _test_revive_all_fills_empty_slots() -> void:
	var state := _new_match()
	_place(state, MatchState.Side.A, _vanilla(3), 0)
	state.graveyard[MatchState.Side.A] = [_vanilla(4), _vanilla(5)]
	var card := _legend(CardEnums.EffectType.REVIVE_RANDOM_ALL, CardEnums.EffectTarget.SELF)
	_play(state, card, 1)
	_assert.call(_count(state, MatchState.Side.A) == 4, "空き枠へ墓地の砂時計を出せるだけ出す")
	_assert.call(state.graveyard[MatchState.Side.A].is_empty(), "出した砂時計は墓地から抜ける")
	var revived: CardInstance = state.board[MatchState.Side.A][2]
	_assert.call(revived != null and not revived.can_attack(), "出した駒はその手番に動けない")


func _test_revive_all_skips_tokens_and_spells() -> void:
	var state := _new_match()
	var token := _vanilla(2, "test_token")
	token.is_token = true
	var spell := _vanilla(0, "test_spell")
	spell.is_spell = true
	state.graveyard[MatchState.Side.A] = [token, spell]
	var card := _legend(CardEnums.EffectType.REVIVE_RANDOM_ALL, CardEnums.EffectTarget.SELF)
	_play(state, card, 0)
	_assert.call(_count(state, MatchState.Side.A) == 1, "トークンと砂術は出さない")


func _test_all_other_units_flips_both_sides_but_self() -> void:
	var state := _new_match()
	var ally := _place(state, MatchState.Side.A, _vanilla(5), 0)
	ally.drop_sand(3)
	var fresh := _place(state, MatchState.Side.B, _vanilla(4), 0)
	var aged := _place(state, MatchState.Side.B, _vanilla(4), 1)
	aged.drop_sand(3)
	var card := _legend(CardEnums.EffectType.SWAP_STATS, CardEnums.EffectTarget.ALL_OTHER_UNITS)
	card.total_sand = 3
	_play(state, card, 1)
	var legend: CardInstance = state.board[MatchState.Side.A][1]
	_assert.call(legend != null and legend.health == 3, "自分自身は返らない")
	_assert.call(ally.health == 3 and ally.attack == 2, "味方も返る")
	_assert.call(aged.health == 3 and aged.attack == 1, "相手の老いた駒は若返る")
	_assert.call(state.board[MatchState.Side.B][0] == null, "攻撃力0の駒は体力0になって砕ける")
	_assert.call(fresh.is_dead(), "砕けたのは攻撃力0だった駒")
