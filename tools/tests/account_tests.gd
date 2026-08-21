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
