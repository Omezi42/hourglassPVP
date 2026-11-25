extends RefCounted
## カードセット「背水の刻」(第2弾の最初のテーマ)の検証。GameDesign.md 6章「自分のHPを参照する効果」
## 「攻撃してきた駒へ返す効果」、Architecture.md 10.8.8節に対応する。

const SET_ID := "back_water"
const A := MatchState.Side.A
const B := MatchState.Side.B

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_set_is_registered()
	_test_parry_raises_attacker_sand()
	_test_parry_ignores_effect_damage()
	_test_parry_skips_dead_attacker()
	_test_parry_works_when_attacking()
	_test_wick_raises_all_allies_on_death()
	_test_rage_drops_extra_sand_only_at_low_hp()
	_test_hold_is_still_only_when_outnumbered()
	_test_hold_stops_sand_drop()
	_test_hold_refreshes_when_board_changes()
	_test_hold_silenced_loses_still()
	_test_backwater_deals_two_when_behind()
	_test_backwater_deals_one_when_even_or_ahead()
	_test_ember_needs_low_hp()
	_test_bastion_cost_drops_at_low_hp()
	_test_libra_heals_half_gap_rounded_up()
	_test_libra_needs_to_be_behind()
	_test_last_hour_hits_gap_times()
	_test_last_hour_skips_when_not_behind()
	_test_last_hour_discards_when_foes_gone()
	_test_last_hour_is_deterministic_with_seed()
	_test_condition_boundaries()
	_test_cpu_skips_unmet_conditions()
	_test_cpu_values_parry_and_back_water_effects()


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


## 体力・攻撃力を指定した駒を置く。
func _place_with(
	state: MatchState, side: int, id: String, slot: int, health: int, attack: int
) -> CardInstance:
	var unit := _place(state, side, id, slot)
	unit.health = health
	unit.attack = attack
	return unit


func _set_hp(state: MatchState, own: int, foe: int) -> void:
	state.hp[A] = own
	state.hp[B] = foe


func _test_set_is_registered() -> void:
	_assert.call(CardSetLibrary.has_set(SET_ID), "背水の刻が登録されている")
	var ids := CardSetLibrary.card_ids(SET_ID)
	_assert.call(ids.size() == 9, "背水の刻は9枚")
	for id in [
		"parry", "wick", "rage", "hold", "backwater", "ember", "bastion", "libra", "last_hour"
	]:
		_assert.call(ids.has(id), "%s が背水の刻に入っている" % id)
		var card := CardLibrary.find_by_id(id)
		_assert.call(card != null and card.set_id == SET_ID, "%s の set_id が背水の刻" % id)
	_assert.call(CardSetLibrary.price(SET_ID) == 0, "背水の刻はまだショップで売らない")
	_assert.call(CardLibrary.find_by_id("libra").rarity == CardEnums.Rarity.EPIC, "リブラはエピック")
	_assert.call(
		CardLibrary.find_by_id("last_hour").rarity == CardEnums.Rarity.LEGENDARY, "ラストアワーはレジェンド"
	)


# --- パリィ -------------------------------------------------------------


func _test_parry_raises_attacker_sand() -> void:
	var state := _new_match([])
	_place_with(state, A, "sand", 0, 3, 2)
	_place_with(state, B, "parry", 0, 4, 0)
	state.attack(A, 0, 0)
	var attacker: CardInstance = state.board[A][0]
	# 殴った駒の砂が1粒上へ戻る(攻撃力2 → 1、体力3 → 4)。
	_assert.call(attacker.attack == 1, "パリィは殴ってきた駒の攻撃力を1抜く")
	_assert.call(attacker.health == 4, "戻った砂は体力へ戻る")


func _test_parry_ignores_effect_damage() -> void:
	var state := _new_match(["shatter"])
	var foe := _place_with(state, B, "parry", 0, 6, 0)
	var mine := _place_with(state, A, "sand", 0, 3, 2)
	state.cast_spell(A, 0, {"side": B, "slot": 0})
	_assert.call(foe.health == 2, "砂術のダメージは通る")
	_assert.call(mine.attack == 2, "効果のダメージではパリィは働かない")


func _test_parry_skips_dead_attacker() -> void:
	var state := _new_match([])
	# 攻撃した駒は反撃で砕ける(体力1、パリィの攻撃力は2)。
	var attacker := _place_with(state, A, "sand", 0, 1, 3)
	_place_with(state, B, "parry", 0, 4, 2)
	state.attack(A, 0, 0)
	_assert.call(state.board[A][0] == null, "攻撃した駒は反撃で砕ける")
	_assert.call(attacker.attack == 3, "砕けた駒へは働かない")


