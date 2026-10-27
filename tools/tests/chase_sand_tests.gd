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
	_test_pelt_hits_unit_and_draws()
	_test_bola_destroys_only_low_health()
	_test_bola_fizzles_on_sturdy_board()
	_test_nibble_hits_lowest_health()
	_test_nibble_breaks_ties_leftmost()
	_test_block_guards_and_draws_on_death()
	_test_vault_grows_ally_when_damaged()
	_test_hive_summons_mote_when_damaged()
	_test_relief_heals_per_enemy_unit()
	_test_relief_heals_nothing_on_empty_board()
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


func _test_pelt_hits_unit_and_draws() -> void:
	var state := _new_match()
	state.hand[MatchState.Side.A] = [CardLibrary.find_by_id("pelt")]
	var foe := _place(state, MatchState.Side.B, _vanilla(3), 1)
	var hp := int(state.hp[MatchState.Side.B])
	state.cast_spell(MatchState.Side.A, 0, {"side": MatchState.Side.B, "slot": 1})
	_assert.call(foe.health == 2, "砂つぶては選んだ駒へ1ダメージ")
	_assert.call(int(state.hp[MatchState.Side.B]) == hp, "砂つぶては本体に当たらない")
	_assert.call(state.hand[MatchState.Side.A].size() == 1, "砂つぶてを撃つとカードを1枚引く")


func _play_bola(state: MatchState, hint: Dictionary) -> void:
	state.hand[MatchState.Side.A] = [CardLibrary.find_by_id("bola")]
	state.mana[MatchState.Side.A] = 3
	state.play_card(MatchState.Side.A, 0, 0, hint)


func _test_bola_destroys_only_low_health() -> void:
	var state := _new_match()
	var sturdy := _place(state, MatchState.Side.B, _vanilla(5), 0)
	_place(state, MatchState.Side.B, _vanilla(2), 1)
	_assert.call(
		not CardEffectResolver.eligible_target(sturdy, CardLibrary.find_by_id("bola").effects[0]),
		"体力3以上の駒はボーラの対象に選べない"
	)
	_play_bola(state, {"side": MatchState.Side.B, "slot": 0})
	_assert.call(state.board[MatchState.Side.B][0] == sturdy, "ボーラは体力の多い駒を破壊しない")
	_assert.call(state.board[MatchState.Side.B][1] == null, "ボーラは体力2以下の駒を破壊する")


func _test_bola_fizzles_on_sturdy_board() -> void:
	var state := _new_match()
	var sturdy := _place(state, MatchState.Side.B, _vanilla(3), 0)
	_play_bola(state, {})
	_assert.call(state.board[MatchState.Side.B][0] == sturdy, "体力2以下の駒がいなければボーラは不発")
	_assert.call(state.board[MatchState.Side.A][0] != null, "不発でもボーラは場に残る")


func _end_turn_with_nibble(state: MatchState) -> void:
	_place(state, MatchState.Side.A, CardLibrary.find_by_id("nibble"), 0)
	state.end_turn()


func _test_nibble_hits_lowest_health() -> void:
	var state := _new_match()
	var sturdy := _place(state, MatchState.Side.B, _vanilla(5), 0)
	var weak := _place(state, MatchState.Side.B, _vanilla(3), 1)
	_end_turn_with_nibble(state)
	_assert.call(weak.health == 2, "ニブルは体力がいちばん少ない駒へ1ダメージ")
	_assert.call(sturdy.health == 5, "ニブルは体力の多い駒を狙わない")


func _test_nibble_breaks_ties_leftmost() -> void:
	var state := _new_match()
	var right := _place(state, MatchState.Side.B, _vanilla(3), 4)
	var left := _place(state, MatchState.Side.B, _vanilla(3), 2)
	_end_turn_with_nibble(state)
	_assert.call(left.health == 2 and right.health == 3, "体力が同じならニブルは左の枠を狙う")


