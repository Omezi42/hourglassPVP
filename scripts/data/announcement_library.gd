class_name AnnouncementLibrary
extends RefCounted
## 更新のお知らせの一覧と既読(GameDesign.md 33章 / Architecture.md 10.22節)。
## 既読は端末に「最後に開いた版」だけを持つ。記録が無ければ、いちばん新しい回だけを読んでいない扱いにする。

const ANNOUNCEMENTS_DIR := "res://data/announcements"
const KEY_LAST_SEEN := "last_seen"
## 一覧に出す回数の上限(古い回は `sync_announcements.py` が消すが、念のため画面でも切る)。
const MAX_LISTED := 20

## テストが差し替える(`user://` の実データに触らないため)。
static var save_path := "user://announcements.json"
static var _cache: Array[AnnouncementData] = []
static var _last_seen := ""
static var _loaded := false


## 新しい順。
static func all() -> Array[AnnouncementData]:
	if not _cache.is_empty():
		return _cache
	var dir := DirAccess.open(ANNOUNCEMENTS_DIR)
	if dir == null:
		return _cache
	for name in dir.get_files():
		# エクスポート後は "<name>.tres.remap" として格納される(Architecture.md 5章)。
		var base := name.trim_suffix(".remap")
		if not base.ends_with(".tres"):
			continue
		var entry: AnnouncementData = load(ANNOUNCEMENTS_DIR + "/" + base)
		if entry != null:
			_cache.append(entry)
	_cache.sort_custom(
		func(a: AnnouncementData, b: AnnouncementData) -> bool: return a.version > b.version
	)
	_cache = _cache.slice(0, MAX_LISTED)
	return _cache


static func is_unread(entry: AnnouncementData) -> bool:
	_ensure_loaded()
	if _last_seen.is_empty():
		var entries := all()
		return not entries.is_empty() and entries[0] == entry
	return entry.version > _last_seen


static func unread_count() -> int:
	var count := 0
	for entry in all():
		if is_unread(entry):
			count += 1
	return count


## モーダルを開いた時点で全部読んだことにする。
static func mark_all_read() -> void:
	var entries := all()
	if entries.is_empty():
		return
	_ensure_loaded()
	_last_seen = entries[0].version
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({KEY_LAST_SEEN: _last_seen}))
	file.close()


## 保存先を差し替えたあとに読み直させる(テスト用)。
static func forget_loaded() -> void:
	_loaded = false
	_last_seen = ""


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_last_seen = str(parsed.get(KEY_LAST_SEEN, ""))