## パリィが攻撃した側のときも、殴り返してきた相手へ働く。
func _test_parry_works_when_attacking() -> void:
	var state := _new_match([])
	_place_with(state, A, "parry", 0, 3, 1)
	_place_with(state, B, "sand", 0, 4, 2)
	state.attack(A, 0, 0)
	var foe: CardInstance = state.board[B][0]
	_assert.call(foe.attack == 1, "殴り返してきた駒の砂もパリィが戻す")


# --- ウィック -----------------------------------------------------------


func _test_wick_raises_all_allies_on_death() -> void:
	var state := _new_match([])
	var wick := _place_with(state, A, "wick", 0, 2, 0)
	var ally1 := _place_with(state, A, "sand", 1, 2, 2)
	var ally2 := _place_with(state, A, "sand", 2, 1, 3)
	state.destroy_unit(A, 0)
	_assert.call(wick.is_dead(), "ウィックは砕けた")
	_assert.call(ally1.attack == 1 and ally1.health == 3, "余砂で味方の砂が1粒戻る")
	_assert.call(ally2.attack == 2 and ally2.health == 2, "味方すべてに働く")


# --- レイジ -------------------------------------------------------------


func _rage_attack_after_turn_end(own_hp: int) -> int:
	var state := _new_match([])
	_set_hp(state, own_hp, 24)
	var rage := _place_with(state, A, "rage", 0, 5, 0)
	state.end_turn()
	return rage.attack


func _test_rage_drops_extra_sand_only_at_low_hp() -> void:
	_assert.call(_rage_attack_after_turn_end(13) == 1, "HPが13なら落砂の1粒だけ")
	_assert.call(_rage_attack_after_turn_end(12) == 2, "HPが12以下なら砂がもう1粒落ちる")
	_assert.call(_rage_attack_after_turn_end(3) == 2, "HPがもっと低くても増えない")


# --- ホールド -----------------------------------------------------------


func _hold_still(foes: int, allies_besides_hold: int) -> bool:
	var state := _new_match(["hold"])
	for i in foes:
		_place(state, B, "sand", i)
	for i in allies_besides_hold:
		_place(state, A, "sand", i + 1)
	state.play_card(A, 0, 0)
	var hold: CardInstance = state.board[A][0]
	return hold.has_keyword(CardEnums.Keyword.STILL)


func _test_hold_is_still_only_when_outnumbered() -> void:
	_assert.call(_hold_still(2, 0), "相手2体・自分はホールドだけなら静止")
	_assert.call(not _hold_still(1, 0), "同数(ホールドを含めて数える)なら静止しない")
	_assert.call(not _hold_still(2, 1), "自分の砂時計が増えて同数なら静止しない")
	_assert.call(not _hold_still(0, 0), "相手がいなければ静止しない")
	_assert.call(_hold_still(3, 1), "相手のほうが多ければ静止")


func _test_hold_stops_sand_drop() -> void:
	var state := _new_match(["hold"])
	_place(state, B, "sand", 0)
	_place(state, B, "sand", 1)
	state.play_card(A, 0, 0)
	var hold: CardInstance = state.board[A][0]
	var before := hold.attack
	state.end_turn()
	_assert.call(hold.attack == before, "静止しているあいだ砂が落ちない")
	# 見せ方: 札の名前の下に出す語へ「静止」が入る。
	_assert.call(hold.keywords().has(CardEnums.Keyword.STILL), "静止が札の語に出る")
	_assert.call(hold.keywords().has(CardEnums.Keyword.GUARD), "守護も持つ")


func _test_hold_refreshes_when_board_changes() -> void:
	var state := _new_match(["hold"])
	_place(state, B, "sand", 0)
	_place(state, B, "sand", 1)
	state.play_card(A, 0, 0)
	var hold: CardInstance = state.board[A][0]
	_assert.call(hold.held_still, "相手2体で静止")
	state.destroy_unit(B, 0)
	state._cleanup_dead()
	_assert.call(not hold.held_still, "相手が減って同数になれば静止が解ける")
	_assert.call(not hold.keywords().has(CardEnums.Keyword.STILL), "解けたら語からも消える")
	var in_hand := CardLibrary.find_by_id("hold")
	_assert.call(not in_hand.has_keyword(CardEnums.Keyword.STILL), "定義そのものは静止を持たない")


