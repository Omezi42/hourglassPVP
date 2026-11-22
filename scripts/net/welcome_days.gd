class_name WelcomeDays
extends RefCounted
## はじめの7日(GameDesign.md 23章 / Architecture.md 10.11節)。
##
## 受け取った日数と最後に受け取った日(日本時間)は `players/{uid}` に持つ。
## 受取は日数・日付・砂金を1回の `commit()` で書く(片方だけ通ると権利か砂金のどちらかが消えるため)。

const DAYS := 7
const DAILY_GOLD := 100
const LAST_DAY_GOLD := 400
## この日は砂金の代わりに、第1弾のテーマを1つ選び、そのテーマのレジェンド以外を2枚ずつ受け取る。
const THEME_DAY := 2
## テーマを選ぶ弾(`PackDefinition` のid)。
const THEME_PACK_ID := "first"
const LAST_DAY_ICON := "mascot"
const FIELD_DAYS := "welcome_days"
const FIELD_DATE := "welcome_last_date"
const FIELD_COUNTS := "card_counts"


static func claimed_days() -> int:
	return int(AccountService.profile_value(FIELD_DAYS, 0))


static func can_claim_today() -> bool:
	return (
		claimed_days() < DAYS
		and str(AccountService.profile_value(FIELD_DATE, "")) != DailyMissionService.today()
	)


## 選べるテーマ(第1弾のテーマのうち、受け取れるカードが1枚でも残っているもの)。
static func theme_choices() -> Array[String]:
	var choices: Array[String] = []
	var pack := PackDefinition.load_pack(THEME_PACK_ID)
	if pack == null:
		return choices
	var fields := AccountService.ownership_fields()
	for set_id in pack.set_ids:
		if not gift_counts(fields, set_id).is_empty():
			choices.append(set_id)
	return choices


## テーマを選んだときに書く所持数(card_id → 上限)。公開済みのレジェンド以外で、上限に満たないものだけ。
static func gift_counts(fields: Dictionary, set_id: String) -> Dictionary:
	var counts := {}
	for card_id in CardSetLibrary.card_ids(set_id):
		var card := CardLibrary.find_by_id(card_id)
		if card == null or card.rarity == CardEnums.Rarity.LEGENDARY:
			continue
		var cap := CardOwnership.cap(card)
		if CardOwnership.count_in(fields, card) < cap:
			counts[card_id] = cap
	return counts


## そのテーマで受け取る枚数(テーマのタイルへ添える)。
static func gift_card_total(set_id: String) -> int:
	var fields := AccountService.ownership_fields()
	var total := 0
	var counts := gift_counts(fields, set_id)
	for card_id: String in counts:
		var card := CardLibrary.find_by_id(card_id)
		total += int(counts[card_id]) - CardOwnership.count_in(fields, card)
	return total


## 選べるテーマが1つも無ければ、ふつうの日と同じ砂金にする。
static func offers_theme(day: int) -> bool:
	return day == THEME_DAY and not theme_choices().is_empty()


## `day` は1始まり。
static func gold_for(day: int) -> int:
	if offers_theme(day):
		return 0
	return LAST_DAY_GOLD if day >= DAYS else DAILY_GOLD


static func icon_for(day: int) -> String:
	return LAST_DAY_ICON if day >= DAYS else ""


## 受け取るものの1行(「100砂金」「300砂金とアイコン『すなえる』」)。
static func reward_text(day: int) -> String:
	if offers_theme(day):
		return "テーマを1つ選べる"
	var text := "%d砂金" % gold_for(day)
	var icon := icon_for(day)
	if not icon.is_empty():
		text += "とアイコン「%s」" % UserProfileLibrary.get_icon_name(icon)
	return text


## 日の粒の下に添える短い報酬(「100」「テーマ」)。
static func short_reward_text(day: int) -> String:
	return "テーマ" if offers_theme(day) else str(gold_for(day))


## CPU戦の結果パネルの1行。今日のぶんを受け取っていて、7日に達していないときだけ出す。
static func tomorrow_line() -> String:
	var days := claimed_days()
	if days <= 0 or days >= DAYS or can_claim_today():
		return ""
	return "明日来ると %s ・ はじめの7日 %d/%d" % [reward_text(days + 1), days + 1, DAYS]


## 今日のぶんを受け取る。受け取った日(1〜7)を返し、受け取れなかったら0。
## 2つのタブで同時に押しても、読み直して今日のぶんが書かれていれば何もしない。
## `set_id` はテーマの日に選んだテーマ。日数・日付・所持数を1回の `commit()` で書く。
## 選んだテーマに受け取れるカードが残っていなければ(別のタブで引いた等)、ふつうの日と同じ砂金を渡す。
static func claim(client: FirestoreClient, uid: String, set_id := "") -> int:
	if client == null or uid.is_empty():
		return 0
	var path := AccountService.path(uid)
	var today := DailyMissionService.today()
	for _attempt in range(AccountService.GRANT_RETRY):
		var doc: Dictionary = await client.get_document_meta(path)
		if not AccountService.read_succeeded(doc):
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
			"updated_at": Time.get_unix_time_from_system(),
		}
		var gifts := _theme_gifts(fields, day, set_id)
		if not gifts.is_empty():
			var counts: Variant = fields.get(FIELD_COUNTS, {})
			var next_counts: Dictionary = (
				(counts as Dictionary).duplicate() if counts is Dictionary else {}
			)
			next_counts.merge(gifts, true)
			data[FIELD_COUNTS] = next_counts
		else:
			data["currency"] = int(fields.get("currency", 0)) + _gold_without_set(day)
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


static func _theme_gifts(fields: Dictionary, day: int, set_id: String) -> Dictionary:
	if day != THEME_DAY or set_id.is_empty():
		return {}
	var pack := PackDefinition.load_pack(THEME_PACK_ID)
	if pack == null or not pack.set_ids.has(set_id):
		return {}
	return gift_counts(fields, set_id)


static func _gold_without_set(day: int) -> int:
	return LAST_DAY_GOLD if day >= DAYS else DAILY_GOLD
