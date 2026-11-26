extends RefCounted
## カードセット「導火の刻」(第2弾の4つ目のテーマ)の検証。GameDesign.md 6章「効果を与える効果」、
## Architecture.md 10.8節に対応する。

const SET_ID := "fuse_sand"
const A := MatchState.Side.A
const B := MatchState.Side.B

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_set_is_registered()
	_test_meteor_stats()
	_test_fuse_hits_one_foe_on_death()
	_test_candle_returns_sand_to_other_ally()
	_test_wire_drops_when_damaged()
	_test_timebomb_cannot_attack_and_bursts()
	_test_timebomb_bursts_after_five_ticks()
	_test_deadline_drops_to_one_and_readies()
	_test_deadline_keeps_attack_count()
	_test_fuseline_grants_and_bursts()
	_test_fuseline_stacks()
	_test_fuseline_text_and_silence()
	_test_fuseline_lost_on_return_to_hand()
	_test_fuseline_survives_fork()
	_test_nova_uses_attack_at_death()
	_test_countdown_destroys_everything()
	_test_countdown_chains_other_death_effects()
	_test_cpu_values()


func _new_match(hand_ids: Array) -> MatchState:
	var deck: Array = []
	for i in MatchState.DECK_SIZE:
		deck.append(CardLibrary.find_by_id("sand"))
	var state := MatchState.new()
	state.start_match(deck, deck.duplicate(), MatchState.Side.A, 12345)
	state.current_turn = A
	var hand: Array = []
	for id in hand_ids:
		hand.append(CardLibrary.find_by_id(id))
	state.hand[A] = hand
	state.mana[A] = MatchState.MAX_MANA
	return state


func _place(state: MatchState, side: int, id: String, slot: int) -> CardInstance:
	var unit := CardInstance.new(CardLibrary.find_by_id(id))
	unit.summoned_this_turn = false
	state.board[side][slot] = unit
	return unit


func _test_set_is_registered() -> void:
	_assert.call(CardSetLibrary.has_set(SET_ID), "導火の刻が登録されている")
	_assert.call(CardSetLibrary.card_ids(SET_ID).size() == 9, "導火の刻は9枚")
	for id in CardSetLibrary.card_ids(SET_ID):
		var card := CardLibrary.find_by_id(id)
		_assert.call(card != null and card.set_id == SET_ID, "%s が導火の刻のカードとして読める" % id)


func _test_meteor_stats() -> void:
	var unit := CardInstance.new(CardLibrary.find_by_id("meteor"))
	_assert.call(unit.health == 2 and unit.attack == 6, "ミーティアは体力2・攻撃力6で落ちてくる")


func _test_fuse_hits_one_foe_on_death() -> void:
	var state := _new_match([])
	_place(state, A, "fuse", 0)
	var weak := _place(state, B, "sand", 0)
	var strong := _place(state, B, "sand", 1)
	strong.attack = 3
	strong.health = 4
	var before := weak.total_sand() + strong.total_sand()
	state.destroy_unit(A, 0)
	_assert.call(weak.total_sand() + strong.total_sand() == before - 2, "フューズの余砂で相手の駒1体に2ダメージ")


func _test_candle_returns_sand_to_other_ally() -> void:
	var state := _new_match([])
	_place(state, A, "candle", 0)
	var ally := _place(state, A, "sand", 1)
	ally.attack = 3
	ally.health = 1
	state.destroy_unit(A, 0)
	_assert.call(ally.attack == 1 and ally.health == 3, "キャンドルの余砂で他の味方の砂が2粒上へ戻る")


func _test_wire_drops_when_damaged() -> void:
	var state := _new_match([])
	var wire := _place(state, A, "wire", 0)
	var before := wire.attack
	state.damage_unit(A, 0, 1)
	_assert.call(wire.attack == before + 2, "ワイヤーは被弾で砂が2粒落ちる(攻撃力+2)")


