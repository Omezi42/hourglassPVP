extends RefCounted
## カードセット「注砂の刻」(第2弾の6つ目のテーマ)とテーマ外のレジェンドの検証。GameDesign.md 6章
## 「残りのマナを使う効果」「味方が出るたびに働く効果」「特殊勝利」、Architecture.md 10.8節に対応する。

const SET_ID := "pour_sand"
const EXTRA_ID := "second_extra"
const A := MatchState.Side.A
const B := MatchState.Side.B

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_sets_are_registered()
	_test_cask_spends_all_mana()
	_test_cask_with_no_mana_left()
	_test_deluge_grows_all_allies()
	_test_ladle_needs_spare_mana()
	_test_pour_raises_all_sand()
	_test_decanter_moves_total()
	_test_decanter_floors_at_one()
	_test_decanter_without_ally()
	_test_overflow_spends_and_hits()
	_test_overflow_stops_without_foes()
	_test_reservoir_uses_unspent_mana()
	_test_reservoir_without_other_unit()
	_test_fountain_from_hand()
	_test_fountain_ignores_itself()
	_test_fountain_on_summon_and_revive()
	_test_fountain_stacks_and_silence()
	_test_fountain_foe_unit_ignored()
	_test_amphora_distributes_attack()
	_test_amphora_wraps_around()
	_test_amphora_alone_does_nothing()
	_test_terminus_wins_on_empty_deck()
	_test_terminus_does_not_win_with_cards()
	_test_special_win_plumbing()
	_test_promise_draws_then_pays()
	_test_promise_returned_or_silenced_does_not_pay()
	_test_live_rules_note()
	_test_cpu_plays_pour_cards()
	_test_cpu_values()


func _new_match(hand_ids: Array, mana := 7, deck_ids: Variant = null) -> MatchState:
	var deck: Array = []
	for i in MatchState.DECK_SIZE:
		deck.append(CardLibrary.find_by_id("sand"))
	var state := MatchState.new()
	state.start_match(deck, deck.duplicate(), MatchState.Side.A, 12345)
	state.current_turn = A
	state.hand[A] = _cards(hand_ids)
	if deck_ids != null:
		state.deck[A] = _cards(deck_ids)
	state.mana[A] = mana
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


func _test_sets_are_registered() -> void:
	_assert.call(CardSetLibrary.card_ids(SET_ID).size() == 9, "注砂の刻は9枚")
	_assert.call(CardSetLibrary.card_ids(EXTRA_ID) == ["terminus", "promise"], "第2弾のテーマ外は2枚")
	for set_id in [SET_ID, EXTRA_ID]:
		_assert.call(CardSetLibrary.has_set(set_id), "%s が登録されている" % set_id)
		for id in CardSetLibrary.card_ids(set_id):
			var card := CardLibrary.find_by_id(id)
			_assert.call(
				card != null and card.set_id == set_id, "%s が %s のカードとして読める" % [id, set_id]
			)


func _test_cask_spends_all_mana() -> void:
	var state := _new_match(["cask"], 7)
	_assert.call(state.play_card(A, 0, 0), "キャスクを出せる")
	_assert.call(int(state.mana[A]) == 0, "残りのマナをすべて使う")
	_assert.call(state.board[A][0].total_sand() == 2 + 5, "残り5につき総量が5増える")


func _test_cask_with_no_mana_left() -> void:
	var state := _new_match(["cask"], 2)
	_assert.call(state.play_card(A, 0, 0), "マナがちょうどでも出せる")
	_assert.call(state.board[A][0].total_sand() == 2, "残りが0なら効果は起きない")


func _test_deluge_grows_all_allies() -> void:
	var state := _new_match(["deluge"], 7)
	var ally := _place(state, A, "sand", 1)
	var before := ally.total_sand()
	state.play_card(A, 0, 0)
	_assert.call(int(state.mana[A]) == 0, "デリュージも残りをすべて使う")
	_assert.call(ally.total_sand() == before + 2, "自分の砂時計すべてが残り2ぶん増える")
	_assert.call(state.board[A][0].total_sand() == 3 + 2, "デリュージ自身も含む")


func _test_ladle_needs_spare_mana() -> void:
	var rich := _new_match(["ladle"], 5)
	var ally := _place(rich, A, "sand", 1)
	var before := ally.total_sand()
	rich.play_card(A, 0, 0)
	_assert.call(int(rich.mana[A]) == 3, "ラドルはマナを使わない")
	_assert.call(
		ally.total_sand() == before + 1 and rich.board[A][0].total_sand() == 4, "残りが3以上なら全体の総量+1"
	)
	var poor := _new_match(["ladle"], 4)
	var other := _place(poor, A, "sand", 1)
	var other_before := other.total_sand()
	poor.play_card(A, 0, 0)
	_assert.call(
		other.total_sand() == other_before and poor.board[A][0].total_sand() == 3, "残りが2なら何も起きない"
	)


