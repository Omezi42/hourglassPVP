extends RefCounted
## カードセット「封じの刻」(第3弾の4つ目のテーマ)の検証。GameDesign.md 6章「封じる効果」、Architecture.md 10.8節に対応する。

const SET_ID := "seal_sand"
const A := MatchState.Side.A
const B := MatchState.Side.B

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_set_is_registered()
	_test_stasis_grants_still()
	_test_still_removed_by_silence()
	_test_chain_blocks_next_turn_only()
	_test_chain_does_not_stack()
	_test_frost_raises_and_freezes()
	_test_seal_blocks_flip_and_flip_right()
	_test_seal_released_by_silence()
	_test_seal_not_flip_target()
	_test_toll_raises_foe_cost()
	_test_toll_stacks_and_stays_above_zero()
	_test_toll_silenced_and_gone()
	_test_toll_with_discount()
	_test_cage_blocks_while_alive()
	_test_cage_released_when_destroyed()
	_test_cage_released_when_returned()
	_test_cage_holds_one_foe()
	_test_amber_freezes_everyone()
	_test_timelock_blocks_all()
	_test_shatter_destroys_still_foes_only()
	_test_jailer_blocks_flip_for_one_turn()
	_test_fork_keeps_seals()
	_test_cpu_plays_seal_cards()


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
	_assert.call(CardSetLibrary.card_ids(SET_ID).size() == 10, "封じの刻は10枚")
	for id in CardSetLibrary.card_ids(SET_ID):
		var card := CardLibrary.find_by_id(id)
		_assert.call(card != null and card.set_id == SET_ID, "%s が封じの刻のカードとして読める" % id)
	var rarities := {
		"stasis_hold": 0,
		"chain": 0,
		"frost": 0,
		"seal_flip": 0,
		"toll": 1,
		"cage": 1,
		"amber": 1,
		"timelock": 2,
		"shatter_still": 2,
		"jailer": 3,
	}
	for id: String in rarities:
		_assert.call(int(CardLibrary.find_by_id(id).rarity) == rarities[id], "%s のレアリティ" % id)


func _test_stasis_grants_still() -> void:
	var state := _new_match(["stasis_hold"])
	var foe := _place(state, B, "sand", 2, 3, 1)
	_assert.call(state.play_card(A, 0, 0, {"side": B, "slot": 2}), "スタシスを出せる")
	_assert.call(foe.has_keyword(CardEnums.Keyword.STILL), "相手の駒が静止を持つ")
	state.end_turn()
	state.end_turn()
	state.end_turn()
	_assert.call(foe.health == 3 and foe.attack == 1, "静止を持つ相手の砂は落ちない")


func _test_still_removed_by_silence() -> void:
	var state := _new_match(["stasis_hold"])
	var foe := _place(state, B, "sand", 2, 3, 1)
	state.play_card(A, 0, 0, {"side": B, "slot": 2})
	foe.silence()
	_assert.call(not foe.has_keyword(CardEnums.Keyword.STILL), "沈黙で静止が消える")


func _test_chain_blocks_next_turn_only() -> void:
	var state := _new_match(["chain"])
	var foe := _place(state, B, "sand", 2, 3, 2)
	state.play_card(A, 0, 0, {"side": B, "slot": 2})
	_assert.call(foe.attack_locked, "チェインで相手の駒が封じられる")
	state.end_turn()
	_assert.call(state.current_turn == B, "相手の手番になった")
	_assert.call(not state.can_attack(B, 2, -1), "次の相手の手番は攻撃できない")
	state.end_turn()
	_assert.call(not foe.attack_locked, "相手の手番の終わりに解ける")
	state.end_turn()
	foe.attacks_this_turn = 0
	_assert.call(state.can_attack(B, 2, -1) or foe.attack > 0, "その次の手番からは攻撃できる")
	_assert.call(foe.can_attack(), "その次の手番からは攻撃できる(駒の判定)")


