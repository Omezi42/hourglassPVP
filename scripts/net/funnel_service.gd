class_name FunnelService
extends RefCounted
## 来た人がどの段階まで進んだか(GameDesign.md 22章 / Architecture.md 10.9節)。
##
## 段階ごとに「この端末で初めて通った」ときだけ `stats/funnel` の日ごとの人数へ1を足す。
## 端末の控えは送れたものだけを `sent` へ移すため、送れなかった段階は次の起動で送り直される。
## 失敗しても画面には何も出さない。

const STATS_PATH := "stats/funnel"
const STATS_RETRIES := 4
const DAY_PREFIX := "d"

const LAUNCH := "launch"
const RETURN := "return"
const HOME := "home"
const TUTORIAL_START := "tutorial_start"
const TUTORIAL_CLEAR := "tutorial_clear"
const MATCH_END := "match_end"
const ONLINE_TRY := "online_try"
const ONLINE_END := "online_end"
const DAILY_PUZZLE := "daily_puzzle"
## 誘導対局の手順(`tutorial_step()` で番号を付ける)。
const TUTORIAL_STEP_FORMAT := "tutorial_%02d"
## ランクマッチの最初の待機(`RankedWaitFunnel`)。
const RANKED_WAIT := "ranked_wait"
const RANKED_WAIT_SECONDS: Array[int] = [5, 15, 30, 60]
const RANKED_WAIT_FORMAT := "ranked_wait_%d"
const RANKED_CPU := "ranked_cpu"
const RANKED_MATCHED := "ranked_matched"
const RANKED_CANCEL := "ranked_cancel"

const KEY_FIRST_DAY := "first_day"
const KEY_SENT := "sent"
const KEY_PENDING := "pending"
const KEY_EXCLUDED := "excluded"

const SAVE_PATH := "user://funnel.json"

## 書き出した版だけで数える(開発機での起動を実際の人数へ混ぜないため)。
static var _enabled := OS.has_feature("template")
static var _save_path := SAVE_PATH
static var _loaded := false
static var _state: Dictionary = {}
static var _sending := false


## 起動時に1度呼ぶ。初めての日を控え、別の日の起動なら「別の日に来た」も立てる。
static func on_launch() -> void:
	if not _enabled:
		return
	_ensure_loaded()
	var today := today_key()
	if str(_state.get(KEY_FIRST_DAY, "")).is_empty():
		# 数え始める前から遊んでいた端末は、初めて来た人ではないため一切数えない。
		if UiState.has_seen_home():
			_state[KEY_EXCLUDED] = true
		_state[KEY_FIRST_DAY] = today
		_save()
	if is_excluded():
		return
	_mark(LAUNCH, today)
	if _state[KEY_FIRST_DAY] != today:
		_mark(RETURN, today)
	flush()


static func reach(step: String) -> void:
	if not _enabled:
		return
	_ensure_loaded()
	if is_excluded():
		return
	_mark(step, today_key())
	flush()


## 控えてある段階を送る。サインインできなければ次の機会へ回す。
static func flush() -> void:
	if _sending or pending().is_empty() or NetSession.client == null:
		return
	_sending = true
	if await NetSession.sign_in():
		await flush_with(NetSession.client)
	_sending = false


## 送っている間に立った段階は、次の1本にまとめて送る(送信は直列にする)。
static func flush_with(client: FirestoreClient) -> void:
	while not pending().is_empty():
		var batch := pending().duplicate()
		if not await send(client, batch):
			return
		var sent: Array = _state.get(KEY_SENT, [])
		for step: String in batch:
			(_state[KEY_PENDING] as Dictionary).erase(step)
			sent.append(step)
		_state[KEY_SENT] = sent
		_save()


## `batch` は {段階: 日のキー}。集計の更新は `MatchRecordService._bump_stats()` と同じ流儀。
static func send(client: FirestoreClient, batch: Dictionary) -> bool:
	for _attempt in STATS_RETRIES:
		var meta: Dictionary = await client.get_document_meta(STATS_PATH)
		var precondition: Dictionary = (
			{"updateTime": meta["update_time"]} if meta.get("exists", false) else {"exists": false}
		)
		var updated := merge(meta.get("fields", {}), batch, PortalInfo.site())
		if await client.commit([client.update_write(STATS_PATH, updated, precondition)]):
			return true
	return false


## 合計(`days`)と配信先ごと(`portals`)の両方へ同じ段階を足す。
static func merge(fields: Dictionary, batch: Dictionary, site: String) -> Dictionary:
	var days: Dictionary = (fields.get("days", {}) as Dictionary).duplicate(true)
	var portals: Dictionary = (fields.get("portals", {}) as Dictionary).duplicate(true)
	var site_days: Dictionary = portals.get(site, {})
	for step: String in batch:
		var day: String = batch[step]
		_bump(days, day, step)
		_bump(site_days, day, step)
	portals[site] = site_days
	return {"days": days, "portals": portals, "updated_at": Time.get_unix_time_from_system()}


static func _bump(days: Dictionary, day: String, step: String) -> void:
	var counts: Dictionary = days.get(day, {})
	counts[step] = int(counts.get(step, 0)) + 1
	days[day] = counts


static func tutorial_step(index: int) -> String:
	return TUTORIAL_STEP_FORMAT % index


static func ranked_wait_after(seconds: int) -> String:
	return RANKED_WAIT_FORMAT % seconds


## Firestoreのフィールドパスで数字始まりを避けるため、先頭に英字を付ける。
static func today_key() -> String:
	var date := Time.get_date_dict_from_system()
	return "%s%04d%02d%02d" % [DAY_PREFIX, date["year"], date["month"], date["day"]]


static func pending() -> Dictionary:
	_ensure_loaded()
	return _state.get(KEY_PENDING, {})


static func is_excluded() -> bool:
	_ensure_loaded()
	return bool(_state.get(KEY_EXCLUDED, false))


static func has_reached(step: String) -> bool:
	_ensure_loaded()
	return (_state.get(KEY_SENT, []) as Array).has(step) or pending().has(step)


## テストが実データを触らずに動かすための差し替え。`path` を空にすると元へ戻す。
static func use_for_test(path: String) -> void:
	_enabled = not path.is_empty() or OS.has_feature("template")
	_save_path = SAVE_PATH if path.is_empty() else path
	reload_state()


static func reload_state() -> void:
	_loaded = false
	_state = {}
	_ensure_loaded()


static func _mark(step: String, day: String) -> void:
	if has_reached(step):
		return
	var queued: Dictionary = pending()
	queued[step] = day
	_state[KEY_PENDING] = queued
	_save()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(_save_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_state = parsed


static func _save() -> void:
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_state))
	file.close()
