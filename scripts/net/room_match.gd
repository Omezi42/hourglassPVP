class_name RoomMatch
extends Node

signal room_created(code: String)
signal room_ready(match_id: String, opponent_uid: String, is_host: bool)
signal room_closed
signal matched(match_id: String, opponent_uid: String)
signal join_failed(reason: String)
signal spectate_ready(match_id: String)
signal spectate_failed(reason: String)
## 観戦しようとした部屋の対局がまだ始まっていない。弾かずに待ちへ入る
## (GameDesign.md 11章)。画面が待機の文言へ切り替えるために1度だけ出す。
signal spectate_waiting

const COLLECTION := "rooms"
## コードは4桁の数字(GameDesign.md 11章)。口頭で伝えられる短さを優先する。
const CODE_LENGTH := 4
const POLL_INTERVAL_SECONDS := 2.0
const CREATE_RETRY_COUNT := 8
## これより古く、まだ対局が始まっていない部屋は番号ごと引き取ってよい。
## 取りうる番号が1万通りしか無いため、**引き取らないと放置された部屋が番号を
## 占め続けて作れなくなる**。対局は20分ほどで終わるため、それより十分に長く取る。
const STALE_SECONDS := 3600.0

var client: FirestoreClient
var auth: FirebaseAuth
## この部屋の持ち時間の入/切(GameDesign.md 5章)。作る側は create_room() の引数で決め、
## 参加・観戦する側は部屋の文書から読んでここへ控える。対局画面まで運ぶのは画面側の仕事。
var time_limit := true
var _code: String = ""
var _my_match_id: String = ""
var _cancelled := false
var _is_host := false


func _init(p_client: FirestoreClient, p_auth: FirebaseAuth) -> void:
	client = p_client
	auth = p_auth


func create_room(p_time_limit: bool = true) -> void:
	_cancelled = false
	_my_match_id = ""
	time_limit = p_time_limit
	for _attempt in range(CREATE_RETRY_COUNT):
		var code := random_code()
		var created: bool = await _claim_code(code, p_time_limit)
		if created:
			_code = code
			_is_host = true
			room_created.emit(code)
			await _wait_for_joiner()
			return
	join_failed.emit("room_create_failed")


func join_room(code: String) -> void:
	_cancelled = false
	_my_match_id = ""
	_code = code
	var room: Dictionary = await client.get_document_meta(_doc_path(code))
	if not room["exists"]:
		join_failed.emit("not_found")
		return
	if room["fields"].get("match_id", "") != "" or room["fields"].get("joiner_uid", "") != "":
		join_failed.emit("full")
		return
	# バージョンが違う相手とはマッチングしない(GameDesign.md 11章)。参加側で弾くため、
	# 作成側が版違いの相手を掴むことはない。
	var their_build: String = room["fields"].get("build", "")
	if not GameVersion.matches_build(their_build):
		join_failed.emit(
			"version_older" if GameVersion.is_newer_than_mine(their_build) else "version_newer"
		)
		return

	# 持ち時間は部屋を作った側が決めたものに従う(GameDesign.md 5章)。この機能より前に
	# 作られた部屋は値を持たないため、既定の「入」として扱う。
	time_limit = bool(room["fields"].get("time_limit", true))

	var creator_uid: String = room["fields"].get("creator_uid", "")
	var new_match_id := MatchIdGenerator.generate()
	# 先手・後手はここで五分五分に振る(GameDesign.md 11章)。参加した側だけが1度振り、
	# 両者は書かれた player_a / player_b を読んで自分の側を決める。
	var sides := MatchSides.assign(creator_uid, auth.uid)
	sides["created_at"] = Time.get_unix_time_from_system()
	# ルームの更新とmatches/{id}の作成を1回のcommitで原子的に行う。別書き込みにすると、
	# 作成側がmatch_idを見てmatches/{id}を読んだときにplayer_a/player_bがまだ空という窓が
	# でき、その窓に入ると双方が後手(side B)と判定されて対局が始まらない
	# (Architecture.md 6.1節)。
	var claimed: bool = await client.commit(
		[
			client.update_write(
				_doc_path(code),
				{"joiner_uid": auth.uid, "match_id": new_match_id},
				{"updateTime": room["update_time"]}
			),
			client.update_write("matches/%s" % new_match_id, sides, {"exists": false})
		]
	)
	if not claimed:
		join_failed.emit("race_lost")
		return

	_my_match_id = new_match_id
	_is_host = false
	room_ready.emit(new_match_id, creator_uid, false)
	await _wait_for_start()


