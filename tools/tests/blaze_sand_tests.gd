extends RefCounted
## カードセット「烈砂の刻」(第2弾の2つ目のテーマ)の検証。GameDesign.md 6章「自分のHPを払う効果」
## 「攻撃したとき・HPを失ったときに働く効果」「相手のHPを参照する効果」「手札から砂時計を出す効果」、
## Architecture.md 10.8.9節に対応する。

const SET_ID := "blaze_sand"
const A := MatchState.Side.A
const B := MatchState.Side.B

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_set_is_registered()
	_test_torch_pays_hp_and_attacks_at_once()
	_test_paying_all_hp_loses()
	_test_tailwind_lets_fresh_unit_attack()
	_test_tailwind_on_old_unit_only_drops_sand()
	_test_blaze_drops_extra_sand()
	_test_spark_drops_sand_after_attacking()
	_test_spark_drops_sand_after_attacking_player()
	_test_spark_does_not_fire_when_it_breaks()
	_test_warcry_drops_all_allies()
	_test_flare_grants_quick_to_other_allies_only()
	_test_chaser_quick_while_foe_hp_low()
	_test_chaser_follows_foe_hp_during_turn()
	_test_stampede_plays_two_cheap_units()
	_test_stampede_skips_spells_and_costly_cards()
	_test_stampede_stops_without_free_slots()
	_test_stampede_resolves_play_effects()
	_test_stampede_is_deterministic_with_seed()
	_test_ignis_grows_per_hp_loss()
	_test_ignis_ignores_heal_and_lethal()
	_test_ignis_reacts_to_foe_attack()
	_test_quick_grant_survives_next_turn()
	_test_cpu_values_new_effects()


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


## 体力・攻撃力を指定した駒を置く(出したターンではない)。
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
	_assert.call(CardSetLibrary.has_set(SET_ID), "烈砂の刻が登録されている")
	var ids := CardSetLibrary.card_ids(SET_ID)
	_assert.call(ids.size() == 9, "烈砂の刻は9枚")
	for id in ids:
		var card := CardLibrary.find_by_id(id)
		_assert.call(card != null and card.set_id == SET_ID, "%s の set_id が烈砂の刻" % id)
	_assert.call(CardSetLibrary.price(SET_ID) == 0, "烈砂の刻はまだショップで売らない")
	_assert.call(CardLibrary.find_by_id("stampede").rarity == CardEnums.Rarity.EPIC, "スタンピードはエピック")
	_assert.call(CardLibrary.find_by_id("ignis").rarity == CardEnums.Rarity.LEGENDARY, "イグニスはレジェンド")
	_assert.call(CardLibrary.find_by_id("tailwind").is_spell, "追い風は砂術")
	_assert.call(CardLibrary.find_by_id("warcry").is_spell, "鬨の声は砂術")
	_assert.call(CardLibrary.find_by_id("chaser").category_name() == "常在", "チェイサーの札は「常在」")
	_assert.call(CardLibrary.find_by_id("spark").category_name() == "常在", "スパークの札は「常在」")
	_assert.call(CardLibrary.find_by_id("ignis").category_name() == "常在", "イグニスの札は「常在」")


# --- トーチ -------------------------------------------------------------


func _test_torch_pays_hp_and_attacks_at_once() -> void:
	var state := _new_match(["torch"])
	_place_with(state, B, "sand", 0, 4, 1)
	state.play_card(A, 0, 0)
	_assert.call(state.hp[A] == MatchState.INITIAL_HP - 2, "トーチは自分のHPを2失う")
	var torch: CardInstance = state.board[A][0]
	_assert.call(torch.can_attack(), "トーチは出したターンから殴れる")
	state.attack(A, 0, 0)
	_assert.call(state.board[B][0].health == 2, "出した手番に2点を出す")


func _test_paying_all_hp_loses() -> void:
	var state := _new_match(["torch"])
	_set_hp(state, 2, 24)
	state.play_card(A, 0, 0)
	_assert.call(state.is_match_over() and state.winner == B, "HPを払って0になれば負ける")


# --- 追い風 -------------------------------------------------------------