func _test_pour_raises_all_sand() -> void:
	var state := _new_match(["pour"], 7)
	var aged := _place(state, A, "sand", 0)
	var young := _place(state, A, "sand", 1)
	aged.drop_sand(3)
	young.drop_sand(2)
	var total := aged.total_sand()
	_assert.call(state.cast_spell(A, 0, {"side": A, "slot": 0}), "注ぎ砂を撃てる")
	_assert.call(aged.attack == 0 and aged.health == total, "選んだ駒の砂が残らず上へ戻る")
	_assert.call(young.attack == 2, "選ばなかった駒は変わらない")


func _test_decanter_moves_total() -> void:
	var state := _new_match(["decanter"], 7)
	var old := _place(state, A, "sand", 1)
	old.drop_sand(2)
	var total := old.total_sand()
	_assert.call(state.play_card(A, 0, 0, {"side": A, "slot": 1}), "デカンタを出せる")
	_assert.call(old.total_sand() == total - 2, "選んだ味方の総量が2減る")
	_assert.call(old.health >= 1, "体力は1以上のまま")
	_assert.call(state.board[A][0].total_sand() == 4 + 2, "デカンタの総量が2増える")
	_assert.call(state.units(A).size() == 2, "減らしても砕けない")


func _test_decanter_floors_at_one() -> void:
	var state := _new_match(["decanter"], 7)
	var tiny := _place(state, A, "sand", 1)
	tiny.health = 1
	tiny.attack = 0
	state.play_card(A, 0, 0, {"side": A, "slot": 1})
	_assert.call(tiny.health == 1 and tiny.attack == 0, "総量1の駒はそれ以上減らない")
	var thin := CardInstance.new(CardLibrary.find_by_id("sand"))
	thin.health = 1
	thin.attack = 3
	CardPourSandEffects.shrink_total(thin, 2)
	_assert.call(thin.health == 1 and thin.attack == 1, "体力から引けないぶんは攻撃力から引く")


func _test_decanter_without_ally() -> void:
	var state := _new_match(["decanter"], 7)
	state.play_card(A, 0, 0)
	_assert.call(state.board[A][0].total_sand() == 4, "他の砂時計がいなければ総量は増えない")


func _test_overflow_spends_and_hits() -> void:
	var state := _new_match(["overflow"], 6)
	var foe := _place(state, B, "lock", 0)
	var before := foe.total_sand()
	_assert.call(state.cast_spell(A, 0), "溢れ砂を撃てる")
	_assert.call(int(state.mana[A]) == 0, "残りのマナをすべて使う")
	_assert.call(foe.total_sand() == before - 5, "残り5につき1ダメージずつ当たる")


func _test_overflow_stops_without_foes() -> void:
	var state := _new_match(["overflow"], 4)
	_assert.call(state.cast_spell(A, 0), "相手の砂時計がいなくても撃てる")
	_assert.call(
		int(state.mana[A]) == 0 and int(state.hp[B]) == MatchState.INITIAL_HP, "マナは使い、相手の本体は殴らない"
	)


func _test_reservoir_uses_unspent_mana() -> void:
	var state := _new_match([], 3)
	_place(state, A, "reservoir", 0)
	var other := _place(state, A, "sand", 1)
	var before := other.total_sand()
	state.end_turn()
	_assert.call(other.total_sand() == before + 3, "使わずに残した3マナぶん他の砂時計が育つ")
	_assert.call(int(state.mana[A]) == 3, "マナは消費しない")


func _test_reservoir_without_other_unit() -> void:
	var state := _new_match([], 3)
	var reservoir := _place(state, A, "reservoir", 0)
	var total := reservoir.total_sand()
	state.end_turn()
	_assert.call(reservoir.total_sand() == total, "他の砂時計がいなければ不発で、自分には乗らない")


func _test_fountain_from_hand() -> void:
	var state := _new_match(["sand"], 7)
	var fountain := _place(state, A, "fountain", 0)
	var total := fountain.total_sand()
	_assert.call(state.play_card(A, 0, 1), "砂時計を出せる")
	var entered: CardInstance = state.board[A][1]
	var base := CardLibrary.find_by_id("sand")
	_assert.call(entered.total_sand() == base.total_sand + 1, "出した砂時計の総量が1増える")
	_assert.call(entered.attack == base.initial_attack + 1, "砂が1粒落ちている")
	_assert.call(fountain.total_sand() == total, "ファウンテン自身は変わらない")


