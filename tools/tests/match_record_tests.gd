extends RefCounted
## 分析用の対局記録(GameDesign.md 22章 / Architecture.md 10.9節)を、
## 差し替え用クライアント(FakeFirestoreClient)の上で実通信なしに検証する。
##
## **確かめたいのは3点。**記録が1件だけ残ること(両者が書きにいっても二重にならない)、
## 集計が1局ぶんだけ増えること、そして記録を消さないこと。

const MATCH_ID := "m_rec"
const MATCH_PATH := "matches/m_rec"
const RECORD_PATH := "match_records/m_rec"
const SEED := 4242
const FakeClient = preload("res://tools/tests/fake_firestore_client.gd")

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	var tree := Engine.get_main_loop() as SceneTree
	var auth := FirebaseAuth.new(null)
	auth.uid = "uid-a"
	var client = FakeClient.new(auth)
	tree.root.add_child(client)
	var decks := _decks()
	client.store[MATCH_PATH] = {
		"fields":
		{
			"deck_a": CardLibrary.ids_from_deck(decks[0]),
			"deck_b": CardLibrary.ids_from_deck(decks[1]),
			"seed": SEED,
			"actions": [{"type": "end_turn", "side": 0}],
			"player_a": "uid-a",
			"player_b": "uid-b",
		},
		"update_time": "0"
	}

	var state := MatchState.new()
	tree.root.add_child(state)
	state.start_match(decks[0], decks[1], MatchState.Side.A, SEED)
	state.surrender(MatchState.Side.B)

	var first: bool = await MatchRecordService.submit(
		client, MATCH_ID, CurrencyRules.MatchKind.RANDOM, state
	)
	_assert.call(first, "the first writer should be able to record the match")
	var second: bool = await MatchRecordService.submit(
		client, MATCH_ID, CurrencyRules.MatchKind.RANDOM, state
	)
	_assert.call(not second, "the second writer should lose the race and record nothing")

	var record: Dictionary = client.store[RECORD_PATH]["fields"]
	_assert.call(record["winner"] == "a", "the surrendering side should not be the winner")
	_assert.call(
		record["end_reason"] == "surrender", "the end reason should be kept as a stable string"
	)
	_assert.call(record["kind"] == "random", "the match kind should be kept")
	_assert.call(
		(record["deck_a"] as Array).size() == MatchState.DECK_SIZE,
		"both decks should be copied from the match document"
	)
	_assert.call(
		(record["actions"] as Array).size() == 1, "the recorded actions should come from the match"
	)
	_assert.call(record["player_b"] == "uid-b", "both player ids should be kept")

	_assert_stats(client, decks)
	state.queue_free()
	client.queue_free()


## 集計は**記録を書けた側だけ**が更新するため、2回呼んでも1局ぶんしか増えない。
func _assert_stats(client, decks: Array) -> void:
	var stats: Dictionary = client.store[MatchRecordService.STATS_PATH]["fields"]
	var counts: Dictionary = stats["counts"]
	_assert.call(int(counts["games"]) == 1, "a match should be counted exactly once")
	_assert.call(int(counts["first_wins"]) == 1, "the first player's win should be counted")
	_assert.call(int(counts["kind_random"]) == 1, "the match kind should be counted")
	_assert.call(int(counts["end_surrender"]) == 1, "the end reason should be counted")
	var cards: Dictionary = stats["cards"]
	var first_id: String = (decks[0][0] as CardData).id
	_assert.call(
		int(cards[first_id]["g"]) >= 1, "a card in the winning deck should be counted as played"
	)


## 同名2枚までを守った30枚を2つ作る。中身は問わないため id 順の先頭から取る。
func _decks() -> Array:
	var pool: Array = CardLibrary.sorted_by_cost()
	var deck_a: Array = []
	var deck_b: Array = []
	for card: CardData in pool:
		for _copy in 2:
			if deck_a.size() < MatchState.DECK_SIZE:
				deck_a.append(card)
			elif deck_b.size() < MatchState.DECK_SIZE:
				deck_b.append(card)
	return [deck_a, deck_b]
