class_name TextSize
extends RefCounted
## 文字の大きさ「標準 / 大」(GameDesign.md 9章)。メニューで切り替え、`user://` へ残す
## (Autoloadを使わずstaticで持つ流儀。CardCpuDifficultySave / UiState と同じ)。
##
## 「大」で大きくするのは詳細パネル・手札の札の名前とキーワード・誘導対局の帯だけ。
## 部品は描くとき・出すときに `factor()` を読む。

const SAVE_PATH := "user://text_size.json"
const KEY_LARGE := "large"
## 「大」の倍率。縦の小さい端末で、手札のキーワードと詳細パネルが目安の大きさへ届くところ。
const LARGE_FACTOR := 1.25

static var _loaded := false
static var _large := false


static func is_large() -> bool:
	_ensure_loaded()
	return _large


static func set_large(value: bool) -> void:
	_ensure_loaded()
	if _large == value:
		return
	_large = value
	_save()


## 撮影ツール用。`user://` へ書かずにこの起動の間だけ切り替える。
static func set_for_test(large: bool) -> void:
	_loaded = true
	_large = large


static func factor() -> float:
	return LARGE_FACTOR if is_large() else 1.0


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
		_large = bool(parsed.get(KEY_LARGE, false))


static func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({KEY_LARGE: _large}))
	file.close()