func _test_fountain_ignores_itself() -> void:
	var state := _new_match(["fountain"], 7)
	state.play_card(A, 0, 0)
	var fountain: CardInstance = state.board[A][0]
	_assert.call(fountain.total_sand() == 6 and fountain.attack == 0, "自分自身が出たときは働かない")


func _test_fountain_on_summon_and_revive() -> void:
	var summon := _new_match([], 7)
	_place(summon, A, "fountain", 0)
	CardEffectResolver.new(summon)._summon(A, "grain")
	var token: CardInstance = summon.board[A][1]
	var grain := CardLibrary.find_by_id("grain")
	_assert.call(token != null and token.total_sand() == grain.total_sand + 1, "効果で出した砂時計にも働く")
	var revive := _new_match([], 7)
	_place(revive, A, "fountain", 0)
	revive.graveyard[A] = _cards(["sand"])
	CardEffectResolver.new(revive)._revive(A, 0, 1)
	_assert.call(revive.board[A][1].attack >= 1, "蘇生した砂時計にも働く")
	var play_top := _new_match([], 7, ["sand"])
	_place(play_top, A, "fountain", 0)
	play_top.hand[A] = _cards(["prophecy"])
	play_top.cast_spell(A, 0)
	var sand := CardLibrary.find_by_id("sand")
	_assert.call(play_top.board[A][1].total_sand() == sand.total_sand + 1, "予言で出した砂時計にも働く")


func _test_fountain_stacks_and_silence() -> void:
	var state := _new_match(["sand"], 7)
	_place(state, A, "fountain", 0)
	_place(state, A, "fountain", 1)
	state.play_card(A, 0, 2)
	var base := CardLibrary.find_by_id("sand")
	_assert.call(state.board[A][2].total_sand() == base.total_sand + 2, "ファウンテンが2体なら2回働く")
	var quiet := _new_match(["sand"], 7)
	var silenced := _place(quiet, A, "fountain", 0)
	silenced.silence()
	quiet.play_card(A, 0, 1)
	_assert.call(quiet.board[A][1].total_sand() == base.total_sand, "効果を消されたら働かない")


func _test_fountain_foe_unit_ignored() -> void:
	var state := _new_match(["sand"], 7)
	_place(state, B, "fountain", 0)
	state.play_card(A, 0, 0)
	var base := CardLibrary.find_by_id("sand")
	_assert.call(state.board[A][0].total_sand() == base.total_sand, "相手のファウンテンは自分の砂時計に働かない")


func _break_amphora(state: MatchState, attack: int) -> void:
	var amphora := _place(state, A, "amphora", 0)
	amphora.health = 1
	amphora.attack = attack
	state.destroy_unit(A, 0)


func _test_amphora_distributes_attack() -> void:
	var state := _new_match([], 7)
	var left := _place(state, A, "sand", 1)
	var right := _place(state, A, "sand", 2)
	var left_before := left.total_sand()
	var right_before := right.total_sand()
	_break_amphora(state, 2)
	_assert.call(
		left.total_sand() == left_before + 1 and right.total_sand() == right_before + 1,
		"攻撃力2ぶん、左から1ずつ足される"
	)


func _test_amphora_wraps_around() -> void:
	var state := _new_match([], 7)
	var left := _place(state, A, "sand", 1)
	var right := _place(state, A, "sand", 2)
	var left_before := left.total_sand()
	var right_before := right.total_sand()
	_break_amphora(state, 3)
	_assert.call(
		left.total_sand() == left_before + 2 and right.total_sand() == right_before + 1,
		"一周したら左から続く"
	)


func _test_amphora_alone_does_nothing() -> void:
	var state := _new_match([], 7)
	_break_amphora(state, 3)
	_assert.call(state.units(A).is_empty(), "他の砂時計がいなければ何も起きない")


func _test_terminus_wins_on_empty_deck() -> void:
	var state := _new_match(["terminus"], 7, [])
	var ended := [-2]
	state.match_ended.connect(func(winner: int) -> void: ended[0] = winner)
	_assert.call(state.play_card(A, 0, 0), "テルミヌスを出せる")
	_assert.call(ended[0] == A and state.winner == A, "山札が0枚なら対局に勝つ")
	_assert.call(state.end_reason == MatchState.EndReason.SPECIAL_WIN, "決着の要因は特殊勝利")
	_assert.call(int(state.hp[B]) == MatchState.INITIAL_HP, "相手のHPは問わない")
	_assert.call(state.is_match_over(), "対局は終わっている")
	_assert.call(CardMatchLog.reason_text(state, A) == "特殊勝利", "結果画面の勝ち方の文言がある")
	_assert.call(MatchRecordService.end_reason_key(state.end_reason) == "special", "戦績の決着の要因が区別できる")