func _test_timebomb_cannot_attack_and_bursts() -> void:
	var state := _new_match([])
	var bomb := _place(state, A, "timebomb", 0)
	bomb.attack = 2
	_assert.call(not bomb.can_attack(), "タイムボムは攻撃できない")
	var foe := _place(state, B, "sand", 0)
	var foe_total := foe.total_sand()
	var hp_before := int(state.hp[B])
	state.destroy_unit(A, 0)
	_assert.call(foe.total_sand() == foe_total - 3, "相手の砂時計すべてに3ダメージ")
	_assert.call(int(state.hp[B]) == hp_before - 3, "相手プレイヤーにも3ダメージ")


func _test_timebomb_bursts_after_five_ticks() -> void:
	var state := _new_match(["timebomb"])
	state.play_card(A, 0, 0)
	var hp_before := int(state.hp[B])
	for i in 5:
		state.end_turn()
		state.end_turn()
	_assert.call(state.board[A][0] == null, "何もしなくても5手番で砕ける")
	_assert.call(int(state.hp[B]) == hp_before - 3, "砕けた時に相手へ3ダメージ")


func _test_deadline_drops_to_one_and_readies() -> void:
	var state := _new_match(["deadline"])
	var unit := CardInstance.new(CardLibrary.find_by_id("sand"))
	state.board[A][0] = unit
	_assert.call(unit.summoned_this_turn and not unit.can_attack(), "出したターンの駒は攻撃できない")
	var total := unit.total_sand()
	_assert.call(state.cast_spell(A, 0, {"side": A, "slot": 0}), "刻限を撃てる")
	_assert.call(unit.health == 1 and unit.attack == total - 1, "体力1を残して砂を落とす")
	_assert.call(not unit.summoned_this_turn, "出したターンの制限が外れる")
	_assert.call(state.can_attack(A, 0, -1), "このターン攻撃できる")


func _test_deadline_keeps_attack_count() -> void:
	var state := _new_match(["deadline"])
	var unit := _place(state, A, "sand", 0)
	unit.attacks_this_turn = 1
	state.cast_spell(A, 0, {"side": A, "slot": 0})
	_assert.call(unit.attacks_this_turn == 1, "攻撃済みの回数は戻さない")
	_assert.call(not unit.can_attack(), "攻撃済みの駒は撃っても追加で殴れない")


func _test_fuseline_grants_and_bursts() -> void:
	var state := _new_match(["fuseline"])
	var unit := _place(state, A, "sand", 0)
	var foe := _place(state, B, "sand", 0)
	var other := _place(state, B, "sand", 1)
	var foe_total := foe.total_sand()
	_assert.call(state.cast_spell(A, 0, {"side": A, "slot": 0}), "導火線を撃てる")
	_assert.call(unit.granted_effects.size() == 1, "駒が効果を1つ持つ")
	state.destroy_unit(A, 0)
	_assert.call(
		foe.total_sand() == foe_total - 1 and other.total_sand() == foe_total - 1,
		"砕けると相手の砂時計すべてに1ダメージ"
	)


func _test_fuseline_stacks() -> void:
	var state := _new_match(["fuseline", "fuseline"])
	var unit := _place(state, A, "sand", 0)
	var foe := _place(state, B, "sand", 0)
	var before := foe.total_sand()
	state.cast_spell(A, 0, {"side": A, "slot": 0})
	state.cast_spell(A, 0, {"side": A, "slot": 0})
	_assert.call(unit.granted_effects.size() == 2, "同じ効果を2回与えれば2つ持つ")
	state.destroy_unit(A, 0)
	_assert.call(foe.total_sand() == before - 2, "2回働く")


func _test_fuseline_text_and_silence() -> void:
	var state := _new_match(["fuseline"])
	var unit := _place(state, A, "sand", 0)
	state.cast_spell(A, 0, {"side": A, "slot": 0})
	_assert.call(unit.granted_effects[0].shown_text == "余砂:相手の砂時計すべてに1ダメージ", "与えた効果は札の文の末尾へ足す一文を持つ")
	unit.silence()
	_assert.call(unit.granted_effects.is_empty(), "沈黙で与えた効果も消える")
	_assert.call(unit.effects_for(CardEnums.Trigger.ON_DEATH).is_empty(), "消された駒は余砂が働かない")