func _test_tailwind_lets_fresh_unit_attack() -> void:
	var state := _new_match(["sand", "tailwind"])
	_place_with(state, B, "sand", 0, 5, 0)
	state.play_card(A, 0, 0)
	var fresh: CardInstance = state.board[A][0]
	_assert.call(not fresh.can_attack(), "出したばかりの駒は殴れない")
	state.cast_spell(A, 0, {"side": A, "slot": 0})
	_assert.call(fresh.has_keyword(CardEnums.Keyword.QUICK), "追い風で疾走を得る")
	_assert.call(fresh.attack == 1 and fresh.health == 4, "その砂が1粒落ちる")
	_assert.call(fresh.can_attack(), "出したターンに与えれば、このターン殴れる")
	_assert.call(state.attack(A, 0, 0), "実際に攻撃できる")


func _test_tailwind_on_old_unit_only_drops_sand() -> void:
	var state := _new_match(["tailwind"])
	var old := _place_with(state, A, "sand", 0, 4, 1)
	state.cast_spell(A, 0, {"side": A, "slot": 0})
	_assert.call(old.attack == 2 and old.health == 3, "出したターン以外の駒でも砂は落ちる")
	_assert.call(old.can_attack(), "もともと殴れる駒は変わらず殴れる")


# --- ブレイズ・スパーク・鬨の声 ----------------------------------------------


func _test_blaze_drops_extra_sand() -> void:
	var state := _new_match([])
	var blaze := _place_with(state, A, "blaze", 0, 7, 0)
	state.end_turn()
	_assert.call(blaze.attack == 2, "ブレイズは落砂で2粒落ちる(効果1粒+通常1粒)")


func _test_spark_drops_sand_after_attacking() -> void:
	var state := _new_match([])
	var spark := _place_with(state, A, "spark", 0, 3, 1)
	_place_with(state, B, "sand", 0, 5, 0)
	state.attack(A, 0, 0)
	_assert.call(spark.attack == 2 and spark.health == 2, "攻撃した後に砂が1粒落ちる")
	_assert.call(state.board[B][0].health == 4, "ダメージは落ちる前の攻撃力(1)")


func _test_spark_drops_sand_after_attacking_player() -> void:
	var state := _new_match([])
	var spark := _place_with(state, A, "spark", 0, 3, 1)
	state.attack(A, 0, -1)
	_assert.call(state.hp[B] == MatchState.INITIAL_HP - 1, "本体へ1ダメージ")
	_assert.call(spark.attack == 2, "相手プレイヤーへの攻撃でも砂が落ちる")


func _test_spark_does_not_fire_when_it_breaks() -> void:
	var state := _new_match([])
	var spark := _place_with(state, A, "spark", 0, 1, 3)
	_place_with(state, B, "sand", 0, 4, 2)
	state.attack(A, 0, 0)
	_assert.call(state.board[A][0] == null and spark.is_dead(), "スパークは反撃で砕ける")
	_assert.call(spark.attack == 3, "砕けた駒の効果は働かない")


func _test_warcry_drops_all_allies() -> void:
	var state := _new_match(["warcry"])
	var first := _place_with(state, A, "sand", 0, 4, 1)
	var second := _place_with(state, A, "sand", 1, 3, 2)
	var foe := _place_with(state, B, "sand", 0, 4, 1)
	state.cast_spell(A, 0)
	_assert.call(first.attack == 2 and second.attack == 3, "自分の砂時計すべての砂が1粒落ちる")
	_assert.call(foe.attack == 1, "相手の砂時計は変わらない")


# --- フレア -------------------------------------------------------------


func _test_flare_grants_quick_to_other_allies_only() -> void:
	var state := _new_match(["sand", "flare"])
	state.play_card(A, 0, 0)
	var ally: CardInstance = state.board[A][0]
	ally.attack = 1
	ally.health = 4
	state.play_card(A, 0, 1)
	var flare: CardInstance = state.board[A][1]
	_assert.call(state.hp[A] == MatchState.INITIAL_HP - 3, "フレアは自分のHPを3失う")
	_assert.call(ally.has_keyword(CardEnums.Keyword.QUICK), "他の砂時計に疾走を与える")
	_assert.call(ally.can_attack(), "同じ手番に出した駒が殴れる")
	_assert.call(not flare.has_keyword(CardEnums.Keyword.QUICK), "フレア自身には与えない")
	_assert.call(not flare.can_attack(), "フレア自身は殴れない")


# --- チェイサー ---------------------------------------------------------


func _chaser_can_attack(foe_hp: int) -> bool:
	var state := _new_match(["chaser"])
	_set_hp(state, 24, foe_hp)
	state.play_card(A, 0, 0)
	var chaser: CardInstance = state.board[A][0]
	chaser.attack = 1
	chaser.health = 4
	return chaser.can_attack()


