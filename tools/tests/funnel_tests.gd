extends RefCounted
## 通過数(GameDesign.md 22章 / Architecture.md 10.9節)を、差し替え用クライアントの上で検証する。
##
## **確かめたいのは6点。**同じ段階は1回しか数えないこと、送れなかった段階は控えに残って
## 次に送り直されること、日ごとに分けて足されること、配信先ごとにも足されること、
## 数え始める前から遊んでいた端末を数えないこと、ランクマッチは最初の待機だけを追うこと。

const FakeClient = preload("res://tools/tests/fake_firestore_client.gd")
const TEST_SAVE := "user://funnel_test.json"
const TEST_UI_SAVE := "user://funnel_test_ui_state.json"
const OTHER_DAY := "d20000101"
const SITE := "itch"

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
		{FunnelService.LAUNCH: OTHER_DAY, FunnelService.HOME: FunnelService.today_key()},
		SITE
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
	_assert.call(
		int(merged["portals"][SITE][OTHER_DAY][FunnelService.LAUNCH]) == 1,
		"each step should also be counted for the site"
	)
	_assert.call(
		PortalInfo.site_from_place("html-classic.itch.zone https://someone.itch.io/") == "itch",
		"itch.io should be told apart from its hosts"
	)
	_assert.call(
		PortalInfo.site_from_place("example.com ") == PortalInfo.SITE_OTHER,
		"an unknown site should fall back to other"
	)
	_check_ranked_wait_first_only(tree)

	_check_existing_player_excluded()

	client.queue_free()
	DirAccess.remove_absolute(TEST_SAVE)
	FunnelService.use_for_test("")


func _check_ranked_wait_first_only(tree: SceneTree) -> void:
	var tracker := RankedWaitFunnel.new(tree.root)
	tracker.begin()
	tracker.switched_to_cpu()
	tracker.end(FunnelService.RANKED_CANCEL)
	_assert.call(
		(
			FunnelService.has_reached(FunnelService.RANKED_WAIT)
			and FunnelService.has_reached(FunnelService.RANKED_CPU)
			and FunnelService.has_reached(FunnelService.RANKED_CANCEL)
		),
		"the first wait should be followed to its end"
	)
	var second := RankedWaitFunnel.new(tree.root)
	second.begin()
	second.end(FunnelService.RANKED_MATCHED)
	_assert.call(
		not FunnelService.has_reached(FunnelService.RANKED_MATCHED),
		"a later wait should not be counted"
	)


func _check_existing_player_excluded() -> void:
	DirAccess.remove_absolute(TEST_SAVE)
	DirAccess.remove_absolute(TEST_UI_SAVE)
	FunnelService.use_for_test(TEST_SAVE)
	UiState._save_path = TEST_UI_SAVE
	UiState._loaded = false
	UiState._state = {}
	UiState.mark_home_seen()
	FunnelService.on_launch()
	FunnelService.reach(FunnelService.HOME)
	_assert.call(
		FunnelService.pending().is_empty(), "a device that played before counting should be ignored"
	)
	FunnelService.reload_state()
	FunnelService.on_launch()
	_assert.call(
		FunnelService.pending().is_empty(), "the device should stay ignored after a restart"
	)
	UiState._save_path = UiState.SAVE_PATH
	UiState._loaded = false
	UiState._state = {}
	DirAccess.remove_absolute(TEST_UI_SAVE)
