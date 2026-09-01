class_name LocalReplayService
extends RefCounted
## CPU戦の対局記録をuser://へローカル保存するクラス(GameDesign.md 12章・13章、
## Architecture.md 7.1節)。Firestoreを使うReplayServiceと対をなす、DeckSaveと同様の
## 「Autoloadを使わずstaticで持つ」流儀のクラス。

const SAVE_PATH := "user://cpu_replays.json"
const RETENTION_LIMIT := 30


## 対局終了時に呼び出す。deck_a/deck_b・placement_a/placement_b・actions・winnerを含む
## recordへid・finished_at・owner_uidを付与して保存し、続けて保存件数の上限
## (アカウントごとに30件)を維持する。
##
## owner_uidは、アカウントを切り替えたときに他のアカウントの記録が一覧へ混ざらない
## ようにするためのもの(GameDesign.md 12章・14章)。上限も所有者ごとに数え、
## 別のアカウントで遊んだ記録を巻き添えで消さない。
static func mark_finished(record: Dictionary, owner_uid: String = "") -> void:
	var entry: Dictionary = record.duplicate(true)
	entry["id"] = "cpu_%d_%d" % [Time.get_unix_time_from_system(), randi() % 1000000]
	entry["finished_at"] = Time.get_unix_time_from_system()
	entry["source"] = "cpu"
	entry["owner_uid"] = owner_uid

	var kept: Array = []
	var mine: Array = [entry]
	for existing in _load_all():
		if _belongs_to(existing, owner_uid):
			mine.append(existing)
		else:
			kept.append(existing)
	_sort_by_finished_at(mine)
	if mine.size() > RETENTION_LIMIT:
		mine = mine.slice(0, RETENTION_LIMIT)
	var all: Array = kept + mine
	_sort_by_finished_at(all)
	_save_all(all)


## owner_uidのアカウントが遊んだCPU戦リプレイを、finished_atの新しい順に返す。
## ReplayService.list_replays()と同じ{"id":..., "fields":{...}}の形へ揃え、
## ReplayListCard側の表示ロジックを共用できるようにする。
static func list_replays(owner_uid: String = "") -> Array[Dictionary]:
	var all: Array = _load_all()
	_sort_by_finished_at(all)
	var result: Array[Dictionary] = []
	for entry in all:
		if not _belongs_to(entry, owner_uid):
			continue
		result.append({"id": str(entry.get("id", "")), "fields": entry})
	return result


## owner_uidを持たない古いレコードは、アカウント機能の導入前に保存されたもの。
## 一覧から消えてしまわないよう、いま遊んでいるアカウントのものとして扱う。
## owner_uid自体が空(サインインできていない)ときは、絞り込む基準が無いため全件返す。
static func _belongs_to(entry: Dictionary, owner_uid: String) -> bool:
	if owner_uid == "":
		return true
	var owner := str(entry.get("owner_uid", ""))
	return owner == "" or owner == owner_uid


static func _sort_by_finished_at(entries: Array) -> void:
	entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("finished_at", 0)) > int(b.get("finished_at", 0))
	)


## idに一致するレコードをフラットな形(再生側がそのまま
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
	var text := file.get_as_text().strip_edges()
	file = null
	if text.is_empty():
		return []
	var parsed: Variant = JSON.parse_string(text)
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
	file = null
