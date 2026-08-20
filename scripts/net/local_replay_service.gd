class_name LocalReplayService
extends RefCounted
## CPU戦の対局記録をuser://へローカル保存するクラス(GameDesign.md 12章・13章、
## Architecture.md 7.1節)。Firestoreを使うReplayServiceと対をなす、DeckSaveと同様の
## 「Autoloadを使わずstaticで持つ」流儀のクラス。

const SAVE_PATH := "user://cpu_replays.json"
const RETENTION_LIMIT := 30


## 対局終了時に呼び出す。deck_a/deck_b・placement_a/placement_b・actions・winnerを含む
## recordへid・finished_atを付与して保存し、続けて保存件数の上限(30件)を維持する。
static func mark_finished(record: Dictionary) -> void:
	var entry: Dictionary = record.duplicate(true)
	entry["id"] = "cpu_%d_%d" % [Time.get_unix_time_from_system(), randi() % 1000000]
	entry["finished_at"] = Time.get_unix_time_from_system()
	entry["source"] = "cpu"

	var all: Array = _load_all()
	all.append(entry)
	all.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("finished_at", 0)) > int(b.get("finished_at", 0))
	)
	if all.size() > RETENTION_LIMIT:
		all = all.slice(0, RETENTION_LIMIT)
	_save_all(all)


## 保存済みの全CPU戦リプレイを、finished_atの新しい順に返す。ReplayService.list_replays()と
## 同じ{"id":..., "fields":{...}}の形へ揃え、ReplayListCard側の表示ロジックを共用できるようにする。
static func list_replays() -> Array[Dictionary]:
	var all: Array = _load_all()
	all.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("finished_at", 0)) > int(b.get("finished_at", 0))
	)
	var result: Array[Dictionary] = []
	for entry in all:
		result.append({"id": str(entry.get("id", "")), "fields": entry})
	return result


## idに一致するレコードをフラットな形(MatchScreen.start_local_replay()がそのまま
## 読める形)で返す。見つからない場合は空Dictionaryを返す。
static func get_replay(id: String) -> Dictionary:
	for entry in _load_all():
		if str(entry.get("id", "")) == id:
			return entry
	return {}


static func _load_all() -> Array:
	if not FileAccess.file_exists(SAVE_PATH):
		return []
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		return []
	var result: Array = []
	for entry in parsed:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append(entry)
	return result


static func _save_all(records: Array) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(records))
