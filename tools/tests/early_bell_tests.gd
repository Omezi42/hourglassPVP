extends RefCounted
## カードセット「早鐘の刻」(第2弾の3つ目のテーマ)の検証。GameDesign.md 6章「マナを動かす効果」、
## Architecture.md 10.8.10節に対応する。

const SET_ID := "early_bell"
const A := MatchState.Side.A
const B := MatchState.Side.B

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_set_is_registered()
	_test_bell_raises_max_mana_only()
	_test_bell_stops_at_cap()
	_test_gong_drops_every_unit()
	_test_boiler_trims_next_turn()
	_test_debts_stack_and_floor_at_zero()
	_test_fastforward_gains_mana_this_turn()
	_test_borrow_caps_at_seven()
	_test_borrow_then_next_turn()
	_test_sunrise_delays_foe()
	_test_carillon_cost_down_at_cap()
	_test_alarm_only_at_cap()
	_test_dawn_raises_to_cap_and_pays_hp()
	_test_dawn_at_cap_is_free()
	_test_dawn_can_be_lethal()
	_test_debt_survives_fork()
	_test_cpu_values_mana_effects()


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
	_assert.call(CardSetLibrary.has_set(SET_ID), "早鐘の刻が登録されている")
	_assert.call(CardSetLibrary.card_ids(SET_ID).size() == 9, "早鐘の刻は9枚")
	for id in CardSetLibrary.card_ids(SET_ID):
		var card := CardLibrary.find_by_id(id)
		_assert.call(card != null and card.set_id == SET_ID, "%s が早鐘の刻のカードとして読める" % id)


func _test_bell_raises_max_mana_only() -> void:
	var state := _new_match(["bell"])
	state.max_mana[A] = 3
	var mana_before := int(state.mana[A])
	_assert.call(state.play_card(A, 0, 0), "ベルを出せる")
	_assert.call(int(state.max_mana[A]) == 4, "最大マナが1増える")
	_assert.call(int(state.mana[A]) == mana_before - 2, "今の手番のマナは増えない(コスト2だけ減る)")
	var unit: CardInstance = state.board[A][0]
	_assert.call(unit.attack == 1, "自分の砂時計すべての砂が1粒落ちる(ベル自身を含む)")


func _test_bell_stops_at_cap() -> void:
	var state := _new_match(["bell"])
	state.max_mana[A] = MatchState.MAX_MANA
	state.play_card(A, 0, 0)
	_assert.call(int(state.max_mana[A]) == MatchState.MAX_MANA, "最大マナは上限7を超えない")


func _test_gong_drops_every_unit() -> void:
	var state := _new_match(["gong"])
	var mine := _place(state, A, "sand", 1)
	var foe := _place(state, B, "sand", 2)
	var mine_before := mine.attack
	var foe_before := foe.attack
	state.play_card(A, 0, 0)
	_assert.call(mine.attack == mine_before + 1, "味方の砂が1粒落ちる")
	_assert.call(foe.attack == foe_before + 1, "相手の砂も1粒落ちる")
	var gong: CardInstance = state.board[A][0]
	_assert.call(gong.attack == 1, "ゴング自身も1粒落ちる")


func _test_boiler_trims_next_turn() -> void:
	var state := _new_match(["boiler"])
	state.play_card(A, 0, 0)
	_assert.call(int(state.mana_debt[A]) == 2, "次の手番のマナ -2 が掛かる")
	state.end_turn()
	state.end_turn()
	_assert.call(int(state.mana_debt[A]) == 0, "手番の始めに引いて0へ戻る")
	_assert.call(int(state.mana[A]) == maxi(int(state.max_mana[A]) - 2, 0), "回復の後にマナが2少なく始まる")


func _test_debts_stack_and_floor_at_zero() -> void:
	var state := _new_match(["boiler", "boiler"])
	state.mana[A] = 8
	state.play_card(A, 0, 0)
	state.play_card(A, 0, 1)
	_assert.call(int(state.mana_debt[A]) == 4, "重なれば足す")
	state.end_turn()
	state.end_turn()
	_assert.call(int(state.mana[A]) == 0, "マナは0未満にならない")
	_assert.call(int(state.max_mana[A]) >= 2, "最大マナは減らない")


func _test_fastforward_gains_mana_this_turn() -> void:
	var state := _new_match(["fastforward"])
	var unit := _place(state, A, "sand", 0)
	state.mana[A] = 3
	var attack_before := unit.attack
	_assert.call(state.cast_spell(A, 0, {"side": A, "slot": 0}), "早回しを撃てる")
	_assert.call(unit.attack == attack_before + 2, "砂が2粒落ちる")
	_assert.call(int(state.mana[A]) == 3, "コスト1を払って+1で、マナは変わらない")


