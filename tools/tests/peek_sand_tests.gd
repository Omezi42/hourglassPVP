extends RefCounted
## カードセット「盗み見の刻」(第3弾の6つ目のテーマ)と第3弾テーマ外のレジェンドの検証。
## GameDesign.md 6章「相手のカードを見る・写す効果」「入れ替える効果」、Architecture.md 10.8節に対応する。

const SET_ID := "peek_sand"
const EXTRA_ID := "third_extra"
const A := MatchState.Side.A
const B := MatchState.Side.B

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_sets_are_registered()
	_test_effects_bind_to_enums()
	_test_pickpocket_copies_foe_deck_top_on_death()
	_test_copy_is_not_a_draw()
	_test_watchman_drops_sand_of_entering_foe()
	_test_spy_keeps_or_mills_foe_deck_top()
	_test_gossip_shows_foe_hand_this_turn_only()
	_test_thief_copies_random_foe_hand_card()
	_test_forger_copies_foe_spell()
	_test_scout_sees_foe_deck_top()
	_test_dreameater_sends_hand_card_to_deck_bottom()
	_test_phantom_copies_picked_card()
	_test_mirage_swaps_all_units()
	_test_mirage_needs_three_fewer()
	_test_mirage_leaves_overflow_in_place()
	_test_janus_swaps_hp()
	_test_fork_keeps_gossip()
	_test_cpu_plays_peek_cards()
	_test_cpu_choices()


func _new_match(hand_ids: Array, mana := 7) -> MatchState:
	var deck: Array = []
	for i in MatchState.DECK_SIZE:
		deck.append(CardLibrary.find_by_id("sand"))
	var state := MatchState.new()
	state.start_match(deck, deck.duplicate(), MatchState.Side.A, 12345)
	state.current_turn = A
	state.hand[A] = _cards(hand_ids)
	state.mana[A] = mana
	return state


func _cards(ids: Array) -> Array:
	var cards: Array = []
	for id in ids:
		cards.append(CardLibrary.find_by_id(id))
	return cards


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


func _test_sets_are_registered() -> void:
	_assert.call(CardSetLibrary.card_ids(SET_ID).size() == 9, "盗み見の刻は9枚")
	_assert.call(CardSetLibrary.card_ids(EXTRA_ID).size() == 2, "第3弾のテーマ外は2枚")
	var rarities := {
		"pickpocket": 0,
		"watchman": 0,
		"spy": 0,
		"gossip": 0,
		"thief": 1,
		"forger": 1,
		"scout": 1,
		"dreameater": 2,
		"phantom": 3,
	}
	for id: String in rarities:
		var card := CardLibrary.find_by_id(id)
		_assert.call(card != null and card.set_id == SET_ID, "%s が盗み見の刻のカードとして読める" % id)
		_assert.call(int(card.rarity) == rarities[id], "%s のレアリティ" % id)
	for id in ["mirage", "janus"]:
		var card := CardLibrary.find_by_id(id)
		_assert.call(card != null and card.set_id == EXTRA_ID, "%s がテーマ外として読める" % id)
		_assert.call(int(card.rarity) == CardEnums.Rarity.LEGENDARY, "%s はレジェンド" % id)
	_assert.call(CardSetLibrary.SETS[SET_ID]["price"] == 0, "盗み見の刻は第3弾のパックが無いため価格0")


func _effect_of(id: String) -> CardEffectData:
	return CardLibrary.find_by_id(id).effects[0]