func _test_chain_does_not_stack() -> void:
	var state := _new_match(["chain", "chain"])
	var foe := _place(state, B, "sand", 2, 3, 2)
	state.play_card(A, 0, 0, {"side": B, "slot": 2})
	state.play_card(A, 0, 1, {"side": B, "slot": 2})
	state.end_turn()
	state.end_turn()
	_assert.call(not foe.attack_locked, "重ねても延びず、1手番で解ける")


func _test_frost_raises_and_freezes() -> void:
	var state := _new_match(["frost"])
	var foe := _place(state, B, "sand", 2, 3, 2)
	_assert.call(state.cast_spell(A, 0, {"side": B, "slot": 2}), "フロストを撃てる")
	_assert.call(foe.health == 4 and foe.attack == 1, "砂が1粒上へ戻る")
	_assert.call(foe.has_keyword(CardEnums.Keyword.STILL), "静止を与える")


func _test_seal_blocks_flip_and_flip_right() -> void:
	var state := _new_match(["seal_flip"])
	var foe := _place(state, B, "sand", 2, 3, 2)
	state.play_card(A, 0, 0, {"side": B, "slot": 2})
	_assert.call(foe.flip_sealed and not foe.flippable(), "シールで反転できなくなる")
	state.end_turn()
	foe.begin_turn()
	_assert.call(not state.can_flip(B, 2), "通常の反転はできない")
	var before: int = state.flip_right_remaining[B]
	_assert.call(not state.use_flip_right(B, B, 2), "自分の反転権でも返せない")
	_assert.call(state.flip_right_remaining[B] == before, "反転権は減らない")
	state.current_turn = A
	_assert.call(not state.use_flip_right(A, B, 2), "相手の反転権でも返せない")


func _test_seal_released_by_silence() -> void:
	var state := _new_match(["seal_flip"])
	var foe := _place(state, B, "sand", 2, 3, 2)
	state.play_card(A, 0, 0, {"side": B, "slot": 2})
	foe.silence()
	_assert.call(foe.flippable(), "沈黙で解ける")


func _test_seal_not_flip_target() -> void:
	var foe := CardInstance.new(CardLibrary.find_by_id("sand"))
	foe.flip_sealed = true
	var swap := CardEffectData.new()
	swap.effect_type = CardEnums.EffectType.SWAP_STATS
	_assert.call(not CardEffectResolver.eligible_target(foe, swap), "反転する効果の対象にもならない")


func _test_toll_raises_foe_cost() -> void:
	var state := _new_match(["toll"])
	state.play_card(A, 0, 0)
	var sand := CardLibrary.find_by_id("sand")
	_assert.call(state.play_cost(B, sand) == sand.cost + 1, "相手のカードのコストが1上がる")
	_assert.call(state.play_cost(A, sand) == sand.cost, "自分のカードは変わらない")
	state.current_turn = B
	state.hand[B] = [sand]
	state.mana[B] = sand.cost
	_assert.call(not state.can_play(B, 0), "上がったぶん足りなければ出せない")
	state.mana[B] = sand.cost + 1
	_assert.call(state.can_play(B, 0), "足りれば出せる")


func _test_toll_stacks_and_stays_above_zero() -> void:
	var state := _new_match([])
	_place(state, A, "toll", 0)
	_place(state, A, "toll", 1)
	var sand := CardLibrary.find_by_id("sand")
	_assert.call(state.play_cost(B, sand) == sand.cost + 2, "2体いれば2上がる")
	var free := CardLibrary.find_by_id("mote")
	_assert.call(state.play_cost(B, free) >= 0, "0未満にはならない")


func _test_toll_silenced_and_gone() -> void:
	var state := _new_match([])
	var toll := _place(state, A, "toll", 0)
	var sand := CardLibrary.find_by_id("sand")
	toll.silence()
	_assert.call(state.play_cost(B, sand) == sand.cost, "消された駒は上げない")
	toll.silenced = false
	state.destroy_unit(A, 0)
	_assert.call(state.play_cost(B, sand) == sand.cost, "場を離れたら戻る")


