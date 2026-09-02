class_name PuzzleLibrary
extends RefCounted
## data/puzzles/ を走査してリーサルパズルの問題を列挙する(GameDesign.md 24章)。
## `CardLibrary` と同じ「Autoloadを使わずstaticで持つ」流儀。

const PUZZLES_DIR := "res://data/puzzles"

static var _cache: Array[PuzzleStageData] = []


## 難易度の順(`order`)に並べて返す。
static func all_stages() -> Array[PuzzleStageData]:
	if not _cache.is_empty():
		return _cache
	var dir := DirAccess.open(PUZZLES_DIR)
	if dir == null:
		return _cache
	var names := dir.get_files()
	names.sort()
	for name in names:
		# エクスポート後は "<name>.tres.remap" として格納される(Architecture.md 5章)。
		var base := name.trim_suffix(".remap")
		if not base.ends_with(".tres"):
			continue
		var stage: PuzzleStageData = load(PUZZLES_DIR + "/" + base)
		if stage != null:
			_cache.append(stage)
	_cache.sort_custom(
		func(a: PuzzleStageData, b: PuzzleStageData) -> bool: return a.order < b.order
	)
	return _cache


static func find_by_id(id: String) -> PuzzleStageData:
	for stage in all_stages():
		if stage.id == id:
			return stage
	return null