func _test_effects_bind_to_enums() -> void:
	var expected := {
		"pickpocket": [CardEnums.Trigger.ON_DEATH, CardEnums.EffectType.COPY_FOE_TOP_TO_HAND],
		"watchman": [CardEnums.Trigger.ON_FOE_ENTER, CardEnums.EffectType.DROP_SAND],
		"spy": [CardEnums.Trigger.ON_PLAY, CardEnums.EffectType.PEEK_FOE_TOP_KEEP_OR_MILL],
		"gossip": [CardEnums.Trigger.ON_PLAY, CardEnums.EffectType.REVEAL_FOE_HAND],
		"thief": [CardEnums.Trigger.ON_PLAY, CardEnums.EffectType.COPY_FOE_HAND_RANDOM_TO_HAND],
		"forger": [CardEnums.Trigger.ON_FOE_SPELL, CardEnums.EffectType.COPY_FOE_SPELL_TO_HAND],
		"dreameater":
		[CardEnums.Trigger.ON_PLAY, CardEnums.EffectType.FOE_HAND_RANDOM_TO_DECK_BOTTOM],
		"phantom": [CardEnums.Trigger.ON_PLAY, CardEnums.EffectType.COPY_FOE_HAND_PICK_TO_HAND],
		"mirage": [CardEnums.Trigger.ON_PLAY, CardEnums.EffectType.SWAP_ALL_UNITS],
		"janus": [CardEnums.Trigger.ON_PLAY, CardEnums.EffectType.SWAP_PLAYER_HP],
	}
	for id: String in expected:
		var effect := _effect_of(id)
		_assert.call(
			effect.trigger == expected[id][0] and effect.effect_type == expected[id][1],
			"%s のトリガーと効果の種類" % id
		)
	_assert.call(
		_effect_of("watchman").target == CardEnums.EffectTarget.ENTERING_FOE_UNIT,
		"ウォッチマンは出た相手の駒を対象にする"
	)
	var mirage := _effect_of("mirage")
	_assert.call(
		(
			mirage.condition_scope == CardEnums.ConditionScope.ENEMY_LEADS_BY
			and mirage.condition_total == 2
		),
		"ミラージュの条件(自分の駒を含めて相手が2体以上多い=ミラージュを除いて3体以上)"
	)
	_assert.call(CardLibrary.find_by_id("scout").sees_foe_deck_top, "スカウトは相手の山札の一番上が見える印を持つ")
	_assert.call(CardLibrary.find_by_id("scout").category_name() == "常在", "スカウトの分類は常在")
	_assert.call(CardLibrary.find_by_id("forger").category_name() == "常在", "フォージャーの分類は常在")


func _top_card(id: String) -> CardData:
	return CardLibrary.find_by_id(id)


func _test_pickpocket_copies_foe_deck_top_on_death() -> void:
	var state := _new_match([])
	state.deck[B][0] = _top_card("hammer")
	var deck_size: int = state.deck[B].size()
	var thief := _place(state, A, "pickpocket", 0, 1, 0)
	var hand_before: int = state.hand[A].size()
	state.destroy_unit(A, 0)
	_assert.call(thief.is_dead(), "ピックポケットは砕けた")
	_assert.call(
		state.hand[A].size() == hand_before + 1 and state.hand[A][-1].id == "hammer",
		"砕けると相手の山札の一番上の写しが手札へ入る"
	)
	_assert.call(
		state.deck[B].size() == deck_size and state.deck[B][0].id == "hammer", "相手の山札は変わらない"
	)
	var empty := _new_match([])
	empty.deck[B] = []
	_place(empty, A, "pickpocket", 0, 1, 0)
	var before: int = empty.hand[A].size()
	empty.destroy_unit(A, 0)
	_assert.call(empty.hand[A].size() == before, "相手の山札が0枚なら何も起きない")


func _test_copy_is_not_a_draw() -> void:
	var state := _new_match(["thief"])
	_place(state, B, "hound", 0, 4, 1)
	var mine := _place(state, A, "sand", 2, 4, 1)
	var drawn := [0]
	state.cards_drawn.connect(func(_side: int, count: int) -> void: drawn[0] += count)
	state.play_card(A, 0, 1)
	_assert.call(drawn[0] == 0, "写しを手札へ加えても「引く」ではない")
	_assert.call(mine.health == 4, "相手のドローに反応する効果(ハウンド)は働かない")


func _test_watchman_drops_sand_of_entering_foe() -> void:
	var state := _new_match([])
	_place(state, A, "watchman", 0)
	state.current_turn = B
	state.hand[B] = _cards(["sand"])
	state.mana[B] = 7
	var health_before := CardLibrary.find_by_id("sand").initial_health()
	_assert.call(state.play_card(B, 0, 2), "相手が砂時計を出せる")
	var entered: CardInstance = state.board[B][2]
	_assert.call(
		entered.health == health_before - 1 and entered.attack == 1, "出てきた駒の砂が1粒落ちる(体力-1・攻撃力+1)"
	)
	var own := _new_match(["sand"])
	_place(own, A, "watchman", 0)
	own.play_card(A, 0, 1)
	var mine: CardInstance = own.board[A][1]
	_assert.call(mine.health == health_before and mine.attack == 0, "自分が出した駒には働かない")


