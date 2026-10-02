extends RefCounted
## `players/{uid}` の読み取りに失敗したとき、空のフィールドを土台に書き込まないこと
## (Architecture.md 10.2)。失敗した分は `AccountStore` の控えへ回り、次に読めたときに足し込まれる。
##
## `AccountStore` は `user://account.json` を直接書くため、控える → 上書き → 検証 → 戻すの往復にする
## (docs/Pitfalls.md「触ってはいけないもの」)。

const FakeClient = preload("res://tools/tests/fake_firestore_client.gd")
const UID := "uid-read-failure"
const BALANCE := 500
const GRANT := 30
const LATER_GRANT := 10
const SET_ID := "set-read-failure"
const OWNED_SETS := ["set-a", "set-b"]
const SHOP_ICON := "mascot"

var _assert: Callable
var _client: FirestoreClient
var _path := AccountService.path(UID)


func run(assert_true: Callable) -> void:
	_assert = assert_true
	var backup: Variant = _backup()
	var auth := FirebaseAuth.new(null)
	auth.uid = UID
	_client = FakeClient.new(auth)
	(Engine.get_main_loop() as SceneTree).root.add_child(_client)

	await _test_grant_keeps_balance_on_read_failure()
	await _test_unlock_keeps_owned_on_read_failure()
	await _test_purchase_stops_on_read_failure()
	await _test_grant_creates_missing_document()

	_client.queue_free()
	AccountService.reset()
	_restore(backup)


func _reset_state() -> void:
	if FileAccess.file_exists(AccountStore.SAVE_PATH):
		DirAccess.remove_absolute(AccountStore.SAVE_PATH)
	AccountService.reset()
	_client.store.clear()
	_client.fail_reads = 0
	_client.commit_count = 0
	_client.store[_path] = {
		"fields": {"currency": BALANCE, "owned_card_sets": OWNED_SETS.duplicate()},
		"update_time": "t0"
	}


func _fields() -> Dictionary:
	return _client.store[_path]["fields"]


func _test_grant_keeps_balance_on_read_failure() -> void:
	_reset_state()
	_client.fail_reads = 1
	await AccountService.grant(_client, UID, GRANT, false)
	_assert.call(_client.commit_count == 0, "grant should not write after a failed read")
	_assert.call(int(_fields()["currency"]) == BALANCE, "a failed read must not reset the balance")
	_assert.call(
		AccountStore.get_pending_currency() == GRANT, "the grant should wait in the pending store"
	)

	var balance: int = await AccountService.grant(_client, UID, LATER_GRANT, false)
	var expected := BALANCE + GRANT + LATER_GRANT
	_assert.call(
		int(_fields()["currency"]) == expected, "the next grant should add the pending amount too"
	)
	_assert.call(balance == expected, "grant should return the new balance")
	_assert.call(AccountStore.get_pending_currency() == 0, "the pending amount should be cleared")


func _test_unlock_keeps_owned_on_read_failure() -> void:
	_reset_state()
	var pending_key := "pending_card_sets"
	_client.fail_reads = 1
	await AccountService.unlock_card_set(_client, UID, SET_ID)
	_assert.call(_client.commit_count == 0, "unlock should not write after a failed read")
	_assert.call(
		_fields()["owned_card_sets"] == OWNED_SETS, "a failed read must not shrink the owned list"
	)
	_assert.call(
		AccountStore.get_pending_unlocks(pending_key).has(SET_ID),
		"the unlock should wait in the pending store"
	)

	await AccountService.unlock_card_set(_client, UID, SET_ID)
	var owned: Array = _fields()["owned_card_sets"]
	_assert.call(
		owned.size() == OWNED_SETS.size() + 1 and owned.has(SET_ID),
		"a later unlock should append to the existing list"
	)
	_assert.call(
		not AccountStore.get_pending_unlocks(pending_key).has(SET_ID),
		"the pending unlock should be cleared"
	)


func _test_purchase_stops_on_read_failure() -> void:
	_reset_state()
	_client.fail_reads = 1
	var result: Dictionary = await AccountService.purchase(
		_client, UID, ShopCatalog.Kind.ICON, SHOP_ICON
	)
	_assert.call(not result["ok"], "purchase should fail after a failed read")
	_assert.call(_client.commit_count == 0, "purchase should not write after a failed read")
	_assert.call(int(_fields()["currency"]) == BALANCE, "the balance should be untouched")


## 「まだ無い」(404)は失敗ではない。最初の獲得でドキュメントが作られる。
func _test_grant_creates_missing_document() -> void:
	_reset_state()
	_client.store.clear()
	await AccountService.grant(_client, UID, GRANT, false)
	_assert.call(
		_client.store.has(_path) and int(_fields()["currency"]) == GRANT,
		"a missing document should be created by the first grant"
	)
	_assert.call(AccountStore.get_pending_currency() == 0, "nothing should be left pending")


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