func _test_hold_silenced_loses_still() -> void:
	var state := _new_match(["hold"])
	_place(state, B, "sand", 0)
	_place(state, B, "sand", 1)
	state.play_card(A, 0, 0)
	var hold: CardInstance = state.board[A][0]
	hold.silence()
	_assert.call(not hold.has_keyword(CardEnums.Keyword.STILL), "効果を消されたら静止しない")
	_assert.call(hold.keywords().is_empty(), "消された駒は語を持たない")


# --- 背水の陣 -----------------------------------------------------------


func _backwater_damage(own_hp: int, foe_hp: int) -> int:
	var state := _new_match(["backwater"])
	_set_hp(state, own_hp, foe_hp)
	var foe := _place_with(state, B, "sand", 0, 5, 0)
	state.cast_spell(A, 0)
	return 5 - foe.health


func _test_backwater_deals_two_when_behind() -> void:
	_assert.call(_backwater_damage(10, 20) == 2, "HPが相手より少なければ2ダメージ")


func _test_backwater_deals_one_when_even_or_ahead() -> void:
	_assert.call(_backwater_damage(20, 20) == 1, "HPが同じなら1ダメージ(満たさない)")
	_assert.call(_backwater_damage(24, 10) == 1, "HPが多ければ1ダメージ")


# --- エンバー -----------------------------------------------------------


func _ember_destroys(own_hp: int) -> bool:
	var state := _new_match(["ember"])
	_set_hp(state, own_hp, 24)
	_place_with(state, B, "sand", 0, 5, 0)
	state.play_card(A, 0, 0, {"side": B, "slot": 0})
	return state.board[B][0] == null


func _hp_state(own_hp: int) -> MatchState:
	var state := _new_match([])
	_set_hp(state, own_hp, 24)
	_place(state, B, "sand", 0)
	return state


func _test_ember_needs_low_hp() -> void:
	_assert.call(_ember_destroys(12), "HP12で相手の砂時計を破壊する")
	_assert.call(not _ember_destroys(13), "HP13では不発")
	var ember := CardLibrary.find_by_id("ember")
	_assert.call(
		not CardMatchEffectTarget.has_candidate(_hp_state(13), ember, B), "HPが高いときは対象を選ばせずに出せる"
	)
	_assert.call(CardMatchEffectTarget.has_candidate(_hp_state(10), ember, B), "HPが低ければ対象を選ばせる")


# --- バスティオン -------------------------------------------------------


func _test_bastion_cost_drops_at_low_hp() -> void:
	var state := _new_match(["bastion"])
	var bastion: CardData = state.hand[A][0]
	_set_hp(state, 13, 24)
	_assert.call(state.play_cost(A, bastion) == 6, "HP13ではコスト6のまま")
	_set_hp(state, 12, 24)
	_assert.call(state.play_cost(A, bastion) == 3, "HP12以下ならコスト3")
	state.mana[A] = 3
	_assert.call(state.can_play(A, 0), "下がったコストのマナで出せる")
	state.play_card(A, 0, 0)
	_assert.call(state.mana[A] == 0, "払うのも下がったコスト")
	_assert.call(state.board[A][0] != null, "バスティオンが場に出る")
	_assert.call(bastion.category_name() != "", "札の名前の下の行が出る")


# --- リブラ -------------------------------------------------------------


func _libra_heal(own_hp: int, foe_hp: int) -> int:
	var state := _new_match(["libra"])
	_set_hp(state, own_hp, foe_hp)
	state.play_card(A, 0, 0)
	return int(state.hp[A]) - own_hp


func _test_libra_heals_half_gap_rounded_up() -> void:
	_assert.call(_libra_heal(10, 20) == 5, "差10の半分は5")
	_assert.call(_libra_heal(10, 15) == 3, "差5の半分は切り上げて3")
	_assert.call(_libra_heal(10, 11) == 1, "差1は切り上げて1")
	_assert.call(_libra_heal(23, 24) == 1, "上限の範囲で回復")


func _test_libra_needs_to_be_behind() -> void:
	_assert.call(_libra_heal(15, 15) == 0, "HPが同じなら回復しない")
	_assert.call(_libra_heal(20, 10) == 0, "HPが多ければ回復しない")


# --- ラストアワー -------------------------------------------------------


func _last_hour_damage(own_hp: int, foe_hp: int, foe_count: int, foe_health := 9) -> int:
	var state := _new_match(["last_hour"])
	_set_hp(state, own_hp, foe_hp)
	for i in foe_count:
		_place_with(state, B, "sand", i, foe_health, 0)
	state.play_card(A, 0, 0)
	var lost := 0
	for i in foe_count:
		var unit: CardInstance = state.board[B][i]
		lost += foe_health - (unit.health if unit != null else 0)
	return lost


