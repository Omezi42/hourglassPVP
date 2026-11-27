extends RefCounted
## カードセット「決闘の刻」(第3弾の5つ目のテーマ)の検証。GameDesign.md 6章「戦わせる効果」、Architecture.md 10.8節に対応する。

const SET_ID := "duel_sand"
const A := MatchState.Side.A
const B := MatchState.Side.B

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_set_is_registered()
	_test_duel_fights_fresh_unit_and_ignores_guard()
	_test_duel_uses_no_attack_and_fires_no_attack_triggers()
	_test_duel_picks_own_unit_by_hint()
	_test_duel_needs_both_sides()
	_test_deathmatch_fights_until_one_breaks()
	_test_deathmatch_stops_when_nobody_can_hurt()
	_test_duelist_raises_sand_on_attack_kill()
	_test_attack_kill_not_on_counter_or_fight()
	_test_knight_heals_on_attack_kill()
	_test_champion_attacks_again_on_kill()
	_test_fencer_softens_counter_when_attacking()
	_test_fencer_not_softened_when_attacked_or_fought()
	_test_squire_sends_fresh_unit_at_units_only()
	_test_gauntlet_adds_attack_and_bars_face()
	_test_gladiator_raises_sand_each_attack()
	_test_veteran_grows_after_any_combat()
	_test_veteran_does_not_grow_when_broken()
	_test_fork_keeps_duel_flags()
	_test_cpu_plays_duel_cards()
	_test_cpu_does_not_attack_barred_face()


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
	_assert.call(CardSetLibrary.card_ids(SET_ID).size() == 10, "決闘の刻は10枚")
	for id in CardSetLibrary.card_ids(SET_ID):
		var card := CardLibrary.find_by_id(id)
		_assert.call(card != null and card.set_id == SET_ID, "%s が決闘の刻のカードとして読める" % id)
	var rarities := {
		"duel": 0,
		"duelist": 0,
		"fencer": 0,
		"squire": 0,
		"gladiator": 1,
		"knight": 1,
		"gauntlet": 1,
		"deathmatch": 2,
		"veteran": 2,
		"champion": 3,
	}
	for id: String in rarities:
		_assert.call(int(CardLibrary.find_by_id(id).rarity) == rarities[id], "%s のレアリティ" % id)


func _test_duel_fights_fresh_unit_and_ignores_guard() -> void:
	var state := _new_match(["duel"])
	var own := _place(state, A, "sand", 0, 3, 2)
	own.summoned_this_turn = true
	_place(state, B, "bastion", 0, 4, 1)
	var foe := _place(state, B, "sand", 2, 3, 1)
	_assert.call(state.cast_spell(A, 0, {"side": B, "slot": 2}), "果たし合いを撃てる")
	_assert.call(own.health == 2 and own.attack == 2, "自分の駒は相手の攻撃力ぶん削られる(出したターンでも戦える)")
	_assert.call(foe.health == 1 and foe.attack == 1, "守護がいても狙った相手の駒と戦う(相打ち)")


func _test_duel_uses_no_attack_and_fires_no_attack_triggers() -> void:
	var state := _new_match(["duel"])
	var own := _place(state, A, "gladiator", 0, 5, 2)
	_place(state, B, "sand", 1, 3, 1)
	state.cast_spell(A, 0, {"side": B, "slot": 1})
	_assert.call(own.attacks_this_turn == 0, "戦わせても攻撃の回数は使わない")
	_assert.call(own.attack == 2, "戦わせても「攻撃するたび」は働かない(グラディエイター)")
	var duelist_state := _new_match(["duel"])
	var duelist := _place(duelist_state, A, "duelist", 0, 5, 3)
	_place(duelist_state, B, "sand", 1, 2, 0)
	duelist_state.cast_spell(A, 0, {"side": B, "slot": 1})
	_assert.call(duelist_state.board[B][1] == null, "相手の駒が砕けた")
	_assert.call(duelist.attack == 3, "戦わせて砕いても「攻撃で破壊するたび」は働かない")


func _test_duel_picks_own_unit_by_hint() -> void:
	var state := _new_match(["duel"])
	var first := _place(state, A, "sand", 0, 4, 1)
	var second := _place(state, A, "sand", 1, 4, 3)
	_place(state, B, "sand", 0, 4, 1)
	state.cast_spell(A, 0, {"side": B, "slot": 0, CardDuelEffects.OWN_SLOT_KEY: 0})
	_assert.call(first.health == 3, "own_slot で選んだ自分の駒が戦う")
	_assert.call(second.health == 4, "選ばれていない駒は戦わない")
	var auto := _new_match(["duel"])
	var weak := _place(auto, A, "sand", 0, 3, 1)
	var strong := _place(auto, A, "sand", 1, 3, 3)
	_place(auto, B, "sand", 0, 3, 2)
	auto.cast_spell(A, 0, {"side": B, "slot": 0})
	_assert.call(strong.health == 1 and weak.health == 3, "指定が無ければ、得がいちばん大きい自分の駒が戦う")


