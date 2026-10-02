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
	save_finished(uid, run, "abandoned_mid_battle")
	clear_run(uid)
	return null


static func save_run(uid: String, run: SoloRun) -> void:
	var entry := _entry(uid)
	entry["run"] = null if run == null else run.to_dict()
	if run != null:
		entry["started"] = true
	_data[_key(uid)] = entry
	_save()


static func clear_run(uid: String) -> void:
	save_run(uid, null)


## 遠征が終わったとき(負け・踏破・対局途中の中断扱い)の記録(GameDesign.md 27章「画面」)。
## 「遠征をやめる」では呼ばない(自分で終えたため、記録を出さない)。
static func save_finished(uid: String, run: SoloRun, reason: String) -> void:
	var entry := _entry(uid)
	entry["finished"] = {"run": run.to_dict(), "reason": reason}
	_data[_key(uid)] = entry
	_save()


## 保存中の遠征の記録を読み、読んだら消す(次に遠征の画面を開いたとき1度だけ出すため)。
static func take_finished(uid: String) -> Dictionary:
	var entry := _entry(uid)
	var finished: Variant = entry.get("finished", null)
	if not (finished is Dictionary):
		return {}
	entry["finished"] = null
	_data[_key(uid)] = entry
	_save()
	return finished


## 遠征を1度でも始めたか(GameDesign.md 18章「つぎはここ」)。この印を持つ前の版で始めた人は、
## 進行中の遠征・終わった遠征の記録・選んだ深さのどれかが残っているため、それも始めた扱いにする。
static func has_started(uid: String) -> bool:
	var entry := _entry(uid)
	return (
		bool(entry.get("started", false))
		or entry.get("run", null) != null
		or entry.has("finished")
		or entry.has("last_depth")
	)


static func best_wins(uid: String) -> int:
	return int(_entry(uid).get("best_wins", 0))


static func clears(uid: String) -> int:
	return int(_entry(uid).get("clears", 0))


## 出発で選べる最大の深さ(GameDesign.md 27章「砂の深さ」)。深さNで踏破すると
## N+1が選べるようになる(作戦を問わない)。
static func unlocked_depth(uid: String) -> int:
	return int(_entry(uid).get("unlocked_depth", 0))


## その作戦で踏破したことのある最も深い深さ(出発の札の封蝋の印)。未踏破は-1。
static func theme_best_depth(uid: String, theme_id: String) -> int:
	var depths: Dictionary = _entry(uid).get("theme_depths", {})
	if not depths.has(theme_id):
		return -1
	return int(depths[theme_id])


## 踏破した作戦の数(出発の記録「踏破した作戦 N / 8」)。
static func cleared_theme_count(uid: String) -> int:
	var depths: Dictionary = _entry(uid).get("theme_depths", {})
	return depths.size()


## 前回選んだ深さ(出発の画面が覚えておく)。
static func last_depth(uid: String) -> int:
	return int(_entry(uid).get("last_depth", 0))


static func set_last_depth(uid: String, depth: int) -> void:
	var entry := _entry(uid)
	entry["last_depth"] = depth
	_data[_key(uid)] = entry
	_save()


## 決着のたびに呼ぶ。最多勝利数・踏破回数を更新し、初めて到達した節目を返す。
static func record(uid: String, run: SoloRun) -> Array[Dictionary]:
	var entry := _entry(uid)
	entry["best_wins"] = maxi(int(entry.get("best_wins", 0)), run.wins)
	if run.cleared:
		entry["clears"] = int(entry.get("clears", 0)) + 1
		entry["unlocked_depth"] = maxi(
			int(entry.get("unlocked_depth", 0)), mini(run.depth + 1, SoloRun.DEPTH_MAX)
		)
		var depths: Dictionary = entry.get("theme_depths", {})
		depths[run.theme_id] = maxi(int(depths.get(run.theme_id, -1)), run.depth)
		entry["theme_depths"] = depths
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
