class_name PuzzleProgress
extends RefCounted
## リーサルパズルのクリア記録(GameDesign.md 24章)。
## `MatchStats` と同じ流儀で `user://puzzle_progress.json` へ**アカウントごとに**貯める。
##
## **初回クリアかどうかだけを覚える。**報酬は1問につき1度きりであり、
## 何手で解いたかを残しても、いまの画面に出す場所が無い。

const SAVE_PATH := "user://puzzle_progress.json"
## 初回クリアの報酬(GameDesign.md 24章)。
const CLEAR_REWARD := 50

static var _loaded := false
static var _muted := false
static var _data: Dictionary = {}


static func is_cleared(owner_uid: String, stage_id: String) -> bool:
	return _list(owner_uid).has(stage_id)


static func cleared_count(owner_uid: String) -> int:
	return _list(owner_uid).size()


## クリアを記録する。**初回だったときだけ true** を返す(報酬を出す側の判断に使う)。
static func mark_cleared(owner_uid: String, stage_id: String) -> bool:
	var ids := _list(owner_uid)
	if ids.has(stage_id):
		return false
	ids.append(stage_id)
	_save()
	return true


static func reset_for_test() -> void:
	_muted = true
	_loaded = true
	_data = {}


static func _list(owner_uid: String) -> Array:
	_ensure_loaded()
	var key := owner_uid if not owner_uid.is_empty() else "local"
	if not _data.has(key):
		_data[key] = []
	return _data[key]


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
