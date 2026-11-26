extends RefCounted
## カードセット「寝返りの刻」(第3弾の2つ目のテーマ)の検証。GameDesign.md 6章「相手の駒を奪う効果」、Architecture.md 10.8節に対応する。

const SET_ID := "turncoat"
const A := MatchState.Side.A
const B := MatchState.Side.B

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_set_is_registered()
	_test_charm_seizes_young_unit()
	_test_charm_ignores_old_unit()
	_test_seize_needs_empty_slot()
	_test_seized_unit_is_fresh()
	_test_seized_unit_dies_to_owner_grave()
	_test_seized_unit_returns_to_owner_hand()
	_test_lure_total_limit()
	_test_defect_condition()
	_test_piper_takes_by_attack_up_to_room()
	_test_lure_sand_loan_and_return()
	_test_lure_sand_destroyed_without_room()
	_test_lure_sand_kept_when_returned_home()
	_test_traitor_swaps_places()
	_test_infight_clash()
	_test_infight_needs_attacker()
	_test_infight_ignores_guard()
	_test_infight_triggers_combat_effects()
	_test_marionette_clash()
	_test_whistle_drops_sand()
	_test_fork_keeps_owner()
	_test_cpu_plays_seize_cards()


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
	_assert.call(CardSetLibrary.card_ids(SET_ID).size() == 9, "寝返りの刻は9枚")
	for id in CardSetLibrary.card_ids(SET_ID):
		var card := CardLibrary.find_by_id(id)
		_assert.call(card != null and card.set_id == SET_ID, "%s が寝返りの刻のカードとして読める" % id)
	var rarities := {
		"infight": 0,
		"charm": 0,
		"whistle": 0,
		"defect": 0,
		"lure_sand": 1,
		"lure": 1,
		"marionette": 1,
		"traitor": 2,
		"piper": 3,
	}
	for id: String in rarities:
		_assert.call(int(CardLibrary.find_by_id(id).rarity) == rarities[id], "%s のレアリティ" % id)


func _test_charm_seizes_young_unit() -> void:
	var state := _new_match(["charm"])
	var foe := _place(state, B, "sand", 2, 3, 1)
	_assert.call(state.play_card(A, 0, 3, {"side": B, "slot": 2}), "チャームを出せる")
	_assert.call(state.board[B][2] == null and state.board[A][0] == foe, "相手の駒が自分の空き枠の左へ移る")
	_assert.call(foe.health == 3 and foe.attack == 1, "砂はそのまま持ってくる")
	_assert.call(
		CardTurncoatEffects.is_seized(foe, A) and CardTurncoatEffects.card_owner(foe, A) == B,
		"カードの持ち主は相手のまま"
	)


func _test_charm_ignores_old_unit() -> void:
	var state := _new_match(["charm"])
	var foe := _place(state, B, "sand", 0, 3, 2)
	state.play_card(A, 0, 3, {"side": B, "slot": 0})
	_assert.call(state.board[B][0] == foe, "攻撃力2の駒は奪えない")


func _test_seize_needs_empty_slot() -> void:
	var state := _new_match(["charm"])
	for slot in 5:
		_place(state, A, "sand", slot)
	var foe := _place(state, B, "sand", 0, 3, 1)
	state.play_card(A, 0, 5, {"side": B, "slot": 0})
	_assert.call(state.board[B][0] == foe, "空き枠が無ければ奪えない(不発)")


func _test_seized_unit_is_fresh() -> void:
	var state := _new_match(["charm"])
	var foe := _place(state, B, "sand", 0, 3, 1)
	state.play_card(A, 0, 3, {"side": B, "slot": 0})
	_assert.call(not foe.can_attack() and not foe.can_flip(), "奪った手番は攻撃も反転もできない")
	foe.begin_turn()
	_assert.call(foe.can_attack(), "次の手番からは動ける")


func _test_seized_unit_dies_to_owner_grave() -> void:
	var state := _new_match(["charm"])
	var foe := _place(state, B, "sand", 0, 3, 1)
	state.play_card(A, 0, 3, {"side": B, "slot": 0})
	var grave_a: int = state.graveyard[A].size()
	var grave_b: int = state.graveyard[B].size()
	state.destroy_unit(A, 0)
	_assert.call(state.graveyard[B].size() == grave_b + 1, "砕けたら元の持ち主の墓地へ行く")
	_assert.call(state.graveyard[A].size() == grave_a, "奪った側の墓地へは行かない")
	_assert.call(foe.is_dead(), "駒は砕けている")


