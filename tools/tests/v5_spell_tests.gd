class_name V5SpellTests
extends RefCounted
## 砂術(GameDesign.md 6章)の検証。盤面へ出ないカードという型が、
## 既存の解決経路(トリガー×ターゲット×エフェクト)へ正しく乗っているかを見る。

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_pool_has_twelve_spells()
	_test_spells_cannot_be_played_onto_the_board()
	_test_a_spell_needs_no_empty_slot()
	_test_a_spell_goes_to_the_graveyard()
	_test_return_to_hand_does_not_trigger_on_death()
	_test_cast_travels_through_match_action()


## 基本セットは砂時計58種+砂術12種=70枚(GameDesign.md 8章)。
func _test_pool_has_twelve_spells() -> void:
	var spells: Array = []
	for card in CardLibrary.all_cards():
		if card.is_spell:
			spells.append(card)
	_assert.call(spells.size() == 12, "砂術は12種(%d)" % spells.size())
	_assert.call(CardLibrary.all_cards().size() == 70, "基本セットは70枚")
	for card in spells:
		_assert.call(card.keywords.is_empty(), "砂術はキーワードを持たない: " + card.id)
		_assert.call(not card.cannot_attack, "砂術は攻撃の制約を持たない: " + card.id)


## 砂術は play_card() の経路へ入れない。空き枠を要求する条件が緩まないようにするため。
func _test_spells_cannot_be_played_onto_the_board() -> void:
	var state := _state_with_spell("shot")
	_assert.call(not state.can_play(MatchState.Side.A, 0), "砂術は出せない")
	_assert.call(not state.play_card(MatchState.Side.A, 0, 0), "砂術は枠へ置けない")
	_assert.call(state.board[MatchState.Side.A][0] == null, "枠は空のまま")
	state.free()


## 盤面が埋まっていても撃てる(GameDesign.md 6章)。
func _test_a_spell_needs_no_empty_slot() -> void:
	var state := _state_with_spell("shot")
	var side := MatchState.Side.A
	var filler := CardLibrary.find_by_id("mote")
	for slot in MatchState.BOARD_SIZE:
		state.board[side][slot] = CardInstance.new(filler)
	_assert.call(state.can_cast(side, 0), "枠が埋まっていても撃てる")
	var before: int = state.hp[MatchState.Side.B]
	_assert.call(state.cast_spell(side, 0), "砂術を撃てた")
	_assert.call(state.hp[MatchState.Side.B] == before - 2, "本体へ2ダメージ")
	state.free()


func _test_a_spell_goes_to_the_graveyard() -> void:
	var state := _state_with_spell("refill")
	var side := MatchState.Side.A
	var hand_before: int = state.hand[side].size()
	_assert.call(state.cast_spell(side, 0), "砂術を撃てた")
	# 撃った1枚が減り、2枚引く。
	_assert.call(state.hand[side].size() == hand_before + 1, "手札が1枚増える")
	_assert.call(state.graveyard[side].size() == 1, "墓地へ積まれる")
	_assert.call(state.graveyard[side][0].id == "refill", "積まれたのは撃った砂術")
	state.free()


## 手札へ戻すのは破壊ではないため、余砂は発火しない(Architecture.md 3.1.1節)。
func _test_return_to_hand_does_not_trigger_on_death() -> void:
	var state := _state_with_spell("recall")
	var side := MatchState.Side.A
	var foe := MatchState.Side.B
	# ダスト(余砂:相手プレイヤーに2ダメージ)を戻す。発火していればAのHPが減る。
	state.board[foe][0] = CardInstance.new(CardLibrary.find_by_id("dust"))
	var hp_before: int = state.hp[side]
	var foe_hand: int = state.hand[foe].size()
	_assert.call(state.cast_spell(side, 0, {"side": foe, "slot": 0}), "砂へ還すを撃てた")
	_assert.call(state.board[foe][0] == null, "盤面から消える")
	_assert.call(state.hand[foe].size() == foe_hand + 1, "持ち主の手札へ戻る")
	_assert.call(state.hand[foe].back().id == "dust", "戻ったのはその駒")
	_assert.call(state.hp[side] == hp_before, "余砂は発火しない")
	state.free()


## 自分の手・CPU・オンライン・リプレイが同じ経路を通ること。
func _test_cast_travels_through_match_action() -> void:
	var state := _state_with_spell("shot")
	var before: int = state.hp[MatchState.Side.B]
	var action := MatchAction.cast(MatchState.Side.A, 0)
	_assert.call(MatchAction.apply(state, action), "cast を適用できた")
	_assert.call(state.hp[MatchState.Side.B] == before - 2, "効果が起きた")
	state.free()


## 手札の先頭がその砂術になっている対局を作る。
func _state_with_spell(id: String) -> MatchState:
	var state := MatchState.new()
	var deck := _deck_of("sand")
	state.start_match(deck, _deck_of("sand"), MatchState.Side.A, 12345)
	var side := MatchState.Side.A
	state.hand[side].insert(0, CardLibrary.find_by_id(id))
	state.mana[side] = MatchState.MAX_MANA
	state.max_mana[side] = MatchState.MAX_MANA
	return state


func _deck_of(id: String) -> Array:
	var card := CardLibrary.find_by_id(id)
	var deck: Array = []
	for i in MatchState.DECK_SIZE:
		deck.append(card)
	return deck
