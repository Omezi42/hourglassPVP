extends RefCounted
## 待っている間のCPU戦(GameDesign.md 11章)。キューの掴み方とCPUのデッキ選びを、
## 差し替え用クライアント(FakeFirestoreClient)の上で実通信なしに確かめる。

const FakeClient = preload("res://tools/tests/fake_firestore_client.gd")
const QUEUE := "matchmaking_queue"

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	await _test_does_not_claim_cpu_player()
	await _test_cpu_player_hears_others()
	_test_playable_decks()
	_test_ranked_queue_collection()
	await _test_count_waiting()


func _test_does_not_claim_cpu_player() -> void:
	var queue := _make_queue("uid-me")
	_add_waiter(queue, "uid-other", true)
	var claimed: bool = await queue._try_claim_or_check()
	_assert.call(not claimed, "CPU戦をしている待機者は掴まないこと")
	_free_queue(queue)


func _test_cpu_player_hears_others() -> void:
	var queue := _make_queue("uid-me")
	_add_waiter(queue, "uid-other", false)
	await queue.set_cpu_playing(true)
	var heard := [[]]
	queue.others_waiting.connect(func(uids: Array) -> void: heard[0] = uids)
	var claimed: bool = await queue._try_claim_or_check()
	_assert.call(not claimed, "CPU戦の最中は自分から掴まないこと")
	_assert.call(heard[0] == ["uid-other"], "CPU戦の最中は待機者を知らせること")
	_assert.call(
		bool(queue.client.store["%s/uid-me" % QUEUE]["fields"].get("cpu", false)), "CPU戦の印をキューへ書くこと"
	)
	await queue.set_cpu_playing(false)
	claimed = await queue._try_claim_or_check()
	_assert.call(claimed, "CPU戦をやめたら通常どおり掴むこと")
	_free_queue(queue)


func _test_playable_decks() -> void:
	var full: Array = []
	for card in CardLibrary.all_cards().slice(0, MatchState.DECK_SIZE / CardDeckSave.COPY_LIMIT):
		for copy in CardDeckSave.COPY_LIMIT:
			full.append(card.id)
	var missing := full.duplicate()
	missing[0] = "no_such_card"
	var over := full.duplicate()
	over[2] = full[0]
	var records := [{"fields": {"deck_a": full, "deck_b": missing}}, {"fields": {"deck_a": over}}]
	var decks := WaitingCpuDeck.playable_decks(records)
	_assert.call(decks.size() == 1, "今の版で組めるデッキだけを残すこと")
	_assert.call(
		decks.size() == 1 and decks[0].size() == MatchState.DECK_SIZE, "残したデッキは30枚そろっていること"
	)


func _test_ranked_queue_collection() -> void:
	var queue := RankedMatchmakingQueue.new(null, FirebaseAuth.new(null))
	_assert.call(queue.collection == "ranked_queue", "ランクマッチは別の待合室を使うこと")
	queue.free()


## ホームへ出す待機人数(GameDesign.md 9章)は、掴める相手だけを数える。
func _test_count_waiting() -> void:
	var queue := _make_queue("uid-me")
	var client = queue.client
	var ranked := RankedMatchmakingQueue.RANKED_COLLECTION
	for waiter: Array in [
		["uid-me", GameVersion.build_id(), ""],
		["uid-other", GameVersion.build_id(), ""],
		["uid-old", "19990101-000000", ""],
		["uid-matched", GameVersion.build_id(), "m1"],
	]:
		client.store["%s/%s" % [ranked, waiter[0]]] = {
			"fields": {"match_id": waiter[2], "build": waiter[1]}, "update_time": "1"
		}
	var count: int = await RankedMatchmakingQueue.count_waiting(client, "uid-me")
	_assert.call(count == 1, "自分・違う版・成立済みを除いて数えること")
	_free_queue(queue)


func _add_waiter(queue: MatchmakingQueue, uid: String, cpu: bool) -> void:
	queue.client.store["%s/%s" % [QUEUE, uid]] = {
		"fields":
		{
			"joined_at": Time.get_unix_time_from_system(),
			"match_id": "",
			"build": GameVersion.build_id(),
			"cpu": cpu
		},
		"update_time": "1"
	}


func _make_queue(uid: String) -> MatchmakingQueue:
	var tree := Engine.get_main_loop() as SceneTree
	var auth := FirebaseAuth.new(null)
	auth.uid = uid
	var client = FakeClient.new(auth)
	tree.root.add_child(client)
	var queue := MatchmakingQueue.new(client, auth)
	_add_waiter(queue, uid, false)
	tree.root.add_child(queue)
	return queue


func _free_queue(queue: MatchmakingQueue) -> void:
	queue.client.queue_free()
	queue.queue_free()
