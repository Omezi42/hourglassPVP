extends RefCounted
## 初日〜2日目の導線(GameDesign.md 11章・18章・23章・27章)を確かめる。
##
## **確かめたいのは4点。**遠征の1段目が初級になること、はじめの7日が1日1回だけ・7日で止まること、
## 遠征を始めたかどうかを覚えること(つぎはここ)、待機の自動CPU戦が時間で始まり・止められること。

const FakeClient = preload("res://tools/tests/fake_firestore_client.gd")
const UID := "uid-welcome"
const OLD_DATE := "2000-01-01"
const AUTO_DELAY := 0.05

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_solo_first_floor_is_beginner()
	_test_solo_progress_remembers_start()
	await _test_welcome_days()
	await _test_waiting_cpu_auto_start()


func _test_solo_first_floor_is_beginner() -> void:
	var expert_from := SoloRun.EXPERT_FROM_FLOOR
	_assert.call(
		SoloRun.difficulty_at(0, expert_from) == CardCpuStrategy.Difficulty.BEGINNER,
		"floor 1 should be beginner at depth 0"
	)
	_assert.call(
		SoloRun.difficulty_at(1, expert_from) == CardCpuStrategy.Difficulty.NORMAL,
		"floor 2 should be normal"
	)
	_assert.call(
		SoloRun.difficulty_at(expert_from, expert_from) == CardCpuStrategy.Difficulty.EXPERT,
		"floor 3 should be expert"
	)
	_assert.call(
		SoloRun.difficulty_at(0, 0) == CardCpuStrategy.Difficulty.EXPERT,
		"depth 1 should make floor 1 expert, not beginner"
	)
	_assert.call(SoloRun.difficulty_name_at(0, expert_from) == "初級", "beginner name")
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], 0, RandomNumberGenerator.new())
	_assert.call(
		run.difficulty() == CardCpuStrategy.Difficulty.BEGINNER,
		"a new run at depth 0 should start against a beginner CPU"
	)


func _test_solo_progress_remembers_start() -> void:
	SoloProgress.reset_for_test()
	_assert.call(not SoloProgress.has_started(UID), "no run started yet")
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], 0, RandomNumberGenerator.new())
	SoloProgress.save_run(UID, run)
	SoloProgress.clear_run(UID)
	_assert.call(SoloProgress.has_started(UID), "a cleared run still counts as started")
	SoloProgress.reset_for_test()


func _test_welcome_days() -> void:
	AccountService.reset()
	var tree := Engine.get_main_loop() as SceneTree
	var auth := FirebaseAuth.new(null)
	auth.uid = UID
	var client = FakeClient.new(auth)
	tree.root.add_child(client)
	var path := AccountService.path(UID)
	client.store[path] = {"fields": {"currency": 50}, "update_time": "t0"}

	_assert.call(WelcomeDays.can_claim_today(), "a new player can claim day 1")
	_assert.call(WelcomeDays.tomorrow_line().is_empty(), "no tomorrow line before day 1")
	var day: int = await WelcomeDays.claim(client, UID)
	var fields: Dictionary = client.store[path]["fields"]
	_assert.call(day == 1, "the first claim should be day 1")
	_assert.call(int(fields["currency"]) == 150, "day 1 should add 100 to the balance")
	_assert.call(not WelcomeDays.can_claim_today(), "day 1 cannot be claimed twice")
	_assert.call(
		WelcomeDays.tomorrow_line() == "明日来ると 100砂金 ・ はじめの7日 2/7",
		"tomorrow line after day 1: " + WelcomeDays.tomorrow_line()
	)
	_assert.call(await WelcomeDays.claim(client, UID) == 0, "a second claim on the same day")
	_assert.call(int(fields["currency"]) == 150, "a same-day claim must not add gold")

	fields[WelcomeDays.FIELD_DATE] = OLD_DATE
	AccountService.apply_local_fields({WelcomeDays.FIELD_DATE: OLD_DATE})
	_assert.call(await WelcomeDays.claim(client, UID) == 2, "another day should be day 2")
	_assert.call(int(fields["currency"]) == 250, "day 2 should add 100")

	fields[WelcomeDays.FIELD_DAYS] = WelcomeDays.DAYS
	fields[WelcomeDays.FIELD_DATE] = OLD_DATE
	_assert.call(await WelcomeDays.claim(client, UID) == 0, "nothing after the 7th day")
	_assert.call(not WelcomeDays.can_claim_today(), "the cache follows the 7-day stop")
	_assert.call(WelcomeDays.gold_for(WelcomeDays.DAYS) == 300, "day 7 gives 300")
	_assert.call(WelcomeDays.icon_for(WelcomeDays.DAYS) == "mascot", "day 7 gives the icon")
	_assert.call(WelcomeDays.icon_for(1).is_empty(), "other days give no icon")

	client.queue_free()
	AccountService.reset()


func _test_waiting_cpu_auto_start() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var host := Control.new()
	tree.root.add_child(host)
	var below := Button.new()
	host.add_child(below)
	var offer := WaitingCpuOffer.new(host, below)
	var requested := [0]
	offer.requested.connect(func() -> void: requested[0] += 1)

	offer.start_auto(AUTO_DELAY)
	_assert.call(offer.wait_button.visible, "the stop button shows while counting down")
	await tree.create_timer(AUTO_DELAY * 3.0).timeout
	_assert.call(requested[0] == 1, "the CPU match should start by itself")
	_assert.call(not offer.wait_button.visible, "the countdown hides once started")

	offer.start_auto(AUTO_DELAY)
	offer.wait_button.pressed.emit()
	await tree.create_timer(AUTO_DELAY * 3.0).timeout
	_assert.call(requested[0] == 1, "choosing to wait must stop the auto start")
	_assert.call(offer.button.visible, "after waiting, the manual button shows")

	offer.start_auto(AUTO_DELAY)
	offer.hide()
	await tree.create_timer(AUTO_DELAY * 3.0).timeout
	_assert.call(requested[0] == 1, "a found opponent (hide) must cancel the auto start")
	host.queue_free()