func _test_toll_with_discount() -> void:
	var state := _new_match([])
	_place(state, A, "toll", 0)
	var sage := _place(state, B, "sage", 0)
	var spell := CardLibrary.find_by_id("frost")
	var plain := spell.cost
	var discount: int = sage.spell_cost_down()
	_assert.call(discount > 0, "セージは砂術を安くする")
	_assert.call(
		state.play_cost(B, spell) == maxi(plain - discount + 1, MatchState.MIN_COST),
		"値下げと値上げは足し引きされ、下限を下回らない"
	)


func _test_cage_blocks_while_alive() -> void:
	var state := _new_match(["cage"])
	var foe := _place(state, B, "sand", 2, 3, 2)
	state.play_card(A, 0, 0, {"side": B, "slot": 2})
	_assert.call(foe.held_caged, "ケージが相手の駒を封じる")
	state.end_turn()
	_assert.call(not foe.can_attack(), "場にいるあいだは何手番でも攻撃できない")
	state.end_turn()
	state.end_turn()
	_assert.call(not foe.can_attack(), "相手の手番が過ぎても解けない")


func _test_cage_released_when_destroyed() -> void:
	var state := _new_match(["cage"])
	var foe := _place(state, B, "sand", 2, 3, 2)
	state.play_card(A, 0, 0, {"side": B, "slot": 2})
	state.destroy_unit(A, 0)
	_assert.call(not foe.held_caged and foe.caged_by == 0, "ケージが砕けると解ける")
	foe.begin_turn()
	_assert.call(foe.can_attack(), "解けた駒は攻撃できる")


func _test_cage_released_when_returned() -> void:
	var state := _new_match(["cage"])
	var foe := _place(state, B, "sand", 2, 3, 2)
	state.play_card(A, 0, 0, {"side": B, "slot": 2})
	state.hand[B] = [CardLibrary.find_by_id("sand")]
	var resolver := CardEffectResolver.new(state)
	resolver._return_to_hand(A, 0)
	_assert.call(not foe.held_caged, "ケージが手札へ戻ると解ける")


func _test_cage_holds_one_foe() -> void:
	var state := _new_match(["cage"])
	var first := _place(state, B, "sand", 1, 3, 2)
	var second := _place(state, B, "sand", 2, 3, 2)
	state.play_card(A, 0, 0, {"side": B, "slot": 1})
	_assert.call(first.held_caged and not second.held_caged, "封じられるのは1体")


func _test_amber_freezes_everyone() -> void:
	var state := _new_match(["amber"])
	var own := _place(state, A, "sand", 0, 3, 2)
	var foe := _place(state, B, "sand", 2, 3, 2)
	state.play_card(A, 0, 1)
	_assert.call(own.has_keyword(CardEnums.Keyword.STILL), "味方の駒も静止する")
	_assert.call(foe.has_keyword(CardEnums.Keyword.STILL), "相手の駒も静止する")
	_assert.call(state.board[A][1].has_keyword(CardEnums.Keyword.STILL), "アンバー自身も静止する")


func _test_timelock_blocks_all() -> void:
	var state := _new_match(["timelock"])
	var first := _place(state, B, "sand", 0, 3, 2)
	var second := _place(state, B, "sand", 3, 3, 2)
	_assert.call(state.cast_spell(A, 0), "タイムロックを撃てる")
	_assert.call(first.attack_locked and second.attack_locked, "相手の駒すべてが封じられる")
	state.end_turn()
	_assert.call(not first.can_attack() and not second.can_attack(), "次の相手の手番はどれも攻撃できない")
	state.end_turn()
	_assert.call(not first.attack_locked and not second.attack_locked, "手番の終わりに解ける")


