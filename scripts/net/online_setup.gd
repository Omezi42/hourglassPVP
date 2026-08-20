class_name OnlineSetup
extends Node

const POLL_INTERVAL_SECONDS := 2.0
const MAX_POLL_ATTEMPTS := 300

var client: FirestoreClient
var match_id: String
var my_side: GameState.PlayerSide


func _init(p_client: FirestoreClient, p_match_id: String, p_my_side: GameState.PlayerSide) -> void:
	client = p_client
	match_id = p_match_id
	my_side = p_my_side


func push_deck(deck_ids: Array[String]) -> void:
	var field := "deck_a" if my_side == GameState.PlayerSide.A else "deck_b"
	await client.set_document("matches/%s" % match_id, {field: deck_ids})


func wait_for_opponent_deck() -> Array[String]:
	var field := "deck_b" if my_side == GameState.PlayerSide.A else "deck_a"
	return await _poll_for_ids(field)


func push_placement(board_ids: Array[String]) -> void:
	var field := "placement_a" if my_side == GameState.PlayerSide.A else "placement_b"
	await client.set_document("matches/%s" % match_id, {field: board_ids})


func wait_for_opponent_placement() -> Array[String]:
	var field := "placement_b" if my_side == GameState.PlayerSide.A else "placement_a"
	return await _poll_for_ids(field)


func _poll_for_ids(field: String) -> Array[String]:
	for _attempt in range(MAX_POLL_ATTEMPTS):
		var doc: Dictionary = await client.get_document("matches/%s" % match_id)
		var raw: Array = doc.get(field, [])
		if raw.size() > 0:
			var result: Array[String] = []
			for id in raw:
				result.append(str(id))
			return result
		await get_tree().create_timer(POLL_INTERVAL_SECONDS).timeout
	return []