func _test_seized_unit_returns_to_owner_hand() -> void:
	var state := _new_match(["charm"])
	_place(state, B, "sand", 0, 3, 1)
	state.play_card(A, 0, 3, {"side": B, "slot": 0})
	state.current_turn = B
	state.hand[B] = [CardLibrary.find_by_id("recall")]
	state.mana[B] = 7
	var hand_a: int = state.hand[A].size()
	_assert.call(state.cast_spell(B, 0, {"side": A, "slot": 0}), "奪われた駒を手札へ戻す砂術を撃てる")
	_assert.call(state.hand[B].size() == 1 and state.hand[B][0].id == "sand", "元の持ち主の手札へ戻る")
	_assert.call(state.hand[A].size() == hand_a, "奪った側の手札には入らない")


func _test_lure_total_limit() -> void:
	var state := _new_match(["lure"])
	var small := _place(state, B, "sand", 0, 3, 1)
	var big := _place(state, B, "sand", 1, 3, 2)
	state.play_card(A, 0, 3, {"side": B, "slot": 1})
	_assert.call(state.board[B][1] == big, "総量5の駒は奪えない")
	_assert.call(state.board[B][0] == null and state.board[A][0] == small, "総量4以下の駒を代わりに奪う")


func _test_defect_condition() -> void:
	var state := _new_match(["defect"])
	_place(state, B, "sand", 0)
	_place(state, B, "sand", 1)
	state.play_card(A, 0, 0)
	_assert.call(state.units(B).size() == 2, "差が1体なら奪えない")
	var behind := _new_match(["defect"])
	_place(behind, B, "sand", 0)
	_place(behind, B, "sand", 1)
	_place(behind, B, "sand", 2)
	behind.play_card(A, 0, 5)
	_assert.call(
		behind.units(B).size() == 2 and behind.units(A).size() == 2, "自分(自身を含む)より2体多ければ1体奪う"
	)


func _test_piper_takes_by_attack_up_to_room() -> void:
	var state := _new_match(["piper"], 7)
	for slot in 3:
		_place(state, A, "sand", slot)
	var weak := _place(state, B, "sand", 0, 1, 2)
	var strong := _place(state, B, "sand", 1, 1, 5)
	var middle := _place(state, B, "sand", 2, 1, 3)
	var young := _place(state, B, "sand", 3, 5, 1)
	state.play_card(A, 0, 3)
	_assert.call(young == state.board[B][3], "攻撃力が体力以下の駒は奪わない")
	_assert.call(state.board[A][4] == strong and state.board[A][5] == middle, "空き枠の数まで攻撃力の高い順に奪う")
	_assert.call(state.board[B][0] == weak, "枠が足りない分は残る")


func _test_lure_sand_loan_and_return() -> void:
	var state := _new_match(["lure_sand"])
	var foe := _place(state, B, "sand", 3, 3, 2)
	_place(state, B, "sand", 4, 3, 0)
	_assert.call(state.cast_spell(A, 0, {"side": B, "slot": 3}), "誘い砂を撃てる")
	_assert.call(state.board[A][0] == foe and foe.can_attack(), "借りた手番に攻撃できる")
	var target_health: int = state.board[B][4].health
	_assert.call(state.attack(A, 0, 4), "借りた駒で相手の駒を攻撃する")
	_assert.call(state.board[B][4] == null or state.board[B][4].health < target_health, "相手の駒へ当たる")
	state.end_turn()
	_assert.call(state.board[A][0] == null, "手番の終わりに自分の場から離れる")
	_assert.call(state.board[B][0] == foe, "元の持ち主の空き枠の左へ戻る")
	_assert.call(not foe.loaned and foe.owner_side < 0, "戻れば奪った印は消える")


func _test_lure_sand_destroyed_without_room() -> void:
	var state := _new_match(["lure_sand"])
	var foe := _place(state, B, "sand", 0, 3, 2)
	state.cast_spell(A, 0, {"side": B, "slot": 0})
	for slot in MatchState.BOARD_SIZE:
		if state.board[B][slot] == null:
			_place(state, B, "sand", slot)
	var grave_b: int = state.graveyard[B].size()
	state.end_turn()
	_assert.call(foe.is_dead() and state.board[A][0] == null, "戻る枠が無ければ破壊される")
	_assert.call(state.graveyard[B].size() == grave_b + 1, "元の持ち主の墓地へ行く")


func _test_lure_sand_kept_when_returned_home() -> void:
	var state := _new_match(["lure_sand"])
	var foe := _place(state, B, "sand", 0, 3, 2)
	state.cast_spell(A, 0, {"side": B, "slot": 0})
	state.end_turn()
	state.end_turn()
	_assert.call(state.board[B][0] == foe, "戻った駒はそのまま相手の場にいる")


