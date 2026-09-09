class_name PuzzleSolver
extends RefCounted
## パズルの局面を組み立て、記録した手順で実際に相手のHPが0になるかを確かめる。
##
## **リーサルパズル(GameDesign.md 24章)とソロモードのパズル型(同27章)で共有する。**
## どちらも「用意した解答が本当に通るか」を出荷前に見るためのもので、片方だけに置くと
## もう片方が「データが読めること」しか確かめられなくなる。


## `CardMatchPuzzle._apply()` と同じ形の局面を、UIを起こさずに作る。
static func build(stage: PuzzleStageData) -> MatchState:
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
		state.hand[mine].append(CardLibrary.find_by_id(id))
	place(state, mine, stage.own_units)
	place(state, foe, stage.foe_units)
	return state


## 盤面へ駒を並べる。**出したターン扱いを解いて置く**(そのままだと反転も攻撃も
## できず、どの問題も解けない)。
static func place(state: MatchState, side: int, rows: Array[String]) -> void:
	var slots: Array = []
	slots.resize(MatchState.BOARD_SIZE)
	for i in rows.size():
		var parsed := PuzzleStageData.parse_unit(rows[i])
		if parsed.is_empty():
			continue
		var unit := CardInstance.new(parsed["card"])
		unit.health = int(parsed["health"])
		unit.attack = int(parsed["attack"])
		unit.summoned_this_turn = false
		slots[i] = unit
	state.board[side] = slots


## 手順を適用し、相手のHPが0以下になったかを返す。手は
## `["flip", slot]` / `["attack", slot, target]` / `["play", hand, slot]` /
## `["cast", hand]`(対象を取るなら `["cast", hand, side, slot]`)の4種。
static func solve(stage: PuzzleStageData, moves: Array) -> bool:
	var state := build(stage)
	var mine: int = MatchState.Side.A
	for move: Array in moves:
		match String(move[0]):
			"flip":
				state.flip(mine, int(move[1]))
			"attack":
				state.attack(mine, int(move[1]), int(move[2]))
			"play":
				state.play_card(mine, int(move[1]), int(move[2]))
			"cast":
				var target := {}
				if move.size() >= 4:
					target = {"side": int(move[2]), "slot": int(move[3])}
				state.cast_spell(mine, int(move[1]), target)
	var cleared: bool = int(state.hp[MatchState.other_side(mine)]) <= 0
	state.free()
	return cleared