func _test_spy_keeps_or_mills_foe_deck_top() -> void:
	var keep := _new_match(["spy"])
	keep.deck[B][0] = _top_card("hammer")
	keep.play_card(A, 0, 0)
	_assert.call(keep.deck[B][0].id == "hammer" and keep.graveyard[B].is_empty(), "選ばなければそのまま")
	var mill := _new_match(["spy"])
	mill.deck[B][0] = _top_card("hammer")
	var deck_size: int = mill.deck[B].size()
	mill.play_card(A, 0, 0, {CardPeekEffects.PEEK_KEY: 0})
	_assert.call(
		mill.deck[B].size() == deck_size - 1 and mill.graveyard[B].size() == 1,
		"選ぶと相手の山札の一番上が相手の墓地へ"
	)
	_assert.call(mill.graveyard[B][0].id == "hammer", "置かれたのは見た札")
	var empty := _new_match(["spy"])
	empty.deck[B] = []
	_assert.call(empty.play_card(A, 0, 0, {CardPeekEffects.PEEK_KEY: 0}), "相手の山札が0枚でも出せる")
	_assert.call(
		CardPeekEffects.seen_cards(empty, A, _effect_of("spy")).is_empty(), "見る札が無ければ選ばせない"
	)


func _test_gossip_shows_foe_hand_this_turn_only() -> void:
	var state := _new_match(["gossip"])
	_assert.call(not CardPeekEffects.hand_seen(state, A), "ゴシップを出す前は見えない")
	state.play_card(A, 0, 0)
	_assert.call(CardPeekEffects.hand_seen(state, A), "出した手番のあいだ相手の手札が見える")
	_assert.call(not CardPeekEffects.hand_seen(state, B), "見えるのは使った側だけ")
	state.end_turn()
	_assert.call(not CardPeekEffects.hand_seen(state, A), "手番が変わると見えなくなる")
	state.end_turn()
	_assert.call(not CardPeekEffects.hand_seen(state, A), "次の自分の手番にも持ち越さない")


func _test_thief_copies_random_foe_hand_card() -> void:
	var state := _new_match(["thief"])
	state.hand[B] = _cards(["hammer"])
	var foe_hand: int = state.hand[B].size()
	state.play_card(A, 0, 0)
	_assert.call(state.hand[A].size() == 1 and state.hand[A][0].id == "hammer", "相手の手札の写しが手札へ入る")
	_assert.call(state.hand[B].size() == foe_hand, "相手の手札は減らない")
	var empty := _new_match(["thief"])
	empty.hand[B] = []
	empty.play_card(A, 0, 0)
	_assert.call(empty.hand[A].is_empty(), "相手の手札が0枚なら何も起きない")
	var first := _new_match(["thief"])
	first.hand[B] = _cards(["sand", "hammer", "lance", "lock"])
	var second := _new_match(["thief"])
	second.hand[B] = _cards(["sand", "hammer", "lance", "lock"])
	first.play_card(A, 0, 0)
	second.play_card(A, 0, 0)
	_assert.call(first.hand[A][0] == second.hand[A][0], "同じ種なら同じ札を写す(オンラインで一致させる)")


func _test_forger_copies_foe_spell() -> void:
	var state := _new_match([])
	var forger := _place(state, A, "forger", 0)
	state.current_turn = B
	state.hand[B] = _cards(["shot"])
	state.mana[B] = 7
	var hand_before: int = state.hand[A].size()
	_assert.call(state.cast_spell(B, 0), "相手が砂術を撃てる")
	_assert.call(
		state.hand[A].size() == hand_before + 1 and state.hand[A][-1].id == "shot",
		"相手が使った砂術の写しが手札へ入る"
	)
	_assert.call(state.graveyard[B].size() == 1, "相手の砂術は墓地へ行く(写しても減らない)")
	var own := _new_match(["shot"])
	_place(own, A, "forger", 0)
	var own_hand: int = own.hand[A].size()
	own.cast_spell(A, 0)
	_assert.call(own.hand[A].size() == own_hand - 1, "自分が撃った砂術は写さない")
	_assert.call(forger != null, "フォージャーがいる")
	var silenced := _new_match([])
	var mute := _place(silenced, A, "forger", 0)
	mute.silenced = true
	silenced.current_turn = B
	silenced.hand[B] = _cards(["shot"])
	silenced.mana[B] = 7
	var silent_hand: int = silenced.hand[A].size()
	silenced.cast_spell(B, 0)
	_assert.call(silenced.hand[A].size() == silent_hand, "効果を消されたフォージャーは写さない")


