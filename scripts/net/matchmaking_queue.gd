class_name MatchmakingQueue
extends Node

signal matched(match_id: String, opponent_uid: String)

const COLLECTION := "matchmaking_queue"
const POLL_INTERVAL_SECONDS := 2.0
const QUERY_LIMIT := 5

var client: FirestoreClient
var auth: FirebaseAuth
var _my_match_id: String = ""
var _cancelled := false


func _init(p_client: FirestoreClient, p_auth: FirebaseAuth) -> void:
	client = p_client
	auth = p_auth


func join() -> void:
	_cancelled = false
	_my_match_id = ""
	var joined: bool = await client.set_document(
		_doc_path(), {"joined_at": Time.get_unix_time_from_system(), "match_id": ""}
	)
	if not joined:
		return

	while not _cancelled and _my_match_id == "":
		var found: bool = await _try_claim_or_check()
		if found:
			return
		if _cancelled:
			return
		await get_tree().create_timer(POLL_INTERVAL_SECONDS).timeout


func cancel() -> void:
	_cancelled = true
	await client.delete_document(_doc_path())


func _try_claim_or_check() -> bool:
	var mine: Dictionary = await client.get_document_meta(_doc_path())
	if not mine["exists"]:
		return false

	var my_assigned_match_id: String = mine["fields"].get("match_id", "")
	if my_assigned_match_id != "":
		return await _finalize_match(my_assigned_match_id, "")

	var candidates: Array = await client.query_waiting(COLLECTION, QUERY_LIMIT)
	for candidate in candidates:
		if candidate["id"] == auth.uid:
			continue
		var new_match_id := MatchIdGenerator.generate()
		var claimed: bool = await client.commit(
			[
				client.update_write(
					_doc_path(candidate["id"]),
					{"match_id": new_match_id},
					{"updateTime": candidate["update_time"]}
				),
				client.update_write(
					_doc_path(), {"match_id": new_match_id}, {"updateTime": mine["update_time"]}
				)
			]
		)
		if claimed:
			await client.set_document(
				"matches/%s" % new_match_id, {"player_a": candidate["id"], "player_b": auth.uid}
			)
			return await _finalize_match(new_match_id, candidate["id"])
		# 失敗時(相手または自分のドキュメントが競合更新された)は、次のポーリングで
		# 最新状態から再試行する(古いmineのまま他候補を試さない)
		return false
	return false


func _finalize_match(match_id: String, known_opponent_uid: String) -> bool:
	_my_match_id = match_id
	var opponent_uid := known_opponent_uid
	if opponent_uid == "":
		var match_doc: Dictionary = await client.get_document("matches/%s" % match_id)
		var player_a: String = match_doc.get("player_a", "")
		var player_b: String = match_doc.get("player_b", "")
		opponent_uid = player_b if player_a == auth.uid else player_a
	await client.delete_document(_doc_path())
	matched.emit(match_id, opponent_uid)
	return true


func _doc_path(uid: String = "") -> String:
	return "%s/%s" % [COLLECTION, uid if uid != "" else auth.uid]
