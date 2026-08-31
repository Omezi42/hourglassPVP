class_name MatchmakingQueue
extends Node

signal matched(match_id: String, opponent_uid: String)
## キューへ入れなかった(通信に失敗した・拒否された)。黙って待ち続けると
## 「押しても何も起きない」ようにしか見えないため、必ず画面へ返す。
signal failed(reason: String)
## 待機者はいたが、全員バージョンが違って掴めなかった(GameDesign.md 11章)。
## 黙って待ち続けると「マッチングしない不具合」にしか見えないため画面へ返す。
## `newer_exists` は、自分より新しい版の相手がいた(=自分が古い)ことを表す。
signal version_mismatch(newer_exists: bool)

const COLLECTION := "matchmaking_queue"
const POLL_INTERVAL_SECONDS := 2.0
const QUERY_LIMIT := 5
## joined_atがこれより古い待機者は、ブラウザを閉じた等で既に居ないものとして扱う。
## 掴んでしまうと、相手のデッキを永久に待つ状態になるため。
const STALE_SECONDS := 60.0
## 待機中に自分のjoined_atを更新する間隔。更新はupdateTimeを変えるため、相手のclaimの
## 前提条件を無効化してしまう。ポーリング間隔より十分長くして衝突を避ける。
const HEARTBEAT_SECONDS := 20.0
## 募集の知らせが届かなかったときに、次を試すまでの間隔。ポーリングのたびに
## 試すと失敗が続く場面で送信が積み上がるため、少し置いてから試し直す。
const ANNOUNCE_RETRY_SECONDS := 30.0

var client: FirestoreClient
var auth: FirebaseAuth
var _my_match_id: String = ""
## 募集の知らせが届いたか。届くまでは間を置いて試し直す(GameDesign.md 11章)。
var _announced := false
var _announce_next_at := 0.0
var _cancelled := false


func _init(p_client: FirestoreClient, p_auth: FirebaseAuth) -> void:
	client = p_client
	auth = p_auth


func join() -> void:
	_cancelled = false
	_my_match_id = ""
	_announced = false
	_announce_next_at = 0.0
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
		# ここへ来た時点で「待機側になった」ことが確定する。即座にマッチが成立した
		# 場合は上で return しているため、条件分岐を足さずに仕様を満たせる。
		# 応答は待たない(通信の成否でポーリングを遅らせないため)
		if not _announced and _now() >= _announce_next_at and QueueNotifier.can_send():
			# **届くまで諦めない。**以前は1回試して終わりで、失敗しても画面には
			# 何も出ず、待っている側には「誰も来ない」としか見えなかった。
			_announce_next_at = _now() + ANNOUNCE_RETRY_SECONDS
			QueueNotifier.notify_waiting(self, _on_announced)
		if Time.get_unix_time_from_system() - last_heartbeat >= HEARTBEAT_SECONDS:
			last_heartbeat = Time.get_unix_time_from_system()
			await client.set_document(_doc_path(), {"joined_at": last_heartbeat})
		await get_tree().create_timer(POLL_INTERVAL_SECONDS).timeout


## 届いたらそれ以上は送らない(待っている間ずっと知らせ続けると、通知そのものを
## 切られてしまう)。**結果は画面へ出さない**(GameDesign.md 11章)。募集の通知は
## プレイヤーの操作ではなく裏方の処理であり、その成否を待機中の文言へ混ぜても
## 待っている人にできることは無い。
func _on_announced(ok: bool) -> void:
	_announced = _announced or ok


func _now() -> float:
	return Time.get_unix_time_from_system()


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
		# バージョンが違う相手は掴まない(GameDesign.md 11章)。**掴まないだけで
		# 削除はしない**。古い版の人が待つ権利まで奪う理由はなく、STALE_SECONDS に
		# よる掃除とは目的が違う。
		var their_build: String = candidate["fields"].get("build", "")
		if not GameVersion.matches_build(their_build):
			mismatch_seen = true
			newer_seen = newer_seen or GameVersion.is_newer_than_mine(their_build)
			continue
		var claimed: bool = await _claim(mine, candidate)
		if claimed:
			return await _finalize_match(_my_match_id, candidate["id"])
		# 失敗時(相手または自分のドキュメントが競合更新された)は、次のポーリングで
		# 最新状態から再試行する(古いmineのまま他候補を試さない)
		return false
	if mismatch_seen:
		version_mismatch.emit(newer_seen)
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