func _test_last_hour_hits_gap_times() -> void:
	_assert.call(_last_hour_damage(10, 15, 3) == 5, "差5なら1点ずつ合計5点")
	_assert.call(_last_hour_damage(10, 15, 1) == 5, "1体しかいなければその駒へ集まる")


func _test_last_hour_skips_when_not_behind() -> void:
	_assert.call(_last_hour_damage(20, 20, 2) == 0, "HPが同じなら何も起きない")
	_assert.call(_last_hour_damage(24, 10, 2) == 0, "HPが多ければ何も起きない")


func _test_last_hour_discards_when_foes_gone() -> void:
	# 体力1の駒2体に差12。2点ぶんで砕け、残りは捨てる(エラーにならない)。
	_assert.call(_last_hour_damage(2, 14, 2, 1) == 2, "砕けた駒は選ばず、残りは捨てる")
	var state := _new_match(["last_hour"])
	_set_hp(state, 1, 24)
	state.play_card(A, 0, 0)
	_assert.call(state.hp[B] == 24, "相手の駒がいなければ本体へは当たらない")


func _test_last_hour_is_deterministic_with_seed() -> void:
	var first := _last_hour_split()
	var second := _last_hour_split()
	_assert.call(first == second, "同じ種なら同じ振り分けになる")
	_assert.call(first.size() == 3, "3体の結果を返す")


func _last_hour_split() -> Array:
	var state := _new_match(["last_hour"])
	_set_hp(state, 10, 18)
	for i in 3:
		_place_with(state, B, "sand", i, 9, 0)
	state.play_card(A, 0, 0)
	var found: Array = []
	for i in 3:
		found.append((state.board[B][i] as CardInstance).health)
	return found


# --- 条件の境目・CPU ----------------------------------------------------


func _test_condition_boundaries() -> void:
	var effect := CardEffectData.new()
	effect.condition_scope = CardEnums.ConditionScope.OWN_HP_AT_MOST
	effect.condition_total = 12
	var state := _new_match([])
	_set_hp(state, 12, 12)
	_assert.call(CardBackWaterEffects.hp_condition_met(state, A, effect), "12以下は12ちょうどを含む")
	effect.condition_scope = CardEnums.ConditionScope.OWN_HP_BELOW_FOE
	_assert.call(not CardBackWaterEffects.hp_condition_met(state, A, effect), "同じなら少なくない")
	_set_hp(state, 11, 12)
	_assert.call(CardBackWaterEffects.hp_condition_met(state, A, effect), "1でも少なければ満たす")
	_assert.call(not CardBackWaterEffects.hp_condition_met(state, B, effect), "相手側から見れば満たさない")


func _test_cpu_skips_unmet_conditions() -> void:
	var cpu := CardCpuStrategy.new()
	var state := _new_match([])
	_place(state, B, "sand", 0)
	var libra := CardLibrary.find_by_id("libra")
	var ember := CardLibrary.find_by_id("ember")
	_set_hp(state, 24, 24)
	_assert.call(cpu._on_play_value(state, A, libra.effects[0]) == 0.0, "劣勢でなければリブラの回復を見積もらない")
	_assert.call(cpu._on_play_value(state, A, ember.effects[0]) == 0.0, "HPが高ければエンバーの破壊を見積もらない")
	_set_hp(state, 8, 24)
	_assert.call(cpu._on_play_value(state, A, libra.effects[0]) > 0.0, "劣勢ならリブラの回復を見積もる")
	_assert.call(cpu._on_play_value(state, A, ember.effects[0]) > 0.0, "HPが低ければエンバーを見積もる")


func _test_cpu_values_parry_and_back_water_effects() -> void:
	var cpu := CardCpuStrategy.new()
	var state := _new_match([])
	_place_with(state, B, "sand", 0, 4, 1)
	_set_hp(state, 8, 20)
	var parry := CardLibrary.find_by_id("parry")
	_assert.call(cpu._repeating_value(state, A, parry) > 0.0, "CPUはパリィの被弾の効果に価値を見る")
	var last_hour := CardLibrary.find_by_id("last_hour")
	_assert.call(cpu._on_play_value(state, A, last_hour.effects[0]) > 0.0, "劣勢ならラストアワーに価値を見る")
	_set_hp(state, 20, 20)
	_assert.call(cpu._on_play_value(state, A, last_hour.effects[0]) == 0.0, "互角ならラストアワーに価値を見ない")
