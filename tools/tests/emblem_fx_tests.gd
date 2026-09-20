class_name EmblemFxTests
extends RefCounted
## 紋章の出どころ(GameDesign.md 9章 2026-09-21・Architecture.md 4.0節)の検証。
## `MatchState.effect_struck` / `effect_struck_many` が運ぶ `origin` が砂術・余砂
## それぞれで正しく届くこと、PULSE/RECALLが正しい効果で出ることを見る。
## `v5_rules_tests.gd` / `run_tests.gd` が1000行の上限に近いため別ファイルへ置く。

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_spell_strike_has_spell_origin()
	_test_death_trigger_has_death_origin()
	_test_draw_spell_emits_pulse()
	_test_return_to_hand_spell_emits_recall()
	_test_ally_wide_death_trigger_emits_descend_many()


## 砂術(砕砂)は盤面へ出ないため、`effect_struck` の出どころは SPELL になる。
func _test_spell_strike_has_spell_origin() -> void:
	var state := _state_with_spell("shatter")
	var side := MatchState.Side.A
	var foe := MatchState.Side.B
	state.board[foe][0] = CardInstance.new(CardLibrary.find_by_id("sand"))
	var origins: Array[int] = []
	state.effect_struck.connect(
		func(_ss: int, _sl: int, _ts: int, _tl: int, _style: int, origin: int) -> void:
			origins.append(origin)
	)
	_assert.call(state.cast_spell(side, 0, {"side": foe, "slot": 0}), "砕砂を撃てた")
	_assert.call(
		origins.size() == 1 and origins[0] == CardEnums.EffectOrigin.SPELL, "砂術の紋章はSPELLの出どころで飛ぶ"
	)
	state.free()


## 余砂(ダスト)が発火したとき、`source_slot` は砕けた枠のままで、
## 出どころはDEATHになる(駒は既に盤面から降りているため)。
func _test_death_trigger_has_death_origin() -> void:
	var state := _new_match()
	var side := MatchState.Side.A
	_force_play(state, side, "dust", 2)
	var hits: Array[Dictionary] = []
	state.effect_struck.connect(
		func(_ss: int, sl: int, _ts: int, _tl: int, _style: int, origin: int) -> void:
			hits.append({"slot": sl, "origin": origin})
	)
	state.destroy_unit(side, 2)
	_assert.call(hits.size() == 1, "余砂で紋章が1度飛ぶ")
	if hits.size() == 1:
		_assert.call(hits[0]["origin"] == CardEnums.EffectOrigin.DEATH, "余砂の出どころはDEATH")
		_assert.call(hits[0]["slot"] == 2, "出どころの枠は砕けた枠のまま")
	state.free()


## 対象を取らない砂術(砂の補給)は、飛ばずにその場で弾けるPULSEを出す。
func _test_draw_spell_emits_pulse() -> void:
	var state := _state_with_spell("refill")
	var side := MatchState.Side.A
	var styles: Array[int] = []
	state.effect_struck.connect(
		func(_ss: int, _sl: int, _ts: int, _tl: int, style: int, _origin: int) -> void:
			styles.append(style)
	)
	_assert.call(state.cast_spell(side, 0), "砂の補給を撃てた")
	_assert.call(
		styles.size() == 1 and styles[0] == CardEnums.EffectVisualStyle.PULSE,
		"対象を取らない砂術のドローはPULSEで出る"
	)
	state.free()


## 砂へ還すは、単体除去とは違うRECALLの型で紋章が飛ぶ。
func _test_return_to_hand_spell_emits_recall() -> void:
	var state := _state_with_spell("recall")
	var side := MatchState.Side.A
	var foe := MatchState.Side.B
	state.board[foe][0] = CardInstance.new(CardLibrary.find_by_id("sand"))
	var styles: Array[int] = []
	state.effect_struck.connect(
		func(_ss: int, _sl: int, _ts: int, _tl: int, style: int, _origin: int) -> void:
			styles.append(style)
	)
	_assert.call(state.cast_spell(side, 0, {"side": foe, "slot": 0}), "砂へ還すを撃てた")
	_assert.call(
		styles.size() == 1 and styles[0] == CardEnums.EffectVisualStyle.RECALL, "砂へ還すはRECALLの型で飛ぶ"
	)
	state.free()


## 味方全体を狙う恵与(レガシー)が余砂から発火した場合も、単体版ではなく
## `effect_struck_many` を DESCEND で1度だけ出す(GameDesign.md 9章)。
func _test_ally_wide_death_trigger_emits_descend_many() -> void:
	var state := _new_match()
	var side := MatchState.Side.A
	_force_play(state, side, "legacy", 0)
	_force_play(state, side, "sand", 1)
	var many_calls: Array[Dictionary] = []
	state.effect_struck_many.connect(
		func(_ss: int, _sl: int, targets: Array, style: int, origin: int) -> void:
			many_calls.append({"targets": targets, "style": style, "origin": origin})
	)
	state.destroy_unit(side, 0)
	_assert.call(many_calls.size() == 1, "レガシーの余砂はeffect_struck_manyを1度だけ出す")
	if many_calls.size() == 1:
		var call: Dictionary = many_calls[0]
		_assert.call(call["style"] == CardEnums.EffectVisualStyle.DESCEND, "味方全体への恵与はDESCEND")
		_assert.call(call["origin"] == CardEnums.EffectOrigin.DEATH, "出どころはDEATH")
		var targets: Array = call["targets"]
		_assert.call(targets.size() == 1, "残っている味方1体だけが対象")
	state.free()


func _new_match(deck_a_id: String = "sand", deck_b_id: String = "sand") -> MatchState:
	var state := MatchState.new()
	state.start_match(_deck_of(deck_a_id), _deck_of(deck_b_id), MatchState.Side.A, 12345)
	return state


## 検証したい場面を直接作るため、手札の先頭へカードを差し込んでから出す。
func _force_play(state: MatchState, side: int, id: String, slot: int) -> CardInstance:
	var previous_turn: int = state.current_turn
	state.current_turn = side
	state.hand[side].push_front(CardLibrary.find_by_id(id))
	state.mana[side] = MatchState.MAX_MANA
	state.play_card(side, 0, slot)
	state.current_turn = previous_turn
	return state.board[side][slot]


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
