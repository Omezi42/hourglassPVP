extends RefCounted
## カードセット「写し身の刻」(第3弾の3つ目のテーマ)の検証。GameDesign.md 6章「写しを出す効果・変える効果」、Architecture.md 10.8節に対応する。

const SET_ID := "mirror_sand"
const A := MatchState.Side.A
const B := MatchState.Side.B

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_set_is_registered()
	_test_copysand_halves_total()
	_test_copy_is_fresh_token_from_top()
	_test_copy_without_room()
	_test_copy_skips_on_play()
	_test_copy_not_revived_or_returned()
	_test_copy_drops_damage_and_grants()
	_test_twins_copy_original_total()
	_test_portrait_leaves_copy()
	_test_doll_copies_foe()
	_test_doll_without_foe()
	_test_mask_copies_traits()
	_test_mask_silence_removes()
	_test_mimic_becomes_foe_card()
	_test_mimic_grave_is_mimic()
	_test_sanddoll_replaces_without_death_effect()
	_test_parallel_copies_all_up_to_room()
	_test_shade_copies_combat_slayer()
	_test_shade_ignores_effect_death()
	_test_doppel_copies_entering_foe()
	_test_doppel_copy_does_not_chain()
	_test_two_doppels_do_not_loop()
	_test_fork_keeps_copy()
	_test_charm_traitor_siphon_numbers()
	_test_cpu_plays_mirror_cards()


func _new_match(hand_ids: Array, mana := 7) -> MatchState:
	var deck: Array = []
	for i in MatchState.DECK_SIZE:
		deck.append(CardLibrary.find_by_id("sand"))
	var state := MatchState.new()
	state.start_match(deck, deck.duplicate(), MatchState.Side.A, 12345)
	state.current_turn = A
	var cards: Array = []
	for id in hand_ids:
		cards.append(CardLibrary.find_by_id(id))
	state.hand[A] = cards
	state.mana[A] = mana
	return state


func _place(
	state: MatchState, side: int, id: String, slot: int, health := -1, attack := -1
) -> CardInstance:
	var unit := CardInstance.new(CardLibrary.find_by_id(id))
	unit.summoned_this_turn = false
	if health >= 0:
		unit.health = health
		unit.attack = attack
	state.board[side][slot] = unit
	return unit


func _test_set_is_registered() -> void:
	_assert.call(CardSetLibrary.card_ids(SET_ID).size() == 10, "写し身の刻は10枚")
	for id in CardSetLibrary.card_ids(SET_ID):
		var card := CardLibrary.find_by_id(id)
		_assert.call(card != null and card.set_id == SET_ID, "%s が写し身の刻のカードとして読める" % id)
	var rarities := {
		"copysand": 0,
		"mask": 0,
		"portrait": 0,
		"doll": 0,
		"mimic": 1,
		"sanddoll": 1,
		"twins": 1,
		"parallel": 2,
		"shade": 2,
		"doppel": 3,
	}
	for id: String in rarities:
		_assert.call(int(CardLibrary.find_by_id(id).rarity) == rarities[id], "%s のレアリティ" % id)


func _test_copysand_halves_total() -> void:
	var state := _new_match(["copysand"])
	var source := _place(state, A, "sand", 0, 4, 3)
	_assert.call(state.cast_spell(A, 0, {"side": A, "slot": 0}), "写し砂を撃てる")
	var copy: CardInstance = state.board[A][1]
	_assert.call(copy != null and copy.data.id == "sand", "元と同じカードの写しが空き枠の左に出る")
	var expected := ceili(CardLibrary.find_by_id("sand").total_sand / 2.0)
	_assert.call(copy.total_sand() == expected, "総量は元のカードの総量の半分(切り上げ)")
	_assert.call(source.total_sand() == 7, "元の駒は変わらない")


func _test_copy_is_fresh_token_from_top() -> void:
	var state := _new_match(["copysand"])
	_place(state, A, "sand", 0, 4, 3)
	state.cast_spell(A, 0, {"side": A, "slot": 0})
	var copy: CardInstance = state.board[A][1]
	_assert.call(copy.attack == 0 and copy.health == copy.total_sand(), "砂はすべて上から")
	_assert.call(
		copy.data.is_token and copy.copy_of != null and not copy.copy_of.is_token,
		"写しはトークンで、写し元を覚えている"
	)
	_assert.call(not copy.can_attack() and not copy.can_flip(), "出たばかりの扱い")


