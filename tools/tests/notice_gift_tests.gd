extends RefCounted
## お知らせとプレゼント(GameDesign.md 33章 / Architecture.md 10.22節)と、砂術「プレゼント」(6章)を確かめる。

const FakeClient = preload("res://tools/tests/fake_firestore_client.gd")
const UID := "uid-gift"
const TEST_SAVE := "user://test_announcements.json"
const PAST := "2000-01-01"

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_present_draws_and_gives_itself()
	_test_present_set_is_not_sold()
	_test_announcement_text()
	_test_announcement_unread()
	_test_gift_listing()
	await _test_gift_claim()


func _test_present_draws_and_gives_itself() -> void:
	var state := MatchState.new()
	var deck: Array = []
	for i in MatchState.DECK_SIZE:
		deck.append(CardLibrary.find_by_id("sand"))
	state.start_match(deck, deck.duplicate(), MatchState.Side.A, 12345)
	var side := MatchState.Side.A
	var foe := MatchState.Side.B
	state.hand[side].insert(0, CardLibrary.find_by_id("present"))
	state.mana[side] = MatchState.MAX_MANA
	state.max_mana[side] = MatchState.MAX_MANA
	var hand_before: int = state.hand[side].size()
	var foe_before: int = state.hand[foe].size()
	var deck_before: int = state.deck[foe].size()
	_assert.call(state.cast_spell(side, 0), "プレゼントを撃てた")
	_assert.call(state.hand[side].size() == hand_before, "撃った1枚が減り、1枚引く")
	_assert.call(state.hand[foe].size() == foe_before + 1, "相手の手札が1枚増える")
	_assert.call(state.hand[foe].back().id == "present", "相手に加わるのはプレゼント")
	_assert.call(state.deck[foe].size() == deck_before, "相手の山札は減らない")
	_assert.call(state.mana[side] == MatchState.MAX_MANA - 1, "コストは1")
	state.free()


func _test_present_set_is_not_sold() -> void:
	var card := CardLibrary.find_by_id("present")
	_assert.call(card != null and card.is_spell, "プレゼントは砂術")
	_assert.call(card.set_id == "gift_present", "プレゼントは配布のセット")
	_assert.call(CardSetLibrary.price("gift_present") == 0, "配布のセットは売らない")
	_assert.call(not CardSetLibrary.purchasable_ids().has("gift_present"), "はじめの7日のセット選びにも出ない")


func _test_announcement_text() -> void:
	var body := "**あたらしいもの**\n- カード[A]が入ったよ\n\n**なおしたもの**\n- なおしたよ\n\n-# 遊ぶ → https://example.com"
	var text := AnnouncementText.to_bbcode(body, 22, Color.WHITE)
	_assert.call(text.contains("あたらしいもの[/color]"), "見出しの行は色付きの見出し: " + text)
	_assert.call(text.contains("・カード[lb]A]が入ったよ"), "項目は行頭の点、[ は逃がす: " + text)
	_assert.call(not text.contains("遊ぶ"), "リンクの行は出さない")
	_assert.call(not text.contains("**"), "太字の印は残さない")


func _test_announcement_unread() -> void:
	var entries := AnnouncementLibrary.all()
	_assert.call(not entries.is_empty(), "お知らせが同梱されている")
	if entries.is_empty():
		return
	_assert.call(entries.size() <= AnnouncementLibrary.MAX_LISTED, "一覧は上限まで")
	if entries.size() > 1:
		_assert.call(entries[0].version > entries[1].version, "新しい順に並ぶ")
	var saved_path := AnnouncementLibrary.save_path
	AnnouncementLibrary.save_path = TEST_SAVE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	AnnouncementLibrary.forget_loaded()
	_assert.call(AnnouncementLibrary.unread_count() == 1, "はじめての起動では最新の1回だけが未読")
	_assert.call(AnnouncementLibrary.is_unread(entries[0]), "未読なのは最新の回")
	AnnouncementLibrary.mark_all_read()
	AnnouncementLibrary.forget_loaded()
	_assert.call(AnnouncementLibrary.unread_count() == 0, "開いたら全部読んだことになる(保存も残る)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	AnnouncementLibrary.save_path = saved_path
	AnnouncementLibrary.forget_loaded()


func _test_gift_listing() -> void:
	AccountService.reset()
	var first := _first_present()
	_assert.call(first != null, "はじめてのプレゼントが同梱されている")
	if first == null:
		return
	_assert.call(CardSetLibrary.has_set(first.set_id), "プレゼントのセットが存在する")
	var today := DailyMissionService.today()
	_assert.call(GiftLibrary.listed(today).has(first), "期限なしは受け取れる")
	var old := GiftData.new()
	old.id = "test_old"
	old.expires = PAST
	_assert.call(old.expired(today), "期限を過ぎた品は期限切れ")
	_assert.call(not old.expired(PAST), "期限の日はまだ受け取れる")


func _test_gift_claim() -> void:
	AccountService.reset()
	var tree := Engine.get_main_loop() as SceneTree
	var auth := FirebaseAuth.new(null)
	auth.uid = UID
	var client = FakeClient.new(auth)
	tree.root.add_child(client)
	var path := AccountService.path(UID)
	client.store[path] = {"fields": {"currency": 10}, "update_time": "t0"}
	var first := _first_present()
	var today := DailyMissionService.today()
	var before := GiftLibrary.unclaimed_count(today)

	_assert.call(await GiftService.claim(client, UID, first), "受け取れる")
	var fields: Dictionary = client.store[path]["fields"]
	_assert.call((fields["claimed_gifts"] as Array).has(first.id), "受け取りの印が書かれる")
	_assert.call((fields["owned_card_sets"] as Array).has(first.set_id), "同じ書き込みでセットが渡る")
	_assert.call(AccountService.owns_card_set(first.set_id), "すぐデッキに入れられる")
	_assert.call(GiftLibrary.unclaimed_count(today) == before - 1, "未受け取りが1件減る")
	_assert.call(not await GiftService.claim(client, UID, first), "2回は受け取れない")

	var gold := GiftData.new()
	gold.id = "test_gold"
	gold.kind = GiftData.Kind.CURRENCY
	gold.amount = 300
	_assert.call(await GiftService.claim(client, UID, gold), "砂金のプレゼントも受け取れる")
	_assert.call(int(fields["currency"]) == 310, "砂金が足される")

	client.fail_reads = 1
	var other := GiftData.new()
	other.id = "test_offline"
	other.kind = GiftData.Kind.CURRENCY
	other.amount = 1
	_assert.call(not await GiftService.claim(client, UID, other), "読み取りに失敗したら書かない")
	_assert.call(int(fields["currency"]) == 310, "失敗しても砂金は変わらない")

	client.queue_free()
	AccountService.reset()


func _first_present() -> GiftData:
	for gift in GiftLibrary.all():
		if gift.id == "first_present":
			return gift
	return null