func _test_duel_needs_both_sides() -> void:
	var state := _new_match(["duel", "deathmatch"])
	_assert.call(not state.can_cast(A, 0), "自分の駒がいなければ果たし合いを撃てない")
	_place(state, A, "sand", 0, 3, 1)
	_assert.call(not state.can_cast(A, 0), "相手の駒がいなければ果たし合いを撃てない")
	_place(state, B, "sand", 0, 3, 1)
	_assert.call(state.can_cast(A, 0) and state.can_cast(A, 1), "両方に駒がいれば撃てる")


func _test_deathmatch_fights_until_one_breaks() -> void:
	var state := _new_match(["deathmatch"])
	var own := _place(state, A, "sand", 0, 6, 1)
	_place(state, B, "sand", 0, 4, 1)
	state.cast_spell(A, 0, {"side": B, "slot": 0})
	_assert.call(state.board[B][0] == null, "どちらかが砕けるまで戦う(相手が砕けた)")
	_assert.call(own.health == 2, "戦った回数ぶんだけ自分も削られる")
	var both := _new_match(["deathmatch"])
	_place(both, A, "sand", 0, 3, 1)
	_place(both, B, "sand", 0, 3, 1)
	both.cast_spell(A, 0, {"side": B, "slot": 0})
	_assert.call(both.board[A][0] == null and both.board[B][0] == null, "互角なら相打ちで両方砕ける")


func _test_deathmatch_stops_when_nobody_can_hurt() -> void:
	var state := _new_match(["deathmatch"])
	var own := _place(state, A, "sand", 0, 4, 0)
	var foe := _place(state, B, "sand", 0, 4, 0)
	_assert.call(state.cast_spell(A, 0, {"side": B, "slot": 0}), "攻撃力0どうしでも撃てる")
	_assert.call(own.health == 4 and foe.health == 4, "どちらも攻撃力0なら止まる(終わらずに固まらない)")


func _test_duelist_raises_sand_on_attack_kill() -> void:
	var state := _new_match([])
	var duelist := _place(state, A, "duelist", 0, 4, 2)
	_place(state, B, "sand", 0, 1, 0)
	state.attack(A, 0, 0)
	_assert.call(state.board[B][0] == null, "攻撃で相手を砕いた")
	_assert.call(duelist.health == 6 and duelist.attack == 0, "砕くたび砂が2粒上へ戻る")
	var miss := _new_match([])
	var other := _place(miss, A, "duelist", 0, 4, 2)
	_place(miss, B, "sand", 0, 5, 0)
	miss.attack(A, 0, 0)
	_assert.call(other.health == 4 and other.attack == 2, "砕けなければ働かない")
	var face := _new_match([])
	var rushed := _place(face, A, "duelist", 0, 4, 2)
	face.attack(A, 0, -1)
	_assert.call(rushed.health == 4, "相手プレイヤーへの攻撃では働かない")


func _test_attack_kill_not_on_counter_or_fight() -> void:
	var state := _new_match([])
	var duelist := _place(state, A, "duelist", 0, 5, 3)
	_place(state, B, "sand", 0, 1, 2)
	state.current_turn = B
	state.attack(B, 0, 0)
	_assert.call(state.board[B][0] == null, "反撃で相手の攻撃側が砕けた")
	_assert.call(duelist.attack == 3 and duelist.health == 3, "反撃で砕いても「攻撃で破壊するたび」は働かない")


func _test_knight_heals_on_attack_kill() -> void:
	var state := _new_match([])
	state.hp[A] = 10
	_place(state, A, "knight", 0, 4, 2)
	_place(state, B, "sand", 0, 1, 0)
	state.attack(A, 0, 0)
	_assert.call(state.hp[A] == 12, "攻撃で砕くたびHPを2回復する")
	state.hp[A] = 10
	var guard := _place(state, B, "sand", 1, 5, 0)
	state.board[A][0].attacks_this_turn = 0
	state.attack(A, 0, 1)
	_assert.call(guard.health == 3 and state.hp[A] == 10, "砕けなければ回復しない")