func _test_block_guards_and_draws_on_death() -> void:
	var state := _new_match()
	var block := CardLibrary.find_by_id("block")
	_assert.call(block.keywords.has(CardEnums.Keyword.GUARD), "ブロックは守護を持つ")
	_place(state, MatchState.Side.A, block, 0)
	var hand := int(state.hand[MatchState.Side.A].size())
	state.destroy_unit(MatchState.Side.A, 0)
	_assert.call(state.hand[MatchState.Side.A].size() == hand + 1, "ブロックが破壊されると持ち主が1枚引く")


func _test_vault_grows_ally_when_damaged() -> void:
	var state := _new_match()
	var vault := CardLibrary.find_by_id("vault")
	_assert.call(vault.keywords.has(CardEnums.Keyword.GUARD), "ヴォールトは守護を持つ")
	_place(state, MatchState.Side.A, vault, 0)
	var ally := _place(state, MatchState.Side.A, _vanilla(3), 1)
	var vault_unit: CardInstance = state.board[MatchState.Side.A][0]
	var own_total := vault_unit.total_sand()
	state.damage_unit(MatchState.Side.A, 0, 1)
	_assert.call(ally.total_sand() == 4, "ヴォールトが被弾すると他の駒の総量+1")
	_assert.call(vault_unit.total_sand() == own_total - 1, "ヴォールトは自分の総量を増やさない")


func _test_hive_summons_mote_when_damaged() -> void:
	var state := _new_match()
	_place(state, MatchState.Side.A, CardLibrary.find_by_id("hive"), 0)
	state.damage_unit(MatchState.Side.A, 0, 1)
	var summoned: CardInstance = state.board[MatchState.Side.A][1]
	_assert.call(summoned != null and summoned.data.id == "mote", "ハイヴが被弾すると空き枠へモートが出る")


func _play_relief(state: MatchState) -> void:
	state.hand[MatchState.Side.A] = [CardLibrary.find_by_id("relief")]
	state.mana[MatchState.Side.A] = 4
	state.play_card(MatchState.Side.A, 0, 0, {})


func _test_relief_heals_per_enemy_unit() -> void:
	var state := _new_match()
	for slot in 3:
		_place(state, MatchState.Side.B, _vanilla(3), slot)
	state.hp[MatchState.Side.A] = 10
	_play_relief(state)
	_assert.call(int(state.hp[MatchState.Side.A]) == 13, "リリーフは相手の砂時計1体につきHPを1回復する")


func _test_relief_heals_nothing_on_empty_board() -> void:
	var state := _new_match()
	state.hp[MatchState.Side.A] = 10
	_play_relief(state)
	_assert.call(int(state.hp[MatchState.Side.A]) == 10, "相手の場が空ならリリーフは回復しない")
	_assert.call(state.board[MatchState.Side.A][0] != null, "回復しなくてもリリーフは場に残る")


func _test_set_is_staged() -> void:
	_assert.call(CardSetLibrary.has_set(SET_ID), "chase_sand is registered")
	_assert.call(CardSetLibrary.price(SET_ID) == 1000, "chase_sand costs 1000")
	_assert.call(CardSetLibrary.planned_count(SET_ID) == 10, "chase_sand plans 10 cards")
	_assert.call(CardSetLibrary.card_ids(SET_ID)[0] == "sling", "chase_sand opens with sling")
	_assert.call(CardSetLibrary.card_ids(SET_ID)[1] == "pelt", "chase_sand's second card is pelt")
	_assert.call(CardSetLibrary.card_ids(SET_ID)[2] == "bola", "chase_sand's third card is bola")
	_assert.call(
		CardSetLibrary.card_ids(SET_ID)[3] == "nibble", "chase_sand's fourth card is nibble"
	)
	_assert.call(CardSetLibrary.card_ids(SET_ID)[4] == "block", "chase_sand's fifth card is block")
	_assert.call(CardSetLibrary.card_ids(SET_ID)[5] == "vault", "chase_sand's sixth card is vault")
	_assert.call(CardSetLibrary.card_ids(SET_ID)[6] == "hive", "chase_sand's seventh card is hive")
	_assert.call(
		CardSetLibrary.card_ids(SET_ID)[7] == "relief", "chase_sand's eighth card is relief"
	)
