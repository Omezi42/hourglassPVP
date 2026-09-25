extends RefCounted

## 掲示板〈ラボ〉(GameDesign.md 29章)の検証。通信を持たない判定(`LabRules` /
## `LabModeration`)と、`FakeFirestoreClient` を使った投稿・投票の一連の流れ
## (rank_tests.gd と同じ流儀)。

const FakeClient = preload("res://tools/tests/fake_firestore_client.gd")
const NOW := 1_790_000_000.0
const DAY := 86400.0
const OPEN_ROUND := {"id": "r1", "title": "お題", "starts_at": NOW - DAY, "ends_at": NOW + DAY}
const CLOSED_ROUND := {
	"id": "r0", "title": "前のお題", "starts_at": NOW - 20 * DAY, "ends_at": NOW - 6 * DAY
}


func run(assert_true: Callable) -> void:
	_test_quick_check(assert_true)
	_test_available_title_ids(assert_true)
	_test_is_registered(assert_true)
	_test_rounds(assert_true)
	_test_vote_block(assert_true)
	_test_orders(assert_true)
	_test_status_and_texts(assert_true)
	await _test_submit_and_vote_flow(assert_true)


func _test_quick_check(assert_true: Callable) -> void:
	assert_true.call(LabModeration.quick_check("", "説明") != "", "empty name should be rejected")
	assert_true.call(
		LabModeration.quick_check("名前", "") != "", "empty description should be rejected"
	)
	assert_true.call(
		LabModeration.quick_check("名前", "普通の説明文") == "", "a normal proposal should pass"
	)
	assert_true.call(
		LabModeration.quick_check("死ねカード", "普通の説明文") != "",
		"a banned word in the name should be rejected"
	)
	assert_true.call(
		LabModeration.quick_check("名前", "説明にfuckが入っている") != "",
		"a banned word (case/width insensitive) in the description should be rejected"
	)
	var too_long_name := "あ".repeat(LabModeration.NAME_MAX_LENGTH + 1)
	assert_true.call(
		LabModeration.quick_check(too_long_name, "説明") != "",
		"a name over the length limit should be rejected"
	)


func _test_available_title_ids(assert_true: Callable) -> void:
	var ids := UserProfileLibrary.get_available_title_ids()
	assert_true.call(ids.has("novice") and ids.has("none"), "everyone can pick novice/none")
	assert_true.call(
		not ids.has("proposer") and not ids.has("hakoniwa_ou"),
		"restricted titles should not be selectable by default"
	)


func _test_is_registered(assert_true: Callable) -> void:
	AccountService.reset()
	assert_true.call(
		not AccountService.is_registered(), "a fresh anonymous profile is not registered"
	)
	AccountService.apply_local_fields({"login_id": "tester"})
	assert_true.call(AccountService.is_registered(), "a profile with a login_id is registered")
	AccountService.reset()


func _test_rounds(assert_true: Callable) -> void:
	var older := {"id": "rx", "starts_at": NOW - 40 * DAY, "ends_at": NOW - 30 * DAY}
	var future := {"id": "rf", "starts_at": NOW + DAY, "ends_at": NOW + 10 * DAY}
	var rounds := [older, CLOSED_ROUND, OPEN_ROUND, future]
	assert_true.call(
		LabRules.current_round(rounds, NOW)["id"] == "r1", "the open round should be current"
	)
	assert_true.call(
		LabRules.current_round([older, future], NOW).is_empty(), "no round is open between rounds"
	)
	var closed := LabRules.closed_rounds(rounds, NOW)
	assert_true.call(
		closed.size() == 2 and closed[0]["id"] == "r0" and closed[1]["id"] == "rx",
		"closed rounds should be listed newest first, without open/future rounds"
	)
	assert_true.call(
		not LabRules.is_open(OPEN_ROUND, OPEN_ROUND["ends_at"]), "a round closes at ends_at"
	)


