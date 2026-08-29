extends RefCounted
## バージョンが違う相手とマッチングしないこと(GameDesign.md 11章)を、
## 差し替え用クライアント(FakeFirestoreClient)の上で実通信なしに検証する。
##
## 確かめたいのは2点。**同じビルドの相手だけを掴むこと**と、**掴めなかったことが
## 画面へ返ること**(黙って待ち続けると「マッチングしない不具合」にしか見えない)。

const FakeClient = preload("res://tools/tests/fake_firestore_client.gd")
const QUEUE := "matchmaking_queue"

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_game_version_rules()
	await _test_queue_skips_other_builds()
	await _test_queue_claims_same_build()
	await _test_room_join_rejects_other_build()


func _test_game_version_rules() -> void:
	var mine := GameVersion.build_id()
	_assert.call(GameVersion.matches_build(mine), "同じビルドIDは通ること")
	_assert.call(not GameVersion.matches_build(mine + "x"), "違うビルドIDは弾くこと")
	# この機能より前の版は build を持たない。盤面が食い違いうるのはまさにその
	# 組み合わせなので、未設定は「何でも通す」側へ倒さない。
	_assert.call(not GameVersion.matches_build(""), "buildを持たない相手は版違いとして扱うこと")
	# 時刻順の比較は、自分が書き出し済みの版であるときだけ成り立つ。エディタ実行の
	# 既定値 `dev` は時刻ではないため、一時的に書き出し済みの値へ差し替えて確かめる。
	var saved: Variant = ProjectSettings.get_setting(
		GameVersion.BUILD_ID_SETTING, GameVersion.DEV_BUILD_ID
	)
	ProjectSettings.set_setting(GameVersion.BUILD_ID_SETTING, "20260829-120000")
	_assert.call(GameVersion.is_newer_than_mine("20260830-090000"), "新しい相手を新しいと見ること")
	_assert.call(not GameVersion.is_newer_than_mine("20260828-090000"), "古い相手を新しいと見ないこと")
	_assert.call(not GameVersion.is_newer_than_mine("dev"), "devを時刻順の比較へ混ぜないこと")
	ProjectSettings.set_setting(GameVersion.BUILD_ID_SETTING, saved)


func _test_queue_skips_other_builds() -> void:
	# 「どちらが古いか」は書き出し済みの版どうしでしか比べられない。エディタ実行の
	# 既定値 `dev` のままだと比較を避ける側へ倒れるため、一時的に時刻の値へ差し替える。
	var saved: Variant = ProjectSettings.get_setting(
		GameVersion.BUILD_ID_SETTING, GameVersion.DEV_BUILD_ID
	)
	ProjectSettings.set_setting(GameVersion.BUILD_ID_SETTING, "20260829-120000")
	var queue := _make_queue("uid-me")
	var client = queue.client
	# 待機者は1人だけ。ただしビルドIDが違う。
	client.store["%s/uid-other" % QUEUE] = {
		"fields":
		{"joined_at": Time.get_unix_time_from_system(), "match_id": "", "build": "99999999-999999"},
		"update_time": "1"
	}
	var notified := [false, false]
	queue.version_mismatch.connect(
		func(newer: bool) -> void:
			notified[0] = true
			notified[1] = newer
	)

	var claimed: bool = await queue._try_claim_or_check()

	_assert.call(not claimed, "版が違う相手は掴まないこと")
	_assert.call(notified[0], "掴めなかったことを画面へ返すこと")
	_assert.call(notified[1], "自分のほうが古いと分かること")
	# 掴まないだけで削除はしない(古い版の人が待つ権利は残す)
	_assert.call(client.store.has("%s/uid-other" % QUEUE), "版が違う相手のキューを消さないこと")
	ProjectSettings.set_setting(GameVersion.BUILD_ID_SETTING, saved)
	_free_queue(queue)


func _test_queue_claims_same_build() -> void:
	var queue := _make_queue("uid-me")
	var client = queue.client
	client.store["%s/uid-other" % QUEUE] = {
		"fields":
		{
			"joined_at": Time.get_unix_time_from_system(),
			"match_id": "",
			"build": GameVersion.build_id()
		},
		"update_time": "1"
	}
	var matched := [false]
	queue.matched.connect(func(_id: String, _uid: String) -> void: matched[0] = true)

	var claimed: bool = await queue._try_claim_or_check()

	_assert.call(claimed, "同じビルドの相手は掴めること")
	_assert.call(matched[0], "掴んだらmatchedが発行されること")
	_free_queue(queue)


func _test_room_join_rejects_other_build() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var auth := FirebaseAuth.new(null)
	auth.uid = "uid-joiner"
	var client = FakeClient.new(auth)
	tree.root.add_child(client)
	client.store["rooms/ABC123"] = {
		"fields":
		{"creator_uid": "uid-host", "joiner_uid": "", "match_id": "", "build": "00000000-000000"},
		"update_time": "1"
	}
	var room := RoomMatch.new(client, auth)
	tree.root.add_child(room)
	var reason := [""]
	room.join_failed.connect(func(r: String) -> void: reason[0] = r)

	await room.join_room("ABC123")

	_assert.call(reason[0] == "version_newer", "版が古い部屋には参加できないこと")
	_assert.call(
		client.store["rooms/ABC123"]["fields"].get("joiner_uid", "") == "", "弾いた部屋を掴んでいないこと"
	)
	room.queue_free()
	client.queue_free()


func _make_queue(uid: String) -> MatchmakingQueue:
	var tree := Engine.get_main_loop() as SceneTree
	var auth := FirebaseAuth.new(null)
	auth.uid = uid
	var client = FakeClient.new(auth)
	tree.root.add_child(client)
	client.store["%s/%s" % [QUEUE, uid]] = {
		"fields":
		{
			"joined_at": Time.get_unix_time_from_system(),
			"match_id": "",
			"build": GameVersion.build_id()
		},
		"update_time": "1"
	}
	var queue := MatchmakingQueue.new(client, auth)
	tree.root.add_child(queue)
	return queue


func _free_queue(queue: MatchmakingQueue) -> void:
	queue.client.queue_free()
	queue.queue_free()