func _test_chaser_quick_while_foe_hp_low() -> void:
	_assert.call(_chaser_can_attack(12), "相手のHPが12以下なら出したターンに殴れる")
	_assert.call(_chaser_can_attack(1), "相手のHPがもっと低くても殴れる")
	_assert.call(not _chaser_can_attack(13), "相手のHPが13なら殴れない")


func _test_chaser_follows_foe_hp_during_turn() -> void:
	var state := _new_match(["chaser"])
	_set_hp(state, 24, 14)
	state.play_card(A, 0, 0)
	var chaser: CardInstance = state.board[A][0]
	chaser.attack = 1
	chaser.health = 4
	_assert.call(not chaser.can_attack(), "相手のHPが高いあいだは疾走を持たない")
	state.damage_player(B, 2)
	_assert.call(chaser.has_keyword(CardEnums.Keyword.QUICK), "相手のHPが12へ下がったら疾走を持つ")
	_assert.call(chaser.keywords().has(CardEnums.Keyword.QUICK), "札の名前の下へ疾走を出す")
	state.heal_player(B, 1)
	_assert.call(not chaser.has_keyword(CardEnums.Keyword.QUICK), "相手が回復して13へ戻れば失う")
	_assert.call(not chaser.can_attack(), "出したターンなら殴れなくなる")


# --- スタンピード -------------------------------------------------------


func _stampede_state(hand_ids: Array) -> MatchState:
	var ids := ["stampede"]
	ids.append_array(hand_ids)
	var state := _new_match(ids)
	state.play_card(A, 0, 0)
	return state


func _test_stampede_plays_two_cheap_units() -> void:
	var state := _new_match(["stampede", "grain", "grain", "grain"])
	var mana_before := int(state.mana[A])
	state.play_card(A, 0, 0)
	_assert.call(state.hp[A] == MatchState.INITIAL_HP - 4, "スタンピードは自分のHPを4失う")
	_assert.call(state.units(A).size() == 3, "スタンピード自身と手札から2体で3体になる")
	_assert.call(state.hand[A].size() == 1, "手札から2枚が減る")
	_assert.call(int(state.mana[A]) == mana_before - 5, "場に出した駒のコストは払わない")
	for slot in [1, 2]:
		var unit: CardInstance = state.board[A][slot]
		_assert.call(unit != null and unit.has_keyword(CardEnums.Keyword.QUICK), "出した駒は疾走を得る")
		_assert.call(not unit.is_fresh(), "出したターンでも動ける")


func _test_stampede_skips_spells_and_costly_cards() -> void:
	var state := _stampede_state(["shot", "lock", "dash", "sand", "grain"])
	# コスト2以下の砂時計はダッシュ・砂・粒の3枚。砂術(ショット)とコスト4(ロック)は出さない。
	_assert.call(state.units(A).size() == 3, "条件に合う手札から2体まで出す")
	var ids: Array[String] = []
	for card: CardData in state.hand[A]:
		ids.append(card.id)
	_assert.call(ids.has("shot") and ids.has("lock"), "砂術とコスト3以上は手札に残る")
	var played: Array[String] = []
	for unit: CardInstance in state.units(A):
		played.append(unit.data.id)
	_assert.call(not played.has("shot") and not played.has("lock"), "砂術・コスト3以上は出ない")


func _test_stampede_stops_without_free_slots() -> void:
	var state := _new_match(["stampede", "grain", "grain"])
	for slot in range(1, MatchState.BOARD_SIZE - 1):
		_place(state, A, "sand", slot)
	state.play_card(A, 0, 0)
	_assert.call(state.units(A).size() == MatchState.BOARD_SIZE, "空き枠が1つなら1体だけ出る")
	_assert.call(state.hand[A].size() == 1, "出せなかった1枚は手札に残る")
	var none := _stampede_state([])
	_assert.call(none.units(A).size() == 1, "手札に合う砂時計が無ければ何も出ない")


func _test_stampede_resolves_play_effects() -> void:
	var state := _new_match(["stampede", "torch"])
	state.play_card(A, 0, 0)
	_assert.call(state.units(A).size() == 2, "トーチが場に出る")
	_assert.call(state.hp[A] == MatchState.INITIAL_HP - 6, "出した駒の設置効果(トーチのHP2)も解決する")


