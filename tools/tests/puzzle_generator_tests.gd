extends RefCounted
## エンドレスモード(GameDesign.md 24章)の生成器を検証する。
##
## `PuzzleGenerator` は「先に正解の部品を決め、実際に `MatchState` で解けることを
## 検証してから出題する」方式を採る(Architecture.md 10.12.1節)。ここでは複数の
## シードで実際に生成し、**返ってきた問題が本当にその手順で解けること**・
## **1手だけでは解けないこと**・**分岐がおおむね一定数あること**を確かめる。
## データが読めることだけを見て終えると、届かない問題を出荷してしまう
## (`tools/tests/puzzle_mission_tests.gd` と同じ考え方)。

const SEED_COUNT := 20

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_generated_puzzles_are_solvable()
	_test_no_single_action_wins()
	_test_branching_target_is_usually_met()


## 生成器が返した手順どおりに指すと、実際に相手のHPが0以下になること。
func _test_generated_puzzles_are_solvable() -> void:
	for seed in range(1, SEED_COUNT + 1):
		var result := PuzzleGenerator.generate_for_test(seed)
		var stage: PuzzleStageData = result["stage"]
		_assert.call(
			stage.foe_hp > 0, "generated puzzle must leave the opponent alive: seed %d" % seed
		)
		_assert.call(
			_replay(stage, result["solution"]),
			"generated puzzle should be solvable: seed %d" % seed
		)


## 正解の部品を1つ欠くと解けないこと(=最初の1手だけでは仕留められないこと)を
## 確かめる。部品が1つしかない稀なケース(フォールバック等)は対象外。
func _test_no_single_action_wins() -> void:
	for seed in range(1, SEED_COUNT + 1):
		var result := PuzzleGenerator.generate_for_test(seed)
		var solution: Array = result["solution"]
		if solution.size() < 2:
			continue
		_assert.call(
			not _replay(result["stage"], [solution[0]]),
			"a single action alone should not reach lethal: seed %d" % seed
		)


## 1手目に選べる行動の数が、狙いどおりおおむね基準を満たしていること。
## 生成は確率的なため、**すべてのシードで基準を満たす**ことまでは求めない
## (基準に届かなかった場合は検証済みの問題をそのまま渡す設計のため。同節)。
func _test_branching_target_is_usually_met() -> void:
	var below_target := 0
	for seed in range(1, SEED_COUNT + 1):
		var result := PuzzleGenerator.generate_for_test(seed)
		if int(result["branching"]) < PuzzleGenerator.MIN_BRANCHING:
			below_target += 1
	_assert.call(
		below_target <= SEED_COUNT / 4,
		(
			"generated puzzles should usually meet the branching target (%d/%d fell short)"
			% [below_target, SEED_COUNT]
		)
	)


## 手順どおりに指して相手のHPが0以下になるかどうか。
func _replay(stage: PuzzleStageData, solution: Array) -> bool:
	var state := _build(stage)
	var mine: int = MatchState.Side.A
	var foe: int = MatchState.other_side(mine)
	for step: Dictionary in solution:
		match String(step["type"]):
			"flip":
				if not state.flip(mine, int(step["slot"])):
					state.free()
					return false
			"attack":
				if not state.attack(mine, int(step["slot"]), int(step["target_slot"])):
					state.free()
					return false
			"cast_id":
				if not _cast_by_id(state, mine, String(step["card_id"])):
					state.free()
					return false
	var cleared: bool = int(state.hp[foe]) <= 0
	state.free()
	return cleared


func _cast_by_id(state: MatchState, side: int, card_id: String) -> bool:
	var hand: Array = state.hand[side]
	for i in hand.size():
		var card: CardData = hand[i]
		if card.id == card_id:
			return state.cast_spell(side, i)
	return false


## `tools/tests/puzzle_mission_tests.gd` の `_build()`/`_place()` と同じ形の局面を作る。
func _build(stage: PuzzleStageData) -> MatchState:
	var state := MatchState.new()
	var deck := CardPresetDecks.basic()
	state.start_match(deck, deck, MatchState.Side.A, 1, false, false)
	var mine: int = MatchState.Side.A
	var foe: int = MatchState.other_side(mine)
	state.hp[mine] = stage.own_hp
	state.hp[foe] = stage.foe_hp
	state.max_mana[mine] = stage.mana
	state.mana[mine] = stage.mana
	state.hand[mine] = []
	for id in stage.hand_ids:
		var card := CardLibrary.find_by_id(id)
		if card != null:
			state.hand[mine].append(card)
	_place(state, mine, stage.own_units)
	_place(state, foe, stage.foe_units)
	return state


func _place(state: MatchState, side: int, rows: Array[String]) -> void:
	var slots: Array = []
	slots.resize(MatchState.BOARD_SIZE)
	for i in rows.size():
		if i >= MatchState.BOARD_SIZE:
			break
		var parsed := PuzzleStageData.parse_unit(rows[i])
		if parsed.is_empty():
			continue
		var unit := CardInstance.new(parsed["card"])
		unit.health = int(parsed["health"])
		unit.attack = int(parsed["attack"])
		unit.summoned_this_turn = false
		slots[i] = unit
	state.board[side] = slots
