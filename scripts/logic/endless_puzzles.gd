class_name EndlessPuzzles
extends RefCounted
## エンドレス(GameDesign.md 24章)の出題。同梱の問題集からランダムに1問を選ぶ。
## 問題集は手元で総当たりにかけて難しさを確かめたもので、その場では作らない(Architecture.md 10.12.1節)。

const BOOK_PATH := "res://data/endless_puzzles.json"
const STAGE_ID := "endless"
const TITLE := "エンドレス"
## 直前に出したこの数の問題は選ばない(問題集がこれより小さければ半分まで)。
const RECENT_LIMIT := 50

static var _book: Array = []
static var _recent: Array[int] = []


## 問題集の全問(`stage` / `solution` / `metrics` の Dictionary)。
static func book() -> Array:
	if _book.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BOOK_PATH))
		if parsed is Array:
			_book = parsed
	return _book


static func next() -> PuzzleStageData:
	var entries := book()
	if entries.is_empty():
		return null
	var limit := mini(RECENT_LIMIT, entries.size() / 2)
	var candidates: Array[int] = []
	for i in entries.size():
		if not _recent.has(i):
			candidates.append(i)
	var index: int = candidates.pick_random()
	_recent.append(index)
	while _recent.size() > limit:
		_recent.pop_front()
	return stage_at(index)


static func stage_at(index: int) -> PuzzleStageData:
	var stage := PuzzleStageData.from_dict(book()[index]["stage"], STAGE_ID)
	stage.title = TITLE
	return stage
