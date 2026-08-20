class_name ReplayService
extends RefCounted

const COLLECTION := "matches"
const RETENTION_LIMIT := 30
const QUERY_LIMIT := 50


## 対局終了時に呼び出す。finished_at/winnerを書き込み、続けて保存件数の上限を維持する。
static func mark_finished(client: FirestoreClient, match_id: String, winner: String) -> void:
	await client.set_document(
		"%s/%s" % [COLLECTION, match_id],
		{"finished_at": Time.get_unix_time_from_system(), "winner": winner}
	)
	await _enforce_retention(client)


## 自分が対局した終了済みマッチを、finished_atの新しい順に返す。
static func list_replays(client: FirestoreClient, uid: String) -> Array[Dictionary]:
	var as_a: Array = await client.query_field_equals(COLLECTION, "player_a", uid, QUERY_LIMIT)
	var as_b: Array = await client.query_field_equals(COLLECTION, "player_b", uid, QUERY_LIMIT)

	var seen_ids: Dictionary = {}
	var combined: Array[Dictionary] = []
	for doc in as_a + as_b:
		var doc_id: String = doc["id"]
		if seen_ids.has(doc_id):
			continue
		seen_ids[doc_id] = true
		if doc["fields"].get("finished_at", null) == null:
			continue
		combined.append(doc)

	combined.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["fields"]["finished_at"]) > int(b["fields"]["finished_at"])
	)
	return combined


static func _enforce_retention(client: FirestoreClient) -> void:
	var finished: Array = await client.query_finished_matches_oldest_first(
		COLLECTION, RETENTION_LIMIT + 20
	)
	var excess: int = finished.size() - RETENTION_LIMIT
	if excess <= 0:
		return
	var writes: Array = []
	for i in range(excess):
		writes.append(client.delete_write("%s/%s" % [COLLECTION, finished[i]["id"]]))
	await client.commit(writes)
