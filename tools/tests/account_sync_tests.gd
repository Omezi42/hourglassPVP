extends RefCounted
## デッキ・遠征・とどめ問題・デイリーミッションのアカウント同期
## (GameDesign.md 14章「アカウントに紐づけるもの」/ Architecture.md 10.23節)の検証。
## `FakeFirestoreClient` で引く/押すを実通信なしで確かめる。デッキの控えは `run_tests.gd` が
## テスト用のファイルへ差し替えてある。

const FakeClient = preload("res://tools/tests/fake_firestore_client.gd")
const UID := "account-sync-test-uid"


func run(assert_true: Callable) -> void:
	SoloProgress.reset_for_test()
	PuzzleProgress.reset_for_test()
	DailyMissionService.reset_for_test()
	await _test_legacy_decks_are_uploaded(assert_true)
	await _test_account_decks_replace_local(assert_true)
	await _test_other_accounts_decks_are_dropped(assert_true)
	await _test_unsent_decks_win(assert_true)
	await _test_solo_pull_and_push(assert_true)
	await _test_puzzles_are_merged(assert_true)
	await _test_missions_are_merged(assert_true)
	AccountSyncService.reset()


func _test_legacy_decks_are_uploaded(assert_true: Callable) -> void:
	var client = _make_client()
	_write_local_decks({"decks": [_deck_entry("いち")], "selected": 0})
	await AccountSyncService.sync_after_sign_in(client, UID, {})
	var fields: Dictionary = client.store[AccountService.path(UID)]["fields"]
	assert_true.call(
		(fields.get("decks", []) as Array).size() == 1,
		"decks saved before syncing existed should be uploaded to an account that has none"
	)
	var snap := CardDeckSave.sync_snapshot()
	assert_true.call(
		snap["owner"] == UID and not bool(snap["dirty"]),
		"after uploading, the local copy should belong to the account and be clean"
	)
	client.queue_free()


func _test_account_decks_replace_local(assert_true: Callable) -> void:
	var client = _make_client()
	_write_local_decks({"owner": "someone-else", "decks": [_deck_entry("いち")], "selected": 0})
	var remote := {"decks": [_deck_entry("に"), _deck_entry("さん")], "deck_selected": 1}
	await AccountSyncService.sync_after_sign_in(client, UID, remote)
	var decks := CardDeckSave.list_decks()
	assert_true.call(
		decks.size() == 2 and decks[0]["name"] == "に",
		"the account's decks should replace the local copy on sign-in"
	)
	assert_true.call(CardDeckSave.selected_index() == 1, "the selected deck should come along")
	client.queue_free()


func _test_other_accounts_decks_are_dropped(assert_true: Callable) -> void:
	var client = _make_client()
	_write_local_decks({"owner": "logged-out-uid", "decks": [_deck_entry("いち")], "selected": 0})
	await AccountSyncService.sync_after_sign_in(client, UID, {})
	assert_true.call(
		CardDeckSave.list_decks().is_empty(),
		"a fresh guest after logging out should not inherit the previous account's decks"
	)
	var fields: Dictionary = client.store[AccountService.path(UID)]["fields"]
	assert_true.call(not fields.has("decks"), "the previous account's decks should not be uploaded")
	client.queue_free()


func _test_unsent_decks_win(assert_true: Callable) -> void:
	var client = _make_client()
	_write_local_decks({"owner": UID, "dirty": true, "decks": [_deck_entry("てもと")], "selected": 0})
	await AccountSyncService.sync_after_sign_in(client, UID, {"decks": [_deck_entry("ふるい")]})
	var fields: Dictionary = client.store[AccountService.path(UID)]["fields"]
	assert_true.call(
		str(fields["decks"][0]["name"]) == "てもと",
		"decks changed offline and not yet sent should overwrite the account's copy"
	)
	assert_true.call(CardDeckSave.list_decks()[0]["name"] == "てもと", "the local copy should stay")
	client.queue_free()


