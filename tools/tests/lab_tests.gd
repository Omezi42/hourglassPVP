extends RefCounted

## 掲示板〈ラボ〉(GameDesign.md 29章)の検証。NGワードチェック・月キーの形式・
## 登録済みアカウントの判定という通信を伴わない部分と、`FakeFirestoreClient`を
## 使った投稿・投票の一連の流れ(rank_tests.gdと同じ流儀)。

const FakeClient = preload("res://tools/tests/fake_firestore_client.gd")


func run(assert_true: Callable) -> void:
	_test_quick_check(assert_true)
	_test_current_month_format(assert_true)
	_test_available_title_ids(assert_true)
	_test_is_registered(assert_true)
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


func _test_current_month_format(assert_true: Callable) -> void:
	var month := LabProposalService.current_month()
	var regex := RegEx.new()
	regex.compile("^[0-9]{4}-[0-9]{2}$")
	assert_true.call(
		regex.search(month) != null, "current_month() should look like YYYY-MM, got %s" % month
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


## 投稿(残高を減らして`pending`のドキュメントを作る)→ 投票(1回だけ通り、2回目は
## 拒否される)までを実通信なしで確かめる。
func _test_submit_and_vote_flow(assert_true: Callable) -> void:
	AccountService.reset()
	var tree := Engine.get_main_loop() as SceneTree
	var auth := FirebaseAuth.new(null)
	auth.uid = "author_uid"
	var client := FakeClient.new(auth)
	tree.root.add_child(client)
	var uid := auth.uid
	client.store[AccountService.path(uid)] = {"fields": {"currency": 500}, "update_time": "t1"}
	AccountService.apply_local_fields({"login_id": "tester", "currency": 500})

	var submit_result: Dictionary = await LabProposalService.submit(
		client, uid, "テストカード", "テストのための説明文", LabProposalService.Kind.HOURGLASS
	)
	assert_true.call(
		bool(submit_result.get("ok", false)), "submit should succeed with enough currency"
	)
	assert_true.call(
		int(AccountService.currency()) == 500 - LabProposalService.SUBMIT_COST,
		"submitting should deduct the currency cost locally"
	)

	var proposal_id := ""
	for path in client.store.keys():
		if String(path).begins_with("%s/" % LabProposalService.COLLECTION):
			proposal_id = String(path).get_file()
			break
	assert_true.call(proposal_id != "", "a proposal document should have been created")

	var voter_uid := "voter_uid"
	var first_vote: Dictionary = await LabProposalService.vote(client, voter_uid, proposal_id)
	assert_true.call(bool(first_vote.get("ok", false)), "the first vote should succeed")
	var proposal_fields: Dictionary = (
		client.store["%s/%s" % [LabProposalService.COLLECTION, proposal_id]]["fields"]
	)
	assert_true.call(
		int(proposal_fields.get("good_count", 0)) == 1, "good_count should be 1 after one vote"
	)

	var second_vote: Dictionary = await LabProposalService.vote(client, voter_uid, proposal_id)
	assert_true.call(not bool(second_vote.get("ok", false)), "the same voter cannot vote twice")
	client.queue_free()
	AccountService.reset()