func _test_scout_sees_foe_deck_top() -> void:
	var state := _new_match([])
	_assert.call(not CardPeekEffects.deck_top_seen(state, A), "スカウトがいなければ見えない")
	var scout := _place(state, A, "scout", 0)
	_assert.call(CardPeekEffects.deck_top_seen(state, A), "スカウトが場にいるあいだ相手の山札の一番上が見える")
	_assert.call(not CardPeekEffects.deck_top_seen(state, B), "見えるのは持ち主だけ")
	scout.silenced = true
	_assert.call(not CardPeekEffects.deck_top_seen(state, A), "効果を消されると見えない")
	scout.silenced = false
	state.deck[B] = []
	_assert.call(not CardPeekEffects.deck_top_seen(state, A), "相手の山札が0枚なら見るものが無い")
	state.deck[B] = _cards(["sand"])
	state.destroy_unit(A, 0)
	_assert.call(not CardPeekEffects.deck_top_seen(state, A), "スカウトが砕けると見えなくなる")


func _test_dreameater_sends_hand_card_to_deck_bottom() -> void:
	var state := _new_match(["dreameater"])
	state.hand[B] = _cards(["hammer"])
	var deck_size: int = state.deck[B].size()
	state.play_card(A, 0, 0)
	_assert.call(state.hand[B].is_empty(), "相手の手札から1枚が減る")
	_assert.call(
		state.deck[B].size() == deck_size + 1 and state.deck[B][-1].id == "hammer", "相手の山札の一番下へ戻る"
	)
	_assert.call(state.graveyard[B].is_empty(), "捨てさせはしない(墓地へは行かない)")
	var empty := _new_match(["dreameater"])
	empty.hand[B] = []
	_assert.call(empty.play_card(A, 0, 0) and empty.deck[B].size() == deck_size, "相手の手札が0枚なら何も起きない")
	var spent := _new_match(["dreameater"])
	spent.deck[B] = []
	spent._deck_exhausted[B] = true
	spent.hand[B] = _cards(["hammer"])
	spent.play_card(A, 0, 0)
	_assert.call(
		spent.deck[B].size() == 1 and not spent._deck_exhausted[B], "山札が空だった相手は、戻った1枚で疲労しなくなる"
	)


func _test_phantom_copies_picked_card() -> void:
	var state := _new_match(["phantom"])
	state.hand[B] = _cards(["sand", "hammer", "lance"])
	state.play_card(A, 0, 0, {CardPeekEffects.PEEK_KEY: 1})
	_assert.call(state.hand[A].size() == 1 and state.hand[A][0].id == "hammer", "選んだ札の写しが手札へ入る")
	_assert.call(state.hand[B].size() == 3, "相手の手札は変わらない")
	var auto := _new_match(["phantom"])
	auto.hand[B] = _cards(["sand", "colossus", "lance"])
	auto.play_card(A, 0, 0)
	var best := 0
	for card: CardData in auto.hand[B]:
		best = maxi(best, card.cost)
	_assert.call(auto.hand[A][0].cost == best, "選びの指定が無ければ、コストがいちばん高い札を写す")
	var empty := _new_match(["phantom"])
	empty.hand[B] = []
	_assert.call(empty.play_card(A, 0, 0) and empty.hand[A].is_empty(), "相手の手札が0枚なら何も起きない")
	var effect := _effect_of("phantom")
	_assert.call(CardPeekEffects.seen_cards(state, A, effect).size() == 3, "ファントムは相手の手札すべてを見て選ぶ")