func _test_copy_without_room() -> void:
	var state := _new_match(["copysand"])
	for slot in MatchState.BOARD_SIZE:
		_place(state, A, "sand", slot)
	_assert.call(not state.cast_spell(A, 0, {"side": A, "slot": 0}), "空き枠が無ければ写し砂は撃てない")


func _test_copy_skips_on_play() -> void:
	var state := _new_match(["twins"])
	state.play_card(A, 0, 0)
	_assert.call(state.units(A).size() == 2, "ツインズが1体と写し1体で2体並ぶ")
	_assert.call(state.board[A][1].copy_of.id == "twins", "写しはツインズの写し")
	_assert.call(state.units(A).size() == 2, "写しの設置効果は働かず、写しが増え続けない")


func _test_copy_not_revived_or_returned() -> void:
	var state := _new_match(["twins"])
	state.play_card(A, 0, 0)
	state.destroy_unit(A, 1)
	_assert.call(state.graveyard[A].back().is_token, "砕けた写しはトークンとして墓地に積もる")
	var picks := CardEffectResolver.grave_choices(state, A)
	_assert.call(not picks.has(state.graveyard[A].size() - 1), "写しは蘇生・回収の対象にならない")
	var state2 := _new_match(["recall"])
	var source := CardLibrary.find_by_id("sand")
	var copy := CardInstance.new(CardMirrorEffects.token_card(source, 2))
	copy.copy_of = source
	state2.board[B][1] = copy
	var hand_before: int = state2.hand[B].size()
	state2.cast_spell(A, 0, {"side": B, "slot": 1})
	_assert.call(state2.board[B][1] == null, "手札へ戻す効果を受けた写しは場から離れる")
	_assert.call(state2.hand[B].size() == hand_before, "戻った写しは手札に加わらない")


func _test_copy_drops_damage_and_grants() -> void:
	var state := _new_match(["copysand"])
	var source := _place(state, A, "sand", 0, 2, 2)
	source.grant_keyword(CardEnums.Keyword.GUARD)
	state.cast_spell(A, 0, {"side": A, "slot": 0})
	var copy: CardInstance = state.board[A][1]
	_assert.call(
		copy.total_sand() == ceili(CardLibrary.find_by_id("sand").total_sand / 2.0),
		"ダメージを受けた駒でも元のカードの総量で数える"
	)
	_assert.call(not copy.granted_keywords.has(CardEnums.Keyword.GUARD), "与えられた語は写さない")


func _test_twins_copy_original_total() -> void:
	var state := _new_match(["twins"])
	state.play_card(A, 0, 0)
	var copy: CardInstance = state.board[A][1]
	_assert.call(copy.total_sand() == 4 and copy.attack == 0, "ツインズの写しは総量4・砂は上から")
	_assert.call(state.board[A][0].total_sand() == 4, "元のツインズも変わらない")


func _test_portrait_leaves_copy() -> void:
	var state := _new_match([])
	var portrait := _place(state, A, "portrait", 0)
	state.destroy_unit(A, 0)
	var copy: CardInstance = state.board[A][0]
	_assert.call(copy != null and copy.copy_of.id == "portrait", "砕けるとポートレイトの写しが出る")
	_assert.call(copy.total_sand() == 2 and copy.attack == 0, "写しの総量は2")
	_assert.call(portrait.is_dead(), "元は砕けている")
	state.destroy_unit(A, 0)
	_assert.call(state.board[A][0] == null and state.units(A).is_empty(), "写しが砕けても写しは出ない")


func _test_doll_copies_foe() -> void:
	var state := _new_match([])
	_place(state, A, "doll", 0)
	var foe := _place(state, B, "lock", 2)
	state.destroy_unit(A, 0)
	var copy: CardInstance = state.board[A][0]
	_assert.call(copy != null and copy.copy_of.id == foe.data.id, "相手の駒の写しが自分の場に出る")
	_assert.call(copy.total_sand() == 1, "写しの総量は1")


func _test_doll_without_foe() -> void:
	var state := _new_match([])
	_place(state, A, "doll", 0)
	state.destroy_unit(A, 0)
	_assert.call(state.units(A).is_empty(), "相手の駒がいなければ不発")


