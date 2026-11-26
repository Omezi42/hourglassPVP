extends RefCounted
## カードセット「汲砂の刻」(第3弾の最初のテーマ)の検証。GameDesign.md 6章「相手から砂を移す効果」、Architecture.md 10.8節に対応する。

const SET_ID := "draw_sand"
const A := MatchState.Side.A
const B := MatchState.Side.B

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_set_is_registered()
	_test_drawup_moves_drained_attack()
	_test_drawup_caps_at_attack()
	_test_drawup_without_ally()
	_test_sandtheft_heals()
	_test_maelstrom_drains_all()
	_test_bucket_and_aquifer()
	_test_aquifer_per_unit()
	_test_aquifer_ignores_attack_drain()
	_test_pump_highest_attack()
	_test_pump_tie_goes_left()
	_test_siphon_moves_total()
	_test_drain_can_destroy()
	_test_barter_keeps_ratio()
	_test_barter_without_ally()
	_test_leech_both_directions()
	_test_leech_ignores_player_hits()
	_test_cpu_plays_draw_cards()


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
	_assert.call(CardSetLibrary.card_ids(SET_ID).size() == 10, "汲砂の刻は10枚")
	for id in CardSetLibrary.card_ids(SET_ID):
		var card := CardLibrary.find_by_id(id)
		_assert.call(card != null and card.set_id == SET_ID, "%s が汲砂の刻のカードとして読める" % id)
	var rarities := {
		"drawup": 0,
		"leech": 0,
		"pump": 0,
		"bucket": 0,
		"siphon": 1,
		"drain": 1,
		"sandtheft": 1,
		"barter": 2,
		"aquifer": 2,
		"maelstrom": 3,
	}
	for id: String in rarities:
		_assert.call(int(CardLibrary.find_by_id(id).rarity) == rarities[id], "%s のレアリティ" % id)


func _test_drawup_moves_drained_attack() -> void:
	var state := _new_match(["drawup"], 7)
	var foe := _place(state, B, "sand", 0, 2, 3)
	var ally := _place(state, A, "sand", 0, 4, 1)
	_assert.call(state.cast_spell(A, 0, {"side": B, "slot": 0}), "汲み上げを撃てる")
	_assert.call(foe.attack == 1 and foe.health == 2, "相手の攻撃力が2抜ける(体力は変わらない)")
	_assert.call(ally.health == 6, "抜けた2だけ自分の体力が増える")


func _test_drawup_caps_at_attack() -> void:
	var state := _new_match(["drawup"], 7)
	var foe := _place(state, B, "sand", 0, 4, 1)
	var ally := _place(state, A, "sand", 0, 4, 1)
	state.cast_spell(A, 0, {"side": B, "slot": 0})
	_assert.call(foe.attack == 0 and ally.health == 5, "実際に抜けた1だけ移す")


func _test_drawup_without_ally() -> void:
	var state := _new_match(["drawup"], 7)
	var foe := _place(state, B, "sand", 0, 2, 3)
	state.cast_spell(A, 0, {"side": B, "slot": 0})
	_assert.call(foe.attack == 1, "移す先がいなくても抜くだけは起きる")


func _test_sandtheft_heals() -> void:
	var state := _new_match(["sandtheft"], 7)
	var foe := _place(state, B, "sand", 0, 2, 4)
	state.hp[A] = 10
	state.cast_spell(A, 0, {"side": B, "slot": 0})
	_assert.call(foe.attack == 0 and foe.health == 2, "攻撃力がすべて抜ける")
	_assert.call(int(state.hp[A]) == 14, "抜けた4だけ自分のHPが回復する")


func _test_maelstrom_drains_all() -> void:
	var state := _new_match(["maelstrom"], 7)
	var f0 := _place(state, B, "sand", 0, 2, 2)
	var f1 := _place(state, B, "sand", 1, 2, 0)
	var f2 := _place(state, B, "sand", 2, 2, 1)
	state.play_card(A, 0, 0)
	_assert.call(f0.attack == 1 and f1.attack == 0 and f2.attack == 0, "相手すべての攻撃力が1ずつ抜ける")
	_assert.call(state.board[A][0].health == 3 + 2, "実際に抜けた2だけこの砂時計の体力が増える")


func _test_bucket_and_aquifer() -> void:
	var state := _new_match(["bucket"], 7)
	var aquifer := _place(state, A, "aquifer", 0)
	var foe := _place(state, B, "sand", 0, 2, 2)
	var before := aquifer.total_sand()
	state.play_card(A, 0, 1, {"side": B, "slot": 0})
	_assert.call(foe.attack == 1 and foe.health == 3, "バケツで砂が1粒上へ戻る")
	_assert.call(aquifer.total_sand() == before + 1, "アクイファーの総量が+1")


func _test_aquifer_per_unit() -> void:
	var state := _new_match([], 7)
	var aquifer := _place(state, A, "aquifer", 0)
	var before := aquifer.total_sand()
	CardDrawSandEffects.note_sand_raised(state, B, 0, 2)
	CardDrawSandEffects.note_sand_raised(state, B, 1, 1)
	_assert.call(aquifer.total_sand() == before + 2, "戻った駒1体ごとに1回(量は問わない)")
	CardDrawSandEffects.note_sand_raised(state, A, 0, 1)
	_assert.call(aquifer.total_sand() == before + 2, "自分の駒の砂が戻っても反応しない")


