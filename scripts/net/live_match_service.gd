class_name LiveMatchService
extends RefCounted
## ランクマッチの観戦一覧(GameDesign.md 12章、Architecture.md 7.2節)。
## いま進んでいる対局を `matches` から探し、行に出す両者の名前・段位を添えて返す。

## `matches/{id}.kind` の値。対局を作る側が書く。
const KIND_RANKED := "ranked"
const KIND_ROOM := "room"
const KIND_RANDOM := "random"
const COLLECTION := "matches"
## 一覧に出す上限と、そのために新しい順に読む件数(終わった対局を読み飛ばす余裕を持たせる)。
const LIST_LIMIT := 10
const QUERY_LIMIT := 40
## 最後の書き込みからこれ以上経った対局は、両者とも去ったものとみなす。
## 持ち時間(1手番60秒)を切れば時間切れの手が書かれるため、3手番ぶん黙っていれば生きていない。
const LIVE_SECONDS := 180.0
const FIELDS := [
	"kind", "build", "player_a", "player_b", "deck_b", "seed", "finished_at", "abandoned", "actions"
]
## 手番を終える手。ターン数はこの数 + 1。
const TURN_ENDING_ACTIONS := ["end_turn", "time_up"]


## 観戦できるランクマッチを新しい順に返す。1件は
## {"match_id", "turn", "a": プロフィール, "b": プロフィール}。
static func list_live(client: FirestoreClient) -> Array[Dictionary]:
	var docs: Array = await client.query_recent(COLLECTION, "created_at", QUERY_LIMIT, FIELDS)
	var entries: Array[Dictionary] = []
	for doc: Dictionary in docs:
		if entries.size() >= LIST_LIMIT:
			break
		if not is_live(doc):
			continue
		var fields: Dictionary = doc["fields"]
		entries.append(
			{
				"match_id": str(doc["id"]),
				"turn": turn_of(fields.get("actions", [])),
				"a": await _fetch_player(client, str(fields.get("player_a", ""))),
				"b": await _fetch_player(client, str(fields.get("player_b", "")))
			}
		)
	return entries


## クエリ結果の1件が「同じ版のランクマッチで、始まっていて、まだ続いている」か。
## 古さは端末の時計でなくサーバー時刻どうしで比べる(Pitfalls.md)。
static func is_live(doc: Dictionary) -> bool:
	var fields: Dictionary = doc.get("fields", {})
	if str(fields.get("kind", "")) != KIND_RANKED:
		return false
	if not GameVersion.matches_build(str(fields.get("build", ""))):
		return false
	if not fields.has("seed") or (fields.get("deck_b", []) as Array).is_empty():
		return false
	if fields.has("finished_at") or bool(fields.get("abandoned", false)):
		return false
	var read_at := FirestoreCodec.timestamp_seconds(str(doc.get("read_time", "")))
	var updated_at := FirestoreCodec.timestamp_seconds(str(doc.get("update_time", "")))
	return read_at - updated_at <= LIVE_SECONDS


static func turn_of(actions: Array) -> int:
	var turn := 1
	for action in actions:
		if action is Dictionary and TURN_ENDING_ACTIONS.has(str(action.get("type", ""))):
			turn += 1
	return turn


static func _fetch_player(client: FirestoreClient, uid: String) -> Dictionary:
	if uid.is_empty():
		return {}
	return await client.get_document("%s/%s" % [AccountService.COLLECTION, uid])
