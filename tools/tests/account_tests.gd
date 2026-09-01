extends RefCounted

## フェーズ27: アカウント(`AccountStore`/`FirebaseAuth`の入力検証)と
## 通貨(`CurrencyRules`)の、通信を伴わない部分を検証する。
## run_tests.gdが1000行の上限に達しているため別ファイルへ切り出している
## (sound_settings_tests.gdと同じ流儀。判定は_assert_trueをCallableで受け取る)。
##
## 実通信を伴う経路(登録・ログイン・残高の加算)は2つのアカウントを同時に
## 動かさないと再現できないため、ここでは扱わない。


func run(assert_true: Callable) -> void:
	_test_credential_validation(assert_true)
	_test_synthetic_email(assert_true)
	_test_currency_rules(assert_true)
	_test_account_store(assert_true)
	_test_local_replay_ownership(assert_true)
	_test_text_glyphs(assert_true)
	_test_profile_customization(assert_true)
	_test_emotes(assert_true)


func _test_credential_validation(assert_true: Callable) -> void:
	assert_true.call(
		FirebaseAuth.validate_credentials("omezi", "secret123") == "",
		"a normal id and password should pass validation"
	)
	assert_true.call(
		FirebaseAuth.validate_credentials("  Omezi  ", "secret123") == "",
		"validation should trim and lowercase the id before checking it"
	)
	assert_true.call(
		FirebaseAuth.validate_credentials("ab", "secret123") != "",
		"an id shorter than the minimum should be rejected"
	)
	assert_true.call(
		FirebaseAuth.validate_credentials("a".repeat(21), "secret123") != "",
		"an id longer than the maximum should be rejected"
	)
	assert_true.call(
		FirebaseAuth.validate_credentials("砂時計", "secret123") != "",
		"an id with characters invalid in an address should be rejected"
	)
	assert_true.call(
		FirebaseAuth.validate_credentials("ome zi", "secret123") != "",
		"an id containing a space should be rejected"
	)
	assert_true.call(
		FirebaseAuth.validate_credentials("omezi", "12345") != "",
		"a password shorter than the minimum should be rejected"
	)


func _test_synthetic_email(assert_true: Callable) -> void:
	# IDの一意性はFirebase側のアドレスの一意性に委ねているため、
	# 大文字小文字の違いで別アカウントを作れてしまわないことを確かめる
	var upper := FirebaseAuth._to_email("Omezi")
	var lower := FirebaseAuth._to_email("omezi")
	assert_true.call(upper == lower, "the same id in different cases should map to one address")
	assert_true.call(
		lower == "omezi@%s" % FirebaseAuth.SYNTHETIC_EMAIL_DOMAIN,
		"the id should map to <id>@<synthetic domain>"
	)
	assert_true.call(
		FirebaseAuth._to_email("  omezi ") == lower,
		"surrounding spaces should not change the address"
	)