func _stampede_ids(seed_value: int) -> Array[String]:
	var state := _new_match(["stampede", "grain", "sand", "dash", "torch", "spark"])
	state._rng.seed = seed_value
	state.play_card(A, 0, 0)
	var found: Array[String] = []
	for unit: CardInstance in state.units(A):
		found.append(unit.data.id)
	return found


func _test_stampede_is_deterministic_with_seed() -> void:
	var first := _stampede_ids(7)
	var second := _stampede_ids(7)
	_assert.call(first == second, "同じ種なら同じ手札が出る")
	var seen := {}
	for seed_value in 12:
		seen[",".join(_stampede_ids(seed_value + 1))] = true
	_assert.call(seen.size() > 1, "種を変えれば別の手札が出る")


# --- イグニス -----------------------------------------------------------


func _test_ignis_grows_per_hp_loss() -> void:
	var state := _new_match(["torch"])
	var ignis := _place(state, A, "ignis", 0)
	var before := ignis.total_sand()
	state.play_card(A, 0, 1)
	_assert.call(ignis.total_sand() == before + 1, "代償でHPを失うたびに総量+1")
	state.damage_player(A, 5)
	_assert.call(ignis.total_sand() == before + 2, "減った量が大きくても1回ぶん")
	state.damage_player(A, 1)
	_assert.call(ignis.total_sand() == before + 3, "減るたびに1回")


func _test_ignis_ignores_heal_and_lethal() -> void:
	var state := _new_match([])
	var ignis := _place(state, A, "ignis", 0)
	var before := ignis.total_sand()
	state.heal_player(A, 3)
	_assert.call(ignis.total_sand() == before, "回復では育たない")
	state.damage_player(A, 0)
	_assert.call(ignis.total_sand() == before, "0ダメージでは育たない")
	state.damage_player(A, 99)
	_assert.call(state.is_match_over(), "HPが尽きれば決着する")
	_assert.call(ignis.total_sand() == before, "決着した後は働かない")


func _test_ignis_reacts_to_foe_attack() -> void:
	var state := _new_match([])
	var ignis := _place(state, A, "ignis", 0)
	_place_with(state, B, "sand", 0, 3, 2)
	state.current_turn = B
	var before := ignis.total_sand()
	state.attack(B, 0, -1)
	_assert.call(state.hp[A] == MatchState.INITIAL_HP - 2, "相手の攻撃でHPが減る")
	_assert.call(ignis.total_sand() == before + 1, "相手からのダメージにも反応する")
	_assert.call(ignis.has_keyword(CardEnums.Keyword.QUICK), "イグニスは疾走を持つ")


func _test_quick_grant_survives_next_turn() -> void:
	var state := _new_match(["sand", "tailwind"])
	state.play_card(A, 0, 0)
	state.cast_spell(A, 0, {"side": A, "slot": 0})
	var unit: CardInstance = state.board[A][0]
	state.end_turn()
	state.end_turn()
	_assert.call(unit.has_keyword(CardEnums.Keyword.QUICK), "与えた疾走は次の手番以降も残る")
	_assert.call(unit.can_attack(), "次の手番も普通に殴れる")


# --- CPU ----------------------------------------------------------------


func _test_cpu_values_new_effects() -> void:
	var cpu := CardCpuStrategy.new()
	var state := _new_match(["stampede", "grain", "grain", "grain"])
	var torch := CardLibrary.find_by_id("torch")
	_assert.call(cpu._on_play_value(state, A, torch.effects[0]) < 0.0, "CPUは自分のHPを払うことを損として見る")
	_set_hp(state, 2, 24)
	_assert.call(cpu._on_play_value(state, A, torch.effects[0]) < -10.0, "払えば負けるHPなら出さない見積もりにする")
	_set_hp(state, 24, 24)
	var stampede := CardLibrary.find_by_id("stampede")
	_assert.call(cpu._on_play_value(state, A, stampede.effects[1]) > 0.0, "手札から出せるならスタンピードに価値を見る")
	state.hand[A] = []
	_assert.call(cpu._on_play_value(state, A, stampede.effects[1]) == 0.0, "出せる手札が無ければ価値を見ない")
	var spark := CardLibrary.find_by_id("spark")
	_assert.call(cpu._repeating_value(state, A, spark) >= 0.0, "攻撃したときの効果を見積もれる")
	var ignis := CardLibrary.find_by_id("ignis")
	_assert.call(cpu._repeating_value(state, A, ignis) > 0.0, "HPを失ったときの効果に価値を見る")