func _test_terminus_does_not_win_with_cards() -> void:
	var state := _new_match(["terminus"], 7, ["sand"])
	state.play_card(A, 0, 0)
	_assert.call(not state.is_match_over() and state.winner == -1, "山札に1枚でもあれば勝たない")


func _test_special_win_plumbing() -> void:
	var state := _new_match(["terminus", "sand"], 7, [])
	state.play_card(A, 0, 0)
	_assert.call(not state.can_play(A, 0), "決着したら何も指せない")
	MatchAction.apply(state, MatchAction.end_turn(A))
	_assert.call(state.winner == A, "決着の後に手を流しても勝者は変わらない")


func _test_promise_draws_then_pays() -> void:
	var state := _new_match(["promise"], 7)
	state.play_card(A, 0, 0)
	_assert.call(state.hand[A].size() == 3, "設置で3枚引く")
	var hp := int(state.hp[A])
	state.destroy_unit(A, 0)
	_assert.call(int(state.hp[A]) == hp - 6, "砕けた時に自分のHPを6失う")


func _test_promise_returned_or_silenced_does_not_pay() -> void:
	var state := _new_match([], 7)
	var promise := _place(state, A, "promise", 0)
	promise.silence()
	var hp := int(state.hp[A])
	state.destroy_unit(A, 0)
	_assert.call(int(state.hp[A]) == hp, "効果を消されたら払わない")
	var back := _new_match([], 7)
	_place(back, A, "promise", 0)
	var back_hp := int(back.hp[A])
	CardEffectResolver.new(back)._return_to_hand(A, 0)
	_assert.call(int(back.hp[A]) == back_hp, "手札へ戻されたら払わない")


func _test_live_rules_note() -> void:
	var state := _new_match(["cask", "overflow", "deluge", "sand"], 7)
	var cask := CardLibrary.find_by_id("cask")
	_assert.call(
		CardEffectResolver.live_rules_text(state, A, cask).ends_with("(いま使うと +5)"),
		"キャスクの文にいま使うと得る量が添う"
	)
	var overflow := CardLibrary.find_by_id("overflow")
	_assert.call(
		CardEffectResolver.live_rules_text(state, A, overflow).ends_with("(いま使うと 6ダメージ)"),
		"溢れ砂の文に添う"
	)
	var deluge := CardLibrary.find_by_id("deluge")
	_assert.call(
		CardEffectResolver.live_rules_text(state, A, deluge).ends_with("(いま使うと +2)"), "デリュージの文に添う"
	)
	var plain := CardLibrary.find_by_id("sand")
	_assert.call(
		CardEffectResolver.live_rules_text(state, A, plain) == plain.rules_text, "ほかの札には添わない"
	)


func _test_cpu_plays_pour_cards() -> void:
	var cpu := CardCpuStrategy.new()
	var state := _new_match(["cask"], 6)
	_assert.call(cpu.choose_action(state, A).get("type", "") == "play", "CPUはキャスクを出す")
	var terminus := _new_match(["terminus"], 7, [])
	_assert.call(cpu.choose_action(terminus, A).get("type", "") == "play", "CPUは山札が0枚ならテルミヌスを出す")
	var board := _new_match([], 7)
	var strong := _place(board, A, "sand", 0)
	strong.health = 4
	strong.attack = 3
	var weak := _place(board, A, "sand", 1)
	weak.health = 3
	weak.attack = 0
	_assert.call(CardPourSandEffects.cpu_transfer_slot(board, A, 2) == 1, "デカンタで減らす味方は痛みの少ない駒")


func _test_cpu_values() -> void:
	var cask := CardLibrary.find_by_id("cask")
	var cpu := CardCpuStrategy.new()
	var rich := cpu._card_value(_new_match([], 7), A, cask)
	var poor := cpu._card_value(_new_match([], 2), A, cask)
	_assert.call(rich > poor, "残りのマナが多いほどキャスクの見積もりが高い")
	var ladle := CardLibrary.find_by_id("ladle")
	var with_mana := cpu._card_value(_new_match([], 5), A, ladle)
	var without := cpu._card_value(_new_match([], 3), A, ladle)
	_assert.call(with_mana > without, "ラドルの条件を満たさないと見積もりが下がる")
