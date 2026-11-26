extends RefCounted
## カードセット「先触の刻」(第2弾の5つ目のテーマ)の検証。GameDesign.md 6章「山札の上を扱う効果」、
## Architecture.md 10.8節に対応する。

const SET_ID := "foresight_sand"
const A := MatchState.Side.A
const B := MatchState.Side.B
const PEEK := CardForesightEffects.PEEK_KEY

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_set_is_registered()
	_test_shaft_mills_three()
	_test_mill_is_not_a_draw()
	_test_mill_stops_at_empty_deck()
	_test_scope_keeps_or_mills()
	_test_omen_picks_one()
	_test_omen_with_one_card_left()
	_test_rune_reveals_and_raises_sand()
	_test_rune_counts_spell_cost()
	_test_foresight_plays_light_unit()
	_test_foresight_sends_others_to_hand()
	_test_foresight_without_slot_goes_to_hand()
	_test_digger_takes_the_costliest_unit()
	_test_digger_without_unit_adds_nothing()
	_test_horoscope_hits_when_spell()
	_test_prophecy_plays_unit_free()
	_test_prophecy_casts_spell_free()
	_test_prophecy_needs_deck_and_slot()
	_test_sibyl_extends_hand()
	_test_sibyl_plays_deck_top_with_cost()
	_test_sibyl_casts_spell_on_top()
	_test_sibyl_silenced_and_foe()
	_test_sibyl_through_match_action()
	_test_state_fork_keeps_deck_play()
	_test_cpu_plays_sibyl_top()
	_test_cpu_peek_choices()
	_test_cpu_values()


func _new_match(hand_ids: Array, deck_ids: Variant = null) -> MatchState:
	var deck: Array = []
	for i in MatchState.DECK_SIZE:
		deck.append(CardLibrary.find_by_id("sand"))
	var state := MatchState.new()
	state.start_match(deck, deck.duplicate(), MatchState.Side.A, 12345)
	state.current_turn = A
	state.hand[A] = _cards(hand_ids)
	if deck_ids != null:
		state.deck[A] = _cards(deck_ids)
	state.mana[A] = MatchState.MAX_MANA
	return state


func _cards(ids: Array) -> Array:
	var cards: Array = []
	for id in ids:
		cards.append(CardLibrary.find_by_id(id))
	return cards


func _place(state: MatchState, side: int, id: String, slot: int) -> CardInstance:
	var unit := CardInstance.new(CardLibrary.find_by_id(id))
	unit.summoned_this_turn = false
	state.board[side][slot] = unit
	return unit


func _grave_ids(state: MatchState, side: int) -> Array:
	return state.graveyard[side].map(func(card: CardData) -> String: return card.id)


func _test_set_is_registered() -> void:
	_assert.call(CardSetLibrary.has_set(SET_ID), "先触の刻が登録されている")
	_assert.call(CardSetLibrary.card_ids(SET_ID).size() == 9, "先触の刻は9枚")
	for id in CardSetLibrary.card_ids(SET_ID):
		var card := CardLibrary.find_by_id(id)
		_assert.call(card != null and card.set_id == SET_ID, "%s が先触の刻のカードとして読める" % id)


func _test_shaft_mills_three() -> void:
	var state := _new_match(["shaft"], ["sand", "ember", "wick", "gong", "bell"])
	_assert.call(state.play_card(A, 0, 0), "シャフトを出せる")
	_assert.call(_grave_ids(state, A) == ["sand", "ember", "wick"], "山札の上から3枚が墓地へ順に置かれる")
	_assert.call(state.deck[A].size() == 2 and state.deck[A][0].id == "gong", "残りの山札の一番上が繰り上がる")


func _test_mill_is_not_a_draw() -> void:
	var state := _new_match(["shaft"])
	var drawn := [0]
	state.cards_drawn.connect(func(_side: int, count: int) -> void: drawn[0] += count)
	_place(state, B, "hound", 0)
	var foe_hp := int(state.hp[B])
	var own_hp := int(state.hp[A])
	state.play_card(A, 0, 0)
	_assert.call(drawn[0] == 0, "山札を墓地へ置いても引いた数に入らない")
	_assert.call(int(state.hp[A]) == own_hp and int(state.hp[B]) == foe_hp, "ハウンドは反応しない")


