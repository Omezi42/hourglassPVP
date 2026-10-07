extends RefCounted
## カードセット「反響の刻」と、反転の扱いの統一(GameDesign.md 6章「反転は、誰がどう起こしても反転である」)の検証。
## Architecture.md 10.8.4節に対応する。

const SET_ID := "echo_time"

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_effect_flip_fires_flip_trigger_and_marks_flipped()
	_test_effect_flip_skips_unflippable()
	_test_flip_right_keeps_manual_flip()
	_test_reverb_flips_an_aged_ally()
	_test_reverb_pair_does_not_loop()
	_test_reverb_picks_only_eligible_at_random()
	_test_delay_flips_an_aged_ally_at_turn_end()
	_test_delay_triggers_reverb_chain()
	_test_repeat_resets_flipped_allies()
	_test_repeat_keeps_summoning_sickness()
	_test_turn_spell_still_survives_on_fresh_unit()
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
	return state


func _place(state: MatchState, side: int, card: CardData, slot: int) -> CardInstance:
	var unit := CardInstance.new(card)
	unit.summoned_this_turn = false
	state.board[side][slot] = unit
	return unit


func _cast(state: MatchState, spell: CardData, target: Dictionary) -> bool:
	state.hand[MatchState.Side.A] = [spell]
	state.mana[MatchState.Side.A] = spell.cost
	return state.cast_spell(MatchState.Side.A, 0, target)


func _test_effect_flip_fires_flip_trigger_and_marks_flipped() -> void:
	var state := _new_match()
	var glow := _place(state, MatchState.Side.A, CardLibrary.find_by_id("glow"), 0)
	glow.drop_sand(5)
	var before := glow.total_sand()
	_cast(state, _swap_spell(), {"side": 0, "slot": 0})
	_assert.call(glow.total_sand() == before + 1, "効果による反転でも反転トリガーが発動する")
	_assert.call(state.can_flip(MatchState.Side.A, 0), "効果で反転しても、そのターンの手の反転は残る")


func _swap_spell() -> CardData:
	var effect := CardEffectData.new()
	effect.trigger = CardEnums.Trigger.ON_PLAY
	effect.target = CardEnums.EffectTarget.ALLY_UNIT
	effect.effect_type = CardEnums.EffectType.SWAP_STATS
	var spell := CardData.new()
	spell.id = "test_swap"
	spell.cost = 1
	spell.is_spell = true
	spell.effects = [effect] as Array[CardEffectData]
	return spell


func _test_effect_flip_skips_unflippable() -> void:
	var state := _new_match()
	var chronos := _place(state, MatchState.Side.A, CardLibrary.find_by_id("chronos"), 0)
	chronos.drop_sand(4)
	var attack := chronos.attack
	_cast(state, _swap_spell(), {"side": 0, "slot": 0})
	_assert.call(chronos.attack == attack, "反転できない駒は効果でも反転しない")


func _test_flip_right_keeps_manual_flip() -> void:
	var state := _new_match()
	var unit := _place(state, MatchState.Side.A, _vanilla(6), 0)
	unit.drop_sand(4)
	_assert.call(state.use_flip_right(MatchState.Side.A, MatchState.Side.A, 0), "反転権を使える")
	_assert.call(state.can_flip(MatchState.Side.A, 0), "反転権で返しても、そのターンの手の反転は残る")


func _test_reverb_flips_an_aged_ally() -> void:
	var state := _new_match()
	var reverb := _place(state, MatchState.Side.A, CardLibrary.find_by_id("reverb"), 0)
	reverb.drop_sand(4)
	var young := _place(state, MatchState.Side.A, _vanilla(6), 1)
	young.drop_sand(1)
	var aged := _place(state, MatchState.Side.A, _vanilla(6), 2)
	aged.drop_sand(5)
	_assert.call(state.flip(MatchState.Side.A, 0), "リバーブを反転できる")
	_assert.call(aged.health == 5 and aged.attack == 1, "リバーブは攻撃力が体力より多い味方を返す")
	_assert.call(young.health == 5 and young.attack == 1, "若い味方は返さない")


func _test_reverb_pair_does_not_loop() -> void:
	var state := _new_match()
	var first := _place(state, MatchState.Side.A, CardLibrary.find_by_id("reverb"), 0)
	first.drop_sand(4)
	var second := _place(state, MatchState.Side.A, CardLibrary.find_by_id("reverb"), 1)
	second.drop_sand(4)
	_assert.call(state.flip(MatchState.Side.A, 0), "リバーブ2体でも反転が終わる")
	_assert.call(first.health == 4 and second.health == 4, "互いに1度ずつ返って止まる")