func _test_champion_attacks_again_on_kill() -> void:
	var state := _new_match([])
	var champion := _place(state, A, "champion", 0, 4, 3)
	_place(state, B, "sand", 0, 1, 0)
	_place(state, B, "sand", 1, 1, 0)
	state.attack(A, 0, 0)
	_assert.call(champion.attacks_this_turn == 0, "砕くたび攻撃の回数が1回ぶん戻る")
	_assert.call(state.can_attack(A, 0, 1), "もう一度攻撃できる")
	state.attack(A, 0, 1)
	_assert.call(state.board[B][1] == null and champion.can_attack(), "勝ち続けるかぎり殴り続ける")
	var stalled := _new_match([])
	var tired := _place(stalled, A, "champion", 0, 4, 3)
	_place(stalled, B, "sand", 0, 6, 0)
	stalled.attack(A, 0, 0)
	_assert.call(tired.attacks_this_turn == 1 and not tired.can_attack(), "砕けなければ攻撃は1回のまま")


func _test_fencer_softens_counter_when_attacking() -> void:
	var state := _new_match([])
	var fencer := _place(state, A, "fencer", 0, 3, 2)
	var plain := _place(state, A, "sand", 1, 3, 2)
	_place(state, B, "sand", 0, 5, 3)
	_place(state, B, "sand", 1, 5, 3)
	state.attack(A, 0, 0)
	state.attack(A, 1, 1)
	_assert.call(fencer.health == 1, "フェンサーは攻撃したとき反撃のダメージが1少ない")
	_assert.call(plain.health == 0 or state.board[A][1] == null, "他の駒は減らない")
	var floor_state := _new_match([])
	var brave := _place(floor_state, A, "fencer", 0, 3, 2)
	_place(floor_state, B, "sand", 0, 5, 1)
	floor_state.attack(A, 0, 0)
	_assert.call(brave.health == 3, "反撃が0になっても0未満にはならない(削られない)")


func _test_fencer_not_softened_when_attacked_or_fought() -> void:
	var state := _new_match([])
	var fencer := _place(state, A, "fencer", 0, 4, 2)
	_place(state, B, "sand", 0, 5, 3)
	state.current_turn = B
	state.attack(B, 0, 0)
	_assert.call(fencer.health == 1, "攻撃されたときは減らない")
	var fight := _new_match(["duel"])
	var duelist := _place(fight, A, "fencer", 0, 4, 2)
	_place(fight, B, "sand", 0, 5, 3)
	fight.cast_spell(A, 0, {"side": B, "slot": 0})
	_assert.call(duelist.health == 1, "戦わされたときも減らない")


func _test_squire_sends_fresh_unit_at_units_only() -> void:
	var state := _new_match(["squire"])
	var ally := _place(state, A, "sand", 1, 4, 2)
	ally.summoned_this_turn = true
	_place(state, B, "sand", 0, 3, 1)
	_assert.call(not ally.can_attack(), "出したばかりの駒は攻撃できない")
	state.play_card(A, 0, 0, {"side": A, "slot": 1})
	_assert.call(ally.can_attack(), "スクワイアに送り出された駒は出したターンでも攻撃できる")
	_assert.call(not state.can_attack(A, 1, -1), "ただし相手プレイヤーは攻撃できない")
	_assert.call(state.can_attack(A, 1, 0), "相手の砂時計は攻撃できる")
	_assert.call(not state.board[A][0].rushed, "スクワイア自身は送り出されない")
	state.end_turn()
	state.end_turn()
	_assert.call(not ally.face_barred and not ally.rushed, "次の手番には解ける")
	_assert.call(state.can_attack(A, 1, -1), "次の手番は相手プレイヤーを攻撃できる")


func _test_gauntlet_adds_attack_and_bars_face() -> void:
	var state := _new_match(["gauntlet"])
	var ally := _place(state, A, "sand", 0, 3, 1)
	_place(state, B, "sand", 0, 5, 0)
	state.cast_spell(A, 0, {"side": A, "slot": 0})
	_assert.call(ally.attack == 3, "籠手で攻撃力が2上がる")
	_assert.call(not state.can_attack(A, 0, -1), "このターンは相手プレイヤーを攻撃できない")
	_assert.call(state.can_attack(A, 0, 0), "相手の砂時計は攻撃できる")
	state.end_turn()
	state.end_turn()
	_assert.call(ally.attack >= 3, "攻撃力の上昇は残る")
	_assert.call(state.can_attack(A, 0, -1), "次の手番は相手プレイヤーを攻撃できる")


