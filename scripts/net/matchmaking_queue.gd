class_name MatchmakingQueue
extends Node

signal matched(match_id: String, opponent_uid: String)
## キューへ入れなかった(通信に失敗した・拒否された)。黙って待ち続けると
## 「押しても何も起きない」ようにしか見えないため、必ず画面へ返す。
signal failed(reason: String)

const COLLECTION := "matchmaking_queue"
const POLL_INTERVAL_SECONDS := 2.0
const QUERY_LIMIT := 5
## joined_atがこれより古い待機者は、ブラウザを閉じた等で既に居ないものとして扱う。
## 掴んでしまうと、相手のデッキを永久に待つ状態になるため。
const STALE_SECONDS := 60.0
## 待機中に自分のjoined_atを更新する間隔。更新はupdateTimeを変えるため、相手のclaimの
## 前提条件を無効化してしまう。ポーリング間隔より十分長くして衝突を避ける。
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
		_doc_path(), {"joined_at": Time.get_unix_time_from_system(), "match_id": ""}
	)
	if not joined:
		failed.emit("マッチングを開始できませんでした")
		return

	var last_heartbeat := Time.get_unix_time_from_system()
	var announced := false
	while not _cancelled and _my_match_id == "":
		var found: bool = await _try_claim_or_check()
		if found or _cancelled:
			return
		# ここへ来た時点で「待機側になった」ことが確定する。即座にマッチが成立した
		# 場合は上で return しているため、条件分岐を足さずに仕様を満たせる。
		# 応答は待たない(通信の成否でポーリングを遅らせないため)
		if not announced and QueueNotifier.can_send():
			announced = true
			QueueNotifier.notify_waiting(self)
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
	for candidate in candidates:
		if candidate["id"] == auth.uid:
			continue
		if _is_stale(candidate):
			await client.delete_document(_doc_path(candidate["id"]))
			continue
		var claimed: bool = await _claim(mine, candidate)
		if claimed:
			return await _finalize_match(_my_match_id, candidate["id"])
		# 失敗時(相手または自分のドキュメントが競合更新された)は、次のポーリングで
		# 最新状態から再試行する(古いmineのまま他候補を試さない)
		return false
	return false


## 相手のキュー更新・自分のキュー更新・matches/{id}の作成を1回のcommitで原子的に行う。
## 以前はmatches/{id}への書き込みだけ別だったため、掴まれた側がmatch_idを見て
## matches/{id}を読んだときにplayer_a/player_bがまだ空という窓があり、その窓に入ると
## 双方が後手(side B)と判定されて対局が始まらなかった(Architecture.md 6.1節)。
func _claim(mine: Dictionary, candidate: Dictionary) -> bool:
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
			),
			client.update_write(
				"matches/%s" % new_match_id,
				{
					"player_a": candidate["id"],
					"player_b": auth.uid,
					"created_at": Time.get_unix_time_from_system()
				},
				{"exists": false}
			)
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