func _test_fuseline_lost_on_return_to_hand() -> void:
	var state := _new_match(["fuseline"])
	var unit := _place(state, A, "sand", 0)
	state.cast_spell(A, 0, {"side": A, "slot": 0})
	_assert.call(unit.granted_effects.size() == 1, "効果が付いた")
	# 手札へ戻るのは CardData だけ。出し直した駒は新しい CardInstance で、与えた効果を持たない。
	var again := CardInstance.new(unit.data)
	_assert.call(again.granted_effects.is_empty(), "手札へ戻って出し直した駒は効果を持たない")


func _test_fuseline_survives_fork() -> void:
	var state := _new_match(["fuseline"])
	_place(state, A, "sand", 0)
	state.cast_spell(A, 0, {"side": A, "slot": 0})
	var twin := SpellForecast.fork(state)
	var copy: CardInstance = twin.board[A][0]
	_assert.call(copy.granted_effects.size() == 1, "対局の写しにも与えた効果が残る")
	copy.silence()
	_assert.call((state.board[A][0] as CardInstance).granted_effects.size() == 1, "写しの変更は元へ届かない")


func _test_nova_uses_attack_at_death() -> void:
	var state := _new_match([])
	var nova := _place(state, A, "nova", 0)
	nova.attack = 4
	nova.health = 0
	var foe := _place(state, B, "sand", 0)
	foe.attack = 3
	foe.health = 6
	var other := _place(state, B, "sand", 1)
	other.attack = 1
	other.health = 2
	state.destroy_unit(A, 0)
	_assert.call(foe.health == 2, "砕けた時点の攻撃力4ぶんのダメージ")
	_assert.call(state.board[B][1] == null or other.is_dead(), "体力が尽きた駒は砕ける")


func _test_countdown_destroys_everything() -> void:
	var state := _new_match(["countdown"])
	state.play_card(A, 0, 0)
	var mine := _place(state, A, "sand", 1)
	var foe := _place(state, B, "sand", 0)
	_assert.call(not (state.board[A][0] as CardInstance).can_attack(), "カウントダウンは攻撃できない")
	for i in 3:
		state.end_turn()
		state.end_turn()
	_assert.call(state.board[A][0] == null, "3回の落砂で砕ける")
	_assert.call(mine.is_dead() and foe.is_dead(), "場のすべての砂時計を破壊する(敵味方とも)")


func _test_countdown_chains_other_death_effects() -> void:
	var state := _new_match([])
	var count := _place(state, A, "countdown", 0)
	count.health = 0
	_place(state, A, "timebomb", 1)
	var foe := _place(state, B, "sand", 0)
	var hp_before := int(state.hp[B])
	state.destroy_unit(A, 0)
	_assert.call(state.board[A][1] == null and state.board[B][0] == null, "全部砕ける")
	_assert.call(int(state.hp[B]) == hp_before - 3, "巻き込まれたタイムボムの余砂も働く")
	_assert.call(foe.is_dead(), "相手の駒も残らない")


func _test_cpu_values() -> void:
	var state := _new_match([])
	_place(state, A, "sand", 0)
	_place(state, B, "sand", 0)
	_place(state, B, "sand", 1)
	var fuseline := CardLibrary.find_by_id("fuseline")
	_assert.call(
		CardFuseSandEffects.cpu_value(state, A, fuseline.effects[0]) > 0.0, "導火線は相手の駒の数だけ値打ちがある"
	)
	var empty := _new_match([])
	_assert.call(
		CardFuseSandEffects.cpu_value(empty, A, fuseline.effects[0]) == 0.0, "与える駒がいなければ値打ちが無い"
	)
