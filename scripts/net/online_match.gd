class_name OnlineMatch
extends Node

signal action_received(action: Dictionary)
## 送受信が続けて失敗している/回復したことをUIへ伝える(GameDesign.md 11章)。
signal connection_changed(online: bool)

const POLL_INTERVAL_SECONDS := 1.5
const POLL_BACKOFF_MAX := 8.0
const POLL_BACKOFF_FACTOR := 1.6
const SEND_RETRY_COUNT := 4
const SEND_RETRY_DELAY := 0.5
## これだけ連続で失敗したら「接続できていない」とみなす。1回の失敗で警告を出すと、
## 一時的な遅延のたびに表示が点滅するため。
const FAILURE_THRESHOLD := 2

var client: FirestoreClient
var match_id: String = ""
var connected := true
var _known_action_count: int = 0
var _polling := false
var _sending := false
var _failures := 0
var _my_uid := ""
var _send_queue: Array = []
## 受け取った手の待ち行列。受け取る側は1手ごとに演出でawaitすることがあるため、
## 同時に2件流し込むとターン進行が二重に走る。1ポーリングにつき1件だけ配る
## (Architecture.md 6.1節)。適用そのものは MatchAction が受け持つ。
var _inbox: Array = []
var _poll_delay := POLL_INTERVAL_SECONDS


func _init(p_client: FirestoreClient) -> void:
	client = p_client


## p_known_action_countは、既に手元で反映済みのaction件数(観戦を対局途中から
## 開始する場合など)。指定した件数以前のactionはaction_receivedとして再送しない。
func start(p_match_id: String, p_known_action_count: int = 0) -> void:
	match_id = p_match_id
	_known_action_count = p_known_action_count
	_my_uid = client.auth.uid if client != null and client.auth != null else ""
	_polling = true
	_poll_loop()


## ポーリングと送信を止める。**ノードの解放は行わない**。ポーリング・送信のコルーチンが
## awaitの途中で残っている可能性があり、解放すると「Resumed function on a freed object」に
## なるため。_pollingをfalseにした時点で以降は何もしない不活性なノードとして残す。
func stop() -> void:
	_polling = false
	_send_queue.clear()
	_inbox.clear()


func is_busy() -> bool:
	return _sending or not _send_queue.is_empty()


## 1手を送信キューへ積む。順序と重複を保証するため、実際の書き込みは1件ずつ直列に行う。
func send(action: Dictionary) -> void:
	var payload := action.duplicate(true)
	# 自分が書いた手をポーリングが拾って二重に適用しないための印(Architecture.md 6.1節)。
	# OnlineMatch.apply()もリプレイ再生も参照しない追加キーのため、棋譜の互換性は保たれる。
	payload["by"] = _my_uid
	_send_queue.append(payload)
	if not _sending:
		_send_worker()


func _path() -> String:
	return "matches/%s" % match_id


func _send_worker() -> void:
	_sending = true
	while not _send_queue.is_empty():
		var payload: Dictionary = _send_queue.pop_front()
		var ok: bool = await _write_action(payload)
		_note_result(ok)
	_sending = false


## actionsへの追記を、updateTimeを前提条件にしたcommitで行う。競合(相手が同時に投了した等)
## や一時的な失敗の場合はドキュメントを読み直して再試行する。
func _write_action(payload: Dictionary) -> bool:
	for attempt in range(SEND_RETRY_COUNT):
		var meta: Dictionary = await client.get_document_meta(_path())
		if not meta["exists"]:
			return false
		var actions: Array = meta["fields"].get("actions", [])
		actions.append(payload)
		var result: Dictionary = await client.commit_detailed(
			[
				client.update_write(
					_path(), {"actions": actions}, {"updateTime": meta["update_time"]}
				)
			]
		)
		if result["ok"]:
			return true
		if attempt < SEND_RETRY_COUNT - 1:
			await get_tree().create_timer(SEND_RETRY_DELAY * (attempt + 1)).timeout
	return false


func _poll_loop() -> void:
	while _polling:
		await get_tree().create_timer(_poll_delay).timeout
		if not _polling:
			return
		# 送信中は同じドキュメントを読み書きしているため、読み取りを重ねない
		if not _sending:
			await _fetch()
		if not _polling:
			return
		_deliver_one()


func _fetch() -> void:
	var meta: Dictionary = await client.get_document_meta(_path())
	if not meta["exists"]:
		_note_result(false)
		return
	_note_result(true)
	var actions: Array = meta["fields"].get("actions", [])
	if actions.size() <= _known_action_count:
		return
	for i in range(_known_action_count, actions.size()):
		var action: Variant = actions[i]
		if typeof(action) != TYPE_DICTIONARY:
			continue
		if _my_uid != "" and str((action as Dictionary).get("by", "")) == _my_uid:
			continue
		_inbox.append(action)
	_known_action_count = actions.size()


func _deliver_one() -> void:
	if _inbox.is_empty():
		return
	action_received.emit(_inbox.pop_front())


func _note_result(ok: bool) -> void:
	if ok:
		_failures = 0
		_poll_delay = POLL_INTERVAL_SECONDS
		_set_connected(true)
		return
	_failures += 1
	_poll_delay = minf(_poll_delay * POLL_BACKOFF_FACTOR, POLL_BACKOFF_MAX)
	if _failures >= FAILURE_THRESHOLD:
		_set_connected(false)


func _set_connected(value: bool) -> void:
	if connected == value:
		return
	connected = value
	connection_changed.emit(value)
