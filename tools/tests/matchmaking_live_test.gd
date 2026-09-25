extends SceneTree
## 本物のFirebaseへ2つの匿名アカウントでつなぎ、ランクマッチの待合室で対局が成立し、
## デッキと種の交換まで済むことを確かめる(Architecture.md 6.1節・10.16節)。
## 差し替え用クライアントでは、Firestoreの応答の形・時刻の形式・前提条件の扱いの
## 食い違いを拾えないため、実物に当てる。
##
## 実行: godot --headless --path . --script res://tools/tests/matchmaking_live_test.gd
##
## - 本物の待合室を使うため、ビルドIDを実行ごとの使い捨ての値へ差し替える。遊んでいる人と
##   掴み合わず、「0」始まりにして相手の画面で「新しい版が公開されています」と出させない
## - 保存済みのセッション(user://)へは書かない(`_persist()` を止めた `LiveAuth` を使う)
## - Discordへの募集通知は送らない。作った匿名アカウントと文書は最後に消す

const CONFIG_PATH := "res://data/firebase_config.tres"
const DELETE_ACCOUNT_URL := "https://identitytoolkit.googleapis.com/v1/accounts:delete?key=%s"
const MATCH_TIMEOUT_SECONDS := 40.0
const LATE_JOIN_SECONDS := 3.0
const SEED_VALUE := 424242

var _failures := 0
var _config: FirebaseConfig


class LiveAuth:
	extends FirebaseAuth

	func _persist() -> void:
		pass


class SilentQueue:
	extends RankedMatchmakingQueue

	func _announce_if_due() -> void:
		pass


class Player:
	var auth: LiveAuth
	var client: FirestoreClient
	var queue: SilentQueue
	var match_id := ""
	var opponent_uid := ""
	var failure := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_config = load(CONFIG_PATH)
	ProjectSettings.set_setting(
		GameVersion.BUILD_ID_SETTING, "0000-livetest-%d" % (randi() % 1000000)
	)
	var a := await _make_player()
	var b := await _make_player()
	if a == null or b == null:
		_check(false, "匿名サインインに失敗")
		_finish([a, b])
		return

	await _scenario(a, b, LATE_JOIN_SECONDS, "片方が待っているところへ後から入る")
	await _scenario(a, b, 0.0, "2人が同時に入る")
	_finish([a, b])


func _scenario(a: Player, b: Player, late_join: float, label: String) -> void:
	print("== ", label)
	for p in [a, b]:
		_reset_queue(p)
	a.queue.join()
	if late_join > 0.0:
		await create_timer(late_join).timeout
	b.queue.join()

	var deadline := Time.get_unix_time_from_system() + MATCH_TIMEOUT_SECONDS
	while Time.get_unix_time_from_system() < deadline:
		if a.match_id != "" and b.match_id != "":
			break
		if a.failure != "" or b.failure != "":
			break
		await process_frame
	_check(
		a.failure == "" and b.failure == "", "%s: 失敗の通知なし (%s / %s)" % [label, a.failure, b.failure]
	)
	_check(a.match_id != "" and b.match_id != "", "%s: 両者とも成立する" % label)
	if a.match_id == "" or b.match_id == "":
		for p in [a, b]:
			p.queue.cancel()
		return
	_check(a.match_id == b.match_id, "%s: 同じ対局へ入る" % label)
	_check(a.opponent_uid == b.auth.uid and b.opponent_uid == a.auth.uid, "%s: 相手が互いを指す" % label)

	var doc: Dictionary = await a.client.get_document("matches/%s" % a.match_id)
	var side_a := _side_of(doc, a.auth.uid)
	var side_b := _side_of(doc, b.auth.uid)
	_check(side_a >= 0 and side_b >= 0 and side_a != side_b, "%s: 先手・後手が1人ずつ" % label)
	if side_a < 0 or side_b < 0 or side_a == side_b:
		return
	await _exchange_setup(a, b, side_a, side_b, label)

	for p in [a, b]:
		var mine: Dictionary = await p.client.get_document_meta(
			"%s/%s" % [p.queue.collection, p.auth.uid]
		)
		_check(not mine["exists"], "%s: 成立後は待合室から消える" % label)
	await a.client.delete_document("matches/%s" % a.match_id)


