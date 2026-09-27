class_name SoloGateLibrary
extends RefCounted
## data/solo_gates/ を走査して関門(GameDesign.md 27章)を列挙する。
## `PuzzleLibrary` と同じ「Autoloadを使わずstaticで持つ」流儀。

const GATES_DIR := "res://data/solo_gates"

static var _cache: Array[SoloGateData] = []


static func all_gates() -> Array[SoloGateData]:
	if not _cache.is_empty():
		return _cache
	var dir := DirAccess.open(GATES_DIR)
	if dir == null:
		return _cache
	var names := dir.get_files()
	names.sort()
	for name in names:
		# エクスポート後は "<name>.tres.remap" として格納される(Architecture.md 5章)。
		var base := name.trim_suffix(".remap")
		if not base.ends_with(".tres"):
			continue
		var gate: SoloGateData = load(GATES_DIR + "/" + base)
		if gate != null:
			_cache.append(gate)
	return _cache


static func find_by_id(id: String) -> SoloGateData:
	if id.is_empty():
		return null
	for gate in all_gates():
		if gate.id == id:
			return gate
	return null


static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for gate in all_gates():
		ids.append(gate.id)
	return ids
