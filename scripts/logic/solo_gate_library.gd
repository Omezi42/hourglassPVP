class_name SoloGateLibrary
extends RefCounted
## data/solo_gates/ の関門と data/solo_bosses/ の主(GameDesign.md 27章)を列挙する。
## 主は関門と同じ`SoloGateData`で持つ。`PuzzleLibrary` と同じ「Autoloadを使わずstaticで持つ」流儀。

const GATES_DIR := "res://data/solo_gates"
const BOSSES_DIR := "res://data/solo_bosses"

static var _cache: Array[SoloGateData] = []
static var _boss_cache: Array[SoloGateData] = []


static func all_gates() -> Array[SoloGateData]:
	if _cache.is_empty():
		_cache = _load_dir(GATES_DIR)
	return _cache


static func all_bosses() -> Array[SoloGateData]:
	if _boss_cache.is_empty():
		_boss_cache = _load_dir(BOSSES_DIR)
	return _boss_cache


## 関門・主のどちらのidでも引ける(道の行き先の`gate`には、最終戦なら主のidが入る)。
static func find_by_id(id: String) -> SoloGateData:
	if id.is_empty():
		return null
	for gate in all_gates() + all_bosses():
		if gate.id == id:
			return gate
	return null


static func boss_ids() -> Array[String]:
	var ids: Array[String] = []
	for boss in all_bosses():
		ids.append(boss.id)
	return ids


static func _load_dir(path: String) -> Array[SoloGateData]:
	var found: Array[SoloGateData] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return found
	var names := dir.get_files()
	names.sort()
	for name in names:
		# エクスポート後は "<name>.tres.remap" として格納される(Architecture.md 5章)。
		var base := name.trim_suffix(".remap")
		if not base.ends_with(".tres"):
			continue
		var gate: SoloGateData = load(path + "/" + base)
		if gate != null:
			found.append(gate)
	return found


static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for gate in all_gates():
		ids.append(gate.id)
	return ids
