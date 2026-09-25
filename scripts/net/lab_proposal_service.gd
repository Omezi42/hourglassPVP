class_name LabProposalService
extends RefCounted
## 掲示板〈ラボ〉の回の取得・案の一覧・投稿・投票(GameDesign.md 29章、
## Architecture.md 10.17節)。`AccountService` と同じ「staticのみ・`FirestoreClient` を
## 受け取る」流儀で、UI が Firestore を直接叩かない。
##
## お題の作成・非表示・採用の確定はここでは行わない(`tools/lab_admin/` の管理ツールの役目)。
## 1回1件・1人3票などの上限は、ここでの判定に加えて `firestore.rules` が縛る。

enum Kind { HOURGLASS, SPELL }

const ROUNDS := "lab_rounds"
const PROPOSALS := "lab_proposals"
const BALLOTS := "lab_ballots"
const ROUND_FIELDS: Array[String] = ["title", "detail", "starts_at", "ends_at", "results_fixed"]
const ROUND_LIMIT := 30
const LIST_LIMIT := 300
## 投票が他の人の投票と競合したときの読み直し回数。
const RETRY_COUNT := 3
const HTTP_OK := 200
const HTTP_NOT_FOUND := 404

const VOTE_BLOCK_MESSAGES := {
	LabRules.VoteBlock.CLOSED: "この回の投票は締め切られました。",
	LabRules.VoteBlock.OWN: "自分の案には投票できません。",
	LabRules.VoteBlock.ALREADY: "この案には投票済みです。",
	LabRules.VoteBlock.NO_VOTES_LEFT: "この回の票はすべて使いました。",
	LabRules.VoteBlock.HIDDEN: "この案は見つかりません。",
}


## 回を新しい順に(`starts_at` 降順。単一フィールドの並べ替えなので複合インデックスは要らない)。
static func fetch_rounds(client: FirestoreClient) -> Array:
	if client == null:
		return []
	var docs: Array = await client.query_recent(ROUNDS, "starts_at", ROUND_LIMIT, ROUND_FIELDS)
	return _rows(docs)


## ある回の案(非表示を除く)。
static func list_round(client: FirestoreClient, round_id: String) -> Array:
	if client == null:
		return []
	var docs: Array = await client.query_field_equals(PROPOSALS, "round_id", round_id, LIST_LIMIT)
	return LabRules.visible_rows(_rows(docs))


## 自分の投稿を新しい順に(非表示も含む。本人にだけ「非表示」と出すため)。
static func list_mine(client: FirestoreClient, uid: String) -> Array:
	if client == null or uid.is_empty():
		return []
	var rows := _rows(await client.query_field_equals(PROPOSALS, "author_uid", uid, LIST_LIMIT))
	rows.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("created_at", 0)) > float(b.get("created_at", 0))
	)
	return rows


## 自分の投票用紙(無ければ空の辞書)。
static func fetch_ballot(client: FirestoreClient, round_id: String, uid: String) -> Dictionary:
	if client == null or uid.is_empty() or round_id.is_empty():
		return {}
	return await client.get_document(_ballot_path(round_id, uid))


## 自分の案(無ければ空の辞書)。
static func fetch_own(client: FirestoreClient, round_id: String, uid: String) -> Dictionary:
	if client == null or uid.is_empty() or round_id.is_empty():
		return {}
	var fields: Dictionary = await client.get_document(_proposal_path(round_id, uid))
	if not fields.is_empty():
		fields["id"] = LabRules.entry_id(round_id, uid)
	return fields


