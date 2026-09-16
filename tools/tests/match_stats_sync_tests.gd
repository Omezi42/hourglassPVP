extends RefCounted
## 戦績のFirestore同期(GameDesign.md 19章 / Architecture.md 10.7.0節)の検証。
## 前半は通信を伴わない`MatchStats`側の計算(`apply_delta`/`replace_bucket`)、
## 後半は`FakeFirestoreClient`で`MatchStatsService`の押す/引くを実通信なしで確かめる
## (`rank_tests.gd`と同じ流儀)。
## `run_tests.gd`が1000行の上限に近いため別ファイルへ切り出す(他のtestsと同じ流儀)。

const FakeClient = preload("res://tools/tests/fake_firestore_client.gd")


func run(assert_true: Callable) -> void:
	_test_apply_delta_accumulates(assert_true)
	_test_replace_bucket_overwrites(assert_true)
	await _test_push_without_client_queues_pending(assert_true)
	await _test_push_writes_through_fake_client(assert_true)
	await _test_sync_after_sign_in_pulls_and_reapplies_pending(assert_true)


func _test_apply_delta_accumulates(assert_true: Callable) -> void:
	var bucket := {}
	MatchStats.apply_delta(
		bucket, CurrencyRules.MatchKind.CPU, true, 10, ["sand", "sword"], "code-1"
	)
	MatchStats.apply_delta(bucket, CurrencyRules.MatchKind.CPU, false, 20, ["sand"], "code-1")
	assert_true.call(
		int(bucket["kinds"][str(CurrencyRules.MatchKind.CPU)]["games"]) == 2,
		"kinds should accumulate games across calls"
	)
	assert_true.call(
		int(bucket["cards"]["sand"]["games"]) == 2, "a card present in both calls should accumulate"
	)
	assert_true.call(
		int(bucket["cards"]["sword"]["games"]) == 1,
		"a card present in only one call should count once"
	)
	assert_true.call(
		int(bucket["decks"]["code-1"]["games"]) == 2, "the same deck code should accumulate"
	)


func _test_replace_bucket_overwrites(assert_true: Callable) -> void:
	var uid := "match-stats-sync-test-local"
	var backup := MatchStats.bucket_snapshot(uid)
	MatchStats.replace_bucket(
		uid, {"0": {"games": 3, "wins": 1, "turns": 30}}, {"sand": {"games": 3, "wins": 1}}, {}
	)
	var snap := MatchStats.bucket_snapshot(uid)
	assert_true.call(int(snap["kinds"]["0"]["games"]) == 3, "replace_bucket should overwrite kinds")
	assert_true.call(
		int(snap["cards"]["sand"]["games"]) == 3, "replace_bucket should overwrite cards"
	)
	MatchStats.replace_bucket(uid, backup["kinds"], backup["cards"], backup["decks"])


func _test_push_without_client_queues_pending(assert_true: Callable) -> void:
	AccountStore.clear_pending_matches()
	var deck: Array[CardData] = [CardLibrary.find_by_id("sand")]
	await MatchStatsService.push(null, "", CurrencyRules.MatchKind.CPU, true, 15, deck)
	assert_true.call(
		AccountStore.get_pending_matches().size() == 1,
		"pushing without a client should queue the entry locally instead of losing it"
	)
	AccountStore.clear_pending_matches()


func _test_push_writes_through_fake_client(assert_true: Callable) -> void:
	var setup := _make_client()
	var client = setup["client"]
	var uid: String = setup["uid"]
	var path := AccountService.path(uid)
	var deck: Array[CardData] = [CardLibrary.find_by_id("sand"), CardLibrary.find_by_id("sword")]

	await MatchStatsService.push(client, uid, CurrencyRules.MatchKind.CPU, true, 12, deck)
	var fields: Dictionary = client.store[path]["fields"]
	assert_true.call(
		int(fields["stats_kinds"][str(CurrencyRules.MatchKind.CPU)]["games"]) == 1,
		"pushing once should write a single game to stats_kinds"
	)
	assert_true.call(
		int(fields["stats_cards"]["sand"]["games"]) == 1, "pushing should write per-card stats"
	)

	await MatchStatsService.push(client, uid, CurrencyRules.MatchKind.CPU, false, 8, deck)
	fields = client.store[path]["fields"]
	assert_true.call(
		int(fields["stats_kinds"][str(CurrencyRules.MatchKind.CPU)]["games"]) == 2,
		"a second push should read-modify-write on top of the first (not overwrite it)"
	)
	assert_true.call(
		int(fields["stats_cards"]["sand"]["wins"]) == 1,
		"wins should only increase for the game that was actually won"
	)


func _test_sync_after_sign_in_pulls_and_reapplies_pending(assert_true: Callable) -> void:
	var uid := "match-stats-sync-test-remote"
	AccountStore.clear_pending_matches()
	AccountStore.add_pending_match(
		{
			"kind": CurrencyRules.MatchKind.CPU,
			"won": true,
			"turns": 5,
			"card_ids": ["sand"],
			"deck_code": ""
		}
	)
	var remote_fields := {
		"stats_kinds": {str(CurrencyRules.MatchKind.RANDOM): {"games": 4, "wins": 2, "turns": 90}},
		"stats_cards": {"sword": {"games": 4, "wins": 2}},
		"stats_decks": {},
	}
	# client=null(通信できない)のまま呼んでも、pull直後のローカルへ退避分が
	# 正しく重なって見えることだけを確かめる(送り直しは失敗してまた退避される)。
	await MatchStatsService.sync_after_sign_in(null, uid, remote_fields)
	var snap := MatchStats.bucket_snapshot(uid)
	assert_true.call(
		int(snap["cards"]["sword"]["games"]) == 4,
		"the remote snapshot should replace the local bucket"
	)
	assert_true.call(
		int(snap["cards"].get("sand", {}).get("games", 0)) == 1,
		"a still-pending local match should be re-applied on top of the pulled snapshot"
	)
	assert_true.call(
		AccountStore.get_pending_matches().size() == 1,
		"the entry should stay pending since there was still no client to send it through"
	)
	AccountStore.clear_pending_matches()


func _make_client() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var auth := FirebaseAuth.new(null)
	auth.uid = "match-stats-sync-test-uid"
	var client = FakeClient.new(auth)
	tree.root.add_child(client)
	return {"client": client, "host": tree.root, "uid": auth.uid}
