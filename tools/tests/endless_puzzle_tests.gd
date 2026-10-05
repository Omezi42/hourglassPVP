extends RefCounted
## エンドレス(GameDesign.md 24章 / Architecture.md 10.12.1節)の問題集の検証。
##
## **同梱した全問が、問題集の正解手順で実際に解けることまで確かめる。**
## データが読めることだけを見て終えると、届かない問題を出荷してしまう。

const Solver := preload("res://tools/shorts/puzzle_solver.gd")
const DAILY_BOOK_PATH := "res://tools/shorts/puzzles.json"
## 問題集はこれ以上の問数を同梱する。GameDesign.md 24章の「数百問」へ増やすまでの下限(TODO.md)。
const MIN_BOOK_SIZE := 15

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_book_is_large_enough()
	_test_every_puzzle_is_solvable()
	_test_no_overlap_with_daily_book()
	_test_next_avoids_recent()


func _test_book_is_large_enough() -> void:
	var size := EndlessPuzzles.book().size()
	_assert.call(size >= MIN_BOOK_SIZE, "endless book should hold enough puzzles: %d" % size)


func _test_every_puzzle_is_solvable() -> void:
	var book := EndlessPuzzles.book()
	for i in book.size():
		var stage := EndlessPuzzles.stage_at(i)
		_assert.call(stage.foe_hp > 0, "endless puzzle should leave the foe alive: #%d" % i)
		_assert.call(
			_solves(stage, book[i]["solution"]), "endless puzzle should be solvable: #%d" % i
		)


## エンドレスで今日の1問の答えを先に知ってしまわないこと。
func _test_no_overlap_with_daily_book() -> void:
	var daily := {}
	for entry in _read(DAILY_BOOK_PATH):
		daily[_signature(entry["stage"])] = true
	var seen := {}
	for entry in EndlessPuzzles.book():
		var key := _signature(entry["stage"])
		_assert.call(not daily.has(key), "endless puzzle should not be a daily puzzle: " + key)
		_assert.call(not seen.has(key), "endless puzzle should not repeat in the book: " + key)
		seen[key] = true


func _test_next_avoids_recent() -> void:
	var limit := mini(EndlessPuzzles.RECENT_LIMIT, EndlessPuzzles.book().size() / 2)
	var shown: Array[String] = []
	for i in limit:
		var stage := EndlessPuzzles.next()
		var key := _signature(
			{
				"mana": stage.mana,
				"hand_ids": stage.hand_ids,
				"own_units": stage.own_units,
				"foe_units": stage.foe_units,
			}
		)
		_assert.call(not shown.has(key), "endless should not repeat a recent puzzle")
		shown.append(key)


func _solves(stage: PuzzleStageData, answer: Array) -> bool:
	var state := Solver.build(stage)
	for action in answer:
		if not MatchAction.apply(state, _whole_numbers(action)):
			state.free()
			return false
	var solved := int(state.hp[MatchState.Side.B]) <= 0
	state.free()
	return solved


func _signature(stage: Dictionary) -> String:
	return JSON.stringify(
		[int(stage["mana"]), stage["hand_ids"], stage["own_units"], stage["foe_units"]]
	)


## JSONを通ると整数が小数になるため、手の番号を整数へ戻す。
func _whole_numbers(value: Variant) -> Variant:
	if value is float:
		return int(value)
	if value is Dictionary:
		var copy := {}
		for key in value:
			copy[key] = _whole_numbers(value[key])
		return copy
	return value


func _read(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Array else []
