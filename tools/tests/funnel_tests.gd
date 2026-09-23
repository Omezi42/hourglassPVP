extends RefCounted
## 通過数(GameDesign.md 22章 / Architecture.md 10.9節)を、差し替え用クライアントの上で検証する。
##
## **確かめたいのは3点。**同じ段階は1回しか数えないこと、送れなかった段階は控えに残って
## 次に送り直されること、日ごとに分けて足されること。

const FakeClient = preload("res://tools/tests/fake_firestore_client.gd")
const TEST_SAVE := "user://funnel_test.json"
const OTHER_DAY := "d20000101"

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	DirAccess.remove_absolute(TEST_SAVE)
	FunnelService.use_for_test(TEST_SAVE)

	var tree := Engine.get_main_loop() as SceneTree
	var auth := FirebaseAuth.new(null)
	auth.uid = "uid-funnel"
	var client = FakeClient.new(auth)
	tree.root.add_child(client)

	FunnelService.reach(FunnelService.HOME)
	FunnelService.reach(FunnelService.HOME)
	_assert.call(FunnelService.pending().size() == 1, "a step should be queued only once")

	client.fail_commits = FunnelService.STATS_RETRIES
	await FunnelService.flush_with(client)
	_assert.call(
		FunnelService.pending().has(FunnelService.HOME),
		"a step that failed to send should stay queued"
	)

	FunnelService.reload_state()
	_assert.call(
		FunnelService.pending().has(FunnelService.HOME), "the queue should survive a restart"
	)
	await FunnelService.flush_with(client)
	_assert.call(FunnelService.pending().is_empty(), "a sent step should leave the queue")
	FunnelService.reach(FunnelService.HOME)
	_assert.call(FunnelService.pending().is_empty(), "a sent step should never be counted again")

	var days: Dictionary = client.store[FunnelService.STATS_PATH]["fields"]["days"]
	var today: Dictionary = days[FunnelService.today_key()]
	_assert.call(int(today[FunnelService.HOME]) == 1, "the step should be counted once for today")

	var merged := FunnelService.merge(
		{"days": days},
		{FunnelService.LAUNCH: OTHER_DAY, FunnelService.HOME: FunnelService.today_key()}
	)
	var merged_days: Dictionary = merged["days"]
	_assert.call(
		int(merged_days[OTHER_DAY][FunnelService.LAUNCH]) == 1,
		"each step goes to the day it happened"
	)
	_assert.call(
		int(merged_days[FunnelService.today_key()][FunnelService.HOME]) == 2,
		"counts should add up within a day"
	)

	client.queue_free()
	DirAccess.remove_absolute(TEST_SAVE)
	FunnelService.use_for_test("")
