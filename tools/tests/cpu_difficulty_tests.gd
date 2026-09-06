extends RefCounted
## CPU戦の思考レベル(GameDesign.md 13章「CPU戦の思考レベル」)の検証。
## v5_rules_tests.gd が大きいため別ファイルへ切り出している。

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_all_difficulties_finish_a_match()
	_test_beginner_never_flips_or_uses_flip_right()
	_test_expert_avoids_a_lethal_flip()


func _card(id: String) -> CardData:
	return CardLibrary.find_by_id(id)


func _deck_of(id: String) -> Array:
	var cards: Array = []
	for i in MatchState.DECK_SIZE:
		cards.append(_card(id))
	return cards


func _new_match(deck_a_id: String = "sand", deck_b_id: String = "sand") -> MatchState:
	var state := MatchState.new()
	state.start_match(_deck_of(deck_a_id), _deck_of(deck_b_id), MatchState.Side.A, 12345)
	return state


## 検証したい場面を直接作るため、手札の先頭へカードを差し込んでから出す。
func _force_play(state: MatchState, side: int, id: String, slot: int) -> CardInstance:
	var previous_turn: int = state.current_turn
	state.current_turn = side
	state.hand[side].push_front(_card(id))
	state.mana[side] = MatchState.MAX_MANA
	state.play_card(side, 0, slot)
	state.current_turn = previous_turn
	return state.board[side][slot]


## 3段階どれで自己対戦させても、貪欲法の骨格が壊れて手詰まりにならないことを確認する。
func _test_all_difficulties_finish_a_match() -> void:
	var difficulties: Array = [
		CardCpuStrategy.Difficulty.BEGINNER,
		CardCpuStrategy.Difficulty.NORMAL,
		CardCpuStrategy.Difficulty.EXPERT,
	]
	for difficulty in difficulties:
		var state := _new_match("sand", "sword")
		var cpu := CardCpuStrategy.new()
		cpu.difficulty = difficulty
		var turns := 0
		while not state.is_match_over() and turns < MatchState.MAX_TURNS + 5:
			cpu.take_turn(state, state.current_turn)
			turns += 1
		_assert.call(state.is_match_over(), "difficulty %d should still reach an end" % difficulty)


## 初級は貪欲法(生涯ダメージの比較)を一切通らないため、対局を通して
## 反転・反転権が一度も選ばれない(GameDesign.md 13章)。
func _test_beginner_never_flips_or_uses_flip_right() -> void:
	var state := _new_match("sand", "sword")
	var cpu := CardCpuStrategy.new()
	cpu.difficulty = CardCpuStrategy.Difficulty.BEGINNER
	var turns := 0
	var saw_flip := false
	while not state.is_match_over() and turns < MatchState.MAX_TURNS + 5:
		var performed: Array = cpu.take_turn(state, state.current_turn)
		for action in performed:
			if str(action.get("type", "")) in ["flip", "flip_right"]:
				saw_flip = true
		turns += 1
	_assert.call(not saw_flip, "beginner should never flip or use flip right")


## 上級は、反転した結果いま相手が持っている攻撃力でその場で仕留められるようになる
## 反転を避ける(GameDesign.md 13章)。中級はこの危険を見ないため同じ場面でも反転する。
func _test_expert_avoids_a_lethal_flip() -> void:
	var state := _new_match()
	var mine: CardInstance = _force_play(state, MatchState.Side.A, "sand", 0)
	mine.summoned_this_turn = false
	mine.drop_sand(3)  # total 5: health=2 / attack=3 → 反転で health=3 / attack=2(得な反転)
	var foe: CardInstance = _force_play(state, MatchState.Side.B, "sword", 0)
	foe.drop_sand(3)  # total 6: health=3 / attack=3(反転後の体力3を仕留められる攻撃力)

	var expert := CardCpuStrategy.new()
	expert.difficulty = CardCpuStrategy.Difficulty.EXPERT
	var risky: Dictionary = expert._choose_flip(state, MatchState.Side.A)
	_assert.call(
		risky.is_empty(),
		"expert should refuse a flip that would leave the unit dead to the foe's attack"
	)

	var normal := CardCpuStrategy.new()
	var accepted: Dictionary = normal._choose_flip(state, MatchState.Side.A)
	_assert.call(
		not accepted.is_empty(), "normal should still take the flip (the risk check is expert-only)"
	)
