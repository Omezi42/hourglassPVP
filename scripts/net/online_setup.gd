class_name OnlineSetup
extends Node

const POLL_INTERVAL_SECONDS := 2.0
## 配置は人間の操作待ちのため長めに取るが、待たされる側にも限度があるため約5分で打ち切る。
const MAX_POLL_ATTEMPTS := 150

var client: FirestoreClient
var match_id: String
## 自分の側。GameState.PlayerSide と MatchState.Side はどちらも 0/1 のため int で受ける。
var my_side: int
## 待機が中断された理由("cancelled" / "abandoned" / "timeout")。空なら正常。
var abort_reason: String = ""

var _cancelled := false


func _init(p_client: FirestoreClient, p_match_id: String, p_my_side: int) -> void:
	client = p_client
	match_id = p_match_id
	my_side = p_my_side


func push_deck(deck_ids: Array[String]) -> void:
	if _cancelled:
		return
	var field := "deck_a" if my_side == 0 else "deck_b"
	await client.set_document("matches/%s" % match_id, {field: deck_ids})


func wait_for_opponent_deck() -> Array[String]:
	var field := "deck_b" if my_side == 0 else "deck_a"
	return await _poll_for_ids(field)


func push_placement(board_ids: Array[String]) -> void:
	if _cancelled:
		return
	var field := "placement_a" if my_side == 0 else "placement_b"
	await client.set_document("matches/%s" % match_id, {field: board_ids})


func wait_for_opponent_placement() -> Array[String]:
	var field := "placement_b" if my_side == 0 else "placement_a"
	return await _poll_for_ids(field)


## v5.0の準備。配置フェーズが無いため、デッキ(20枚)と**山札のシャッフルに使う種**だけを
## やり取りする。種は先手が決めて書き、後手はそれを読む。
##
## **両者が同じ種で同じ手順を再現する**ため、相手の山札の並びも手元で計算できてしまう。
## クライアントを信頼する方針(GameDesign.md 11章)の範囲として許容しているが、
## 不正対策を入れる際はここが最初の対象になる。
func push_setup(deck_ids: Array[String], seed_value: int) -> void:
	if _cancelled:
		return
	var fields := {"deck_a" if my_side == 0 else "deck_b": deck_ids}
	if my_side == 0:
		fields["seed"] = seed_value
	await client.set_document("matches/%s" % match_id, fields)


## 相手のデッキと、対局で使う種を受け取る。{"deck": Array[String], "seed": int}。
## 種が届かない・先手自身の場合は seed_value をそのまま返す。
func wait_for_opponent_setup(seed_value: int) -> Dictionary:
	var deck := await wait_for_opponent_deck()
	if deck.is_empty():
		return {"deck": deck, "seed": seed_value}
	if my_side == 0:
		return {"deck": deck, "seed": seed_value}
	var doc: Dictionary = await client.get_document("matches/%s" % match_id)
	return {"deck": deck, "seed": int(doc.get("seed", seed_value))}


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
