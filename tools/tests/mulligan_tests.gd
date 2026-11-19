extends RefCounted
## マリガン(引き直し)の検証。v5_rules_tests.gd が1000行の上限に近づいたため切り出した。

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_mulligan_waits_for_both_sides()
	_test_mulligan_never_returns_the_same_cards()
	_test_mulligan_is_order_independent()
	_test_mulligan_match_replays_from_the_record()


## 同じカードを30枚並べた検証用デッキ。
func _deck_of(id: String) -> Array:
	var cards: Array = []
	for i in MatchState.DECK_SIZE:
		cards.append(CardLibrary.find_by_id(id))
	return cards


## 30種すべてを1枚ずつ並べた検証用デッキ(引き直したカードを見分けるため)。
func _mixed_deck() -> Array:
	var cards: Array = []
	for card in CardLibrary.all_cards():
		cards.append(card)
		if cards.size() >= MatchState.DECK_SIZE:
			break
	return cards


func _new_mulligan_match() -> MatchState:
	var state := MatchState.new()
	state.start_match(_mixed_deck(), _mixed_deck(), MatchState.Side.A, 777, true, true)
	return state


func _test_mulligan_waits_for_both_sides() -> void:
	var state := _new_mulligan_match()
	_assert.call(state.mulligan_pending, "the match should wait for the mulligan")
	_assert.call(state.turn_count == 0, "no turn should begin before the mulligan is settled")
	_assert.call(
		state.hand[MatchState.Side.A].size() == MatchState.FIRST_PLAYER_HAND,
		"the first player should hold the opening hand during the mulligan"
	)
	state.mulligan(MatchState.Side.A, [0])
	_assert.call(state.mulligan_pending, "one side alone should not settle the mulligan")
	_assert.call(state.turn_count == 0, "the turn should not begin until both sides choose")
	state.mulligan(MatchState.Side.B, [])
	_assert.call(not state.mulligan_pending, "both choices should settle the mulligan")
	_assert.call(state.turn_count == 1, "the first turn should begin once both sides choose")
	_assert.call(
		state.hand[MatchState.Side.A].size() == MatchState.FIRST_PLAYER_HAND + 1,
		"the first player should draw for the turn after the mulligan"
	)


func _test_mulligan_never_returns_the_same_cards() -> void:
	var state := _new_mulligan_match()
	var before: Array = state.hand[MatchState.Side.A].duplicate()
	var deck_size: int = state.deck[MatchState.Side.A].size()
	var indices: Array = []
	for i in before.size():
		indices.append(i)
	state.mulligan(MatchState.Side.A, indices)
	state.mulligan(MatchState.Side.B, [])
	var after: Array = state.hand[MatchState.Side.A]
	_assert.call(
		after.size() == before.size() + 1,
		"a full mulligan should keep the hand size (plus the turn draw)"
	)
	_assert.call(
		state.deck[MatchState.Side.A].size() == deck_size - 1,
		"the returned cards should go back into the deck"
	)
	for card in before:
		_assert.call(
			not after.has(card), "a mulliganed card should not come straight back to the hand"
		)


## 届いた順に適用すると山札の切り直しの順序が変わり、同じ対局が再現できなくなる。
func _test_mulligan_is_order_independent() -> void:
	var first := _new_mulligan_match()
	MatchAction.apply(first, MatchAction.mulligan(MatchState.Side.A, [0, 1]))
	MatchAction.apply(first, MatchAction.mulligan(MatchState.Side.B, [2]))

	var second := _new_mulligan_match()
	MatchAction.apply(second, MatchAction.mulligan(MatchState.Side.B, [2]))
	MatchAction.apply(second, MatchAction.mulligan(MatchState.Side.A, [0, 1]))

	for side in [MatchState.Side.A, MatchState.Side.B]:
		var a: Array = first.hand[side]
		var b: Array = second.hand[side]
		_assert.call(a.size() == b.size(), "both arrival orders should deal the same hand size")
		for i in a.size():
			_assert.call(a[i] == b[i], "both arrival orders should deal the same hand")
		var deck_a: Array = first.deck[side]
		var deck_b: Array = second.deck[side]
		for i in deck_a.size():
			_assert.call(deck_a[i] == deck_b[i], "both arrival orders should leave the same deck")


## 棋譜にマリガンが含まれていても、初期状態から手を並べ直せば同じ対局になる
## (リプレイ・観戦はこの経路で局面を作る)。
func _test_mulligan_match_replays_from_the_record() -> void:
	var deck_a := _deck_of("sand")
	var deck_b := _deck_of("sword")
	var seed_value := 20260828
	var cpu := CardCpuStrategy.new()

	var live := MatchState.new()
	live.start_match(deck_a, deck_b, MatchState.Side.A, seed_value, MatchState.COIN_ENABLED, true)
	var recorded: Array = []
	for side in [MatchState.Side.B, MatchState.Side.A]:
		var choice := MatchAction.mulligan(side, cpu.choose_mulligan(live, side))
		recorded.append(choice)
		MatchAction.apply(live, choice)
	_assert.call(not live.mulligan_pending, "both mulligans should settle the opening")
	var guard := 0
	while not live.is_match_over() and guard < 400:
		guard += 1
		var action := cpu.choose_action(live, live.current_turn)
		recorded.append(action)
		MatchAction.apply(live, action)
	_assert.call(live.is_match_over(), "the recorded match should have reached an end")
	_assert.call(
		MatchAction.contains_mulligan(recorded), "the record should be detected as a mulligan game"
	)

	var replay := MatchState.new()
	replay.start_match(
		deck_a,
		deck_b,
		MatchState.Side.A,
		seed_value,
		MatchState.COIN_ENABLED,
		MatchAction.contains_mulligan(recorded)
	)
	for action in recorded:
		MatchAction.apply(replay, action)
	_assert.call(
		(
			replay.hp[MatchState.Side.A] == live.hp[MatchState.Side.A]
			and replay.hp[MatchState.Side.B] == live.hp[MatchState.Side.B]
		),
		"replaying a mulligan game should reach the same hp"
	)
	_assert.call(replay.winner == live.winner, "replaying a mulligan game should reach the winner")
