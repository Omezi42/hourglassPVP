extends RefCounted
## 今日の1問(GameDesign.md 24章 / Architecture.md 10.12.2節)の検証。
##
## **同梱した各日の問題が、問題集の正解手順で実際に解けることまで確かめる。**
## `.tres` は `schedule.py` が書き出すため、写し間違い(駒の並び・マナ)があれば解けなくなる。

const Forge := preload("res://tools/shorts/puzzle_solver.gd")
const BOOK_PATH := "res://tools/shorts/puzzles.json"
const LEDGER_PATH := "res://tools/shorts/schedule.json"
## 2026-09-27 15:00 UTC = 2026-09-28 0:00 JST。
const JST_MIDNIGHT := 1790521200

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_date_switches_at_jst_midnight()
	_test_every_daily_is_solvable()


func _test_date_switches_at_jst_midnight() -> void:
	_assert.call(DailyPuzzle.date_key(JST_MIDNIGHT - 1) == "2026-09-27", "before JST midnight")
	_assert.call(DailyPuzzle.date_key(JST_MIDNIGHT) == "2026-09-28", "at JST midnight")


func _test_every_daily_is_solvable() -> void:
	var book: Array = _read(BOOK_PATH)
	var count := 0
	for entry in _read(LEDGER_PATH):
		if String(entry["kind"]) != "puzzle":
			continue
		var date := String(entry["date"])
		var stage := DailyPuzzle.for_date(date)
		_assert.call(stage != null, "daily puzzle should be bundled: " + date)
		if stage == null:
			continue
		count += 1
		_assert.call(DailyPuzzle.is_daily(stage), "daily puzzle id should be marked: " + date)
		var answer: Array = book[int(entry["id"]) - 1]["solution"]
		_assert.call(_solves(stage, answer), "daily puzzle should be solvable: " + date)
	_assert.call(count > 0, "at least one daily puzzle should be bundled")


func _solves(stage: PuzzleStageData, answer: Array) -> bool:
	var state := Forge.build(stage)
	for action in answer:
		if not MatchAction.apply(state, _whole_numbers(action)):
			state.free()
			return false
	var solved := int(state.hp[MatchState.Side.B]) <= 0
	state.free()
	return solved


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
