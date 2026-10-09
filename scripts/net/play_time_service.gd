class_name PlayTimeService
extends RefCounted
## CPU戦・遠征の1局の時間(GameDesign.md 22章 / Architecture.md 10.9節)。
##
## 1局ごとに所要時間の帯・手数・勝敗だけを `stats/play_time` の日ごとの数へ足す。
## 棋譜もデッキも送らない。端末には控えず、送れなかった1局はそのまま捨てる。

const STATS_PATH := "stats/play_time"
const STATS_RETRIES := 4

const KIND_CPU := "cpu"
const KIND_SOLO := "solo"

## 帯の上限(分)とキー。最後の帯より長い局は `BAND_OVER`。
const BAND_MINUTES: Array[int] = [5, 10, 15]
const BAND_FORMAT := "m%d"
const BAND_OVER := "over"
const SECONDS_PER_MINUTE := 60.0

## 書き出した版だけで数える(開発機での対局を実際の数へ混ぜないため)。
static var _enabled := OS.has_feature("template")


static func record(kind: String, seconds: float, turns: int, won: bool) -> void:
	if not _enabled or NetSession.client == null:
		return
	if await NetSession.sign_in():
		await send(NetSession.client, FunnelService.today_key(), kind, seconds, turns, won)


## 集計の更新は `FunnelService.send()` と同じ流儀。
static func send(
	client: FirestoreClient, day: String, kind: String, seconds: float, turns: int, won: bool
) -> bool:
	for _attempt in STATS_RETRIES:
		var meta: Dictionary = await client.get_document_meta(STATS_PATH)
		if not AccountService.read_succeeded(meta):
			return false
		var precondition: Dictionary = (
			{"updateTime": meta["update_time"]} if meta.get("exists", false) else {"exists": false}
		)
		var updated := merge(meta.get("fields", {}), day, kind, seconds, turns, won)
		if await client.commit([client.update_write(STATS_PATH, updated, precondition)]):
			return true
	return false


static func merge(
	fields: Dictionary, day: String, kind: String, seconds: float, turns: int, won: bool
) -> Dictionary:
	var days: Dictionary = (fields.get("days", {}) as Dictionary).duplicate(true)
	var counts: Dictionary = days.get(day, {})
	_add(counts, kind, "games", 1)
	_add(counts, kind, "wins", 1 if won else 0)
	_add(counts, kind, "turns", turns)
	_add(counts, kind, band_key(seconds), 1)
	days[day] = counts
	return {"days": days, "updated_at": Time.get_unix_time_from_system()}


static func band_key(seconds: float) -> String:
	for minutes in BAND_MINUTES:
		if seconds <= minutes * SECONDS_PER_MINUTE:
			return BAND_FORMAT % minutes
	return BAND_OVER


static func _add(counts: Dictionary, kind: String, field: String, amount: int) -> void:
	var key := "%s_%s" % [kind, field]
	counts[key] = int(counts.get(key, 0)) + amount