func _test_borrow_caps_at_seven() -> void:
	var state := _new_match(["borrow"])
	state.mana[A] = 6
	state.cast_spell(A, 0)
	_assert.call(int(state.mana[A]) == MatchState.MAX_MANA, "上限7を超えるぶんは捨てる")
	_assert.call(int(state.mana_debt[A]) == 2, "次の手番のマナ -2")


func _test_borrow_then_next_turn() -> void:
	var state := _new_match(["borrow"])
	state.mana[A] = 1
	state.cast_spell(A, 0)
	_assert.call(int(state.mana[A]) == 3, "1マナを払って+3")
	state.end_turn()
	state.end_turn()
	_assert.call(int(state.mana[A]) == maxi(int(state.max_mana[A]) - 2, 0), "次の手番は2少ない")
	state.end_turn()
	state.end_turn()
	_assert.call(int(state.mana[A]) == int(state.max_mana[A]), "その次の手番は元に戻る")


func _test_sunrise_delays_foe() -> void:
	var state := _new_match(["sunrise"])
	state.play_card(A, 0, 0)
	_assert.call(int(state.mana_debt[B]) == 1, "相手に次の手番のマナ -1")
	_assert.call(int(state.mana_debt[A]) == 0, "自分には掛からない")
	state.end_turn()
	_assert.call(int(state.mana[B]) == maxi(int(state.max_mana[B]) - 1, 0), "相手のマナが1少なく始まる")


func _test_carillon_cost_down_at_cap() -> void:
	var state := _new_match(["carillon"])
	var card: CardData = state.hand[A][0]
	state.max_mana[A] = 6
	_assert.call(state.play_cost(A, card) == 6, "最大マナが7でなければコストはそのまま")
	state.max_mana[A] = MatchState.MAX_MANA
	_assert.call(state.play_cost(A, card) == 4, "最大マナが7ならコストが2下がる")
	_assert.call(card.category_name() == "常在", "札の名前の下に常在と出る")


func _test_alarm_only_at_cap() -> void:
	var state := _new_match(["alarm", "alarm"])
	var foe := _place(state, B, "sand", 0)
	foe.attack = 3
	foe.health = 1
	state.max_mana[A] = 6
	state.play_card(A, 0, 0)
	_assert.call(foe.attack == 3, "最大マナが7でなければ何も起きない")
	state.max_mana[A] = MatchState.MAX_MANA
	state.play_card(A, 0, 1)
	_assert.call(foe.attack == 1 and foe.health == 3, "最大マナが7なら相手の砂が2粒上へ戻る")


func _test_dawn_raises_to_cap_and_pays_hp() -> void:
	var state := _new_match(["dawn"])
	state.max_mana[A] = 3
	var hp_before := int(state.hp[A])
	state.play_card(A, 0, 0)
	_assert.call(int(state.max_mana[A]) == MatchState.MAX_MANA, "最大マナが7になる")
	_assert.call(int(state.hp[A]) == hp_before - 8, "上がった4につきHPを2ずつ、計8失う")


func _test_dawn_at_cap_is_free() -> void:
	var state := _new_match(["dawn"])
	state.max_mana[A] = MatchState.MAX_MANA
	var hp_before := int(state.hp[A])
	state.play_card(A, 0, 0)
	_assert.call(int(state.hp[A]) == hp_before, "既に上限ならHPは減らない")


func _test_dawn_can_be_lethal() -> void:
	var state := _new_match(["dawn"])
	state.max_mana[A] = 1
	state.hp[A] = 12
	state.play_card(A, 0, 0)
	_assert.call(state.is_match_over() and state.winner == B, "払うHPが尽きれば負ける")


func _test_debt_survives_fork() -> void:
	var state := _new_match(["boiler"])
	state.play_card(A, 0, 0)
	var twin := SpellForecast.fork(state)
	_assert.call(int(twin.mana_debt[A]) == 2, "対局の写しにも次の手番のマナの減りが残る")


func _test_cpu_values_mana_effects() -> void:
	var state := _new_match(["borrow", "carillon"])
	state.mana[A] = 4
	var gain := CardEffectData.new()
	gain.effect_type = CardEnums.EffectType.GAIN_MANA
	gain.target = CardEnums.EffectTarget.OWN_PLAYER
	gain.value = 3
	_assert.call(CardEarlyBellEffects.cpu_value(state, A, gain, 1) > 0.0, "前借りで出せるようになる札があれば値打ちがある")
	state.hand[A] = [CardLibrary.find_by_id("bell")]
	_assert.call(CardEarlyBellEffects.cpu_value(state, A, gain, 1) == 0.0, "新しく出せる札が無い前借りは値打ちが無い")
	var dawn := CardLibrary.find_by_id("dawn")
	state.hp[A] = 3
	state.max_mana[A] = 1
	_assert.call(
		CardEarlyBellEffects.cpu_value(state, A, dawn.effects[0]) < -100.0, "払えば負けるドーンは強く減点する"
	)