func _exchange_setup(a: Player, b: Player, side_a: int, side_b: int, label: String) -> void:
	var deck := _deck()
	var setup_a := OnlineSetup.new(a.client, a.match_id, side_a)
	var setup_b := OnlineSetup.new(b.client, b.match_id, side_b)
	root.add_child(setup_a)
	root.add_child(setup_b)
	var results := [{}, {}]
	var run_side := func(setup: OnlineSetup, index: int) -> void:
		# 両者が別々の種を用意し、先手の種へそろうことを確かめる(Main と同じ使い方)
		await setup.push_setup(deck, SEED_VALUE + index)
		results[index] = await setup.wait_for_opponent_setup(SEED_VALUE + index)
	run_side.call(setup_a, 0)
	run_side.call(setup_b, 1)
	var deadline := Time.get_unix_time_from_system() + MATCH_TIMEOUT_SECONDS
	while Time.get_unix_time_from_system() < deadline:
		if not results[0].is_empty() and not results[1].is_empty():
			break
		await process_frame
	var ok: bool = not results[0].is_empty() and not results[1].is_empty()
	_check(ok, "%s: デッキと種の交換が終わる" % label)
	if ok:
		_check(
			results[0]["deck"].size() == deck.size() and results[1]["deck"].size() == deck.size(),
			"%s: 相手のデッキを受け取る" % label
		)
		_check(results[0]["seed"] == results[1]["seed"], "%s: 両者の種がそろう" % label)
	setup_a.queue_free()
	setup_b.queue_free()


func _deck() -> Array[String]:
	var ids: Array[String] = []
	for i in MatchState.DECK_SIZE:
		ids.append("card_%d" % i)
	return ids


func _side_of(doc: Dictionary, uid: String) -> int:
	if doc.get("player_a", "") == uid:
		return MatchState.Side.A
	if doc.get("player_b", "") == uid:
		return MatchState.Side.B
	return -1


func _make_player() -> Player:
	var p := Player.new()
	p.auth = LiveAuth.new(_config)
	root.add_child(p.auth)
	var done := [false]
	p.auth.signed_in.connect(func(_uid: String) -> void: done[0] = true, CONNECT_ONE_SHOT)
	p.auth.sign_in_failed.connect(func(_e: String) -> void: done[0] = true, CONNECT_ONE_SHOT)
	p.auth.sign_in_anonymously()
	while not done[0]:
		await process_frame
	if not p.auth.is_signed_in():
		return null
	p.client = FirestoreClient.new(_config, p.auth)
	root.add_child(p.client)
	return p


func _reset_queue(p: Player) -> void:
	if p.queue != null:
		p.queue.queue_free()
	p.match_id = ""
	p.opponent_uid = ""
	p.failure = ""
	p.queue = SilentQueue.new(p.client, p.auth)
	root.add_child(p.queue)
	p.queue.matched.connect(
		func(id: String, opponent: String) -> void:
			p.match_id = id
			p.opponent_uid = opponent
	)
	p.queue.failed.connect(func(reason: String) -> void: p.failure = reason)


func _finish(players: Array) -> void:
	for p: Player in players:
		if p == null:
			continue
		await p.client.delete_document(
			"%s/%s" % [RankedMatchmakingQueue.RANKED_COLLECTION, p.auth.uid]
		)
		await HttpJson.request(
			root,
			DELETE_ACCOUNT_URL % _config.api_key,
			HTTPClient.METHOD_POST,
			PackedStringArray(["Content-Type: application/json"]),
			JSON.stringify({"idToken": p.auth.id_token})
		)
	print("matchmaking live %s" % ("passed" if _failures == 0 else "FAILED (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
		return
	_failures += 1
	printerr("  NG: ", message)
