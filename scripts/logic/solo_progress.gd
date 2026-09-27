class_name SoloProgress
extends RefCounted
## 遠征(ソロモード)の保存と記録(GameDesign.md 27章、Architecture.md 10.15節)。
## `user://solo_progress.json` へアカウントごと(未サインインは `"local"`)に持つ。
##
## 以前の形式(ステージidの配列)を読んだときは空の記録として扱う。

const SAVE_PATH := "user://solo_progress.json"

static var _loaded := false
static var _muted := false
static var _data: Dictionary = {}


## 保存中の遠征。`in_battle` のまま残っていたら負けとして遠征を終え、`null` を返す
## (GameDesign.md 27章「中断と再開」)。
static func load_run(uid: String) -> SoloRun:
	var raw: Variant = _entry(uid).get("run", null)
	if not (raw is Dictionary):
		return null
	var run := SoloRun.from_dict(raw)
	if not run.in_battle:
		return run
	run.finish_battle(false, 0, RandomNumberGenerator.new())
	record(uid, run)
	clear_run(uid)
	return null


static func save_run(uid: String, run: SoloRun) -> void:
	var entry := _entry(uid)
	entry["run"] = null if run == null else run.to_dict()
	_data[_key(uid)] = entry
	_save()


static func clear_run(uid: String) -> void:
	save_run(uid, null)


static func best_wins(uid: String) -> int:
	return int(_entry(uid).get("best_wins", 0))


static func clears(uid: String) -> int:
	return int(_entry(uid).get("clears", 0))


## 決着のたびに呼ぶ。最多勝利数・踏破回数を更新し、初めて到達した節目を返す。
static func record(uid: String, run: SoloRun) -> Array[Dictionary]:
	var entry := _entry(uid)
	entry["best_wins"] = maxi(int(entry.get("best_wins", 0)), run.wins)
	if run.cleared:
		entry["clears"] = int(entry.get("clears", 0)) + 1
	var milestones: Array = entry.get("milestones", [])
	var reached: Array[Dictionary] = []
	for milestone in SoloRun.MILESTONES:
		var id := str(milestone["id"])
		if milestones.has(id):
			continue
		var hit := false
		if milestone.has("wins") and run.wins >= int(milestone["wins"]):
			hit = true
		if milestone.has("cleared") and run.cleared:
			hit = true
		if not hit:
			continue
		milestones.append(id)
		reached.append(milestone)
	entry["milestones"] = milestones
	_data[_key(uid)] = entry
	_save()
	return reached


static func reset_for_test() -> void:
	_muted = true
	_loaded = true
	_data = {}


static func _entry(uid: String) -> Dictionary:
	_ensure_loaded()
	var key := _key(uid)
	var current: Variant = _data.get(key, null)
	if not (current is Dictionary) or not (current as Dictionary).has("best_wins"):
		current = {"run": null, "best_wins": 0, "clears": 0, "milestones": []}
		_data[key] = current
	return current


static func _key(uid: String) -> String:
	return uid if not uid.is_empty() else "local"


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_data = parsed


static func _save() -> void:
	if _muted:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_data))
	file.close()