func _test_currency_rules(assert_true: Callable) -> void:
	var enough := CurrencyRules.MIN_MOVES

	var random_win := CurrencyRules.evaluate(CurrencyRules.MatchKind.RANDOM, true, enough, 0)
	assert_true.call(int(random_win["amount"]) == 30, "a random match win should award 30")
	var random_loss := CurrencyRules.evaluate(CurrencyRules.MatchKind.RANDOM, false, enough, 0)
	assert_true.call(int(random_loss["amount"]) == 10, "a random match loss should still award 10")

	var room_win := CurrencyRules.evaluate(CurrencyRules.MatchKind.ROOM, true, enough, 0)
	assert_true.call(int(room_win["amount"]) == 10, "a room match win should award 10")
	var cpu_win := CurrencyRules.evaluate(CurrencyRules.MatchKind.CPU, true, enough, 0)
	assert_true.call(int(cpu_win["amount"]) == 5, "a cpu match win should award 5")

	# 自分ひとりで繰り返せる対局ほど報酬が低いこと(GameDesign.md 15章の線引き)
	assert_true.call(
		(
			int(cpu_win["amount"]) < int(room_win["amount"])
			and int(room_win["amount"]) < int(random_win["amount"])
		),
		"rewards should decrease as a match gets easier to repeat alone"
	)

	var short_match := CurrencyRules.evaluate(CurrencyRules.MatchKind.RANDOM, true, enough - 1, 0)
	assert_true.call(
		int(short_match["amount"]) == 0, "a match shorter than the minimum awards none"
	)
	assert_true.call(
		str(short_match["reason"]) != "", "a match that awards none should explain why"
	)

	var capped := CurrencyRules.evaluate(
		CurrencyRules.MatchKind.CPU, true, enough, CurrencyRules.CPU_DAILY_LIMIT
	)
	assert_true.call(int(capped["amount"]) == 0, "cpu matches past the daily cap award none")
	assert_true.call(str(capped["reason"]) != "", "reaching the daily cap should explain why")
	var under_cap := CurrencyRules.evaluate(
		CurrencyRules.MatchKind.CPU, true, enough, CurrencyRules.CPU_DAILY_LIMIT - 1
	)
	assert_true.call(int(under_cap["amount"]) == 5, "the last cpu match under the cap still awards")

	# ローカル対戦・観戦・リプレイ再生は「自分が1人のプレイヤーとして対局した」とは
	# 言えないため対象外。理由の表示も出さない(獲得できて当然の場面ではないため)
	var none := CurrencyRules.evaluate(CurrencyRules.MatchKind.NONE, true, enough, 0)
	assert_true.call(int(none["amount"]) == 0, "an unrewarded match kind awards none")
	assert_true.call(str(none["reason"]) == "", "an unrewarded match kind should not explain")

	assert_true.call(
		CurrencyRules.format_reward(random_win) == "+30 %s" % CurrencyRules.CURRENCY_NAME,
		"a reward should be formatted with a leading plus"
	)
	assert_true.call(
		CurrencyRules.format_reward(none) == "", "a silent non-reward should format to nothing"
	)


## user://の実データを壊さないよう、DeckSaveのテストと同じバックアップ→復元の往復を使う。
func _test_account_store(assert_true: Callable) -> void:
	var backup: Variant = _backup()

	AccountStore.clear_session()
	var empty := AccountStore.load_session()
	assert_true.call(
		empty["uid"] == "" and empty["refresh_token"] == "" and empty["login_id"] == "",
		"a cleared store should report an empty session"
	)

	AccountStore.save_session("uid-1", "refresh-1", "omezi")
	var restored := AccountStore.load_session()
	assert_true.call(restored["uid"] == "uid-1", "the uid should survive a save/load round trip")
	assert_true.call(
		restored["refresh_token"] == "refresh-1", "the refresh token should survive the round trip"
	)
	assert_true.call(restored["login_id"] == "omezi", "the login id should survive the round trip")

	# 更新用トークンが無いのに保存できると、次回起動時に復帰できないセッションが残る
	AccountStore.save_session("uid-2", "", "omezi")
	assert_true.call(
		AccountStore.load_session()["uid"] == "",
		"saving without a refresh token should clear the session instead"
	)

	AccountStore.save_session("uid-1", "refresh-1", "omezi")
	AccountStore.clear_pending_currency()
	AccountStore.add_pending_currency(30)
	AccountStore.add_pending_currency(5)
	assert_true.call(
		AccountStore.get_pending_currency() == 35, "pending currency should accumulate"
	)
	assert_true.call(
		AccountStore.load_session()["uid"] == "uid-1",
		"storing pending currency should not disturb the saved session"
	)
	AccountStore.add_pending_currency(-10)
	assert_true.call(
		AccountStore.get_pending_currency() == 35, "a non-positive grant should not be stored"
	)
	AccountStore.clear_pending_currency()
	assert_true.call(AccountStore.get_pending_currency() == 0, "clearing should zero the pending")

	# ログアウトで捨てる。未反映の砂金は次のアカウントのものではないため一緒に消える
	AccountStore.add_pending_currency(7)
	AccountStore.clear_session()
	assert_true.call(
		AccountStore.get_pending_currency() == 0, "logging out should drop pending currency too"
	)

	_restore(backup)


