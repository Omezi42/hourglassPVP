extends RefCounted
## 能力の実演の台本(`CardEffectPlan`)の検証。Architecture.md 4.0.4節に対応する。
## 台本はカードから自動で組むため、カードを足したときに反則の手を指す実演が混ざらないかをここで見張る。

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_every_card_plays_only_legal_moves()
	_test_every_card_has_at_least_one_step()
	_test_keyword_dict_demo_uses_the_plainest_card()


func _test_every_card_plays_only_legal_moves() -> void:
	for card in CardLibrary.all_cards():
		for kind in CardEffectPlan.kinds(card):
			var state := _new_match()
			var actions := CardEffectPlan.stage(state, MatchState.Side.A, card, kind)
			var legal := true
			for action in actions:
				if not MatchAction.apply(state, action):
					legal = false
					break
			_assert.call(legal, "実演の台本は合法手だけを指す: %s 段%d" % [card.id, kind])
			state.free()


func _test_every_card_has_at_least_one_step() -> void:
	for card in CardLibrary.all_cards():
		_assert.call(not CardEffectPlan.kinds(card).is_empty(), "どのカードにも実演の段がある: %s" % card.id)


func _test_keyword_dict_demo_uses_the_plainest_card() -> void:
	var entry := KeywordEntries.keyword_entry(CardEnums.Keyword.GUARD)
	var demo := KeywordEntries.demo(entry)
	_assert.call(not demo.is_empty(), "守護の項目には実演がある")
	if demo.is_empty():
		return
	var card: CardData = demo["card"]
	_assert.call(card.has_keyword(CardEnums.Keyword.GUARD), "辞書の実演は、その語を持つ砂時計で見せる")
	_assert.call(int(demo["kind"]) == CardEffectPlan.Kind.GUARD, "辞書の実演は、その語の段だけを見せる")


func _new_match() -> MatchState:
	var state := MatchState.new()
	state.start_match(CardPresetDecks.basic(), CardPresetDecks.basic(), MatchState.Side.A, 1)
	return state
