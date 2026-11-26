extends RefCounted
## 第2弾のエピックの追加4枚(クロックワーク・爆心・ヴィジョン・スルース)の検証。
## GameDesign.md 6章「砂術のコストを下げる効果」「撃つ条件のある砂術」「マナを動かす効果」、Architecture.md 10.8節に対応する。

const A := MatchState.Side.A
const B := MatchState.Side.B

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_sets_are_registered()
	_test_clockwork_discounts_only_at_full_mana()
	_test_clockwork_stacks_and_floors()
	_test_clockwork_silenced()
	_test_sluice_carries_unspent_mana()
	_test_sluice_caps_and_debt()
	_test_sluice_carries_once_and_silence()
	_test_next_mana_shift()
	_test_vision_needs_ten_in_grave()
	_test_epicenter_fires_death_twice()
	_test_epicenter_needs_death_effect()
	_test_epicenter_counts_granted_death_effect()
	_test_cpu_values()


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


func _place(state: MatchState, side: int, id: String, slot: int) -> CardInstance:
	var unit := CardInstance.new(CardLibrary.find_by_id(id))
	unit.summoned_this_turn = false
	state.board[side][slot] = unit
	return unit


func _test_sets_are_registered() -> void:
	var expected := {
		"clockwork": "early_bell",
		"epicenter": "fuse_sand",
		"vision": "foresight_sand",
		"sluice": "pour_sand",
	}
	for id: String in expected:
		var card := CardLibrary.find_by_id(id)
		_assert.call(
			card != null and card.set_id == expected[id], "%s が %s のカードとして読める" % [id, expected[id]]
		)
		_assert.call(CardSetLibrary.card_ids(expected[id]).has(id), "%s がセットの一覧にある" % id)
		_assert.call(card != null and card.rarity == CardEnums.Rarity.EPIC, "%s はエピック" % id)


func _test_clockwork_discounts_only_at_full_mana() -> void:
	var state := _new_match([])
	var card := CardLibrary.find_by_id("middle")
	_place(state, A, "clockwork", 0)
	state.max_mana[A] = 6
	_assert.call(state.play_cost(A, card) == card.cost, "最大マナが7でなければ下がらない")
	state.max_mana[A] = MatchState.MAX_MANA
	_assert.call(state.play_cost(A, card) == card.cost - 1, "最大マナが7なら自分のカードのコストが1下がる")
	var foe_state := _new_match([])
	_place(foe_state, B, "clockwork", 0)
	foe_state.max_mana[A] = MatchState.MAX_MANA
	foe_state.max_mana[B] = MatchState.MAX_MANA
	_assert.call(foe_state.play_cost(A, card) == card.cost, "相手のカードのコストは下がらない")


func _test_clockwork_stacks_and_floors() -> void:
	var state := _new_match([])
	state.max_mana[A] = MatchState.MAX_MANA
	_place(state, A, "clockwork", 0)
	_place(state, A, "clockwork", 1)
	var heavy := CardLibrary.find_by_id("clockwork")
	_assert.call(state.play_cost(A, heavy) == heavy.cost - 2, "2体なら2下がる")
	var light := CardLibrary.find_by_id("pour")
	_assert.call(state.play_cost(A, light) == MatchState.MIN_COST, "1未満にはならない")


func _test_clockwork_silenced() -> void:
	var state := _new_match([])
	state.max_mana[A] = MatchState.MAX_MANA
	_place(state, A, "clockwork", 0).silenced = true
	var card := CardLibrary.find_by_id("middle")
	_assert.call(state.play_cost(A, card) == card.cost, "効果を消されると働かない")


## A が手番を終え、B も終えて、A の手番が回ってくるまで進める。
func _end_and_begin(state: MatchState) -> void:
	state.end_turn()
	state.end_turn()