func cancel() -> void:
	_cancelled = true
	if _code != "":
		await client.delete_document(_doc_path(_code))


## ホストが対局開始のタイミングを決める。参加者が入っただけでは開始しない。
func start_room() -> bool:
	if not _is_host or _code.is_empty() or _my_match_id.is_empty() or _cancelled:
		return false
	var room := await client.get_document_meta(_doc_path(_code))
	if not room.get("exists", false) or room["fields"].get("match_id", "") != _my_match_id:
		return false
	return await client.commit(
		[
			client.update_write(
				_doc_path(_code), {"started": true}, {"updateTime": room["update_time"]}
			)
		]
	)


## 観戦用にコードからmatch_idを取得する。**対局がまだ始まっていなければ弾かずに待つ**
## (GameDesign.md 11章)。版の突き合わせは待ち始める前に済ませる(版が違う部屋を
## 待ち続けても、始まった瞬間に弾かれるだけのため)。
func spectate(code: String) -> void:
	_cancelled = false
	var waiting_announced := false
	while not _cancelled:
		var room: Dictionary = await client.get_document_meta(_doc_path(code))
		if not room["exists"]:
			spectate_failed.emit("not_found")
			return
		# 観戦も同じ扱い。盤面は手の並びから作り直すため、版が違えば同じように食い違う。
		var their_build: String = room["fields"].get("build", "")
		if not GameVersion.matches_build(their_build):
			spectate_failed.emit(
				"version_older" if GameVersion.is_newer_than_mine(their_build) else "version_newer"
			)
			return
		time_limit = bool(room["fields"].get("time_limit", true))
		var match_id: String = room["fields"].get("match_id", "")
		# started が無いのは旧版で既に成立した部屋。match_id がある旧部屋は
		# 既に対局中として扱い、更新後の待機部屋(false)とは区別する。
		if match_id != "" and bool(room["fields"].get("started", true)):
			spectate_ready.emit(match_id)
			return
		if not waiting_announced:
			waiting_announced = true
			spectate_waiting.emit()
		await get_tree().create_timer(POLL_INTERVAL_SECONDS).timeout


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
			room_ready.emit(match_id, joiner_uid, true)
			await _wait_for_start()
			return


func _wait_for_start() -> void:
	while not _cancelled:
		var room := await client.get_document(_doc_path(_code))
		if room.is_empty():
			room_closed.emit()
			return
		if bool(room.get("started", true)):
			matched.emit(_my_match_id, room.get("joiner_uid", ""))
			return
		await get_tree().create_timer(POLL_INTERVAL_SECONDS).timeout


func _doc_path(code: String) -> String:
	return "%s/%s" % [COLLECTION, code]


## その番号で部屋を作る。空いていれば作り、埋まっていても**古くて対局が始まって
## いない部屋なら番号ごと引き取る**(GameDesign.md 11章)。引き取りは `updateTime` を
## 前提条件にした1回の commit で行い、同時に掴もうとした相手がいれば失敗させる。
func _claim_code(code: String, p_time_limit: bool) -> bool:
	var fields := {
		"creator_uid": auth.uid,
		"joiner_uid": "",
		"match_id": "",
		"started": false,
		"created_at": Time.get_unix_time_from_system(),
		"build": GameVersion.build_id(),
		"time_limit": p_time_limit
	}
	if await client.create_document(_doc_path(code), fields):
		return true
	var room: Dictionary = await client.get_document_meta(_doc_path(code))
	if not room["exists"] or not _is_stale(room["fields"]):
		return false
	return await client.commit(
		[client.update_write(_doc_path(code), fields, {"updateTime": room["update_time"]})]
	)


func _is_stale(fields: Dictionary) -> bool:
	if fields.get("match_id", "") != "":
		return false
	var created_at := float(fields.get("created_at", 0.0))
	return Time.get_unix_time_from_system() - created_at > STALE_SECONDS


## 番号を1つ引く。テストから形を確かめられるよう static にしてある。
static func random_code() -> String:
	var code := ""
	for _i in range(CODE_LENGTH):
		code += str(randi() % 10)
	return code