func _test_mirage_swaps_all_units() -> void:
	var state := _new_match(["mirage"])
	var mine := _place(state, A, "sand", 0, 4, 1)
	var foe_a := _place(state, B, "sand", 0, 3, 2)
	var foe_b := _place(state, B, "lock", 3, 5, 0)
	var foe_c := _place(state, B, "sand", 4, 2, 2)
	var foe_d := _place(state, B, "sand", 5, 2, 2)
	_assert.call(state.play_card(A, 0, 5), "ミラージュを出せる")
	var mirage: CardInstance = state.board[A][5]
	_assert.call(mirage != null and mirage.data.id == "mirage", "ミラージュ自身は動かない")
	_assert.call(
		(
			state.board[A][0] == foe_a
			and state.board[A][1] == foe_b
			and state.board[A][2] == foe_c
			and state.board[A][3] == foe_d
		),
		"相手の駒が自分の場へ左から入る"
	)
	_assert.call(state.board[B][0] == mine, "自分の駒が相手の場へ移る")
	_assert.call(state.board[B][3] == null and state.board[B][4] == null, "相手の元の枠は空く")
	_assert.call(
		not foe_a.can_attack() and not foe_a.can_flip() and not mine.can_attack(),
		"入れ替わった駒は、その手番は攻撃も反転もできない"
	)
	_assert.call(
		(
			CardTurncoatEffects.card_owner(foe_a, A) == B
			and CardTurncoatEffects.card_owner(mine, B) == A
		),
		"持ち主は変わらない(砕ければ元の持ち主の墓地へ)"
	)
	state.destroy_unit(A, 0)
	_assert.call(state.graveyard[B].size() == 1, "入れ替わった駒が砕けると元の持ち主の墓地へ行く")


func _test_mirage_needs_three_fewer() -> void:
	var state := _new_match(["mirage"])
	var mine := _place(state, A, "sand", 0, 4, 1)
	var foe_a := _place(state, B, "sand", 0, 3, 2)
	var foe_b := _place(state, B, "sand", 1, 3, 2)
	_assert.call(state.play_card(A, 0, 5), "条件を満たさなくても出せる")
	_assert.call(state.board[A][0] == mine and state.board[B][0] == foe_a, "相手が1体多いだけでは入れ替わらない")
	var equal := _new_match(["mirage"])
	_place(equal, A, "sand", 0, 4, 1)
	_place(equal, A, "sand", 1, 4, 1)
	_place(equal, B, "sand", 0, 3, 2)
	_place(equal, B, "sand", 1, 3, 2)
	var kept: CardInstance = equal.board[A][0]
	equal.play_card(A, 0, 5)
	_assert.call(equal.board[A][0] == kept, "同数なら入れ替わらない")
	_assert.call(foe_b != null, "相手の2体目")
	var exact := _new_match(["mirage"])
	var lone := _place(exact, A, "sand", 0, 4, 1)
	_place(exact, B, "sand", 0, 3, 2)
	_place(exact, B, "sand", 1, 3, 2)
	_place(exact, B, "sand", 2, 3, 2)
	exact.play_card(A, 0, 5)
	_assert.call(exact.board[A][0] == lone, "ミラージュを除いて2体少ないだけでは入れ替わらない")
	var three := _new_match(["mirage"])
	var alone := _place(three, A, "sand", 0, 4, 1)
	for slot in 4:
		_place(three, B, "sand", slot, 3, 2)
	three.play_card(A, 0, 5)
	_assert.call(three.board[B][0] == alone, "ミラージュを除いて3体少なければ入れ替わる")


func _test_mirage_leaves_overflow_in_place() -> void:
	var state := _new_match(["mirage"])
	var foes: Array[CardInstance] = []
	for slot in MatchState.BOARD_SIZE:
		foes.append(_place(state, B, "sand", slot, 3, 1))
	_assert.call(state.play_card(A, 0, 0), "相手の場が埋まっていてもミラージュを出せる")
	var moved := 0
	for slot in MatchState.BOARD_SIZE:
		if state.board[A][slot] != null and state.board[A][slot].data.id != "mirage":
			moved += 1
	_assert.call(moved == 5, "自分の場の枠(ミラージュを除く5つ)に入るぶんだけ動く")
	_assert.call(state.board[B][5] == foes[5], "枠が足りないぶんは、右の駒がその場に残る")
	_assert.call(state.board[A][1] == foes[0] and state.board[A][5] == foes[4], "左から順に入る")


