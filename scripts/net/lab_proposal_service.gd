class_name LabProposalService
extends RefCounted
## 掲示板〈ラボ〉への新規カード案の投稿・一覧・投票(GameDesign.md 29章、
## Architecture.md 10.17節)。`AccountService` / `MatchRecordService` と同じ
## 「staticのみ・`FirestoreClient` を受け取る」流儀で、UI が Firestore を直接叩かない。
##
## **承認・却下・月末の採用判断はここでは行わない。**開発側だけが開く管理ツール
## (`tools/lab_admin/`、Cloud Functions `functions/lab_admin.js`)の役目であり、
## プレイヤー側クライアントが行うのは「投稿」「一覧の取得」「投票」の3つだけ。

enum Kind { HOURGLASS, SPELL }

const COLLECTION := "lab_proposals"
const SUBMIT_COST := 300
## 残高の加算(`AccountService.grant()`)と同じ、競合したときの読み直し回数。
const RETRY_COUNT := 3
const LIST_LIMIT := 100


## 投稿する。{"ok": bool, "message": String} を返す。
## **登録済みアカウントであること**(GameDesign.md 29章)と、NGワードの自明な弾き
## (`LabModeration.quick_check()`)を通してから、購入(`AccountService.purchase()`)と
## 同じ「`updateTime`前提の`commit()`で残高を確認しつつ減算し、同時に`lab_proposals`へ
## ドキュメントを作る」処理を1回の`commit()`で行う。
static func submit(
	client: FirestoreClient, uid: String, card_name: String, description: String, kind: Kind
) -> Dictionary:
	if not AccountService.is_registered():
		return {"ok": false, "message": "投稿には登録済みアカウントが必要です。"}
	var reason := LabModeration.quick_check(card_name, description)
	if not reason.is_empty():
		return {"ok": false, "message": reason}
	if uid == "" or client == null:
		return {"ok": false, "message": "接続できないため投稿できません。"}

	var month := current_month()
	var proposal_id := _new_id()
	var proposal_path := "%s/%s" % [COLLECTION, proposal_id]
	var proposal_data := {
		"author_uid": uid,
		"card_name": card_name.strip_edges(),
		"description": description.strip_edges(),
		"card_kind": "hourglass" if kind == Kind.HOURGLASS else "spell",
		"month": month,
		"status": "pending",
		"good_count": 0,
		"result": "",
		"cost_paid": SUBMIT_COST,
		"source": "vote",
		"created_at": Time.get_unix_time_from_system(),
	}

	for _attempt in range(RETRY_COUNT):
		var doc: Dictionary = await client.get_document_meta(AccountService.path(uid))
		var fields: Dictionary = doc.get("fields", {})
		var balance := int(fields.get("currency", 0))
		if balance < SUBMIT_COST:
			return {
				"ok": false,
				"message": "%sが足りません(あと%d)。" % [CurrencyRules.CURRENCY_NAME, SUBMIT_COST - balance]
			}
		var precondition := {}
		if bool(doc.get("exists", false)) and str(doc.get("update_time", "")) != "":
			precondition = {"updateTime": doc["update_time"]}
		var player_write := (
			client
			. update_write(
				AccountService.path(uid),
				{
					"currency": balance - SUBMIT_COST,
					"updated_at": Time.get_unix_time_from_system(),
				},
				precondition
			)
		)
		var proposal_write := client.update_write(proposal_path, proposal_data, {"exists": false})
		var ok: bool = await client.commit([player_write, proposal_write])
		if ok:
			AccountService.apply_local_fields({"currency": balance - SUBMIT_COST})
			return {"ok": true, "message": "投稿しました。審査が済むと一覧へ並びます。"}

	return {"ok": false, "message": "投稿できませんでした。接続を確認してください。"}


## 承認済みの投稿を、指定した月キー(`"2026-09"`のような`YYYY-MM`)ぶん取得する。
## **`good_count`降順の並びはクライアント側で行う**(orderByを重ねると複合
## インデックスが要るため。Architecture.md 10.17節)。
static func list_approved(client: FirestoreClient, month: String) -> Array:
	if client == null:
		return []
	var docs: Array = await client.query_two_fields_equal(
		COLLECTION, "status", "approved", "month", month, LIST_LIMIT
	)
	var rows: Array = []
	for doc in docs:
		var fields: Dictionary = doc.get("fields", {})
		fields["id"] = doc.get("id", "")
		rows.append(fields)
	rows.sort_custom(func(a, b): return int(a.get("good_count", 0)) > int(b.get("good_count", 0)))
	return rows


## 投票する。1人1投稿につき1回まで、取り消しはできない(GameDesign.md 29章)。
## {"ok": bool, "message": String} を返す。
static func vote(client: FirestoreClient, uid: String, proposal_id: String) -> Dictionary:
	if not AccountService.is_registered():
		return {"ok": false, "message": "投票には登録済みアカウントが必要です。"}
	if uid == "" or client == null:
		return {"ok": false, "message": "接続できないため投票できません。"}

	var vote_path := "%s/%s/votes/%s" % [COLLECTION, proposal_id, uid]
	var proposal_path := "%s/%s" % [COLLECTION, proposal_id]

	for _attempt in range(RETRY_COUNT):
		var existing: Dictionary = await client.get_document_meta(vote_path)
		if bool(existing.get("exists", false)):
			return {"ok": false, "message": "すでに投票済みです。"}
		var doc: Dictionary = await client.get_document_meta(proposal_path)
		if not bool(doc.get("exists", false)):
			return {"ok": false, "message": "この投稿は見つかりません。"}
		var fields: Dictionary = doc.get("fields", {})
		var precondition := {}
		if str(doc.get("update_time", "")) != "":
			precondition = {"updateTime": doc["update_time"]}
		var vote_write := client.update_write(
			vote_path, {"voted_at": Time.get_unix_time_from_system()}, {"exists": false}
		)
		var count_write := client.update_write(
			proposal_path, {"good_count": int(fields.get("good_count", 0)) + 1}, precondition
		)
		var ok: bool = await client.commit([vote_write, count_write])
		if ok:
			return {"ok": true, "message": "投票しました。"}

	return {"ok": false, "message": "投票できませんでした。接続を確認してください。"}


## `YYYY-MM` の月キー。`SundayEventRules.is_active()` と同じJST換算(UTC+9)。
static func current_month() -> String:
	var jst_time := Time.get_unix_time_from_system() + 9 * 3600.0
	var dict := Time.get_datetime_dict_from_unix_time(int(jst_time))
	return "%04d-%02d" % [int(dict["year"]), int(dict["month"])]


static func _new_id() -> String:
	return "lab_%d_%d" % [Time.get_unix_time_from_system(), randi() % 1000000]
