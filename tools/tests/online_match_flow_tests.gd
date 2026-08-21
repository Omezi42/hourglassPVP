extends RefCounted

## フェーズ26 AE-5/AE-6: 手の送受信を、差し替え用クライアント(FakeFirestoreClient)の上で
## 実通信なしに検証する。狙いは次の3点。
##
##   1. 自分が書いた手をポーリングが拾って自分に配り返さないこと(二重適用の競合)
##   2. 書き込みが競合・失敗しても読み直して再試行し、最終的に1件だけ積まれること
##   3. 受け取った手を1ポーリングにつき1件だけ配ること(ターン進行の二重起動を防ぐ)
##
## ポーリングのタイマーを待つと実時間が伸びるため、_poll_loop()自体は止めたうえで
## _fetch()/_deliver_one()を直接呼ぶ。検証対象がその内部の順序そのもののため、
## テストからprivateを呼ぶことを許している。

const MATCH_PATH := "matches/m_test"
const FakeClient = preload("res://tools/tests/fake_firestore_client.gd")

var _received: Array = []


func run(assert_true: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var auth := FirebaseAuth.new(null)
	auth.uid = "uid-me"
	var client = FakeClient.new(auth)
	tree.root.add_child(client)
	client.store[MATCH_PATH] = {"fields": {"actions": []}, "update_time": "0"}

	var online := OnlineMatch.new(client)
	tree.root.add_child(online)
	online.action_received.connect(func(action: Dictionary) -> void: _received.append(action))
	# start()は_my_uidの設定とポーリングの開始を兼ねる。ポーリングは最初のタイマー待ちの
	# 時点で止まるため、直後にstop()しておけば以降は明示的に呼んだ分だけが動く。
	online.start("m_test")
	online.stop()

	await _test_own_action_is_not_delivered_back(assert_true, client, online, tree)
	await _test_opponent_actions_are_delivered_one_at_a_time(assert_true, client, online, tree)
	await _test_send_retries_until_the_write_lands(assert_true, client, online, tree)
	_test_repeated_failures_report_a_lost_connection(assert_true, client)
	await _test_setup_wait_can_be_aborted(assert_true, client, tree)

	online.stop()
	online.queue_free()
	client.queue_free()


## 送信した手には自分のuidの印が付き、ポーリングはそれを配らない。以前はこの窓で
## 自分の手が自分に返り、同じ手が2度適用されていた。
func _test_own_action_is_not_delivered_back(
	assert_true: Callable, client, online: OnlineMatch, tree: SceneTree
) -> void:
	online.send({"type": "pass", "side": GameState.PlayerSide.A})
	await _wait_until(tree, func() -> bool: return not online.is_busy(), 3.0)

	var stored: Array = client.actions_at(MATCH_PATH)
	assert_true.call(stored.size() == 1, "the sent action should be appended exactly once")
	assert_true.call(
		stored.size() == 1 and stored[0].get("by", "") == "uid-me",
		"the sent action should carry the sender uid so polling can skip it"
	)

	await online._fetch()
	online._deliver_one()
	assert_true.call(
		_received.is_empty(), "polling must not deliver the player's own action back to them"
	)


## 相手の手は届くが、1回のポーリングにつき1件までしか配らない。
func _test_opponent_actions_are_delivered_one_at_a_time(
	assert_true: Callable, client, online: OnlineMatch, tree: SceneTree
) -> void:
	client.append_action(MATCH_PATH, {"type": "pass", "side": GameState.PlayerSide.B, "by": "them"})
	client.append_action(
		MATCH_PATH, {"type": "surrender", "side": GameState.PlayerSide.B, "by": "them"}
	)

	await online._fetch()
	online._deliver_one()
	assert_true.call(_received.size() == 1, "only one action should be delivered per poll")
	assert_true.call(
		_received.size() == 1 and _received[0]["type"] == "pass",
		"actions should be delivered in the order they were written"
	)

	online._deliver_one()
	assert_true.call(_received.size() == 2, "the queued action should follow on the next poll")
	assert_true.call(
		_received.size() == 2 and _received[1]["type"] == "surrender",
		"the second action should be the one written second"
	)
	assert_true.call(not tree.paused, "the scene tree should be untouched by the test")


## 書き込みが失敗しても読み直して再試行し、最終的にちょうど1件だけ積まれること。
func _test_send_retries_until_the_write_lands(
	assert_true: Callable, client, online: OnlineMatch, tree: SceneTree
) -> void:
	var before: int = client.actions_at(MATCH_PATH).size()
	var commits_before: int = client.commit_count
	client.fail_commits = 1

	online.send({"type": "pass", "side": GameState.PlayerSide.A})
	await _wait_until(tree, func() -> bool: return not online.is_busy(), 5.0)

	assert_true.call(
		client.actions_at(MATCH_PATH).size() == before + 1,
		"a retried send should end up appending the action exactly once"
	)
	assert_true.call(
		client.commit_count >= commits_before + 2, "the failed write should have been retried"
	)
	assert_true.call(online.connected, "a send that eventually succeeded should not report offline")


## 連続した失敗は「接続できません」としてUIへ伝わる(GameDesign.md 11章)。
func _test_repeated_failures_report_a_lost_connection(assert_true: Callable, _client) -> void:
	var lonely := OnlineMatch.new(null)
	var states: Array = []
	lonely.connection_changed.connect(func(online: bool) -> void: states.append(online))

	lonely._note_result(false)
	assert_true.call(
		lonely.connected, "a single failure should not raise the warning (it flickers otherwise)"
	)
	lonely._note_result(false)
	assert_true.call(not lonely.connected, "repeated failures should report a lost connection")
	assert_true.call(states == [false], "the change should be reported exactly once")

	lonely._note_result(true)
	assert_true.call(lonely.connected, "a success should clear the warning")
	assert_true.call(states == [false, true], "recovery should be reported once")
	lonely.free()


## 対局が始まる前の待機は、相手が揃えば進み、中断・相手の離脱では待たずに抜ける
## (GameDesign.md 11章)。以前は相手が来ないと約10分待つしかなかった。
func _test_setup_wait_can_be_aborted(assert_true: Callable, client, tree: SceneTree) -> void:
	var path := "matches/m_setup"
	client.store[path] = {"fields": {}, "update_time": "0"}

	var setup := OnlineSetup.new(client, "m_setup", GameState.PlayerSide.A)
	tree.root.add_child(setup)
	var own_ids: Array[String] = ["sand", "sword", "king", "wall", "eye"]
	await setup.push_deck(own_ids)
	assert_true.call(
		(client.store[path]["fields"] as Dictionary).has("deck_a"),
		"the first player should publish their deck as deck_a"
	)

	# 相手が揃った場合は、そのidsがそのまま返る
	client.store[path]["fields"]["deck_b"] = ["sand", "sand", "sand", "sand", "sand"]
	var opponent: Array[String] = await setup.wait_for_opponent_deck()
	assert_true.call(opponent.size() == 5, "the opponent deck should be picked up once written")
	assert_true.call(setup.abort_reason == "", "a successful wait should not record an abort")

	# 相手が対局を取りやめた場合は、待ち続けずに抜ける
	client.store[path]["fields"].erase("deck_b")
	client.store[path]["fields"]["abandoned"] = true
	var abandoned: Array[String] = await setup.wait_for_opponent_deck()
	assert_true.call(abandoned.is_empty(), "an abandoned match should stop the wait")
	assert_true.call(setup.abort_reason == "abandoned", "the wait should record why it stopped")
	assert_true.call(setup.abort_message() != "", "the abort should have a message for the player")

	# 自分から中断した場合も同様に、即座に待機を抜ける
	client.store[path]["fields"].erase("abandoned")
	await setup.cancel()
	assert_true.call(
		bool((client.store[path]["fields"] as Dictionary).get("abandoned", false)),
		"cancelling should leave a mark so the opponent stops waiting too"
	)
	var cancelled: Array[String] = await setup.wait_for_opponent_deck()
	assert_true.call(cancelled.is_empty(), "cancelling should stop our own wait immediately")
	assert_true.call(setup.abort_reason == "cancelled", "the cancel reason should be recorded")
	setup.queue_free()


func _wait_until(tree: SceneTree, condition: Callable, timeout: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await tree.process_frame
	return condition.call()
