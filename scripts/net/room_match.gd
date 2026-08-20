class_name RoomMatch
extends Node

signal room_created(code: String)
signal matched(match_id: String, opponent_uid: String)
signal join_failed(reason: String)
signal spectate_ready(match_id: String)
signal spectate_failed(reason: String)

const COLLECTION := "rooms"
const CODE_CHARS := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
const CODE_LENGTH := 6
const POLL_INTERVAL_SECONDS := 2.0
const CREATE_RETRY_COUNT := 5

var client: FirestoreClient
var auth: FirebaseAuth
var _code: String = ""
var _my_match_id: String = ""
var _cancelled := false


func _init(p_client: FirestoreClient, p_auth: FirebaseAuth) -> void:
	client = p_client
	auth = p_auth


func create_room() -> void:
	_cancelled = false
	_my_match_id = ""
	for _attempt in range(CREATE_RETRY_COUNT):
		var code := _generate_code()
		var created: bool = await client.create_document(
			_doc_path(code), {"creator_uid": auth.uid, "joiner_uid": "", "match_id": ""}
		)
		if created:
			_code = code
			room_created.emit(code)
			await _wait_for_joiner()
			return
	join_failed.emit("room_create_failed")


func join_room(code: String) -> void:
	_cancelled = false
	_my_match_id = ""
	var room: Dictionary = await client.get_document_meta(_doc_path(code))
	if not room["exists"]:
		join_failed.emit("not_found")
		return
	if room["fields"].get("match_id", "") != "" or room["fields"].get("joiner_uid", "") != "":
		join_failed.emit("full")
		return

	var creator_uid: String = room["fields"].get("creator_uid", "")
	var new_match_id := MatchIdGenerator.generate()
	var claimed: bool = await client.commit(
		[
			client.update_write(
				_doc_path(code),
				{"joiner_uid": auth.uid, "match_id": new_match_id},
				{"updateTime": room["update_time"]}
			)
		]
	)
	if not claimed:
		join_failed.emit("race_lost")
		return

	await client.set_document(
		"matches/%s" % new_match_id, {"player_a": creator_uid, "player_b": auth.uid}
	)
	_my_match_id = new_match_id
	matched.emit(new_match_id, creator_uid)


func cancel() -> void:
	_cancelled = true
	if _code != "":
		await client.delete_document(_doc_path(_code))


## 観戦用にコードからmatch_idを取得する。対局がまだ始まっていない場合は失敗する。
func spectate(code: String) -> void:
	var room: Dictionary = await client.get_document_meta(_doc_path(code))
	if not room["exists"]:
		spectate_failed.emit("not_found")
		return
	var match_id: String = room["fields"].get("match_id", "")
	if match_id == "":
		spectate_failed.emit("not_started")
		return
	spectate_ready.emit(match_id)


func _wait_for_joiner() -> void:
	while not _cancelled and _my_match_id == "":
		await get_tree().create_timer(POLL_INTERVAL_SECONDS).timeout
		if _cancelled:
			return
		var doc: Dictionary = await client.get_document(_doc_path(_code))
		var match_id: String = doc.get("match_id", "")
		if match_id != "":
			_my_match_id = match_id
			var joiner_uid: String = doc.get("joiner_uid", "")
			matched.emit(match_id, joiner_uid)
			return


func _doc_path(code: String) -> String:
	return "%s/%s" % [COLLECTION, code]


func _generate_code() -> String:
	var code := ""
	for _i in range(CODE_LENGTH):
		code += CODE_CHARS[randi() % CODE_CHARS.length()]
	return code