func _test_mask_copies_traits() -> void:
	var state := _new_match(["mask"])
	var foe := _place(state, B, "lock", 1)
	var keywords := foe.keywords()
	state.play_card(A, 0, 0, {"side": B, "slot": 1})
	var mask: CardInstance = state.board[A][0]
	for keyword in keywords:
		_assert.call(mask.has_keyword(keyword), "相手の語を自分も持つ")
	var effects := _non_play_effect_count(foe)
	_assert.call(_non_play_effect_count(mask) >= effects, "相手の効果を自分も持つ")
	var state2 := _new_match(["mask"])
	var foe2 := _place(state2, B, "fountain", 1)
	state2.play_card(A, 0, 0, {"side": B, "slot": 1})
	var mask2: CardInstance = state2.board[A][0]
	_assert.call(not mask2.effects_for(CardEnums.Trigger.ON_ALLY_ENTER).is_empty(), "常在の効果を写し取る")
	_assert.call(foe2.effects_for(CardEnums.Trigger.ON_ALLY_ENTER).size() > 0, "相手は変わらない")


func _non_play_effect_count(unit: CardInstance) -> int:
	var count := 0
	for trigger in CardEnums.Trigger.values():
		if trigger != CardEnums.Trigger.ON_PLAY:
			count += unit.effects_for(trigger).size()
	return count


func _test_mask_silence_removes() -> void:
	var state := _new_match(["mask"])
	_place(state, B, "fountain", 1)
	state.play_card(A, 0, 0, {"side": B, "slot": 1})
	var mask: CardInstance = state.board[A][0]
	mask.silence()
	_assert.call(mask.effects_for(CardEnums.Trigger.ON_ALLY_ENTER).is_empty(), "沈黙で写し取った効果は消える")


func _test_mimic_becomes_foe_card() -> void:
	var state := _new_match(["mimic"])
	var foe := _place(state, B, "lock", 1)
	state.play_card(A, 0, 0, {"side": B, "slot": 1})
	var mimic: CardInstance = state.board[A][0]
	_assert.call(mimic.data.id == foe.data.id, "相手のカードの名前・語・効果になる")
	_assert.call(
		mimic.total_sand() == foe.data.total_sand and mimic.attack == 0, "総量は相手のカードの総量で、砂はすべて上から"
	)
	_assert.call(foe.data.id == "lock", "相手は変わらない")


func _test_mimic_grave_is_mimic() -> void:
	var state := _new_match(["mimic"])
	_place(state, B, "lock", 1)
	state.play_card(A, 0, 0, {"side": B, "slot": 1})
	state.destroy_unit(A, 0)
	_assert.call(state.graveyard[A].back().id == "mimic", "砕けて墓地へ行くのはミミック")


func _test_sanddoll_replaces_without_death_effect() -> void:
	var state := _new_match(["sanddoll"])
	var foe := _place(state, B, "amphora", 1, 4, 1)
	var grave_b: int = state.graveyard[B].size()
	_assert.call(state.cast_spell(A, 0, {"side": B, "slot": 1}), "砂人形を撃てる")
	var mote: CardInstance = state.board[B][1]
	_assert.call(
		mote != null and mote.data.id == "mote" and mote.total_sand() == 1, "総量1のモートに置き換わる"
	)
	_assert.call(state.graveyard[B].size() == grave_b, "破壊ではないため墓地へは行かず、余砂も働かない")
	_assert.call(foe.health == 4, "元の駒は変わらず取り除かれる")


func _test_parallel_copies_all_up_to_room() -> void:
	var state := _new_match(["parallel"])
	_place(state, A, "sand", 0, 2, 1)
	_place(state, A, "lock", 1)
	_place(state, A, "grain", 2)
	_place(state, A, "sand", 3)
	_assert.call(state.cast_spell(A, 0), "パラレルを撃てる")
	_assert.call(state.units(A).size() == MatchState.BOARD_SIZE, "自分の4体のうち空き枠の2体ぶんだけ写しが出る")
	_assert.call(
		state.board[A][4].copy_of.id == "sand" and state.board[A][5].copy_of.id == "lock",
		"左の駒から順に写す"
	)
	_assert.call(state.board[A][4].total_sand() == 1, "写しの総量は1")
	_assert.call(CardLibrary.find_by_id("parallel").cost == 3, "パラレルはコスト3")


func _test_shade_copies_combat_slayer() -> void:
	var state := _new_match([])
	_place(state, A, "shade", 0, 1, 0)
	var killer := _place(state, B, "lock", 0, 4, 4)
	state.current_turn = B
	killer.summoned_this_turn = false
	state.attack(B, 0, 0)
	var copy: CardInstance = state.board[A][0]
	_assert.call(
		copy != null and copy.copy_of != null and copy.copy_of.id == "lock", "戦闘で砕いた相手の駒の写しが出る"
	)
	_assert.call(copy.total_sand() == 2, "写しの総量は2")