func _test_mill_stops_at_empty_deck() -> void:
	var state := _new_match(["shaft"], ["sand", "ember"])
	var hp := int(state.hp[A])
	state.play_card(A, 0, 0)
	_assert.call(state.deck[A].is_empty() and state.graveyard[A].size() == 2, "足りなければある分だけ置く")
	_assert.call(int(state.hp[A]) == hp, "足りなくても疲労ダメージは起きない")
	_assert.call(MatchDeckTop.mill(state, A, 3).is_empty(), "空の山札からは何も置かれない")


func _test_scope_keeps_or_mills() -> void:
	var keep := _new_match(["scope"], ["ember", "sand"])
	keep.play_card(A, 0, 0)
	_assert.call(keep.deck[A][0].id == "ember" and keep.graveyard[A].is_empty(), "指定が無ければそのままにする")
	var mill := _new_match(["scope"], ["ember", "sand"])
	mill.play_card(A, 0, 0, {PEEK: 0})
	_assert.call(
		mill.deck[A][0].id == "sand" and _grave_ids(mill, A) == ["ember"], "墓地へ置くと選ぶと一番上が墓地へ行く"
	)
	var empty := _new_match(["scope"], [])
	_assert.call(empty.play_card(A, 0, 0, {PEEK: 0}), "山札が空でもスコープは出せる")


func _test_omen_picks_one() -> void:
	var state := _new_match(["omen"], ["ember", "wick", "sand"])
	_assert.call(state.cast_spell(A, 0, {PEEK: 1}), "予兆を撃てる")
	_assert.call(state.hand[A].size() == 1 and state.hand[A][0].id == "wick", "選んだ札が手札に加わる")
	_assert.call(_grave_ids(state, A) == ["omen", "ember"], "選ばなかった札が墓地へ置かれる")
	_assert.call(state.deck[A].size() == 1, "山札は2枚ぶん減る")
	var untouched := _new_match(["omen"], ["ember", "wick"])
	untouched.cast_spell(A, 0, {PEEK: 9})
	_assert.call(untouched.hand[A].size() == 1, "範囲外の指定でも1枚は手札へ")


func _test_omen_with_one_card_left() -> void:
	var state := _new_match(["omen"], ["ember"])
	state.cast_spell(A, 0)
	_assert.call(state.hand[A].size() == 1 and state.hand[A][0].id == "ember", "山札が1枚ならそれを手札へ")
	_assert.call(state.graveyard[A].size() == 1, "墓地へ行くのは予兆だけ")
	var none := _new_match(["omen"], [])
	_assert.call(none.cast_spell(A, 0) and none.hand[A].is_empty(), "山札が空でも不発で撃てる")


func _test_rune_reveals_and_raises_sand() -> void:
	var state := _new_match(["rune"], ["digger", "sand"])
	var foe := _place(state, B, "sand", 0)
	foe.health = 2
	foe.attack = 5
	var seen: Array = []
	state.deck_revealed.connect(
		func(side: int, card: CardData) -> void: seen.append([side, card.id])
	)
	state.play_card(A, 0, 1, {"side": B, "slot": 0})
	_assert.call(seen == [[A, "digger"]], "山札の一番上が公開される")
	_assert.call(foe.attack == 1 and foe.health == 6, "公開した札のコスト4だけ砂が上へ戻る")
	_assert.call(state.deck[A][0].id == "digger", "公開した札は山札の一番上に残る")


func _test_rune_counts_spell_cost() -> void:
	var state := _new_match(["rune"], ["prophecy", "sand"])
	var foe := _place(state, B, "sand", 0)
	foe.health = 1
	foe.attack = 5
	state.play_card(A, 0, 1, {"side": B, "slot": 0})
	_assert.call(foe.attack == 2, "砂術のコスト3も数える")
	var empty := _new_match(["rune"], [])
	var other := _place(empty, B, "sand", 0)
	other.attack = 3
	other.health = 1
	empty.play_card(A, 0, 1, {"side": B, "slot": 0})
	_assert.call(other.attack == 3, "山札が空なら何も戻らない")