## 投稿する。{"ok": bool, "message": String} を返す。1回1人1件はドキュメントIDで担保する。
static func submit(
	client: FirestoreClient,
	uid: String,
	round: Dictionary,
	card_name: String,
	description: String,
	kind: Kind
) -> Dictionary:
	if not AccountService.is_registered():
		return {"ok": false, "message": "投稿には登録済みアカウントが必要です。"}
	var reason := LabModeration.quick_check(card_name, description)
	if not reason.is_empty():
		return {"ok": false, "message": reason}
	if uid.is_empty() or client == null:
		return {"ok": false, "message": "接続できないため投稿できません。"}
	if not LabRules.is_open(round, Time.get_unix_time_from_system()):
		return {"ok": false, "message": "この回の募集は締め切られました。"}

	var round_id := str(round.get("id", ""))
	var path := _proposal_path(round_id, uid)
	var data := {
		"author_uid": uid,
		"round_id": round_id,
		"card_name": card_name.strip_edges(),
		"description": description.strip_edges(),
		"card_kind": "hourglass" if kind == Kind.HOURGLASS else "spell",
		"hidden": false,
		"good_count": 0,
		"result": "",
		"source": "vote",
		"created_at": Time.get_unix_time_from_system(),
	}
	var result: Dictionary = await client.commit_detailed(
		[client.update_write(path, data, {"exists": false})]
	)
	if bool(result.get("ok", false)):
		return {"ok": true, "message": "投稿しました。"}
	var existing: Dictionary = await client.get_document_meta(path)
	if bool(existing.get("exists", false)):
		return {"ok": false, "message": "この回には投稿済みです。"}
	return {"ok": false, "message": "投稿できませんでした。接続を確認してください。"}


## 投票する。{"ok": bool, "message": String, "ballot": Dictionary} を返す。
## 投票用紙の更新と案の `good_count` +1 を1回の `commit()` で行う(ルールが互いを確かめる)。
static func vote(
	client: FirestoreClient, uid: String, round: Dictionary, proposal_id: String
) -> Dictionary:
	if not AccountService.is_registered():
		return {"ok": false, "message": "投票には登録済みアカウントが必要です。"}
	if uid.is_empty() or client == null:
		return {"ok": false, "message": "接続できないため投票できません。"}

	var round_id := str(round.get("id", ""))
	var ballot_path := _ballot_path(round_id, uid)
	var proposal_path := "%s/%s" % [PROPOSALS, proposal_id]
	for _attempt in range(RETRY_COUNT):
		var ballot_doc: Dictionary = await client.get_document_meta(ballot_path)
		var ballot_code := int(ballot_doc.get("code", 0))
		if ballot_code != HTTP_OK and ballot_code != HTTP_NOT_FOUND:
			continue
		var proposal_doc: Dictionary = await client.get_document_meta(proposal_path)
		if not bool(proposal_doc.get("exists", false)):
			return {"ok": false, "message": VOTE_BLOCK_MESSAGES[LabRules.VoteBlock.HIDDEN]}
		var proposal: Dictionary = proposal_doc["fields"]
		proposal["id"] = proposal_id
		var ballot: Dictionary = ballot_doc.get("fields", {})
		var block := LabRules.vote_block(
			proposal, ballot, uid, round, Time.get_unix_time_from_system()
		)
		if block != LabRules.VoteBlock.NONE:
			return {"ok": false, "message": VOTE_BLOCK_MESSAGES[block], "ballot": ballot}

		var ids := LabRules.voted_ids(ballot).duplicate()
		ids.append(proposal_id)
		var new_ballot := {
			"voter_uid": uid, "round_id": round_id, "proposal_ids": ids, "last_id": proposal_id
		}
		var ballot_precondition := (
			{"updateTime": ballot_doc["update_time"]}
			if bool(ballot_doc.get("exists", false))
			else {"exists": false}
		)
		var writes := [
			client.update_write(ballot_path, new_ballot, ballot_precondition),
			client.update_write(
				proposal_path,
				{"good_count": int(proposal.get("good_count", 0)) + 1},
				{"updateTime": proposal_doc["update_time"]}
			),
		]
		var ok: bool = await client.commit(writes)
		if ok:
			return {"ok": true, "message": "投票しました。", "ballot": new_ballot}

	return {"ok": false, "message": "投票できませんでした。接続を確認してください。"}


static func _proposal_path(round_id: String, uid: String) -> String:
	return "%s/%s" % [PROPOSALS, LabRules.entry_id(round_id, uid)]


static func _ballot_path(round_id: String, uid: String) -> String:
	return "%s/%s" % [BALLOTS, LabRules.entry_id(round_id, uid)]


## クエリ結果を「フィールド + id」の辞書の配列にする。
static func _rows(docs: Array) -> Array:
	var rows: Array = []
	for doc in docs:
		var fields: Dictionary = doc.get("fields", {})
		fields["id"] = doc.get("id", "")
		rows.append(fields)
	return rows
