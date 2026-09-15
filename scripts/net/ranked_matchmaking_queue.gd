class_name RankedMatchmakingQueue
extends Node
## ランクマッチ専用のマッチングキュー(GameDesign.md 28章、Architecture.md 10.16節)。
## `MatchmakingQueue`とほぼ同じ実装だが、コレクションを`ranked_queue`に分けて
## フリーマッチ(通常のランダムマッチ)のプールと混ざらないようにする。
## v1では段位を考慮せず、フリーマッチと同じ「早い者勝ち」でマッチさせる
## (マッチング精度の改善は次のステップ)。

signal matched(match_id: String, opponent_uid: String)
## キューへ入れなかった(通信に失敗した・拒否された)。
signal failed(reason: String)
## 待機者はいたが、全員バージョンが違って掴めなかった(GameDesign.md 11章と同じ考え方)。
signal version_mismatch(newer_exists: bool)

const COLLECTION := "ranked_queue"
const POLL_INTERVAL_SECONDS := 2.0
const QUERY_LIMIT := 5
## joined_atがこれより古い待機者は、ブラウザを閉じた等で既に居ないものとして扱う。
const STALE_SECONDS := 60.0
## 待機中に自分のjoined_atを更新する間隔。
const HEARTBEAT_SECONDS := 20.0

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
		_doc_path(),
		{
			"joined_at": Time.get_unix_time_from_system(),
			"match_id": "",
			"build": GameVersion.build_id()
		}
	)
	if not joined:
		failed.emit("マッチングを開始できませんでした")
		return

	var last_heartbeat := Time.get_unix_time_from_system()
	while not _cancelled and _my_match_id == "":
		var found: bool = await _try_claim_or_check()
		if found or _cancelled:
			return
		if Time.get_unix_time_from_system() - last_heartbeat >= HEARTBEAT_SECONDS:
			last_heartbeat = Time.get_unix_time_from_system()
			await client.set_document(_doc_path(), {"joined_at": last_heartbeat})
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
	var newer_seen := false
	var mismatch_seen := false
	for candidate in candidates:
		if candidate["id"] == auth.uid:
			continue
		if _is_stale(candidate):
			await client.delete_document(_doc_path(candidate["id"]))
			continue
		var their_build: String = candidate["fields"].get("build", "")
		if not GameVersion.matches_build(their_build):
			mismatch_seen = true
			newer_seen = newer_seen or GameVersion.is_newer_than_mine(their_build)
			continue
		var claimed: bool = await _claim(mine, candidate)
		if claimed:
			return await _finalize_match(_my_match_id, candidate["id"])
		return false
	if mismatch_seen:
		version_mismatch.emit(newer_seen)
	return false


## 相手のキュー更新・自分のキュー更新・matches/{id}の作成を1回のcommitで原子的に行う
## (`MatchmakingQueue._claim()`と同じ理由。Architecture.md 6.1節)。
func _claim(mine: Dictionary, candidate: Dictionary) -> bool:
	var new_match_id := MatchIdGenerator.generate()
	var sides := MatchSides.assign(str(candidate["id"]), auth.uid)
	sides["created_at"] = Time.get_unix_time_from_system()
	var claimed: bool = await client.commit(
		[
			client.update_write(
				_doc_path(candidate["id"]),
				{"match_id": new_match_id},
				{"updateTime": candidate["update_time"]}
			),
			client.update_write(
				_doc_path(), {"match_id": new_match_id}, {"updateTime": mine["update_time"]}
			),
			client.update_write("matches/%s" % new_match_id, sides, {"exists": false})
		]
	)
	if claimed:
		_my_match_id = new_match_id
	return claimed


func _is_stale(candidate: Dictionary) -> bool:
	var joined_at := float(candidate["fields"].get("joined_at", 0.0))
	return Time.get_unix_time_from_system() - joined_at > STALE_SECONDS


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