## CPU戦のリプレイがアカウントごとに分かれること(AJ-2)。
## user://の実データを壊さないよう、ここでもバックアップ→復元の往復を使う。
func _test_local_replay_ownership(assert_true: Callable) -> void:
	var backup: Variant = _backup_path(LocalReplayService.SAVE_PATH)

	var file := FileAccess.open(LocalReplayService.SAVE_PATH, FileAccess.WRITE)
	file.store_string("[]")
	file = null

	LocalReplayService.mark_finished({"winner": "a"}, "uid-alice")
	LocalReplayService.mark_finished({"winner": "b"}, "uid-alice")
	LocalReplayService.mark_finished({"winner": "a"}, "uid-bob")

	assert_true.call(
		LocalReplayService.list_replays("uid-alice").size() == 2,
		"a replay list should only contain that account's own cpu matches"
	)
	assert_true.call(
		LocalReplayService.list_replays("uid-bob").size() == 1,
		"another account should see only its own cpu matches"
	)
	assert_true.call(
		LocalReplayService.list_replays("uid-carol").is_empty(),
		"an account that never played should see no cpu matches"
	)
	# サインインできていないときは絞り込む基準が無いため全件返す
	assert_true.call(
		LocalReplayService.list_replays("").size() == 3,
		"an unknown account should not filter the list at all"
	)

	# 上限は所有者ごとに数える。別のアカウントの記録を巻き添えで消さないこと
	for i in range(LocalReplayService.RETENTION_LIMIT + 2):
		LocalReplayService.mark_finished({"winner": "a", "index": i}, "uid-alice")
	assert_true.call(
		LocalReplayService.list_replays("uid-alice").size() == LocalReplayService.RETENTION_LIMIT,
		"an account's cpu replays should be capped at the retention limit"
	)
	assert_true.call(
		LocalReplayService.list_replays("uid-bob").size() == 1,
		"overflowing one account should not drop another account's replays"
	)

	_restore_path(LocalReplayService.SAVE_PATH, backup)


