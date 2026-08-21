class_name ReplayService
extends RefCounted

const COLLECTION := "matches"
const RETENTION_LIMIT := 30
const QUERY_LIMIT := 50


## 対局終了時に呼び出す。finished_at/winnerを書き込み、続けて保存件数の上限を維持する。
## 上限はアカウントごとに数えるため、自分のuidを渡す(GameDesign.md 12章)。
static func mark_finished(
	client: FirestoreClient, match_id: String, winner: String, uid: String
) -> void:
	await client.set_document(
		"%s/%s" % [COLLECTION, match_id],
		{"finished_at": Time.get_unix_time_from_system(), "winner": winner}
	)
	await _enforce_retention(client, uid)


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


## 自分が対局した終了済みマッチが上限を超えていたら、古いものから削除する。
##
## 以前は終了済みマッチをアプリ全体で古い順に消していたため、プレイヤーが増えると
## 互いの記録を消し合っていた。list_replays()が返す「自分の対局だけ・新しい順」の
## 並びをそのまま使い、上限より後ろを消す。
static func _enforce_retention(client: FirestoreClient, uid: String) -> void:
	if uid == "":
		return
	var mine: Array[Dictionary] = await list_replays(client, uid)
	if mine.size() <= RETENTION_LIMIT:
		return
	var writes: Array = []
	for i in range(RETENTION_LIMIT, mine.size()):
		writes.append(client.delete_write("%s/%s" % [COLLECTION, mine[i]["id"]]))
	await client.commit(writes)
