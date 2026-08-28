class_name UiState
extends RefCounted
## 画面まわりの小さな永続状態(Autoloadを使わずstaticで持つ流儀。CardDeckSave と同じ)。
##
## 「ホーム画面を一度でも開いたか」と「誘導対局を遊んだか」を持つ。前者は初回だけ「ルール」タブから
## 始めるための判定に使う(GameDesign.md 9章)。読んだかどうかではなくホームを開いたかで
## 判定しているのは、読了を測るとルールを閉じただけの人へ何度も出てしまうため。

const SAVE_PATH := "user://ui_state.json"
const KEY_HOME_SEEN := "home_seen"
const KEY_TUTORIAL_DONE := "tutorial_done"

static var _loaded := false
static var _state: Dictionary = {}


static func has_seen_home() -> bool:
	_ensure_loaded()
	return bool(_state.get(KEY_HOME_SEEN, false))


static func mark_home_seen() -> void:
	_ensure_loaded()
	if _state.get(KEY_HOME_SEEN, false):
		return
	_state[KEY_HOME_SEEN] = true
	_save()


## 誘導対局を一度でも遊んだか(GameDesign.md 18章)。終えた人へ毎回いちばん目立つ位置で
## 勧め続けないための判定に使う。
static func has_done_tutorial() -> bool:
	_ensure_loaded()
	return bool(_state.get(KEY_TUTORIAL_DONE, false))


static func mark_tutorial_done() -> void:
	_ensure_loaded()
	if _state.get(KEY_TUTORIAL_DONE, false):
		return
	_state[KEY_TUTORIAL_DONE] = true
	_save()


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
		_state = parsed


static func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_state))
	file.close()
