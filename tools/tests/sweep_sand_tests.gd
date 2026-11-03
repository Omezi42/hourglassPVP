extends RefCounted
## カードセット「薙砂の刻」の検証。Architecture.md 10.8.6節に対応する。

const SET_ID := "sweep_sand"

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_gale_sweeps_wide_board()
	_test_gale_fizzles_on_narrow_board()
	_test_grit_rain_hits_three_times()
	_test_grit_rain_skips_broken_units()
	_test_grit_rain_ignores_hint()
	_test_bypass_lets_attack_past_guard()
	_test_bypass_ends_with_turn()
	_test_hound_bites_on_extra_draw()
	_test_hound_ignores_turn_start_draw()
	_test_colossus_cost_drops_per_enemy()
	_test_colossus_cost_floor()
	_test_cpu_values_bypass_only_against_guard()
	_test_set_is_registered()


func _vanilla(total: int) -> CardData:
	var card := CardData.new()
	card.id = "test_vanilla"
	card.display_name = "検証用バニラ"
	card.cost = 1
	card.total_sand = total
	return card


func _guard(total: int) -> CardData:
	var card := _vanilla(total)
	card.keywords = [CardEnums.Keyword.GUARD]
	return card


func _new_match(hand_id: String, mana := MatchState.MAX_MANA) -> MatchState:
	var deck: Array = []
	for i in MatchState.DECK_SIZE:
		deck.append(CardLibrary.find_by_id("sand"))
	var state := MatchState.new()
	state.start_match(deck, deck.duplicate(), MatchState.Side.A, 12345)
	state.current_turn = MatchState.Side.A
	state.hand[MatchState.Side.A] = [CardLibrary.find_by_id(hand_id)]
	state.mana[MatchState.Side.A] = mana
	return state


func _place(state: MatchState, side: int, card: CardData, slot: int) -> CardInstance:
	var unit := CardInstance.new(card)
	unit.summoned_this_turn = false
	state.board[side][slot] = unit
	return unit


func _test_gale_sweeps_wide_board() -> void:
	var state := _new_match("gale")
	var foes: Array = []
	for slot in 3:
		foes.append(_place(state, MatchState.Side.B, _vanilla(3), slot))
	state.play_card(MatchState.Side.A, 0, 0)
	_assert.call(
		foes.all(func(unit: CardInstance) -> bool: return unit.health == 2),
		"相手が3体以上ならゲイルは相手全体へ1ダメージ"
	)


func _test_gale_fizzles_on_narrow_board() -> void:
	var state := _new_match("gale")
	var a := _place(state, MatchState.Side.B, _vanilla(3), 0)
	var b := _place(state, MatchState.Side.B, _vanilla(3), 1)
	state.play_card(MatchState.Side.A, 0, 0)
	_assert.call(a.health == 3 and b.health == 3, "相手が2体以下ならゲイルは不発")
	_assert.call(state.board[MatchState.Side.A][0] != null, "不発でもゲイルは場に残る")


func _test_grit_rain_hits_three_times() -> void:
	var state := _new_match("grit_rain")
	var foe := _place(state, MatchState.Side.B, _vanilla(5), 0)
	var hp := int(state.hp[MatchState.Side.B])
	state.cast_spell(MatchState.Side.A, 0)
	_assert.call(foe.health == 2, "相手が1体なら砂礫の雨は3回ともその駒へ当たる")
	_assert.call(int(state.hp[MatchState.Side.B]) == hp, "砂礫の雨は本体には当たらない")


func _test_grit_rain_skips_broken_units() -> void:
	var state := _new_match("grit_rain")
	_place(state, MatchState.Side.B, _vanilla(1), 0)
	var sturdy := _place(state, MatchState.Side.B, _vanilla(5), 1)
	state.cast_spell(MatchState.Side.A, 0)
	_assert.call(state.board[MatchState.Side.B][0] == null, "体力1の駒は砕ける")
	_assert.call(sturdy.health <= 3, "砕けた駒に当たった分は残りの駒へ向かう")
	_assert.call(sturdy.health >= 2, "砂礫の雨の合計は3ダメージ")


func _test_grit_rain_ignores_hint() -> void:
	var state := _new_match("grit_rain")
	var hits := 0
	for slot in 3:
		_place(state, MatchState.Side.B, _vanilla(9), slot)
	state.cast_spell(MatchState.Side.A, 0, {"side": MatchState.Side.B, "slot": 0})
	for slot in 3:
		hits += 9 - state.board[MatchState.Side.B][slot].health
	_assert.call(hits == 3, "砂礫の雨は対象の指定があっても合計3ダメージをランダムに配る")


