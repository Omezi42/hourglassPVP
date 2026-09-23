class_name WaitingCpuDeck
extends RefCounted
## 待っている間のCPU戦(GameDesign.md 11章)でCPUに渡すデッキを選ぶ。
## 他のプレイヤーが実際に組んだデッキを使うため、オンライン対戦の記録(22章)の直近から
## 1つ選ぶ。持ち主は画面に出さないので、記録からはデッキだけを読む。

const RECORDS := "match_records"
const RECENT_LIMIT := 30
const FIELDS := ["deck_a", "deck_b"]


static func pick(client: FirestoreClient) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var records: Array = await client.query_recent(RECORDS, "finished_at", RECENT_LIMIT, FIELDS)
	var decks := playable_decks(records)
	if decks.is_empty():
		return CardDeckSave.random_deck(rng)
	return decks[rng.randi_range(0, decks.size() - 1)]


## いまの版でそのまま組めるデッキだけを残す。消えたカード・変わった枚数の制限を含む
## 記録は、欠けたまま使うと30枚に満たない山札で対局が始まってしまうため除く。
static func playable_decks(records: Array) -> Array:
	var decks: Array = []
	for record in records:
		var fields: Dictionary = record.get("fields", {})
		for key in FIELDS:
			var ids: Array = fields.get(key, [])
			var cards := CardLibrary.deck_from_ids(ids)
			if ids.size() == MatchState.DECK_SIZE and cards.size() == ids.size():
				if _within_copy_limit(ids):
					decks.append(cards)
	return decks


static func _within_copy_limit(ids: Array) -> bool:
	var counts := {}
	for id in ids:
		counts[id] = int(counts.get(id, 0)) + 1
		if counts[id] > CardDeckSave.COPY_LIMIT:
			return false
	return true