func _test_janus_swaps_hp() -> void:
	var state := _new_match(["janus"])
	state.hp[A] = 5
	state.hp[B] = 19
	var changes: Array = []
	state.hp_changed.connect(func(side: int, value: int) -> void: changes.append([side, value]))
	state.play_card(A, 0, 0)
	_assert.call(state.hp[A] == 19 and state.hp[B] == 5, "自分と相手のHPが入れ替わる")
	_assert.call(changes.size() == 2, "HPの変化を両方へ知らせる")
	var lifesteal := _new_match(["janus"])
	lifesteal.hp[A] = 5
	lifesteal.hp[B] = 20
	_place(lifesteal, A, "ignis", 1)
	var ignis: CardInstance = lifesteal.board[A][1]
	var attack_before: int = ignis.attack
	var total_before := ignis.total_sand()
	lifesteal.play_card(A, 0, 0)
	_assert.call(
		ignis.attack == attack_before and ignis.total_sand() == total_before, "HPを失うたびの効果は働かない"
	)
	var capped := _new_match(["janus"])
	capped.hp_max[A] = 30
	capped.hp[A] = 30
	capped.hp[B] = 4
	capped.play_card(A, 0, 0)
	_assert.call(capped.hp[A] == 4 and capped.hp[B] == MatchState.INITIAL_HP, "最大HPを超える側は最大HPで止まる")


func _test_fork_keeps_gossip() -> void:
	var state := _new_match(["gossip"])
	state.play_card(A, 0, 0)
	var twin := SpellForecast.fork(state)
	_assert.call(CardPeekEffects.hand_seen(twin, A), "対局の写しも相手の手札が見えている印を保つ")


func _test_cpu_plays_peek_cards() -> void:
	for id in [
		"pickpocket",
		"spy",
		"gossip",
		"thief",
		"scout",
		"dreameater",
		"phantom",
		"watchman",
		"forger"
	]:
		var state := _new_match([id])
		state.hand[B] = _cards(["hammer", "lance"])
		var action := CardCpuStrategy.new().choose_action(state, A)
		_assert.call(action.get("type", "") == "play", "CPUは%sを出せる" % id)
		var performed := CardCpuStrategy.new().take_turn(state, A)
		_assert.call(performed.size() < 20 and state.hp[B] > 0, "%s を持つCPUの手番は固まらずに終わる" % id)
	var janus := _new_match(["janus"], 7)
	janus.hp[A] = 4
	_assert.call(
		CardCpuStrategy.new().choose_action(janus, A).get("type", "") == "play", "劣勢のCPUはヤヌスを出す"
	)
	var ahead := _new_match(["janus"], 7)
	ahead.hp[B] = 4
	var performed := CardCpuStrategy.new().take_turn(ahead, A)
	_assert.call(ahead.hp[A] >= 4 and performed.size() < 20, "優勢のCPUは自分のHPを手放さない")
	var behind := _new_match(["mirage"], 7)
	for slot in 3:
		_place(behind, B, "sand", slot, 4, 2)
	_assert.call(
		CardCpuStrategy.new().choose_action(behind, A).get("type", "") == "play",
		"押されているCPUはミラージュを出す"
	)


func _test_cpu_choices() -> void:
	var spy := _new_match(["spy"])
	spy.deck[B][0] = CardLibrary.find_by_id("sand")
	var spy_hint := CardCpuStrategy.new()._effect_target(spy, A, spy.hand[A][0])
	_assert.call(spy_hint.is_empty() or spy_hint.has(CardPeekEffects.PEEK_KEY), "CPUはスパイの選びを決められる")
	var phantom := _new_match(["phantom"])
	phantom.hand[B] = _cards(["sand", "colossus", "grain"])
	var hint := CardCpuStrategy.new()._effect_target(phantom, A, phantom.hand[A][0])
	_assert.call(
		hint.has(CardPeekEffects.PEEK_KEY) and int(hint[CardPeekEffects.PEEK_KEY]) < 3,
		"CPUはファントムで相手の手札から写す1枚を選ぶ"
	)