func _test_sluice_carries_unspent_mana() -> void:
	var state := _new_match([], 3)
	state.max_mana[A] = 2
	_place(state, A, "sluice", 0)
	_end_and_begin(state)
	_assert.call(int(state.mana[A]) == 3 + 3, "最大マナ3への回復に、残した3が足される")
	var plain := _new_match([], 3)
	plain.max_mana[A] = 2
	_end_and_begin(plain)
	_assert.call(int(plain.mana[A]) == 3, "スルースがいなければ持ち越さない")


func _test_sluice_caps_and_debt() -> void:
	var state := _new_match([], 6)
	state.max_mana[A] = 5
	_place(state, A, "sluice", 0)
	_end_and_begin(state)
	_assert.call(int(state.mana[A]) == MatchState.MAX_MANA, "持ち越しを足しても上限7")
	var owed := _new_match([], 3)
	owed.max_mana[A] = 4
	_place(owed, A, "sluice", 0)
	owed.mana_debt[A] = 2
	_end_and_begin(owed)
	_assert.call(int(owed.mana[A]) == MatchState.MAX_MANA - 2, "「次 −n」は持ち越しを足して上限に収めた後に引く")


func _test_sluice_carries_once_and_silence() -> void:
	var twin := _new_match([], 2)
	twin.max_mana[A] = 2
	_place(twin, A, "sluice", 0)
	_place(twin, A, "sluice", 1)
	_end_and_begin(twin)
	_assert.call(int(twin.mana[A]) == 3 + 2, "2体いても持ち越すのは1回ぶん")
	var quiet := _new_match([], 2)
	quiet.max_mana[A] = 2
	_place(quiet, A, "sluice", 0).silenced = true
	_end_and_begin(quiet)
	_assert.call(int(quiet.mana[A]) == 3, "効果を消されると持ち越さない")


func _test_next_mana_shift() -> void:
	var state := _new_match([], 3)
	_assert.call(CardEarlyBellEffects.next_mana_shift(state, A) == 0, "持ち越しも減りも無ければ0(札は出ない)")
	state.mana_debt[A] = 2
	_assert.call(CardEarlyBellEffects.next_mana_shift(state, A) == -2, "減りだけなら「次 −n」")
	_place(state, A, "sluice", 0)
	_assert.call(
		CardEarlyBellEffects.next_mana_shift(state, A) == 3 - 2, "自分の手番の間は、いま終えたら持ち越す数との差し引き"
	)
	state.mana[A] = 1
	_assert.call(CardEarlyBellEffects.next_mana_shift(state, A) == -1, "差し引きが負なら「次 −n」")
	state.mana[A] = 2
	_assert.call(CardEarlyBellEffects.next_mana_shift(state, A) == 0, "差し引きが0なら札は出ない")
	state.end_turn()
	_assert.call(CardEarlyBellEffects.next_mana_shift(state, A) == 2 - 2, "手番の終わりに預けた持ち越しを読む")
	state.mana_debt[A] = 0
	_assert.call(CardEarlyBellEffects.next_mana_shift(state, A) == 2, "相手の手番の間は預けた数を「次 +n」と出す")


func _test_vision_needs_ten_in_grave() -> void:
	var low := _new_match(["vision"])
	var foe_low := _place(low, B, "sand", 0)
	for i in 9:
		low.graveyard[A].append(CardLibrary.find_by_id("sand"))
	low.play_card(A, 0, 0)
	_assert.call(low.board[B][0] == foe_low, "墓地が9枚なら何も壊れない")
	var high := _new_match(["vision"])
	_place(high, B, "sand", 0)
	_place(high, B, "sand", 3)
	_place(high, A, "sand", 1)
	high.graveyard[A].append(CardLibrary.find_by_id("pour"))
	for i in 9:
		high.graveyard[A].append(CardLibrary.find_by_id("sand"))
	high.play_card(A, 0, 0)
	_assert.call(high.units(B).is_empty(), "墓地が10枚以上なら相手の砂時計がすべて壊れる(砂術も数える)")
	_assert.call(high.board[A][1] != null, "自分の砂時計は壊れない")


