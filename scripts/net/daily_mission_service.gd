class_name DailyMissionService
extends RefCounted
## デイリーミッションの日付判定・進捗・受取(GameDesign.md 23章)。
##
## `MatchStats` と同じ「Autoloadを使わずstaticで持つ」流儀で `user://daily_missions.json`
## へ貯め、**アカウント(uid)ごとに数える**。報酬の砂金だけは `AccountService` を通す
## (残高はアカウントにあり、手元で増やしても次の通信で消えるため)。
##
## **提示する3つは日付から決める。**乱数で選ぶと、起動し直すたびに違う課題が並ぶ。

const SAVE_PATH := "user://daily_missions.json"
## 日付の境目は日本時間の0時(GameDesign.md 23章)。
const JST_OFFSET_SECONDS := 9 * 3600
## 報酬の対象になる最低の手数。開始直後に投げ捨てて回すのを防ぐ(GameDesign.md 15章と同じ線)。
const MIN_MOVES := 10

static var _loaded := false
static var _muted := false
static var _data: Dictionary = {}
## いまの対局で数えているぶん。終局まで確定しない。
static var _session: Dictionary = {}


## 日本時間の「今日」(`YYYY-MM-DD`)。
static func today() -> String:
	var t := Time.get_datetime_dict_from_unix_time(
		Time.get_unix_time_from_system() + JST_OFFSET_SECONDS
	)
	return "%04d-%02d-%02d" % [t["year"], t["month"], t["day"]]


## 今日のミッション3件。`{"id":, "text":, "goal":, "reward":, "progress":, "claimed":}`。
static func missions(owner_uid: String) -> Array[Dictionary]:
	var bucket := _bucket(owner_uid)
	var rows: Array[Dictionary] = []
	for id: String in bucket["ids"]:
		var entry := DailyMissionData.find(id)
		if entry.is_empty():
			continue
		var row := entry.duplicate()
		row["progress"] = mini(int(bucket["progress"].get(id, 0)), int(entry["goal"]))
		row["claimed"] = bucket["claimed"].has(id)
		row["done"] = row["progress"] >= int(entry["goal"])
		rows.append(row)
	return rows


## 受け取っていない達成済みが1件でもあるか(ホーム画面の印に使う)。
static func has_claimable(owner_uid: String) -> bool:
	for row in missions(owner_uid):
		if row["done"] and not row["claimed"]:
			return true
	return false


## 報酬を受け取る。砂金を足せたら true。**通信できないときは受け取らせない**
## (手元で受取済みにすると、残高が増えないまま権利だけ消える)。
static func claim(owner_uid: String, id: String) -> bool:
	var bucket := _bucket(owner_uid)
	if bucket["claimed"].has(id):
		return false
	var entry := DailyMissionData.find(id)
	if entry.is_empty():
		return false
	if int(bucket["progress"].get(id, 0)) < int(entry["goal"]):
		return false
	if NetSession.client == null or owner_uid.is_empty():
		return false
	AccountService.grant(NetSession.client, owner_uid, int(entry["reward"]), false)
	bucket["claimed"].append(id)
	_save()
	return true


## 対局を1つ見張る。**進捗はここでは書かず、`commit()` まで手元に溜める**
## (10手に満たない対局は数えないため。GameDesign.md 23章)。
static func watch(state: MatchState, my_side: int) -> void:
	_session = {"side": my_side}
	state.trigger_fired.connect(_on_trigger)
	state.unit_flipped.connect(_on_flip)
	state.spell_cast.connect(_on_cast)
	state.unit_played.connect(_on_played)
	state.attack_performed.connect(_on_attack)


## 終局のぶんを書き込む。`moves` は総手数。
static func commit(owner_uid: String, won: bool, moves: int) -> void:
	var counts: Dictionary = _session.duplicate()
	_session = {}
	if moves < MIN_MOVES or owner_uid.is_empty():
		return
	counts[DailyMissionData.Metric.MATCH] = 1
	if won:
		counts[DailyMissionData.Metric.WIN] = 1
	var bucket := _bucket(owner_uid)
	for row in missions(owner_uid):
		var metric: int = row["metric"]
		var gained: int = int(counts.get(metric, 0))
		if gained <= 0:
			continue
		var id: String = row["id"]
		bucket["progress"][id] = int(bucket["progress"].get(id, 0)) + gained
	_save()


static func reset_for_test() -> void:
	_muted = true
	_loaded = true
	_data = {}
	_session = {}


static func _on_trigger(side: int, trigger: int) -> void:
	if trigger == CardEnums.Trigger.ON_TURN_END:
		_bump(side, DailyMissionData.Metric.TRIGGER_TURN_END)


static func _on_flip(side: int, _slot: int) -> void:
	_bump(side, DailyMissionData.Metric.FLIP)


static func _on_cast(side: int, _card: CardData) -> void:
	_bump(side, DailyMissionData.Metric.CAST_SPELL)


static func _on_played(side: int, _slot: int) -> void:
	_bump(side, DailyMissionData.Metric.UNIT_PLAYED)


static func _on_attack(side: int, _slot: int, _target_slot: int) -> void:
	_bump(side, DailyMissionData.Metric.ATTACK)


## 自分がやったぶんだけ数える。相手の反転や砂術は自分の課題を進めない。
static func _bump(side: int, metric: int) -> void:
	if not _session.has("side") or int(_session["side"]) != side:
		return
	_session[metric] = int(_session.get(metric, 0)) + 1


## その日のぶんを取り出す。日付が変わっていたら3件を選び直し、進捗を捨てる。
static func _bucket(owner_uid: String) -> Dictionary:
	_ensure_loaded()
	var key := owner_uid if not owner_uid.is_empty() else "local"
	var bucket: Dictionary = _data.get(key, {})
	var date := today()
	if bucket.get("date", "") != date:
		bucket = {"date": date, "ids": _pick(date), "progress": {}, "claimed": []}
		_data[key] = bucket
		_save()
	return bucket


## 日付から3件を選ぶ。同じ日なら誰が開いても同じ並びになる。
static func _pick(date: String) -> Array:
	var pool := DailyMissionData.all()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(date)
	var ids: Array = []
	while ids.size() < DailyMissionData.DAILY_COUNT and not pool.is_empty():
		var index := rng.randi_range(0, pool.size() - 1)
		ids.append(pool[index]["id"])
		pool.remove_at(index)
	return ids


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_data = parsed


static func _save() -> void:
	if _muted:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_data))
	file.close()
