class_name DeckSave
extends RefCounted

const SAVE_PATH := "user://deck_save.json"


## 複数デッキを保存する。1件 = {"name": String, "ids": Array[String]}
## selected_indexは対戦で使用するデッキの添字(-1は未選択)。
static func save_decks(decks: Array[Dictionary], selected_index: int = -1) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"decks": decks, "selected_index": selected_index}))


## 対戦で使用するデッキの添字を読み込む(未選択・範囲外なら-1)。
static func load_selected_index() -> int:
	if not FileAccess.file_exists(SAVE_PATH):
		return -1
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return -1
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("selected_index"):
		return -1
	return int(parsed["selected_index"])


## 保存済みの全デッキを読み込む。並び順は保存時の配列順を保持する。
## 旧形式({"ids": [...]})が見つかった場合は1件のみのデッキ配列として読み替える。
static func load_decks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not FileAccess.file_exists(SAVE_PATH):
		return result
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return result
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return result

	if parsed.has("decks"):
		for entry in parsed["decks"]:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var ids: Array[String] = []
			for id in entry.get("ids", []):
				ids.append(str(id))
			result.append({"name": str(entry.get("name", "")), "ids": ids})
		return result

	if parsed.has("ids"):
		var legacy_ids: Array[String] = []
		for id in parsed["ids"]:
			legacy_ids.append(str(id))
		if legacy_ids.size() > 0:
			result.append({"name": "デッキ1", "ids": legacy_ids})
	return result
