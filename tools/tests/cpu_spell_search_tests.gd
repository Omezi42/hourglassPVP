extends RefCounted
## 砂術の1手読み(`CardCpuSpellSearch`。GameDesign.md 13章・Architecture.md 8章)の検証。

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_flips_own_unit_that_gains_from_it()
	_test_waits_to_flip_until_the_unit_has_attacked()
	_test_does_not_cast_targeted_spell_without_targets()
	_test_lookahead_does_not_change_the_board()


func _card(id: String) -> CardData:
	return CardLibrary.find_by_id(id)


## 手札を `hand_ids` だけにし、自分の場の枠0へ攻撃力が体力を上回る駒を置いた対局。
func _setup(hand_ids: Array, can_attack: bool) -> MatchState:
	var deck: Array = []
	for i in MatchState.DECK_SIZE:
		deck.append(_card("sand"))
	var state := MatchState.new()
	state.start_match(deck, deck.duplicate(), MatchState.Side.A, 12345)
	state.mulligan_pending = false
	state.current_turn = MatchState.Side.A
	var unit := CardInstance.new(_card("sand"))
	unit.drop_sand(3)
	unit.summoned_this_turn = not can_attack
	state.board[MatchState.Side.A][0] = unit
	var hand: Array = []
	for id in hand_ids:
		hand.append(_card(id))
	state.hand[MatchState.Side.A] = hand
	state.mana[MatchState.Side.A] = MatchState.MAX_MANA
	return state


## 逆さ砂(自分の砂時計1体を反転)は、攻撃力が体力を上回った味方へ撃つ。
## 13章が「CPUが使いこなせない」としていた自分の砂時計を対象に取る砂術の基本形。
func _test_flips_own_unit_that_gains_from_it() -> void:
	var state := _setup(["turn"], false)
	var action := CardCpuStrategy.new()._choose_play(state, MatchState.Side.A)
	_assert.call(action.get("type", "") == "cast", "lookahead should cast 逆さ砂 on a top-heavy ally")
	_assert.call(
		action.get("target", {}).get("slot", -1) == 0, "逆さ砂 should target the top-heavy ally"
	)


## まだ攻撃できる味方へ撃つ逆さ砂は、攻撃を済ませてから撃つ(攻撃力を先に使う)。
func _test_waits_to_flip_until_the_unit_has_attacked() -> void:
	var state := _setup(["turn"], true)
	var cpu := CardCpuStrategy.new()
	_assert.call(
		cpu._choose_play(state, MatchState.Side.A).is_empty(),
		"逆さ砂 on a ready attacker should wait until after attacking"
	)
	_assert.call(
		cpu._choose_play(state, MatchState.Side.A, true).get("type", "") == "cast",
		"逆さ砂 should be cast in the after-attack pass"
	)


## 相手の砂時計を対象に取る砂術(封砂)は、相手の場が空なら撃たない。
func _test_does_not_cast_targeted_spell_without_targets() -> void:
	var state := _setup(["seal"], false)
	_assert.call(
		CardCpuStrategy.new()._choose_play(state, MatchState.Side.A).is_empty(),
		"a targeted spell with no enemy should not be cast"
	)


## 1手読みは写しへ撃つだけで、本物の盤面・手札・マナを変えない。
func _test_lookahead_does_not_change_the_board() -> void:
	var state := _setup(["turn", "shot"], false)
	var unit: CardInstance = state.board[MatchState.Side.A][0]
	var health := unit.health
	var cpu := CardCpuStrategy.new()
	for index in 2:
		cpu._spell_cast(state, MatchState.Side.A, index)
	_assert.call(
		(
			unit.health == health
			and state.hand[MatchState.Side.A].size() == 2
			and state.mana[MatchState.Side.A] == MatchState.MAX_MANA
		),
		"the lookahead must not touch the real match"
	)