func _test_foresight_plays_light_unit() -> void:
	var state := _new_match(["foresight"], ["shaft", "ember", "sand", "wick"])
	var seen: Array = []
	state.deck_revealed.connect(func(_side: int, card: CardData) -> void: seen.append(card.id))
	state.cast_spell(A, 0)
	_assert.call(seen == ["shaft"], "一番上が公開される")
	_assert.call(
		state.board[A][0] != null and state.board[A][0].data.id == "shaft", "コスト2の砂時計は場に出る"
	)
	_assert.call(
		_grave_ids(state, A) == ["foresight", "ember", "sand", "wick"], "設置効果が働き、山札の上から3枚が墓地へ"
	)
	_assert.call(state.hand[A].is_empty(), "手札には加わらない")


func _test_foresight_sends_others_to_hand() -> void:
	var heavy := _new_match(["foresight"], ["digger", "sand"])
	heavy.cast_spell(A, 0)
	_assert.call(heavy.hand[A].size() == 1 and heavy.hand[A][0].id == "digger", "コスト4の砂時計は手札へ")
	_assert.call(heavy.board[A][0] == null, "場には出ない")
	var spell := _new_match(["foresight"], ["omen", "sand"])
	spell.cast_spell(A, 0)
	_assert.call(spell.hand[A].size() == 1 and spell.hand[A][0].id == "omen", "砂術は手札へ")
	var edge := _new_match(["foresight"], ["scope", "sand"])
	edge.cast_spell(A, 0)
	_assert.call(
		edge.board[A][0] != null and edge.board[A][0].data.id == "scope", "コスト3ちょうどの砂時計も場に出る"
	)


func _test_foresight_without_slot_goes_to_hand() -> void:
	var state := _new_match(["foresight"], ["shaft", "sand"])
	for slot in MatchState.BOARD_SIZE:
		_place(state, A, "sand", slot)
	state.cast_spell(A, 0)
	_assert.call(state.hand[A].size() == 1 and state.hand[A][0].id == "shaft", "空き枠が無ければ手札に加える")
	_assert.call(state.graveyard[A].size() == 1, "設置効果は働かない")


func _test_digger_takes_the_costliest_unit() -> void:
	var state := _new_match(["digger"], ["sand", "ember", "omen", "wick", "gong"])
	state.play_card(A, 0, 0)
	_assert.call(state.deck[A].size() == 1, "4枚が山札から減る")
	_assert.call(state.hand[A].size() == 1 and state.hand[A][0].id == "ember", "コストがいちばん高い砂時計が手札へ")
	_assert.call(_grave_ids(state, A) == ["sand", "omen", "wick"], "残りは墓地に残り、手札へ戻った札は墓地から抜ける")


func _test_digger_without_unit_adds_nothing() -> void:
	var state := _new_match(["digger"], ["omen", "foresight", "prophecy", "omen", "sand"])
	state.play_card(A, 0, 0)
	_assert.call(state.hand[A].is_empty(), "砂時計が無ければ手札に何も加えない")
	_assert.call(state.graveyard[A].size() == 4, "4枚は墓地へ")


func _test_horoscope_hits_when_spell() -> void:
	var state := _new_match([], ["omen", "sand", "sand"])
	_place(state, A, "horoscope", 0)
	var foe := _place(state, B, "sand", 0)
	var total := foe.total_sand()
	state.end_turn()
	_assert.call(
		state.graveyard[A].size() == 1 and state.graveyard[A][0].id == "omen", "落砂で山札の一番上が墓地へ置かれる"
	)
	_assert.call(foe.total_sand() == total - 1, "砂術なら相手の砂時計に1ダメージ")
	state.current_turn = A
	state.end_turn()
	_assert.call(state.graveyard[A].size() == 2, "毎ターン1枚ずつ墓地へ置かれる")
	_assert.call(foe.total_sand() == total - 1, "砂時計なら追加のダメージは無い")
	var lone := _new_match([], ["omen"])
	_place(lone, A, "horoscope", 0)
	lone.end_turn()
	_assert.call(lone.graveyard[A].size() == 1, "相手の駒がいなければダメージは不発(墓地へは置く)")


