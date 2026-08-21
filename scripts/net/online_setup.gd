class_name OnlineSetup
extends Node

const POLL_INTERVAL_SECONDS := 2.0
## 配置は人間の操作待ちのため長めに取るが、待たされる側にも限度があるため約5分で打ち切る。
const MAX_POLL_ATTEMPTS := 150

var client: FirestoreClient
var match_id: String
var my_side: GameState.PlayerSide
## 待機が中断された理由("cancelled" / "abandoned" / "timeout")。空なら正常。
var abort_reason: String = ""

var _cancelled := false


func _init(p_client: FirestoreClient, p_match_id: String, p_my_side: GameState.PlayerSide) -> void:
	client = p_client
	match_id = p_match_id
	my_side = p_my_side


func push_deck(deck_ids: Array[String]) -> void:
	if _cancelled:
		return
	var field := "deck_a" if my_side == GameState.PlayerSide.A else "deck_b"
	await client.set_document("matches/%s" % match_id, {field: deck_ids})


func wait_for_opponent_deck() -> Array[String]:
	var field := "deck_b" if my_side == GameState.PlayerSide.A else "deck_a"
	return await _poll_for_ids(field)


func push_placement(board_ids: Array[String]) -> void:
	if _cancelled:
		return
	var field := "placement_a" if my_side == GameState.PlayerSide.A else "placement_b"
	await client.set_document("matches/%s" % match_id, {field: board_ids})


func wait_for_opponent_placement() -> Array[String]:
	var field := "placement_b" if my_side == GameState.PlayerSide.A else "placement_a"
	return await _poll_for_ids(field)


## 対局が始まる前の待機を中断する(GameDesign.md 11章)。ポーリングを即座に打ち切り、
## 待っている相手が永久に待たされないようmatches/{id}へabandonedを書き残す。
func cancel() -> void:
	if _cancelled:
		return
	_cancelled = true
	abort_reason = "cancelled"
	await client.set_document("matches/%s" % match_id, {"abandoned": true})


## 中断の理由を画面に出す文言。正常に終わった場合は空文字。
func abort_message() -> String:
	match abort_reason:
		"abandoned":
			return "対戦相手が対局を取りやめました"
		"timeout":
			return "対戦相手の応答がありません。通信状態を確認してください"
		_:
			return ""


func _poll_for_ids(field: String) -> Array[String]:
	abort_reason = ""
	for _attempt in range(MAX_POLL_ATTEMPTS):
		if _cancelled:
			abort_reason = "cancelled"
			return []
		var doc: Dictionary = await client.get_document("matches/%s" % match_id)
		if bool(doc.get("abandoned", false)):
			abort_reason = "abandoned"
			return []
		var raw: Array = doc.get(field, [])
		if raw.size() > 0:
			var result: Array[String] = []
			for id in raw:
				result.append(str(id))
			return result
		await get_tree().create_timer(POLL_INTERVAL_SECONDS).timeout
	abort_reason = "timeout"
	return []