func _test_gladiator_raises_sand_each_attack() -> void:
	var state := _new_match([])
	var gladiator := _place(state, A, "gladiator", 0, 4, 3)
	_place(state, B, "sand", 0, 5, 0)
	state.attack(A, 0, 0)
	_assert.call(gladiator.attack == 2 and gladiator.health == 5, "攻撃するたび砂が1粒上へ戻る")
	var face := _new_match([])
	var other := _place(face, A, "gladiator", 0, 4, 3)
	face.attack(A, 0, -1)
	_assert.call(other.attack == 2, "相手プレイヤーへの攻撃でも戻る")


func _test_veteran_grows_after_any_combat() -> void:
	var attacking := _new_match([])
	var vet := _place(attacking, A, "veteran", 0, 4, 2)
	_place(attacking, B, "sand", 0, 5, 1)
	attacking.attack(A, 0, 0)
	_assert.call(vet.health == 3 + 2, "攻撃して生き残ると総量+2")
	var defending := _new_match([])
	var wall := _place(defending, A, "veteran", 0, 4, 1)
	_place(defending, B, "sand", 0, 5, 2)
	defending.current_turn = B
	defending.attack(B, 0, 0)
	_assert.call(wall.health == 2 + 2 and wall.total_sand() == 5, "攻撃されて生き残っても総量+2")
	var fought := _new_match(["duel"])
	var champion := _place(fought, A, "veteran", 0, 4, 1)
	_place(fought, B, "sand", 0, 5, 2)
	fought.cast_spell(A, 0, {"side": B, "slot": 0})
	_assert.call(champion.health == 2 + 2, "戦わされて生き残っても総量+2")


func _test_veteran_does_not_grow_when_broken() -> void:
	var state := _new_match([])
	var vet := _place(state, A, "veteran", 0, 2, 2)
	_place(state, B, "sand", 0, 5, 4)
	state.attack(A, 0, 0)
	_assert.call(vet.is_dead() and state.board[A][0] == null, "砕けたベテランは育たない")
	var idle := _new_match([])
	var rest := _place(idle, A, "veteran", 0, 4, 1)
	idle.end_turn()
	_assert.call(rest.total_sand() <= 5, "戦闘がなければ育たない")


func _test_fork_keeps_duel_flags() -> void:
	var state := _new_match(["squire"])
	var ally := _place(state, A, "sand", 1, 4, 2)
	ally.summoned_this_turn = true
	state.play_card(A, 0, 0, {"side": A, "slot": 1})
	var twin := SpellForecast.fork(state)
	var copy: CardInstance = twin.board[A][1]
	_assert.call(copy.rushed and copy.face_barred, "対局の写しも送り出しの印を保つ")
	_assert.call(copy.can_attack() and not twin.can_attack(A, 1, -1), "対局の写しでも相手プレイヤーは攻撃できない")


func _test_cpu_plays_duel_cards() -> void:
	var fight := _new_match(["duel"])
	_place(fight, A, "sand", 0, 4, 3)
	_place(fight, B, "sand", 0, 3, 3)
	fight.hand[B] = [CardLibrary.find_by_id("sand")]
	var action := CardCpuStrategy.new().choose_action(fight, A)
	_assert.call(
		action.get("type", "") == "cast" or action.get("type", "") == "attack", "CPUは果たし合いを検討できる"
	)
	var deathmatch := _new_match(["deathmatch"])
	var fresh_own := _place(deathmatch, A, "sand", 0, 5, 3)
	fresh_own.summoned_this_turn = true
	_place(deathmatch, B, "sand", 0, 4, 0)
	var cast := CardCpuStrategy.new().choose_action(deathmatch, A)
	_assert.call(cast.get("type", "") == "cast", "CPUは勝てる組があればデスマッチを撃つ")
	var squire := _new_match(["squire"])
	_place(squire, B, "sand", 0, 3, 1)
	var fresh := _place(squire, A, "sand", 1, 4, 2)
	fresh.summoned_this_turn = true
	_assert.call(
		CardCpuStrategy.new().choose_action(squire, A).get("type", "") == "play", "CPUはスクワイアを出す"
	)


func _test_cpu_does_not_attack_barred_face() -> void:
	var state := _new_match([])
	var barred := _place(state, A, "sand", 0, 3, 24)
	barred.face_barred = true
	_place(state, B, "sand", 0, 3, 1)
	var action := CardCpuStrategy.new().choose_action(state, A)
	_assert.call(
		action.get("type", "") != "attack" or int(action.get("target_slot", -1)) >= 0,
		"相手プレイヤーを攻撃できない駒で、CPUは本体を攻撃しない"
	)
	var performed := CardCpuStrategy.new().take_turn(state, A)
	_assert.call(performed.size() < 20 and state.hp[B] > 0, "CPUの手番は固まらずに終わる")