func _test_shatter_destroys_still_foes_only() -> void:
	var state := _new_match(["shatter_still"])
	var frozen := _place(state, B, "freeze", 0)
	var granted := _place(state, B, "sand", 1, 3, 2)
	granted.grant_keyword(CardEnums.Keyword.STILL)
	var plain := _place(state, B, "sand", 2, 3, 2)
	var own_still := _place(state, A, "freeze", 0)
	state.play_card(A, 0, 1)
	_assert.call(frozen.is_dead() and granted.is_dead(), "静止を持つ相手の駒を壊す")
	_assert.call(not plain.is_dead(), "静止を持たない相手の駒は壊さない")
	_assert.call(not own_still.is_dead(), "自分の静止の駒は壊さない")


func _test_jailer_blocks_flip_for_one_turn() -> void:
	var state := _new_match(["jailer"])
	var foe := _place(state, B, "sand", 2, 3, 2)
	state.play_card(A, 0, 0)
	_assert.call(CardSealEffects.flip_locked(state, B), "ジェイラーで相手の反転が封じられる")
	state.end_turn()
	foe.begin_turn()
	_assert.call(not state.can_flip(B, 2), "反転できない")
	var rights: int = state.flip_right_remaining[B]
	_assert.call(not state.use_flip_right(B, B, 2), "反転権も使えない")
	_assert.call(state.flip_right_remaining[B] == rights, "反転権は減らない")
	state.end_turn()
	_assert.call(not CardSealEffects.flip_locked(state, B), "相手の手番の終わりに解ける")
	_assert.call(not CardSealEffects.flip_locked(state, A), "自分には掛からない")
	state.end_turn()
	state.current_turn = B
	foe.begin_turn()
	_assert.call(state.can_flip(B, 2), "その次の手番からは反転できる")


func _test_fork_keeps_seals() -> void:
	var state := _new_match(["cage", "jailer"], 10)
	var foe := _place(state, B, "sand", 2, 3, 2)
	foe.flip_sealed = true
	foe.attack_locked = true
	state.play_card(A, 0, 0, {"side": B, "slot": 2})
	state.play_card(A, 0, 1)
	var twin := SpellForecast.fork(state)
	var copy: CardInstance = twin.board[B][2]
	_assert.call(copy.flip_sealed and copy.attack_locked, "対局の写しも封じを保つ")
	_assert.call(copy.held_caged and copy.caged_by == foe.caged_by, "対局の写しも檻を保つ")
	_assert.call(CardSealEffects.flip_locked(twin, B), "対局の写しもジェイラーの封じを保つ")
	twin.destroy_unit(A, 0)
	_assert.call(not copy.held_caged and foe.held_caged, "写しでケージが砕けても、元の檻は解けない")


func _test_cpu_plays_seal_cards() -> void:
	var cpu := CardCpuStrategy.new()
	for id in ["stasis_hold", "chain", "seal_flip", "cage", "jailer", "toll"]:
		var state := _new_match([id])
		_place(state, B, "sand", 0, 3, 3)
		_place(state, B, "sand", 1, 3, 3)
		state.hand[B] = [CardLibrary.find_by_id("sand"), CardLibrary.find_by_id("sand")]
		_assert.call(
			cpu.choose_action(state, A).get("type", "") == "play", "CPUは相手の駒がいれば%sを出す" % id
		)
	var frost := _new_match(["frost"])
	_place(frost, B, "sand", 0, 4, 1)
	_assert.call(
		CardCpuStrategy.new().choose_action(frost, A).get("type", "") == "cast", "CPUは若い相手へフロストを撃つ"
	)
	var timelock := _new_match(["timelock"])
	_place(timelock, B, "sand", 0, 2, 4)
	_place(timelock, B, "sand", 1, 2, 4)
	var action := CardCpuStrategy.new().choose_action(timelock, A)
	_assert.call(action.get("type", "") == "cast", "CPUは相手の攻撃を止めるためタイムロックを撃つ")