func _backup_path(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	var content := file.get_as_text()
	file = null
	return content


func _restore_path(path: String, backup: Variant) -> void:
	if backup == null:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(str(backup))


func _backup() -> Variant:
	if not FileAccess.file_exists(AccountStore.SAVE_PATH):
		return null
	var file := FileAccess.open(AccountStore.SAVE_PATH, FileAccess.READ)
	var content := file.get_as_text()
	file = null
	return content


func _restore(backup: Variant) -> void:
	if backup == null:
		if FileAccess.file_exists(AccountStore.SAVE_PATH):
			DirAccess.remove_absolute(AccountStore.SAVE_PATH)
		return
	var file := FileAccess.open(AccountStore.SAVE_PATH, FileAccess.WRITE)
	file.store_string(str(backup))


## 表示名に使える文字(GameDesign.md 14章)。同梱フォントに字形が無い文字は
## 入力で取り除き、相手から届いた名前では「?」へ置き換える。
func _test_text_glyphs(assert_true: Callable) -> void:
	assert_true.call(
		TextGlyphs.supports_text("砂時計アリーナ Omezi 42"),
		"japanese, latin and digits should all be supported by the bundled font"
	)
	# U+1F600(絵文字)と U+D55C(ハングル)はいずれも字形が無い
	var emoji := String.chr(0x1F600)
	assert_true.call(not TextGlyphs.supports_text(emoji), "an emoji should not be supported")
	assert_true.call(
		not TextGlyphs.supports_text(String.chr(0xD55C)), "hangul should not be supported"
	)
	assert_true.call(
		TextGlyphs.sanitize("砂" + emoji + "時計") == "砂時計",
		"sanitize should drop unsupported characters and keep the rest"
	)
	assert_true.call(
		TextGlyphs.replace_unsupported("砂" + emoji + "時計") == "砂?時計",
		"replace_unsupported should keep the position of a dropped character"
	)


func _test_profile_customization(assert_true: Callable) -> void:
	# UserProfileLibraryの検証
	assert_true.call(
		UserProfileLibrary.DEFAULT_ICON_ID == "sand", "default icon id should be sand"
	)
	var icons := UserProfileLibrary.get_available_icon_ids()
	assert_true.call(not icons.has("mascot"), "available icons should not include mascot")
	assert_true.call(icons.has("sand"), "available icons should include sand")
	assert_true.call(icons.has("hour"), "available icons should include hour")
	assert_true.call(
		UserProfileLibrary.get_icon_texture("sand") != null, "sand icon texture exists"
	)
	assert_true.call(
		UserProfileLibrary.get_icon_texture("unknown_id") != null, "fallback icon texture exists"
	)

	var titles := UserProfileLibrary.get_available_title_ids()
	assert_true.call(titles.has("novice"), "available titles should include novice")
	assert_true.call(titles.has("none"), "available titles should include none")
	assert_true.call(not titles.has("cpu_basic"), "cpu title should not be in available titles")
	assert_true.call(
		UserProfileLibrary.get_title_display("novice") == "駆け出し決闘者", "novice title display"
	)
	assert_true.call(
		UserProfileLibrary.get_title_display("none") == "", "none title display should be empty"
	)

	# AccountStoreのローカル保存と復元の検証
	var backup: Variant = _backup()
	AccountStore.save_local_customization("crown", "none")
	var loaded := AccountStore.load_local_customization()
	assert_true.call(loaded["icon_id"] == "crown", "custom icon_id should survive roundtrip")
	assert_true.call(loaded["title_id"] == "none", "custom title_id should survive roundtrip")

	# AccountServiceのフォールバック検証
	AccountService.reset()
	assert_true.call(AccountService.icon_id() == "crown", "AccountService should read local icon_id")
	assert_true.call(AccountService.title_id() == "none", "AccountService should read local title_id")

	AccountStore.save_local_customization("", "")
	AccountService.reset()
	assert_true.call(
		AccountService.icon_id() == UserProfileLibrary.DEFAULT_ICON_ID,
		"empty icon_id should fallback to default"
	)
	assert_true.call(
		AccountService.title_id() == UserProfileLibrary.DEFAULT_TITLE_ID,
		"empty title_id should fallback to default"
	)

	_restore(backup)


func _test_emotes(assert_true: Callable) -> void:
	var ids := EmoteLibrary.get_emote_ids()
	assert_true.call(ids.size() == 4, "should have 4 emotes")
	assert_true.call(EmoteLibrary.get_emote_text("hello") == "よろしくお願いします", "hello text")
	assert_true.call(EmoteLibrary.get_emote_text("praise") == "見事な一手です", "praise text")
	assert_true.call(EmoteLibrary.get_emote_text("shock") == "なんだと…", "shock text")
	assert_true.call(
		EmoteLibrary.get_emote_text("advantage") == "こちらに傾いているようですね", "advantage text"
	)

	var action := MatchAction.emote(MatchState.Side.A, "hello")
	assert_true.call(action["type"] == "emote", "action type should be emote")
	assert_true.call(action["side"] == MatchState.Side.A, "action side should match")
	assert_true.call(action["emote_id"] == "hello", "action emote_id should match")

	var state := MatchState.new()
	var ok: bool = MatchAction.apply(state, action)
	assert_true.call(ok, "applying emote action should return true without error")
	state.queue_free()
