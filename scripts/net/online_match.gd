class_name OnlineMatch
extends Node

signal action_received(action: Dictionary)

const POLL_INTERVAL_SECONDS := 2.0

var client: FirestoreClient
var match_id: String = ""
var _known_action_count: int = 0
var _polling := false


func _init(p_client: FirestoreClient) -> void:
	client = p_client


## p_known_action_countは、既に手元で反映済みのaction件数(観戦を対局途中から
## 開始する場合など)。指定した件数以前のactionはaction_receivedとして再送しない。
func start(p_match_id: String, p_known_action_count: int = 0) -> void:
	match_id = p_match_id
	_known_action_count = p_known_action_count
	_polling = true
	_poll_loop()


func stop() -> void:
	_polling = false


## 1手をGameStateへ反映し、同時に対戦相手へ送信する。
func send_and_apply(action: Dictionary, state: GameState) -> void:
	apply(action, state)
	await _send(action)


## 1手をGameStateへ反映する。flip/move/swap_in/passは「その手番の行動」として設定するだけで
## 盤面は動かさず、実際の適用は続く state.advance_and_end_turn() の解決で行われる
## (GameDesign.md 4.3・4.4)。surrenderのみ、盤面を変えずに即座に終局させる性質のため
## 予約の対象にせず従来どおり即時に適用する。
static func apply(action: Dictionary, state: GameState) -> void:
	match action.get("type", ""):
		"flip", "skill", "pass":
			state.set_pending_action(action)
		"move", "swap_in":
			# 基本行動としては廃止済み(GameDesign.md 4.3)。過去のリプレイの再生用に残している。
			state.set_pending_action(action)
		"surrender":
			state.surrender(action["side"])


func _send(action: Dictionary) -> void:
	var doc: Dictionary = await client.get_document("matches/%s" % match_id)
	var actions: Array = doc.get("actions", [])
	actions.append(action)
	await client.set_document("matches/%s" % match_id, {"actions": actions})
	_known_action_count = actions.size()


func _poll_loop() -> void:
	while _polling:
		await get_tree().create_timer(POLL_INTERVAL_SECONDS).timeout
		if not _polling:
			return
		var doc: Dictionary = await client.get_document("matches/%s" % match_id)
		var actions: Array = doc.get("actions", [])
		if actions.size() > _known_action_count:
			for i in range(_known_action_count, actions.size()):
				action_received.emit(actions[i])
			_known_action_count = actions.size()