func _test_shade_ignores_effect_death() -> void:
	var state := _new_match([])
	_place(state, A, "shade", 0, 1, 0)
	_place(state, B, "lock", 0, 4, 4)
	state.destroy_unit(A, 0)
	_assert.call(state.units(A).is_empty(), "効果で砕けたときは働かない")


func _test_doppel_copies_entering_foe() -> void:
	var state := _new_match(["lock"])
	_place(state, B, "doppel", 0)
	state.play_card(A, 0, 0)
	var copy: CardInstance = state.board[B][1]
	_assert.call(
		copy != null and copy.copy_of != null and copy.copy_of.id == "lock", "相手が出した駒の写しが出る"
	)
	_assert.call(copy.total_sand() == 1, "写しの総量は1")
	var state2 := _new_match(["sand"])
	_place(state2, B, "doppel", 0)
	state2.play_card(A, 0, 0)
	_assert.call(state2.units(B).size() == 2, "他の駒でも写す")


func _test_doppel_copy_does_not_chain() -> void:
	var state := _new_match(["sand"])
	_place(state, B, "doppel", 0)
	_place(state, A, "doppel", 3)
	state.play_card(A, 0, 0)
	_assert.call(state.units(B).size() == 2, "相手のドッペルは出された駒を1回だけ写す")
	var copy: CardInstance = state.board[B][1]
	_assert.call(copy.doppel_made, "ドッペルが出した写しだと印が付く")
	_assert.call(state.units(A).size() == 2, "ドッペルが出した写しには自分のドッペルも働かない")


func _test_two_doppels_do_not_loop() -> void:
	var state := _new_match(["lock"])
	_place(state, A, "doppel", 3)
	_place(state, B, "doppel", 0)
	state.play_card(A, 0, 0)
	_assert.call(state.units(A).size() <= 3 and state.units(B).size() <= 3, "ドッペルどうしでも写しが連鎖しない")


func _test_fork_keeps_copy() -> void:
	var state := _new_match(["twins"])
	state.play_card(A, 0, 0)
	var twin := SpellForecast.fork(state)
	var copy: CardInstance = twin.board[A][1]
	_assert.call(
		copy.copy_of != null and copy.copy_of.id == "twins" and copy.data.is_token,
		"対局の写しも写しの元を覚えている"
	)
	var state2 := _new_match(["mimic"])
	_place(state2, B, "lock", 1)
	state2.play_card(A, 0, 0, {"side": B, "slot": 1})
	var fork2 := SpellForecast.fork(state2)
	_assert.call(fork2.board[A][0].origin_card.id == "mimic", "化けた駒の本当のカードも覚えている")


func _test_charm_traitor_siphon_numbers() -> void:
	var charm := CardLibrary.find_by_id("charm")
	_assert.call(
		charm.total_sand == 3 and charm.effects[0].condition_total == 3, "チャームは総量3・総量3以下を奪う"
	)
	var traitor := CardLibrary.find_by_id("traitor")
	_assert.call(
		traitor.cost == 4 and traitor.total_sand == 3 and traitor.effects[0].condition_total == 6,
		"トレイターはコスト4・総量6以下と入れ替える"
	)
	var state := _new_match(["traitor"])
	var big := _place(state, B, "sand", 2, 5, 2)
	state.play_card(A, 0, 4, {"side": B, "slot": 2})
	_assert.call(state.board[B][2] == big, "総量7の駒とは入れ替えられない")
	var siphon := CardLibrary.find_by_id("siphon")
	_assert.call(
		siphon.effects[0].value == 2 and siphon.effects[0].transfer_gain == 1, "サイフォンは2減らして1増やす"
	)


func _test_cpu_plays_mirror_cards() -> void:
	var cpu := CardCpuStrategy.new()
	var state := _new_match(["twins"])
	_assert.call(cpu.choose_action(state, A).get("type", "") == "play", "CPUはツインズを出す")
	var state2 := _new_match(["mimic"])
	_place(state2, B, "lock", 0, 4, 4)
	_assert.call(cpu.choose_action(state2, A).get("type", "") == "play", "CPUは大きな相手がいればミミックを出す")
	var state3 := _new_match(["sanddoll"])
	_place(state3, B, "lock", 0, 4, 4)
	_assert.call(cpu.choose_action(state3, A).get("type", "") in ["cast", "play"], "CPUは砂人形を撃つ")
