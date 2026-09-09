class_name SoloLibrary
extends RefCounted
## data/solo_stages/ を走査してソロモードのステージを列挙する(GameDesign.md 27章)。
## `PuzzleLibrary`と同じ「Autoloadを使わずstaticで持つ」流儀。

const STAGES_DIR := "res://data/solo_stages"

static var _cache: Array[SoloStageData] = []


## ツリー上の並び順(`order`)に並べて返す。v1は1本道のため、これがそのまま道順になる。
static func all_stages() -> Array[SoloStageData]:
	if not _cache.is_empty():
		return _cache
	var dir := DirAccess.open(STAGES_DIR)
	if dir == null:
		return _cache
	var names := dir.get_files()
	names.sort()
	for name in names:
		# エクスポート後は "<name>.tres.remap" として格納される(Architecture.md 5章)。
		var base := name.trim_suffix(".remap")
		if not base.ends_with(".tres"):
			continue
		var stage: SoloStageData = load(STAGES_DIR + "/" + base)
		if stage != null:
			_cache.append(stage)
	_cache.sort_custom(func(a: SoloStageData, b: SoloStageData) -> bool: return a.order < b.order)
	return _cache


static func find_by_id(id: String) -> SoloStageData:
	for stage in all_stages():
		if stage.id == id:
			return stage
	return null


## そのステージへ挑戦できるか。前提ステージ(`requires`)がすべてクリア済みなら true。
## 前提が無いステージ(先頭)は常に挑戦できる。
static func is_unlocked(stage: SoloStageData, owner_uid: String) -> bool:
	if stage.requires.is_empty():
		return true
	for required_id in stage.requires:
		if not SoloProgress.is_cleared(owner_uid, required_id):
			return false
	return true