func _amphora(state: MatchState, slot: int, attack: int) -> CardInstance:
	var amphora := _place(state, A, "amphora", slot)
	amphora.attack = attack
	amphora.health = 3
	return amphora


func _test_epicenter_fires_death_twice() -> void:
	var state := _new_match(["epicenter"])
	var ally := _place(state, A, "sand", 1)
	_amphora(state, 0, 2)
	var before := ally.total_sand()
	_assert.call(state.can_cast(A, 0), "余砂を持つ駒がいれば撃てる")
	_assert.call(state.cast_spell(A, 0, {"side": A, "slot": 0}), "爆心を撃てる")
	_assert.call(state.board[A][0] == null, "選んだ駒は破壊される")
	_assert.call(ally.total_sand() == before + 4, "攻撃力2の余砂が破壊で1回、もう一度で1回働く")


func _test_epicenter_needs_death_effect() -> void:
	var none := _new_match(["epicenter"])
	_assert.call(not none.can_cast(A, 0), "自分の砂時計がいなければ撃てない")
	var plain := _new_match(["epicenter"])
	_place(plain, A, "sand", 0)
	_assert.call(not plain.can_cast(A, 0), "余砂を持たない駒しかいなければ撃てない")
	var mixed := _new_match(["epicenter"])
	var plain_unit := _place(mixed, A, "sand", 0)
	var amphora := _amphora(mixed, 2, 1)
	var effect := CardLibrary.find_by_id("epicenter").effects_for(CardEnums.Trigger.ON_PLAY)[0]
	_assert.call(
		(
			CardEffectResolver.eligible_target(amphora, effect)
			and not CardEffectResolver.eligible_target(plain_unit, effect)
		),
		"余砂を持つ駒だけが対象に選べる"
	)
	mixed.cast_spell(A, 0, {"side": A, "slot": 0})
	_assert.call(
		mixed.board[A][0] == plain_unit and mixed.board[A][2] == null, "余砂を持たない駒を指定しても、余砂を持つ駒が選ばれる"
	)


func _test_epicenter_counts_granted_death_effect() -> void:
	var state := _new_match(["epicenter"])
	var carrier := _place(state, A, "sand", 0)
	var source := _place(state, A, "sand", 1)
	carrier.grant_effect(
		CardLibrary.find_by_id("amphora").effects_for(CardEnums.Trigger.ON_DEATH)[0]
	)
	carrier.attack = 1
	var before := source.total_sand()
	_assert.call(state.can_cast(A, 0), "導火線で与えた余砂も数える")
	state.cast_spell(A, 0, {"side": A, "slot": 0})
	_assert.call(source.total_sand() == before + 2, "与えた余砂も2回働く")


func _test_cpu_values() -> void:
	var cpu := CardCpuStrategy.new()
	var full := _new_match(["middle", "phase"])
	full.max_mana[A] = MatchState.MAX_MANA
	var building := _new_match(["middle", "phase"])
	building.max_mana[A] = 5
	var clockwork := CardLibrary.find_by_id("clockwork")
	_assert.call(
		cpu._card_value(full, A, clockwork) > cpu._card_value(building, A, clockwork),
		"最大マナが7に届いているほどクロックワークの値打ちが高い"
	)
	var sluice := CardLibrary.find_by_id("sluice")
	_assert.call(
		cpu._card_value(full, A, sluice) > CardCpuStrategy._lifetime_damage(sluice),
		"スルースは持ち越しぶんの値打ちが乗る"
	)
	var vision := CardLibrary.find_by_id("vision")
	var rich := _new_match([])
	_place(rich, B, "sand", 0)
	for i in 10:
		rich.graveyard[A].append(CardLibrary.find_by_id("sand"))
	var poor := _new_match([])
	_place(poor, B, "sand", 0)
	_assert.call(
		cpu._card_value(rich, A, vision) > cpu._card_value(poor, A, vision),
		"墓地が10枚たまっているときだけヴィジョンの除去が見積もられる"
	)