func _test_vote_block(assert_true: Callable) -> void:
	var proposal := {"id": "r1_author", "author_uid": "author"}
	var empty_ballot := {}
	assert_true.call(
		(
			LabRules.vote_block(proposal, empty_ballot, "voter", OPEN_ROUND, NOW)
			== LabRules.VoteBlock.NONE
		),
		"another player's proposal in an open round can be voted"
	)
	assert_true.call(
		(
			LabRules.vote_block(proposal, empty_ballot, "author", OPEN_ROUND, NOW)
			== LabRules.VoteBlock.OWN
		),
		"the author cannot vote for their own proposal"
	)
	assert_true.call(
		(
			LabRules.vote_block(proposal, empty_ballot, "voter", CLOSED_ROUND, NOW)
			== LabRules.VoteBlock.CLOSED
		),
		"votes are refused after the deadline"
	)
	var voted := {"proposal_ids": ["r1_author"]}
	assert_true.call(
		(
			LabRules.vote_block(proposal, voted, "voter", OPEN_ROUND, NOW)
			== LabRules.VoteBlock.ALREADY
		),
		"the same proposal cannot be voted twice"
	)
	var full := {"proposal_ids": ["a", "b", "c"]}
	assert_true.call(LabRules.votes_left(full) == 0, "three votes use up the ballot")
	assert_true.call(
		(
			LabRules.vote_block(proposal, full, "voter", OPEN_ROUND, NOW)
			== LabRules.VoteBlock.NO_VOTES_LEFT
		),
		"a fourth vote is refused"
	)
	assert_true.call(
		LabRules.votes_left({}) == LabRules.VOTES_PER_ROUND, "an empty ballot has all votes"
	)


func _test_orders(assert_true: Callable) -> void:
	var rows := []
	for i in 6:
		rows.append({"id": "p%d" % i, "good_count": i % 3, "created_at": float(i)})
	var first := LabRules.viewer_order(rows, "viewer_a")
	var again := LabRules.viewer_order(rows, "viewer_a")
	assert_true.call(first == again, "the viewer order should not change between openings")
	assert_true.call(first.size() == rows.size(), "the viewer order keeps every proposal")
	var ranked := LabRules.ranked(rows)
	assert_true.call(
		ranked[0]["id"] == "p2" and ranked[1]["id"] == "p5",
		"ranked order is by votes, earlier post first on ties"
	)
	var with_hidden := [{"id": "a"}, {"id": "b", "hidden": true}]
	assert_true.call(
		LabRules.visible_rows(with_hidden).size() == 1, "hidden proposals are not listed"
	)


func _test_status_and_texts(assert_true: Callable) -> void:
	var listed := {"id": "x"}
	assert_true.call(
		LabRules.status_of(listed, OPEN_ROUND, NOW) == LabRules.Status.LISTED,
		"a proposal in an open round is listed"
	)
	assert_true.call(
		LabRules.status_of({"hidden": true}, OPEN_ROUND, NOW) == LabRules.Status.HIDDEN,
		"a hidden proposal shows as hidden to its author"
	)
	assert_true.call(
		LabRules.status_of(listed, CLOSED_ROUND, NOW) == LabRules.Status.REVIEWING,
		"a closed round without fixed results is under review"
	)
	var fixed := CLOSED_ROUND.duplicate()
	fixed["results_fixed"] = true
	assert_true.call(
		LabRules.status_of(listed, fixed, NOW) == LabRules.Status.RESULT,
		"after results are fixed, a non-adopted proposal shows its votes"
	)
	assert_true.call(
		LabRules.status_of({"result": "adopted"}, CLOSED_ROUND, NOW) == LabRules.Status.ADOPTED,
		"an adopted proposal shows as adopted"
	)
	assert_true.call(
		LabRules.status_of({"source": "tournament"}, {}, NOW) == LabRules.Status.TOURNAMENT,
		"a tournament prize is marked as such"
	)
	assert_true.call(
		LabRules.deadline_text(NOW + 5 * DAY + 14 * 3600, NOW) == "あと5日 14時間",
		"deadline text in days and hours"
	)
	assert_true.call(LabRules.deadline_text(NOW + 30, NOW) == "あと1分", "never shows 0 minutes")
	# 2026-09-01 00:00 JST 〜 2026-09-15 00:00 JST は「9/1〜9/14」。
	var period := {"starts_at": 1788188400, "ends_at": 1789398000}
	assert_true.call(
		LabRules.period_text(period) == "9/1〜9/14",
		"period text should end on the last day, got %s" % LabRules.period_text(period)
	)


