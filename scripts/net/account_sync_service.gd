class_name AccountSyncService
extends RefCounted
## デッキ・遠征・とどめ問題・デイリーミッションを `players/{uid}` へ同期し、
## ログインしたどの端末でも同じ続きを遊べるようにする
## (GameDesign.md 14章「アカウントに紐づけるもの」/ Architecture.md 10.23節)。
##
## **引く**: サインインのたびに(`AccountService.load_profile()` から)読んだフィールドで手元を合わせる。
## **押す**: 手元を変えるたびに送る。await しない呼び出しを前提にする(画面を通信で止めないため)。
## 失敗しても退避はしない。デッキ・遠征は手元の「送れていない」印、とどめ問題・ミッションは
## 和集合で合わせるため、次のサインインで送り直される。

const FIELD_DECKS := "decks"
const FIELD_DECK_SELECTED := "deck_selected"
const FIELD_SOLO := "solo_progress"
const FIELD_PUZZLES := "puzzle_cleared"
const FIELD_MISSIONS := "daily_missions"
## 競合・通信失敗時に読み直して再試行する回数(`MatchStatsService.RETRY` と同じ)。
const RETRY := 3

## 引き終えたアカウント。引く前に押すと、別の端末で保存した内容を古い手元で上書きしてしまうため、
## これと一致するときだけ押す。
static var _synced_uid := ""


## 引き終えたアカウントのuid。まだなら空文字。
static func synced_uid() -> String:
	return _synced_uid


## ログアウト・ログインでアカウントが変わったときに呼ぶ(`AccountService.reset()`)。
static func reset() -> void:
	_synced_uid = ""


## サインインの直後、`AccountService.load_profile()` が読んだフィールドをそのまま渡す。
static func sync_after_sign_in(client: FirestoreClient, uid: String, fields: Dictionary) -> void:
	if uid.is_empty() or client == null:
		return
	_synced_uid = ""
	await _sync_decks(client, uid, fields)
	await _sync_solo(client, uid, fields)
	if PuzzleProgress.merge_remote(uid, fields.get(FIELD_PUZZLES, [])):
		await _push_puzzles(client, uid)
	if (
		not fields.has(FIELD_MISSIONS)
		or DailyMissionService.merge_remote(uid, fields[FIELD_MISSIONS])
	):
		await _push_missions(client, uid)
	_synced_uid = uid
	await DeckInboxService.receive(client, uid)
	# 引いている間に変えた分(この間は押さずに印だけ残している)を送る。
	if bool(CardDeckSave.sync_snapshot()["dirty"]):
		await push_decks()
	if bool(SoloProgress.sync_snapshot(uid)["dirty"]):
		await push_solo(uid)


static func push_decks() -> void:
	var client := _client_for(_synced_uid)
	if client == null or CardDeckSave.sync_snapshot()["owner"] != _synced_uid:
		return
	await _push_decks(client, _synced_uid)


static func push_solo(uid: String) -> void:
	var client := _client_for(uid)
	if client == null:
		return
	await _push_solo(client, uid)


static func push_puzzles(uid: String) -> void:
	var client := _client_for(uid)
	if client == null:
		return
	await _push_puzzles(client, uid)


static func push_missions(uid: String) -> void:
	var client := _client_for(uid)
	if client == null:
		return
	await _push_missions(client, uid)


## デッキ: 送れていない変更があれば手元、無ければアカウントを正とする。アカウントにまだ無ければ手元を上げる。
## 別のアカウントの控え(ログアウトした後など)は上げずに捨てる。
static func _sync_decks(client: FirestoreClient, uid: String, fields: Dictionary) -> void:
	var snap := CardDeckSave.sync_snapshot()
	var owner := str(snap["owner"])
	var mine := owner == uid or owner.is_empty()
	if mine and bool(snap["dirty"]):
		CardDeckSave.claim_owner(uid)
		await _push_decks(client, uid)
	elif fields.has(FIELD_DECKS):
		CardDeckSave.replace_from_account(
			uid, fields[FIELD_DECKS], int(fields.get(FIELD_DECK_SELECTED, 0))
		)
	elif mine and not (snap["decks"] as Array).is_empty():
		CardDeckSave.claim_owner(uid)
		await _push_decks(client, uid)
	else:
		CardDeckSave.replace_from_account(uid, [], 0)


## 遠征: デッキと同じ決め方。アカウントにまだ無ければ手元(紐づける前から遊んでいた分)を上げる。
static func _sync_solo(client: FirestoreClient, uid: String, fields: Dictionary) -> void:
	var snap := SoloProgress.sync_snapshot(uid)
	if bool(snap["dirty"]) or not fields.has(FIELD_SOLO):
		await _push_solo(client, uid)
	else:
		SoloProgress.replace_from_account(uid, fields[FIELD_SOLO])


static func _push_decks(client: FirestoreClient, uid: String) -> void:
	var snap := CardDeckSave.sync_snapshot()
	var data := {
		FIELD_DECKS: snap["decks"],
		FIELD_DECK_SELECTED: snap["selected"],
		"updated_at": Time.get_unix_time_from_system(),
	}
	if await client.set_document(AccountService.path(uid), data):
		CardDeckSave.mark_synced(uid, int(snap["revision"]))


static func _push_solo(client: FirestoreClient, uid: String) -> void:
	var snap := SoloProgress.sync_snapshot(uid)
	var data := {FIELD_SOLO: snap["entry"], "updated_at": Time.get_unix_time_from_system()}
	if await client.set_document(AccountService.path(uid), data):
		SoloProgress.mark_synced(uid, int(snap["revision"]))


## とどめ問題・ミッションは両方を合わせた値を書く。別の端末の書き込みを消さないよう、
## `updateTime` を前提条件にして読み直しながら書く(`MatchStatsService` と同じ流儀)。
static func _push_puzzles(client: FirestoreClient, uid: String) -> void:
	await _push_merged(
		client,
		uid,
		FIELD_PUZZLES,
		func(remote: Variant) -> Variant:
			PuzzleProgress.merge_remote(uid, remote if remote is Array else [])
			return PuzzleProgress.cleared_ids(uid)
	)


static func _push_missions(client: FirestoreClient, uid: String) -> void:
	await _push_merged(
		client,
		uid,
		FIELD_MISSIONS,
		func(remote: Variant) -> Variant:
			if remote is Dictionary:
				DailyMissionService.merge_remote(uid, remote)
			return DailyMissionService.bucket_snapshot(uid)
	)


static func _push_merged(
	client: FirestoreClient, uid: String, field: String, merge: Callable
) -> void:
	var path := AccountService.path(uid)
	for _attempt in range(RETRY):
		var doc: Dictionary = await client.get_document_meta(path)
		if not AccountService.read_succeeded(doc):
			return
		var fields: Dictionary = doc.get("fields", {})
		var data := {
			field: merge.call(fields.get(field, null)),
			"updated_at": Time.get_unix_time_from_system(),
		}
		var precondition := {}
		if bool(doc.get("exists", false)) and str(doc.get("update_time", "")) != "":
			precondition = {"updateTime": doc["update_time"]}
		if await client.commit([client.update_write(path, data, precondition)]):
			return


## 引き終えたアカウントへ送れるときだけクライアントを返す。
static func _client_for(uid: String) -> FirestoreClient:
	if uid.is_empty() or uid != _synced_uid:
		return null
	return NetSession.client
