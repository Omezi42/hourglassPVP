class_name SoloBoonLibrary
extends RefCounted
## data/solo_boons/ を走査して恩恵(GameDesign.md 27章「恩恵」)を列挙する。
## `SoloGateLibrary` と同じ「Autoloadを使わずstaticで持つ」流儀。

const BOONS_DIR := "res://data/solo_boons"

static var _cache: Array[SoloBoonData] = []


static func all_boons() -> Array[SoloBoonData]:
	if not _cache.is_empty():
		return _cache
	var dir := DirAccess.open(BOONS_DIR)
	if dir == null:
		return _cache
	var names := dir.get_files()
	names.sort()
	for name in names:
		# エクスポート後は "<name>.tres.remap" として格納される(Architecture.md 5章)。
		var base := name.trim_suffix(".remap")
		if not base.ends_with(".tres"):
			continue
		var boon: SoloBoonData = load(BOONS_DIR + "/" + base)
		if boon != null:
			_cache.append(boon)
	return _cache


static func find_by_id(id: String) -> SoloBoonData:
	if id.is_empty():
		return null
	for boon in all_boons():
		if boon.id == id:
			return boon
	return null


static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for boon in all_boons():
		ids.append(boon.id)
	return ids