func _test_prophecy_plays_unit_free() -> void:
	var state := _new_match(["prophecy"], ["wick", "sand"])
	state.mana[A] = 3
	state.cast_spell(A, 0)
	_assert.call(
		state.board[A][0] != null and state.board[A][0].data.id == "wick", "砂時計ならコストを払わず出る"
	)
	_assert.call(int(state.mana[A]) == 0, "予言のコスト3だけを払う")
	var heavy := _new_match(["prophecy"], ["digger", "ember", "sand", "sand", "sand", "sand"])
	heavy.mana[A] = 3
	heavy.cast_spell(A, 0)
	_assert.call(heavy.board[A][0] != null and heavy.board[A][0].data.id == "digger", "重い砂時計もただで出る")
	_assert.call(
		heavy.graveyard[A].size() == 4 and heavy.hand[A].size() == 1, "出した設置効果(ディガー)が働き、ember が手札へ"
	)


func _test_prophecy_casts_spell_free() -> void:
	var state := _new_match(["prophecy"], ["shot", "sand"])
	state.mana[A] = 3
	var hp := int(state.hp[B])
	state.cast_spell(A, 0)
	_assert.call(int(state.hp[B]) == hp - 2, "砂術なら撃たれる")
	_assert.call(_grave_ids(state, A) == ["prophecy", "shot"], "どちらも墓地へ行く")
	_assert.call(state.deck[A].size() == 1, "山札の一番上が減る")


func _test_prophecy_needs_deck_and_slot() -> void:
	var empty := _new_match(["prophecy"], [])
	_assert.call(not empty.can_cast(A, 0), "山札が0枚なら予言は撃てない")
	var full := _new_match(["prophecy"], ["wick", "sand"])
	for slot in MatchState.BOARD_SIZE:
		_place(full, A, "sand", slot)
	full.cast_spell(A, 0)
	_assert.call(full.deck[A][0].id == "wick", "空き枠が無ければ砂時計は山札に残る")


func _test_sibyl_extends_hand() -> void:
	var state := _new_match(["sand"], ["ember", "sand"])
	_assert.call(MatchDeckTop.playable_hand(state, A).size() == 1, "シビルがいなければ手札のまま")
	_place(state, A, "sibyl", 0)
	var view := MatchDeckTop.playable_hand(state, A)
	_assert.call(view.size() == 2 and view[1].id == "ember", "手札の右端に山札の一番上が並ぶ")
	_assert.call(state.hand[A].size() == 1, "手札の枚数には数えない")
	_assert.call(
		(
			MatchDeckTop.card_at(state, A, 1).id == "ember"
			and MatchDeckTop.card_at(state, A, 2) == null
		),
		"手札の枚数と同じ位置が山札の一番上"
	)
	state.deck[A] = []
	_assert.call(MatchDeckTop.playable_hand(state, A).size() == 1, "山札が空なら何も並ばない")


func _test_sibyl_plays_deck_top_with_cost() -> void:
	var state := _new_match(["sand"], ["ember", "wick"])
	_place(state, A, "sibyl", 0)
	state.mana[A] = 3
	_assert.call(not state.can_play(A, 1), "コストが払えなければ出せない(エンバーは4)")
	state.mana[A] = 4
	_assert.call(state.can_play(A, 1), "コストを払えば山札の一番上を出せる")
	var played := [0]
	state.unit_played.connect(func(_side: int, _slot: int) -> void: played[0] += 1)
	state.play_card(A, 1, 1)
	_assert.call(state.board[A][1] != null and state.board[A][1].data.id == "ember", "山札の一番上が場に出る")
	_assert.call(int(state.mana[A]) == 0 and played[0] == 1, "コストを払い、手札から出したのと同じ合図が出る")
	_assert.call(state.deck[A].size() == 1 and state.hand[A].size() == 1, "山札から減り、手札は変わらない")
	_assert.call(MatchDeckTop.card_at(state, A, 1).id == "wick", "次の札が右端へ上がる")


