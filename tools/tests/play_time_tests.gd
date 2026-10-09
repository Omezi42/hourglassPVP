extends RefCounted
## 1局の時間(GameDesign.md 22章 / Architecture.md 10.9節)を、差し替え用クライアントの上で検証する。
##
## **確かめたいのは3点。**所要時間が正しい帯へ入ること、1局ごとに種別・日で足されること、
## 送れなかった1局は数に入らないこと。

const FakeClient = preload("res://tools/tests/fake_firestore_client.gd")
const DAY := "d20261009"
const OTHER_DAY := "d20261010"

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_assert.call(PlayTimeService.band_key(299.0) == "m5", "under 5 minutes goes to m5")
	_assert.call(PlayTimeService.band_key(300.0) == "m5", "exactly 5 minutes stays in m5")
	_assert.call(PlayTimeService.band_key(301.0) == "m10", "just over 5 minutes goes to m10")
	_assert.call(PlayTimeService.band_key(900.0) == "m15", "exactly 15 minutes stays in m15")
	_assert.call(
		PlayTimeService.band_key(901.0) == PlayTimeService.BAND_OVER, "over 15 minutes is over"
	)

	var tree := Engine.get_main_loop() as SceneTree
	var auth := FirebaseAuth.new(null)
	auth.uid = "uid-play-time"
	var client = FakeClient.new(auth)
	tree.root.add_child(client)

	var cpu := PlayTimeService.KIND_CPU
	var solo := PlayTimeService.KIND_SOLO
	await PlayTimeService.send(client, DAY, cpu, 420.0, 20, true)
	await PlayTimeService.send(client, DAY, cpu, 1200.0, 30, false)
	await PlayTimeService.send(client, DAY, solo, 100.0, 12, true)
	await PlayTimeService.send(client, OTHER_DAY, cpu, 100.0, 9, false)
	client.fail_commits = PlayTimeService.STATS_RETRIES
	var sent: bool = await PlayTimeService.send(client, DAY, cpu, 100.0, 5, true)
	_assert.call(not sent, "a match that failed to send is reported as not sent")

	var days: Dictionary = client.store[PlayTimeService.STATS_PATH]["fields"]["days"]
	var today: Dictionary = days[DAY]
	_assert.call(int(today["cpu_games"]) == 2, "every CPU match is counted, failed one is not")
	_assert.call(int(today["cpu_wins"]) == 1, "wins are counted per kind")
	_assert.call(int(today["cpu_turns"]) == 50, "turns add up within a day")
	_assert.call(
		int(today["cpu_m10"]) == 1 and int(today["cpu_over"]) == 1, "each match goes to its band"
	)
	_assert.call(int(today.get("cpu_m5", 0)) == 0, "the failed match is not in any band")
	_assert.call(int(today["solo_games"]) == 1, "expeditions are counted apart from CPU matches")
	_assert.call(int(days[OTHER_DAY]["cpu_games"]) == 1, "each match goes to its own day")

	client.queue_free()
