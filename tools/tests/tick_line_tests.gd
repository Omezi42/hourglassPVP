extends RefCounted
## 刻み線(GameDesign.md 2章、Architecture.md 3.1.3節)の検証。
## 失ったHPが8・16に初めて届いたとき、その側の反転権が1つ増える。

const SIDE := MatchState.Side.A
const FOE := MatchState.Side.B
const FIRST_LINE := 8
const SECOND_LINE := 16

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_initial_flip_rights_are_one_and_two()
	_test_lines_fire_when_lost_hp_reaches_them()
	_test_a_line_fires_once_even_after_healing()
	_test_crossing_several_lines_at_once_fires_all_of_them()
	_test_hp_inversion_can_cross_both_lines()
	_test_signal_reports_the_line_and_side()
	_test_cpu_counts_the_lines_an_attack_would_cross()


func _new_match() -> MatchState:
	var state := MatchState.new()
	var card := CardLibrary.find_by_id("sand")
	var deck: Array = []
	for i in MatchState.DECK_SIZE:
		deck.append(card)
	state.start_match(deck, deck.duplicate(), SIDE, 12345)
	return state


func _rights(state: MatchState, side: int) -> int:
	return int(state.flip_right_remaining[side])


func _test_initial_flip_rights_are_one_and_two() -> void:
	var state := _new_match()
	_assert.call(_rights(state, SIDE) == 1, "先手の反転権は1回から始まる")
	_assert.call(_rights(state, FOE) == 2, "後手の反転権は2回から始まる")
	_assert.call(MatchState.HP_TICK_LINES == [FIRST_LINE, SECOND_LINE], "刻み線は8と16")
	state.free()


func _test_lines_fire_when_lost_hp_reaches_them() -> void:
	var state := _new_match()
	var before := _rights(state, SIDE)
	state.damage_player(SIDE, FIRST_LINE - 1)
	_assert.call(_rights(state, SIDE) == before, "失ったHPが7ではまだ増えない")
	state.damage_player(SIDE, 1)
	_assert.call(_rights(state, SIDE) == before + 1, "失ったHPが8に届くと反転権が1つ増える")
	_assert.call(_rights(state, FOE) == 2, "相手の反転権は増えない")
	state.damage_player(SIDE, SECOND_LINE - FIRST_LINE)
	_assert.call(_rights(state, SIDE) == before + 2, "失ったHPが16に届くとさらに1つ増える")
	state.damage_player(SIDE, 3)
	_assert.call(_rights(state, SIDE) == before + 2, "線の先では増えない")
	state.free()


func _test_a_line_fires_once_even_after_healing() -> void:
	var state := _new_match()
	var before := _rights(state, SIDE)
	state.damage_player(SIDE, FIRST_LINE)
	state.heal_player(SIDE, FIRST_LINE)
	_assert.call(int(state.hp_lost[SIDE]) == 0, "回復すると失ったHPが戻る")
	state.damage_player(SIDE, FIRST_LINE)
	_assert.call(_rights(state, SIDE) == before + 1, "回復で戻って再び届いても再発動しない")
	state.damage_player(SIDE, FIRST_LINE)
	_assert.call(_rights(state, SIDE) == before + 2, "次の線には届く")
	state.free()


func _test_crossing_several_lines_at_once_fires_all_of_them() -> void:
	var state := _new_match()
	var before := _rights(state, SIDE)
	state.damage_player(SIDE, SECOND_LINE)
	_assert.call(_rights(state, SIDE) == before + 2, "一度に2本越えたら2本とも働く")
	_assert.call(int(state.tick_lines_fired[SIDE]) == 2, "働いた線の数が数えられる")
	state.free()


## 時の逆流(HPの反転)は残りHPと失ったHPを入れ替えるため、一度に両方の線を越えうる。
func _test_hp_inversion_can_cross_both_lines() -> void:
	var state := _new_match()
	state.damage_player(SIDE, 4)
	var before := _rights(state, SIDE)
	state.hand[SIDE].insert(0, CardLibrary.find_by_id("reverse"))
	state.mana[SIDE] = MatchState.MAX_MANA
	state.max_mana[SIDE] = MatchState.MAX_MANA
	_assert.call(state.cast_spell(SIDE, 0), "時の逆流を撃てた")
	_assert.call(int(state.hp[SIDE]) == 4 and int(state.hp_lost[SIDE]) == 20, "残りHPと失ったHPが入れ替わる")
	_assert.call(_rights(state, SIDE) == before + 2, "反転で失ったHPが20になり、2本とも働く")
	state.free()


func _test_signal_reports_the_line_and_side() -> void:
	var state := _new_match()
	var seen: Array = []
	state.tick_line_reached.connect(func(side: int, line: int) -> void: seen.append([side, line]))
	state.damage_player(FOE, SECOND_LINE)
	_assert.call(seen == [[FOE, FIRST_LINE], [FOE, SECOND_LINE]], "届いた線ごとに側と位置が通知される")
	state.free()


func _test_cpu_counts_the_lines_an_attack_would_cross() -> void:
	var state := _new_match()
	state.damage_player(FOE, FIRST_LINE - 2)
	_assert.call(MatchCombatPreview.new_tick_lines(state, FOE, 1) == 0, "線の手前で止まる攻撃は越えない")
	_assert.call(MatchCombatPreview.new_tick_lines(state, FOE, 2) == 1, "ちょうど届く攻撃は1本越える")
	_assert.call(MatchCombatPreview.new_tick_lines(state, FOE, 12) == 2, "2本まとめて越える攻撃は2本")
	state.damage_player(FOE, 2)
	_assert.call(MatchCombatPreview.new_tick_lines(state, FOE, 2) == 0, "働いた線はもう数えない")
	state.free()
