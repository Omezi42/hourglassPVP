class_name WelcomeDays
extends RefCounted
## はじめの7日(GameDesign.md 23章 / Architecture.md 10.11節)。
##
## 受け取った日数と最後に受け取った日(日本時間)は `players/{uid}` に持つ。
## 受取は日数・日付・砂金を1回の `commit()` で書く(片方だけ通ると権利か砂金のどちらかが消えるため)。

const DAYS := 7
const DAILY_GOLD := 100
const LAST_DAY_GOLD := 300
const LAST_DAY_ICON := "mascot"
const FIELD_DAYS := "welcome_days"
const FIELD_DATE := "welcome_last_date"
## 読み取りが失敗したときの応答コード以外で、書いてよい読み取りの結果(無い=まだ作られていない)。
const READ_OK := 200
const READ_MISSING := 404


static func claimed_days() -> int:
	return int(AccountService.profile_value(FIELD_DAYS, 0))


static func can_claim_today() -> bool:
	return (
		claimed_days() < DAYS
		and str(AccountService.profile_value(FIELD_DATE, "")) != DailyMissionService.today()
	)


## `day` は1始まり。
static func gold_for(day: int) -> int:
	return LAST_DAY_GOLD if day >= DAYS else DAILY_GOLD


static func icon_for(day: int) -> String:
	return LAST_DAY_ICON if day >= DAYS else ""


## 受け取るものの1行(「100砂金」「300砂金とアイコン『すなえる』」)。
static func reward_text(day: int) -> String:
	var text := "%d砂金" % gold_for(day)
	var icon := icon_for(day)
	if not icon.is_empty():
		text += "とアイコン「%s」" % UserProfileLibrary.get_icon_name(icon)
	return text


## CPU戦の結果パネルの1行。今日のぶんを受け取っていて、7日に達していないときだけ出す。
static func tomorrow_line() -> String:
	var days := claimed_days()
	if days <= 0 or days >= DAYS or can_claim_today():
		return ""
	return "明日来ると %s ・ はじめの7日 %d/%d" % [reward_text(days + 1), days + 1, DAYS]


## 今日のぶんを受け取る。受け取った日(1〜7)を返し、受け取れなかったら0。
## 2つのタブで同時に押しても、読み直して今日のぶんが書かれていれば何もしない。
static func claim(client: FirestoreClient, uid: String) -> int:
	if client == null or uid.is_empty():
		return 0
	var path := AccountService.path(uid)
	var today := DailyMissionService.today()
	for _attempt in range(AccountService.GRANT_RETRY):
		var doc: Dictionary = await client.get_document_meta(path)
		var code := int(doc.get("code", 0))
		if code != READ_OK and code != READ_MISSING:
			return 0
		var fields: Dictionary = doc.get("fields", {})
		var days := int(fields.get(FIELD_DAYS, 0))
		if days >= DAYS or str(fields.get(FIELD_DATE, "")) == today:
			AccountService.apply_local_fields(
				{FIELD_DAYS: days, FIELD_DATE: str(fields.get(FIELD_DATE, ""))}
			)
			return 0
		var day := days + 1
		var data := {
			FIELD_DAYS: day,
			FIELD_DATE: today,
			"currency": int(fields.get("currency", 0)) + gold_for(day),
			"updated_at": Time.get_unix_time_from_system(),
		}
		var precondition := {}
		if bool(doc.get("exists", false)) and str(doc.get("update_time", "")) != "":
			precondition = {"updateTime": doc["update_time"]}
		if await client.commit([client.update_write(path, data, precondition)]):
			AccountService.apply_local_fields(data)
			var icon := icon_for(day)
			if not icon.is_empty():
				await AccountService.unlock_icon(client, uid, icon)
			return day
	return 0