func _test_reverb_picks_only_eligible_at_random() -> void:
	var picked := {}
	for seed_value in range(1, 21):
		var state := _new_match()
		state._rng.seed = seed_value
		var reverb := _place(state, MatchState.Side.A, CardLibrary.find_by_id("reverb"), 0)
		reverb.drop_sand(4)
		_place(state, MatchState.Side.A, _vanilla(6), 1).drop_sand(1)
		_place(state, MatchState.Side.A, _vanilla(6), 2).drop_sand(5)
		_place(state, MatchState.Side.A, _vanilla(6), 3).drop_sand(5)
		state.flip(MatchState.Side.A, 0)
		var flipped := 0
		for slot in [2, 3]:
			if state.board[MatchState.Side.A][slot].health == 5:
				flipped += 1
				picked[slot] = true
		_assert.call(state.board[MatchState.Side.A][1].health == 5, "若い味方は返さない")
		_assert.call(flipped == 1, "条件を満たす味方のうち1体だけを返す")
	_assert.call(picked.size() == 2, "条件を満たす味方のどちらも選ばれうる")


func _test_delay_flips_an_aged_ally_at_turn_end() -> void:
	var state := _new_match()
	_place(state, MatchState.Side.A, CardLibrary.find_by_id("delay"), 0)
	var young := _place(state, MatchState.Side.A, _vanilla(6), 1)
	young.drop_sand(1)
	var aged := _place(state, MatchState.Side.A, _vanilla(6), 2)
	aged.drop_sand(5)
	state.end_turn()
	_assert.call(aged.health == 4 and aged.attack == 2, "ディレイは落砂で攻撃力が体力より多い味方を返してから砂が落ちる")
	_assert.call(young.health == 4 and young.attack == 2, "ディレイは若い味方を返さない")


func _test_delay_triggers_reverb_chain() -> void:
	var chained := false
	for seed_value in range(1, 21):
		var state := _new_match()
		state._rng.seed = seed_value
		_place(state, MatchState.Side.A, CardLibrary.find_by_id("delay"), 0)
		var reverb := _place(state, MatchState.Side.A, CardLibrary.find_by_id("reverb"), 1)
		reverb.drop_sand(4)
		var aged := _place(state, MatchState.Side.A, _vanilla(6), 2)
		aged.drop_sand(5)
		state.end_turn()
		if reverb.health == 3 and aged.health == 4:
			chained = true
	_assert.call(chained, "ディレイがリバーブを返すと、リバーブの反転が次の味方を返す")


func _play_repeat(state: MatchState) -> bool:
	state.hand[MatchState.Side.A] = [CardLibrary.find_by_id("repeat")]
	state.mana[MatchState.Side.A] = 2
	return state.play_card(MatchState.Side.A, 0, 4)


func _test_repeat_resets_flipped_allies() -> void:
	var state := _new_match()
	var flipped := _place(state, MatchState.Side.A, _vanilla(6), 0)
	flipped.drop_sand(5)
	var waiting := _place(state, MatchState.Side.A, _vanilla(6), 1)
	_assert.call(state.flip(MatchState.Side.A, 0), "1回目の反転ができる")
	_assert.call(not state.can_flip(MatchState.Side.A, 0), "反転した駒はそのターンもう反転できない")
	_assert.call(_play_repeat(state), "リピートを出せる")
	_assert.call(state.can_flip(MatchState.Side.A, 0), "リピートで反転済みの駒がもう一度反転できる")
	_assert.call(state.flip(MatchState.Side.A, 0), "2回目の反転ができる")
	_assert.call(
		state.can_flip(MatchState.Side.A, 1) and not waiting.flipped_this_turn, "反転していない駒はそのまま"
	)


func _test_repeat_keeps_summoning_sickness() -> void:
	var state := _new_match()
	var fresh := CardInstance.new(_vanilla(6))
	state.board[MatchState.Side.A][0] = fresh
	_assert.call(_play_repeat(state), "リピートを出せる")
	_assert.call(not state.can_flip(MatchState.Side.A, 0), "リピートでも出したターンの駒は反転できない")


func _test_turn_spell_still_survives_on_fresh_unit() -> void:
	var state := _new_match()
	var fresh := CardInstance.new(_vanilla(3))
	state.board[MatchState.Side.A][0] = fresh
	_cast(state, CardLibrary.find_by_id("turn"), {"side": 0, "slot": 0})
	_assert.call(
		state.board[MatchState.Side.A][0] == fresh and fresh.health == 1,
		"逆さ砂は反転の後の総量+1まで解決してから砕けるかを判断する"
	)


func _test_set_is_staged() -> void:
	_assert.call(CardSetLibrary.has_set(SET_ID), "echo_time is registered")
	_assert.call(CardSetLibrary.price(SET_ID) == 800, "echo_time costs 800")
	_assert.call(CardSetLibrary.planned_count(SET_ID) == 8, "echo_time plans 8 cards")
	_assert.call(CardSetLibrary.card_ids(SET_ID)[0] == "reverb", "echo_time opens with reverb")
	_assert.call(CardSetLibrary.card_ids(SET_ID)[1] == "delay", "echo_time second card is delay")
	_assert.call(CardSetLibrary.card_ids(SET_ID)[2] == "repeat", "echo_time third card is repeat")
