extends RefCounted
## リーサルパズル(GameDesign.md 24章)とデイリーミッション(同23章)の検証。
##
## **パズルは「解ける」ことまで確かめる。**データだけを読んで終えると、
## 出題した手順では届かない問題を出荷してしまう(いちばん起きてほしくない壊れ方)。

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_stages_load()
	_test_every_stage_is_solvable()
	_test_missions_are_stable_for_a_day()
	_test_progress_needs_ten_moves()
	_test_claim_needs_completion()


## 問題そのものが読めること。カードidの打ち間違いはここで出る。
func _test_stages_load() -> void:
	var stages := PuzzleLibrary.all_stages()
	_assert.call(stages.size() >= 5, "at least five puzzle stages should exist")
	for stage in stages:
		_assert.call(not stage.id.is_empty(), "a stage must have an id")
		_assert.call(stage.foe_hp > 0, "a stage must leave the opponent alive at the start")
		for row in stage.own_units + stage.foe_units:
			_assert.call(
				not PuzzleStageData.parse_unit(row).is_empty(), "unit row must parse: " + row
			)
		for id in stage.hand_ids:
			_assert.call(CardLibrary.find_by_id(id) != null, "hand card must exist: " + id)


## 用意した手順で相手のHPが0になること。手順は問題ごとの「解答」にあたる。
func _test_every_stage_is_solvable() -> void:
	var answers := {
		"stage_1": [["flip", 0], ["attack", 0, -1]],
		"stage_2": [["attack", 0, 0], ["attack", 1, -1]],
		"stage_3": [["attack", 0, 0]],
		"stage_4": [["play", 0, 0], ["play", 0, 1], ["attack", 0, -1], ["attack", 1, -1]],
		"stage_5": [["cast", 0], ["attack", 0, -1], ["cast", 0], ["cast", 0]],
	}
	for stage in PuzzleLibrary.all_stages():
		if not answers.has(stage.id):
			_assert.call(false, "no answer recorded for " + stage.id)
			continue
		_assert.call(_solve(stage, answers[stage.id]), "stage should be solvable: " + stage.id)


func _solve(stage: PuzzleStageData, moves: Array) -> bool:
	var state := _build(stage)
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
				state.cast_spell(mine, int(move[1]))
	var cleared: bool = int(state.hp[MatchState.other_side(mine)]) <= 0
	state.free()
	return cleared


## `CardMatchPuzzle._apply()` と同じ形の局面を、UIを起こさずに作る。
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
		state.hand[mine].append(CardLibrary.find_by_id(id))
	_place(state, mine, stage.own_units)
	_place(state, foe, stage.foe_units)
	return state


func _place(state: MatchState, side: int, rows: Array[String]) -> void:
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


## 同じ日なら何度読んでも同じ3件が並ぶ(乱数で選ぶと起動のたびに変わる)。
func _test_missions_are_stable_for_a_day() -> void:
	DailyMissionService.reset_for_test()
	var first := DailyMissionService.missions("uid-a")
	var second := DailyMissionService.missions("uid-a")
	_assert.call(first.size() == DailyMissionData.DAILY_COUNT, "three missions should be offered")
	var ids: Array = []
	for row in first:
		ids.append(row["id"])
	_assert.call(ids.size() == 3 and ids[0] != ids[1] and ids[1] != ids[2], "missions must differ")
	for i in first.size():
		_assert.call(first[i]["id"] == second[i]["id"], "the same day must offer the same missions")


## 10手に満たない対局は数えない(GameDesign.md 23章)。
func _test_progress_needs_ten_moves() -> void:
	DailyMissionService.reset_for_test()
	var id := _mission_id_for(DailyMissionData.Metric.MATCH)
	if id.is_empty():
		return
	DailyMissionService.watch(_dummy_state(), MatchState.Side.A)
	DailyMissionService.commit("uid-a", true, 9)
	_assert.call(_progress("uid-a", id) == 0, "a short match must not count")
	DailyMissionService.watch(_dummy_state(), MatchState.Side.A)
	DailyMissionService.commit("uid-a", true, 10)
	_assert.call(_progress("uid-a", id) == 1, "a full match must count once")


## 達成していない課題は受け取れない。
func _test_claim_needs_completion() -> void:
	DailyMissionService.reset_for_test()
	var rows := DailyMissionService.missions("uid-a")
	_assert.call(
		not DailyMissionService.claim("uid-a", String(rows[0]["id"])), "unfinished claim fails"
	)
	_assert.call(not DailyMissionService.claim("uid-a", "no-such-mission"), "unknown claim fails")


func _mission_id_for(metric: int) -> String:
	for row in DailyMissionService.missions("uid-a"):
		if int(row["metric"]) == metric:
			return String(row["id"])
	return ""


func _progress(uid: String, id: String) -> int:
	for row in DailyMissionService.missions(uid):
		if String(row["id"]) == id:
			return int(row["progress"])
	return -1


## 進捗を数えるためだけの空の対局。シグナルの接続先が要るだけで、手は指さない。
func _dummy_state() -> MatchState:
	var state := MatchState.new()
	var deck := CardPresetDecks.basic()
	state.start_match(deck, deck, MatchState.Side.A, 1, false, false)
	return state