func _test_bypass_lets_attack_past_guard() -> void:
	var state := _new_match("bypass")
	_place(state, MatchState.Side.B, _guard(4), 0)
	_place(state, MatchState.Side.B, _vanilla(3), 1)
	_place(state, MatchState.Side.A, _vanilla(4), 0).drop_sand(2)
	_assert.call(state.can_attack(MatchState.Side.A, 0, 0), "撃つ前も守護の駒は殴れる")
	_assert.call(not state.can_attack(MatchState.Side.A, 0, 1), "撃つ前は守護の後ろを殴れない")
	state.cast_spell(MatchState.Side.A, 0)
	_assert.call(state.can_attack(MatchState.Side.A, 0, 1), "抜け道の後は守護を無視して駒を殴れる")
	_assert.call(state.can_attack(MatchState.Side.A, 0, -1), "抜け道の後は守護がいても本体を殴れる")
	_assert.call(
		state.board[MatchState.Side.B][0].has_keyword(CardEnums.Keyword.GUARD), "守護の駒は守護を持ったまま"
	)


func _test_bypass_ends_with_turn() -> void:
	var state := _new_match("bypass")
	_place(state, MatchState.Side.B, _guard(9), 0)
	state.cast_spell(MatchState.Side.A, 0)
	state.end_turn()
	state.end_turn()
	_place(state, MatchState.Side.A, _vanilla(4), 1)
	_assert.call(not state.can_attack_player(MatchState.Side.A), "抜け道は撃ったターンの終わりまで")


func _test_hound_bites_on_extra_draw() -> void:
	var state := _new_match("sand")
	_place(state, MatchState.Side.A, CardLibrary.find_by_id("hound"), 0)
	var weak := _place(state, MatchState.Side.B, _vanilla(3), 0)
	var strong := _place(state, MatchState.Side.B, _vanilla(6), 1)
	state.draw(MatchState.Side.B, 2)
	_assert.call(weak.health == 1, "相手が2枚引くとハウンドが2回、体力の少ない駒を噛む")
	_assert.call(strong.health == 6, "体力の多い駒には当たらない")


func _test_hound_ignores_turn_start_draw() -> void:
	var state := _new_match("sand")
	_place(state, MatchState.Side.A, CardLibrary.find_by_id("hound"), 0)
	var foe := _place(state, MatchState.Side.B, _vanilla(9), 0)
	state.end_turn()
	_assert.call(foe.health == 9, "手番の始めの1枚にはハウンドは反応しない")


func _test_colossus_cost_drops_per_enemy() -> void:
	var state := _new_match("colossus", 4)
	var colossus := CardLibrary.find_by_id("colossus")
	_assert.call(state.play_cost(MatchState.Side.A, colossus) == 7, "相手の場が空ならコロッサスは7コスト")
	_assert.call(not state.can_play(MatchState.Side.A, 0), "4マナでは出せない")
	for slot in 3:
		_place(state, MatchState.Side.B, _vanilla(2), slot)
	_assert.call(state.play_cost(MatchState.Side.A, colossus) == 4, "相手が3体ならコロッサスは4コスト")
	state.play_card(MatchState.Side.A, 0, 0)
	_assert.call(int(state.mana[MatchState.Side.A]) == 0, "下がったコストぶんだけ払う")


func _test_colossus_cost_floor() -> void:
	var state := _new_match("colossus")
	for slot in MatchState.BOARD_SIZE:
		_place(state, MatchState.Side.B, _vanilla(2), slot)
	var colossus := CardLibrary.find_by_id("colossus")
	_assert.call(
		state.play_cost(MatchState.Side.A, colossus) == MatchState.MIN_COST, "コストは1未満にならない"
	)


func _test_cpu_values_bypass_only_against_guard() -> void:
	var state := _new_match("bypass")
	_place(state, MatchState.Side.A, _vanilla(4), 0).drop_sand(2)
	_place(state, MatchState.Side.B, _vanilla(3), 0)
	var cpu := CardCpuStrategy.new()
	var bypass := CardLibrary.find_by_id("bypass")
	_assert.call(
		cpu._spell_value(state, MatchState.Side.A, bypass) == 0.0, "守護がいなければCPUは抜け道に価値を見ない"
	)
	_place(state, MatchState.Side.B, _guard(4), 1)
	_assert.call(cpu._spell_value(state, MatchState.Side.A, bypass) > 0.0, "守護がいればCPUは抜け道に価値を見る")


func _test_set_is_registered() -> void:
	_assert.call(CardSetLibrary.has_set(SET_ID), "sweep_sand is registered")
	_assert.call(CardSetLibrary.price(SET_ID) == 600, "sweep_sand costs 600")
	_assert.call(CardSetLibrary.hidden_count(SET_ID) == 0, "sweep_sand is not staged")
	for id in CardSetLibrary.card_ids(SET_ID):
		var card := CardLibrary.find_by_id(id)
		_assert.call(card != null and card.set_id == SET_ID, "%s belongs to sweep_sand" % id)