func _test_traitor_swaps_places() -> void:
	var state := _new_match(["traitor"])
	var foe := _place(state, B, "sand", 2, 6, 2)
	state.play_card(A, 0, 4, {"side": B, "slot": 2})
	var traitor: CardInstance = state.board[B][2]
	_assert.call(
		state.board[A][4] == foe and traitor != null and traitor.data.id == "traitor", "持ち場を入れ替える"
	)
	_assert.call(
		(
			CardTurncoatEffects.card_owner(foe, A) == B
			and CardTurncoatEffects.card_owner(traitor, B) == A
		),
		"カードの持ち主は入れ替わらない"
	)
	_assert.call(not foe.can_attack(), "奪った駒はこの手番に攻撃できない")
	var grave_a: int = state.graveyard[A].size()
	state.destroy_unit(B, 2)
	_assert.call(state.graveyard[A].size() == grave_a + 1, "相手の場で砕けたトレイターは自分の墓地へ行く")


func _test_infight_clash() -> void:
	var state := _new_match(["infight"])
	var strong := _place(state, B, "sand", 0, 4, 3)
	var weak := _place(state, B, "sand", 1, 5, 1)
	_assert.call(state.cast_spell(A, 0, {"side": B, "slot": 1}), "同士討ちを撃てる")
	_assert.call(weak.health == 2, "攻撃させた駒の攻撃力ぶん受ける")
	_assert.call(strong.health == 3, "相打ちで反撃を受ける")


func _test_infight_needs_attacker() -> void:
	var state := _new_match(["infight"])
	_place(state, B, "sand", 0, 4, 0)
	_place(state, B, "sand", 1, 5, 0)
	_assert.call(not state.can_cast(A, 0), "攻撃力1以上の駒がいなければ撃てない")
	var lone := _new_match(["infight"])
	_place(lone, B, "sand", 0, 4, 3)
	_assert.call(not lone.can_cast(A, 0), "相手の駒が1体なら撃てない")


func _test_infight_ignores_guard() -> void:
	var state := _new_match(["infight"])
	var guard := _place(state, B, "guard", 0)
	var hit := _place(state, B, "sand", 1, 6, 2)
	var before := guard.health
	var attacker := _place(state, B, "sand", 2, 4, 3)
	state.cast_spell(A, 0, {"side": B, "slot": 1})
	_assert.call(hit.health == 3 and guard.health == before, "守護は無視して指した駒を攻撃する")
	_assert.call(attacker.health < 4, "攻撃させた駒も反撃を受ける")


func _test_infight_triggers_combat_effects() -> void:
	var state := _new_match(["infight"])
	var leech := _place(state, B, "leech", 0, 2, 3)
	var victim := _place(state, B, "sand", 1, 8, 0)
	state.cast_spell(A, 0, {"side": B, "slot": 1})
	_assert.call(victim.health == 5, "リーチが相手の駒へ3ダメージ")
	_assert.call(leech.attack == 0 and leech.health == 5, "リーチの与ダメージの効果が通常の戦闘と同じく働く")


func _test_marionette_clash() -> void:
	var state := _new_match([])
	_place(state, A, "marionette", 0)
	var f0 := _place(state, B, "sand", 0, 5, 2)
	var f1 := _place(state, B, "sand", 1, 5, 2)
	state.end_turn()
	_assert.call(f0.health + f1.health < 10, "落砂で相手の駒どうしが戦う")
	var lone := _new_match([])
	_place(lone, A, "marionette", 0)
	var only := _place(lone, B, "sand", 0, 5, 2)
	lone.end_turn()
	_assert.call(only.health == 5, "相手の駒が1体なら何もしない")


func _test_whistle_drops_sand() -> void:
	var state := _new_match(["whistle"])
	var foe := _place(state, B, "sand", 0, 5, 0)
	state.play_card(A, 0, 0, {"side": B, "slot": 0})
	_assert.call(foe.health == 3 and foe.attack == 2, "相手の砂が2粒落ちる")


func _test_fork_keeps_owner() -> void:
	var state := _new_match(["charm"])
	_place(state, B, "sand", 0, 3, 1)
	state.play_card(A, 0, 3, {"side": B, "slot": 0})
	var twin := SpellForecast.fork(state)
	var copy: CardInstance = twin.board[A][0]
	_assert.call(
		CardTurncoatEffects.card_owner(copy, A) == B and CardTurncoatEffects.is_seized(copy, A),
		"対局の写しも元の持ち主を覚えている"
	)


func _test_cpu_plays_seize_cards() -> void:
	var cpu := CardCpuStrategy.new()
	var state := _new_match(["charm"])
	_place(state, B, "sand", 0, 4, 1)
	_assert.call(cpu.choose_action(state, A).get("type", "") == "play", "CPUは奪える駒がいればチャームを出す")
	var none := CardTurncoatEffects.cpu_value(
		_new_match([]), A, CardLibrary.find_by_id("charm").effects[0]
	)
	_assert.call(none == 0.0, "奪える駒がいなければ見積もりは0")