func _test_solo_pull_and_push(assert_true: Callable) -> void:
	SoloProgress.reset_for_test()
	var client = _make_client()
	var remote := {"run": null, "best_wins": 7, "clears": 2, "milestones": [], "unlocked_depth": 3}
	await AccountSyncService.sync_after_sign_in(client, UID, {"solo_progress": remote})
	assert_true.call(
		SoloProgress.best_wins(UID) == 7 and SoloProgress.unlocked_depth(UID) == 3,
		"the account's expedition record should replace the local one"
	)
	SoloProgress.set_last_depth(UID, 2)
	assert_true.call(
		bool(SoloProgress.sync_snapshot(UID)["dirty"]),
		"a change that could not be sent (no NetSession client) should stay marked as unsent"
	)
	await AccountSyncService.sync_after_sign_in(client, UID, {"solo_progress": remote})
	var fields: Dictionary = client.store[AccountService.path(UID)]["fields"]
	var pushed: Dictionary = fields["solo_progress"]
	assert_true.call(
		int(pushed.get("last_depth", -1)) == 2 and not pushed.has(SoloProgress.SYNC_DIRTY),
		"the unsent change should win on the next sign-in, without the bookkeeping fields"
	)
	assert_true.call(
		not bool(SoloProgress.sync_snapshot(UID)["dirty"]), "once sent, the mark should clear"
	)
	client.queue_free()


func _test_puzzles_are_merged(assert_true: Callable) -> void:
	PuzzleProgress.reset_for_test()
	var client = _make_client()
	PuzzleProgress.mark_cleared(UID, "local-only")
	await AccountSyncService.sync_after_sign_in(client, UID, {"puzzle_cleared": ["remote-only"]})
	assert_true.call(
		PuzzleProgress.is_cleared(UID, "remote-only"),
		"a puzzle cleared on another device should count as cleared here (no second reward)"
	)
	var pushed: Array = client.store[AccountService.path(UID)]["fields"]["puzzle_cleared"]
	assert_true.call(
		pushed.has("local-only") and pushed.has("remote-only"),
		"the account should end up with the union of both devices' clears"
	)
	client.queue_free()


func _test_missions_are_merged(assert_true: Callable) -> void:
	DailyMissionService.reset_for_test()
	var client = _make_client()
	var today := DailyMissionService.bucket_snapshot(UID)
	var ids: Array = today["ids"]
	var other := DailyMissionService.bucket_snapshot(UID)
	other["progress"] = {ids[0]: 3, ids[1]: 1}
	DailyMissionService.merge_remote(UID, other)
	var remote := {"date": today["date"], "ids": ids, "progress": {ids[1]: 5}, "claimed": [ids[2]]}
	await AccountSyncService.sync_after_sign_in(client, UID, {"daily_missions": remote})
	var merged := DailyMissionService.bucket_snapshot(UID)
	assert_true.call(
		int(merged["progress"][ids[0]]) == 3 and int(merged["progress"][ids[1]]) == 5,
		"same-day mission progress should take the larger of the two"
	)
	assert_true.call(
		(merged["claimed"] as Array).has(ids[2]),
		"a reward claimed on another device should not be claimable again here"
	)
	var pushed: Dictionary = client.store[AccountService.path(UID)]["fields"]["daily_missions"]
	assert_true.call(
		int(pushed["progress"][ids[0]]) == 3, "progress only this device had should be sent"
	)
	var stale := {"date": "2000-01-01", "ids": [], "progress": {}, "claimed": ids.duplicate()}
	DailyMissionService.merge_remote(UID, stale)
	assert_true.call(
		not (DailyMissionService.bucket_snapshot(UID)["claimed"] as Array).has(ids[0]),
		"an older day's claims should not leak into today"
	)
	client.queue_free()


func _write_local_decks(raw: Dictionary) -> void:
	var file := FileAccess.open(CardDeckSave.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()


func _deck_entry(deck_name: String) -> Dictionary:
	return {"name": deck_name, "ids": CardLibrary.ids_from_deck(CardDeckSave.default_deck())}


func _make_client():
	var tree := Engine.get_main_loop() as SceneTree
	var auth := FirebaseAuth.new(null)
	auth.uid = UID
	var client = FakeClient.new(auth)
	tree.root.add_child(client)
	return client