func _test_sibyl_casts_spell_on_top() -> void:
	var state := _new_match([], ["shot", "sand"])
	_place(state, A, "sibyl", 0)
	var hp := int(state.hp[B])
	_assert.call(state.can_cast(A, 0), "山札の一番上の砂術も撃てる")
	state.cast_spell(A, 0)
	_assert.call(int(state.hp[B]) == hp - 2 and state.graveyard[A].size() == 1, "撃って墓地へ")
	_assert.call(state.deck[A].size() == 1, "山札が1枚減る")


func _test_sibyl_silenced_and_foe() -> void:
	var state := _new_match([], ["ember", "sand"])
	var sibyl := _place(state, A, "sibyl", 0)
	sibyl.silence()
	_assert.call(MatchDeckTop.playable_hand(state, A).is_empty(), "効果を消されたら働かない")
	var foe := _new_match([], ["ember"])
	_place(foe, A, "sibyl", 0)
	_assert.call(not MatchDeckTop.top_playable(foe, B), "シビルは持ち主の山札だけに効く")


func _test_sibyl_through_match_action() -> void:
	var state := _new_match(["sand"], ["wick", "sand"])
	_place(state, A, "sibyl", 0)
	state.mana[A] = 1
	_assert.call(MatchAction.apply(state, MatchAction.play(A, 1, 2)), "手の hand_index が右端の札を指せる")
	_assert.call(
		state.board[A][2] != null and state.board[A][2].data.id == "wick", "棋譜どおり山札の一番上が出る"
	)


func _test_state_fork_keeps_deck_play() -> void:
	var state := _new_match([], ["wick", "sand"])
	_place(state, A, "sibyl", 0)
	var twin := SpellForecast.fork(state)
	state.mana[A] = 1
	twin.mana[A] = 1
	_assert.call(twin.play_card(A, 0, 1), "写しでも山札の一番上を出せる")
	_assert.call(state.deck[A].size() == 2, "元の山札は減らない")
	_assert.call(state.deck[A][0].id == "wick", "元の山札の一番上は変わらない")


func _test_cpu_plays_sibyl_top() -> void:
	var cpu := CardCpuStrategy.new()
	var state := _new_match([], ["wick", "sand"])
	_place(state, A, "sibyl", 0)
	state.mana[A] = 1
	var action := cpu.choose_action(state, A)
	_assert.call(
		action.get("type", "") == "play" and action.get("hand_index", -1) == 0,
		"CPUはシビルの山札の一番上を手札と同じように出す"
	)


func _test_cpu_peek_choices() -> void:
	var cpu := CardCpuStrategy.new()
	var state := _new_match([], ["sand", "ember"])
	var omen := CardLibrary.find_by_id("omen")
	var hint := CardForesightEffects.cpu_peek_hint(state, A, omen, cpu._peek_value)
	_assert.call(hint.has(PEEK), "予兆の選びを評価値で決める")
	var scope := CardLibrary.find_by_id("scope")
	var strong := _new_match([], ["ember", "sand"])
	_assert.call(
		CardForesightEffects.cpu_peek_hint(strong, A, scope, cpu._peek_value).is_empty(),
		"価値のある札はそのままにする"
	)
	var weak := _new_match([], ["omen", "sand"])
	var weak_hint := CardForesightEffects.cpu_peek_hint(weak, A, scope, cpu._peek_value)
	_assert.call(weak_hint.is_empty() or weak_hint.get(PEEK, -1) == 0, "選びは0(墓地へ)か無し(そのまま)")


func _test_cpu_values() -> void:
	var state := _new_match([], ["sand", "ember", "wick", "gong", "bell"])
	for id in ["shaft", "digger", "foresight", "prophecy"]:
		var card := CardLibrary.find_by_id(id)
		_assert.call(
			CardForesightEffects.cpu_value(state, A, card.effects[0]) != 0.0 or id == "prophecy",
			"%s に値打ちの見積もりがある" % id
		)
	var nearly := _new_match([], ["sand", "ember"])
	var shaft := CardLibrary.find_by_id("shaft")
	_assert.call(
		CardForesightEffects.cpu_value(nearly, A, shaft.effects[0]) < 0.0, "山札が尽きかけているときは山札を削らない"
	)