## 投稿(1回1件)→ 投票(自分へは入れられず、同じ案へ2度入れられず、3票まで)を実通信なしで確かめる。
func _test_submit_and_vote_flow(assert_true: Callable) -> void:
	AccountService.reset()
	var tree := Engine.get_main_loop() as SceneTree
	var auth := FirebaseAuth.new(null)
	auth.uid = "author"
	var client := FakeClient.new(auth)
	tree.root.add_child(client)
	AccountService.apply_local_fields({"login_id": "tester"})
	var now := Time.get_unix_time_from_system()
	var round := {"id": "r1", "title": "お題", "starts_at": now - DAY, "ends_at": now + DAY}
	client.store["%s/r1" % LabProposalService.ROUNDS] = {
		"fields": round.duplicate(), "update_time": "t"
	}

	var kind := LabProposalService.Kind.HOURGLASS
	var first: Dictionary = await LabProposalService.submit(
		client, "author", round, "テストカード", "テストのための説明文", kind
	)
	assert_true.call(bool(first.get("ok", false)), "the first submission should succeed")
	var second: Dictionary = await LabProposalService.submit(
		client, "author", round, "もう一枚", "二件目の説明文", kind
	)
	assert_true.call(not bool(second.get("ok", false)), "a second submission in a round is refused")
	var closed := round.duplicate()
	closed["ends_at"] = now - 1
	var late: Dictionary = await LabProposalService.submit(
		client, "late", closed, "遅れた案", "締切後の説明文", kind
	)
	assert_true.call(not bool(late.get("ok", false)), "submitting after the deadline is refused")

	for author in ["b", "c", "d"]:
		var ok: Dictionary = await LabProposalService.submit(
			client, author, round, "案%s" % author, "説明文", kind
		)
		assert_true.call(bool(ok.get("ok", false)), "other players can submit too")
	var rounds: Array = await LabProposalService.fetch_rounds(client)
	assert_true.call(rounds.size() == 1 and rounds[0]["id"] == "r1", "rounds should be fetched")
	var listed: Array = await LabProposalService.list_round(client, "r1")
	assert_true.call(listed.size() == 4, "four proposals should be listed")

	var own_vote: Dictionary = await LabProposalService.vote(client, "author", round, "r1_author")
	assert_true.call(not bool(own_vote.get("ok", false)), "voting for yourself is refused")
	var vote: Dictionary = await LabProposalService.vote(client, "voter", round, "r1_author")
	assert_true.call(bool(vote.get("ok", false)), "the first vote should succeed")
	var fields: Dictionary = client.store["%s/r1_author" % LabProposalService.PROPOSALS]["fields"]
	assert_true.call(int(fields.get("good_count", 0)) == 1, "good_count should be 1 after a vote")
	var again: Dictionary = await LabProposalService.vote(client, "voter", round, "r1_author")
	assert_true.call(not bool(again.get("ok", false)), "the same voter cannot vote twice")
	for target in ["r1_b", "r1_c"]:
		var more: Dictionary = await LabProposalService.vote(client, "voter", round, target)
		assert_true.call(bool(more.get("ok", false)), "votes two and three should succeed")
	var fourth: Dictionary = await LabProposalService.vote(client, "voter", round, "r1_d")
	assert_true.call(not bool(fourth.get("ok", false)), "a fourth vote in a round is refused")
	var ballot: Dictionary = await LabProposalService.fetch_ballot(client, "r1", "voter")
	assert_true.call(
		LabRules.voted_ids(ballot).size() == LabRules.VOTES_PER_ROUND,
		"the ballot should hold three votes"
	)

	client.store["%s/r1_b" % LabProposalService.PROPOSALS]["fields"]["hidden"] = true
	listed = await LabProposalService.list_round(client, "r1")
	assert_true.call(listed.size() == 3, "a hidden proposal disappears from the list")
	var mine: Array = await LabProposalService.list_mine(client, "b")
	assert_true.call(mine.size() == 1, "the author still sees their hidden proposal")
	client.queue_free()
	AccountService.reset()