func _test_aquifer_ignores_attack_drain() -> void:
	var state := _new_match(["drawup"], 7)
	var aquifer := _place(state, A, "aquifer", 0, 4, 2)
	_place(state, B, "sand", 0, 2, 3)
	state.cast_spell(A, 0, {"side": B, "slot": 0})
	_assert.call(aquifer.total_sand() == 6 + 2, "攻撃力を抜くだけでは反応しない(移した体力ぶんだけ増える)")


func _test_pump_highest_attack() -> void:
	var state := _new_match([], 7)
	_place(state, A, "pump", 0)
	var weak := _place(state, B, "sand", 0, 3, 1)
	var strong := _place(state, B, "sand", 1, 3, 4)
	state.end_turn()
	_assert.call(strong.attack == 3 and strong.health == 4, "攻撃力がいちばん高い駒の砂が1粒戻る")
	_assert.call(weak.attack == 1, "ほかの駒は変わらない")


func _test_pump_tie_goes_left() -> void:
	var state := _new_match([], 7)
	_place(state, A, "pump", 0)
	var left := _place(state, B, "sand", 0, 3, 2)
	var right := _place(state, B, "sand", 1, 3, 2)
	state.end_turn()
	_assert.call(left.attack == 1 and right.attack == 2, "同点なら左の枠")


func _test_siphon_moves_total() -> void:
	var state := _new_match(["siphon"], 7)
	var foe := _place(state, B, "sand", 0, 4, 2)
	var ally := _place(state, A, "sand", 0, 3, 1)
	state.play_card(A, 0, 1, {"side": B, "slot": 0})
	_assert.call(foe.total_sand() == 4 and foe.health == 2 and foe.attack == 2, "相手の総量が体力から2減る")
	_assert.call(ally.total_sand() == 5, "自分の他の砂時計の総量は1増える(半分はこぼれる)")
	_assert.call(state.board[A][1].total_sand() == 5, "この砂時計自身は増えない")


func _test_drain_can_destroy() -> void:
	var state := _new_match(["drain"], 7)
	var foe := _place(state, B, "sand", 0, 1, 0)
	var ally := _place(state, A, "sand", 0, 3, 1)
	_assert.call(state.cast_spell(A, 0, {"side": B, "slot": 0}), "ドレインを撃てる")
	_assert.call(state.board[B][0] == null and foe.is_dead(), "総量が0になった駒は破壊される")
	_assert.call(ally.total_sand() == 5, "減った1だけ自分に足される")
	var short := _new_match(["drain"], 7)
	_place(short, B, "sand", 0, 1, 2)
	short.cast_spell(A, 0, {"side": B, "slot": 0})
	_assert.call(
		short.board[B][0].health == 1 and short.board[B][0].attack == 1, "体力は1を残し、足りないぶんは攻撃力から引く"
	)


func _test_barter_keeps_ratio() -> void:
	var state := _new_match(["barter"], 7)
	var foe := _place(state, B, "sand", 0, 6, 2)
	var ally := _place(state, A, "sand", 0, 1, 2)
	state.play_card(A, 0, 1, {"side": B, "slot": 0})
	_assert.call(foe.health == 2 and foe.attack == 1, "相手は総量3を 3:1 の比で 体力2・攻撃力1")
	_assert.call(ally.health == 3 and ally.attack == 5, "自分は総量8を 1:2 の比で 体力3・攻撃力5")
	_assert.call(CardDrawSandEffects.split_total(1, 1, 1) == Vector2i(1, 0), "ちょうど半分の端数は体力へ")
	_assert.call(CardDrawSandEffects.split_total(5, 9, 1).x >= 1, "体力は1を下回らない")


func _test_barter_without_ally() -> void:
	var state := _new_match(["barter"], 7)
	var foe := _place(state, B, "sand", 0, 6, 2)
	state.play_card(A, 0, 0, {"side": B, "slot": 0})
	_assert.call(foe.health == 6 and foe.attack == 2, "入れ替える自分の砂時計がいなければ何も起きない")


func _test_leech_both_directions() -> void:
	var state := _new_match([], 7)
	var leech := _place(state, A, "leech", 0, 2, 2)
	var foe := _place(state, B, "sand", 0, 5, 1)
	_assert.call(state.attack(A, 0, 0), "リーチで攻撃できる")
	_assert.call(foe.health == 3, "相手には2ダメージ")
	_assert.call(leech.health == 2 - 1 + 2 and leech.attack == 0, "与えた2だけ砂が上へ戻る")
	var defend := _new_match([], 7)
	var defender := _place(defend, B, "leech", 0, 4, 2)
	_place(defend, A, "sand", 0, 5, 1)
	defend.attack(A, 0, 0)
	_assert.call(defender.attack == 0 and defender.health == 5, "反撃で与えた2も戻る")


func _test_leech_ignores_player_hits() -> void:
	var state := _new_match([], 7)
	var leech := _place(state, A, "leech", 0, 2, 2)
	state.attack(A, 0, -1)
	_assert.call(leech.attack == 2, "相手プレイヤーへのダメージでは戻らない")


func _test_cpu_plays_draw_cards() -> void:
	var cpu := CardCpuStrategy.new()
	var state := _new_match(["maelstrom"], 7)
	_place(state, B, "sand", 0, 2, 3)
	_place(state, B, "sand", 1, 2, 3)
	_assert.call(cpu.choose_action(state, A).get("type", "") == "play", "CPUは攻撃力のある相手へメイルストロムを出す")
	var empty := CardDrawSandEffects.cpu_value(
		_new_match([], 7), A, CardLibrary.find_by_id("maelstrom").effects[0]
	)
	_assert.call(empty == 0.0, "相手の駒がいなければ見積もりは0")
