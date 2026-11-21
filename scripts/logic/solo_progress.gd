class_name SoloProgress
extends RefCounted
## 遠征(ソロモード)の保存と記録(GameDesign.md 27章、Architecture.md 10.15節)。
## `user://solo_progress.json` へアカウントごと(未サインインは `"local"`)に持つ。
##
## 以前の形式(ステージidの配列)を読んだときは空の記録として扱う。
##
## アカウントへ同期する(Architecture.md 10.23節)。1アカウントぶんの記録を丸ごと送り、
## まだ送れていない変更があることを `SYNC_DIRTY` で控える(送る値には含めない)。

const SAVE_PATH := "user://solo_progress.json"
const SYNC_DIRTY := "sync_dirty"
const SYNC_REVISION := "sync_revision"
## 週替わりの遠征の別枠(GameDesign.md 27章「週替わりの遠征」)。
## `{"week": id, "run": {...}?, "result": {"wins", "hp"}?, "finished": {...}?}`(?は無いとき null)。
const WEEKLY_KEY := "weekly"
const ABANDONED_MID_BATTLE := "abandoned_mid_battle"

static var _loaded := false
static var _muted := false
static var _data: Dictionary = {}


## 保存中の遠征。`in_battle` のまま残っていたら負けとして遠征を終え、`null` を返す
## (GameDesign.md 27章「中断と再開」)。
static func load_run(uid: String) -> SoloRun:
	var raw: Variant = _entry(uid).get("run", null)
	if not (raw is Dictionary):
		return null
	var run := SoloRun.from_dict(raw)
	if not run.in_battle:
		return run
	FunnelService.reach_first_solo_battle(FunnelService.SOLO_B1_QUIT, run.floor)
	run.finish_battle(false, 0, RandomNumberGenerator.new())
	record(uid, run)
	save_finished(uid, run, ABANDONED_MID_BATTLE)
	clear_run(uid)
	return null


## 遠征を保存する。週替わりの遠征(`weekly_id` あり)は別枠へ入れる。
static func save_run(uid: String, run: SoloRun) -> void:
	if run != null and not run.weekly_id.is_empty():
		var weekly_entry := _entry(uid)
		_weekly_slot(uid, run.weekly_id)["run"] = run.to_dict()
		_commit(uid, weekly_entry)
		return
	var entry := _entry(uid)
	entry["run"] = null if run == null else run.to_dict()
	if run != null:
		entry["started"] = true
	_commit(uid, entry)


static func clear_run(uid: String) -> void:
	save_run(uid, null)


## 遠征が終わったとき(負け・踏破・対局途中の中断扱い)の記録(GameDesign.md 27章「画面」)。
## 「遠征をやめる」では呼ばない(自分で終えたため、記録を出さない)。
static func save_finished(uid: String, run: SoloRun, reason: String) -> void:
	var entry := _entry(uid)
	entry["finished"] = {"run": run.to_dict(), "reason": reason}
	_commit(uid, entry)


## 保存中の遠征の記録を読み、読んだら消す(次に遠征の画面を開いたとき1度だけ出すため)。
static func take_finished(uid: String) -> Dictionary:
	var entry := _entry(uid)
	var finished: Variant = entry.get("finished", null)
	if not (finished is Dictionary):
		return {}
	entry["finished"] = null
	_commit(uid, entry)
	return finished


## 遠征を1度でも始めたか(GameDesign.md 18章「つぎはここ」)。この印を持つ前の版で始めた人は、
## 進行中の遠征・終わった遠征の記録・選んだ深さのどれかが残っているため、それも始めた扱いにする。
static func has_started(uid: String) -> bool:
	var entry := _entry(uid)
	return (
		bool(entry.get("started", false))
		or entry.get("run", null) != null
		or entry.has("finished")
		or entry.has("last_depth")
	)


static func best_wins(uid: String) -> int:
	return int(_entry(uid).get("best_wins", 0))


static func clears(uid: String) -> int:
	return int(_entry(uid).get("clears", 0))


## 出発で選べる最大の深さ(GameDesign.md 27章「砂の深さ」)。深さNで踏破すると
## N+1が選べるようになる(作戦を問わない)。
static func unlocked_depth(uid: String) -> int:
	return int(_entry(uid).get("unlocked_depth", 0))


## その作戦で踏破したことのある最も深い深さ(出発の札の封蝋の印)。未踏破は-1。
static func theme_best_depth(uid: String, theme_id: String) -> int:
	var depths: Dictionary = _entry(uid).get("theme_depths", {})
	if not depths.has(theme_id):
		return -1
	return int(depths[theme_id])


## 踏破した作戦の数(出発の記録「踏破した作戦 N / 8」)。
static func cleared_theme_count(uid: String) -> int:
	var depths: Dictionary = _entry(uid).get("theme_depths", {})
	return depths.size()


## 前回選んだ深さ(出発の画面が覚えておく)。
static func last_depth(uid: String) -> int:
	return int(_entry(uid).get("last_depth", 0))


static func set_last_depth(uid: String, depth: int) -> void:
	var entry := _entry(uid)
	entry["last_depth"] = depth
	_commit(uid, entry)


## 週替わりの遠征の保存中の遠征。週が変わっていれば、残っていた遠征をその時点の勝った数で
## 締めて送り、枠を空にする。`in_battle` のまま残っていたら負けとして終える(27章「中断と再開」)。
static func weekly_run(uid: String, week: String) -> SoloRun:
	var raw: Variant = _weekly_slot(uid, week).get("run", null)
	if not (raw is Dictionary):
		return null
	var run := SoloRun.from_dict(raw)
	if not run.in_battle:
		return run
	run.finish_battle(false, 0, RandomNumberGenerator.new())
	record(uid, run)
	end_weekly_run(uid, run, ABANDONED_MID_BATTLE)
	report_weekly(uid, run)
	return null


## その週の結果 `{"wins", "hp"}`。まだ終えていなければ空。
static func weekly_result(uid: String, week: String) -> Dictionary:
	var result: Variant = _weekly_slot(uid, week).get("result", null)
	return result if result is Dictionary else {}


## 週替わりの遠征を終える(負け・踏破・やめた)。その週はもう出発できない。
## `show_record` なら、次に画面を開いたとき1度だけ遠征の記録を出す。
static func end_weekly_run(uid: String, run: SoloRun, reason: String, show_record := true) -> void:
	var entry := _entry(uid)
	var slot := _weekly_slot(uid, run.weekly_id)
	slot["run"] = null
	slot["result"] = {"wins": run.wins, "hp": run.hp}
	slot["finished"] = {"run": run.to_dict(), "reason": reason} if show_record else null
	_commit(uid, entry)


## 週替わりの遠征の記録を読み、読んだら消す(`take_finished()` と同じ)。
static func take_weekly_finished(uid: String, week: String) -> Dictionary:
	var entry := _entry(uid)
	var slot := _weekly_slot(uid, week)
	var finished: Variant = slot.get("finished", null)
	if not (finished is Dictionary):
		return {}
	slot["finished"] = null
	_commit(uid, entry)
	return finished


## 週替わりの遠征の勝った数と残りHPを順位表へ送る(決着のたび)。
static func report_weekly(uid: String, run: SoloRun) -> void:
	WeeklyBoard.submit(uid, run.weekly_id, run.wins, run.hp)


## 遠征を終える。いつもの遠征は記録を残して保存を消し、週替わりの遠征は別枠に結果を残す。
static func end_run(uid: String, run: SoloRun, reason: String) -> void:
	if run.weekly_id.is_empty():
		save_finished(uid, run, reason)
		clear_run(uid)
		return
	end_weekly_run(uid, run, reason)


## 決着のたびに呼ぶ。最多勝利数・踏破回数を更新し、初めて到達した節目を返す。
## 週替わりの遠征は、選べる深さ・作戦ごとの踏破の深さを更新しない(段階的な解放を飛ばさせないため)。
static func record(uid: String, run: SoloRun) -> Array[Dictionary]:
	var entry := _entry(uid)
	entry["best_wins"] = maxi(int(entry.get("best_wins", 0)), run.wins)
	if run.cleared:
		entry["clears"] = int(entry.get("clears", 0)) + 1
	if run.cleared and run.weekly_id.is_empty():
		entry["unlocked_depth"] = maxi(
			int(entry.get("unlocked_depth", 0)), mini(run.depth + 1, SoloRun.DEPTH_MAX)
		)
		var depths: Dictionary = entry.get("theme_depths", {})
		depths[run.theme_id] = maxi(int(depths.get(run.theme_id, -1)), run.depth)
		entry["theme_depths"] = depths
	var milestones: Array = entry.get("milestones", [])
	var reached: Array[Dictionary] = []
	for milestone in SoloRun.MILESTONES:
		var id := str(milestone["id"])
		if milestones.has(id):
			continue
		var hit := false
		if milestone.has("wins") and run.wins >= int(milestone["wins"]):
			hit = true
		if milestone.has("cleared") and run.cleared:
			hit = true
		if not hit:
			continue
		milestones.append(id)
		reached.append(milestone)
	entry["milestones"] = milestones
	_commit(uid, entry)
	return reached


## アカウントへ送る値(同期の印を除いた1アカウントぶん)と、送れていない変更があるか。
static func sync_snapshot(uid: String) -> Dictionary:
	var entry := _entry(uid).duplicate(true)
	var dirty := bool(entry.get(SYNC_DIRTY, false))
	var revision := int(entry.get(SYNC_REVISION, 0))
	entry.erase(SYNC_DIRTY)
	entry.erase(SYNC_REVISION)
	return {"entry": entry, "dirty": dirty, "revision": revision}


## アカウントの内容で1アカウントぶんを置き換える(サインインの直後)。
static func replace_from_account(uid: String, remote: Dictionary) -> void:
	var entry := remote.duplicate(true)
	entry[SYNC_REVISION] = int(_entry(uid).get(SYNC_REVISION, 0))
	_data[_key(uid)] = entry
	_save()


## 送れた時点で呼ぶ。送っている間に変更が入っていれば印を残す。
static func mark_synced(uid: String, revision: int) -> void:
	var entry := _entry(uid)
	if int(entry.get(SYNC_REVISION, 0)) != revision:
		return
	entry[SYNC_DIRTY] = false
	_save()


static func reset_for_test() -> void:
	_muted = true
	_loaded = true
	_data = {}


## 週替わりの枠。保存されている枠が別の週のものなら、残っていた遠征を締めて空の枠へ替える。
## 読むだけでは書き込まない(呼び出し側が変えたときに `_commit()` する)。
static func _weekly_slot(uid: String, week: String) -> Dictionary:
	var entry := _entry(uid)
	var slot: Variant = entry.get(WEEKLY_KEY, null)
	if slot is Dictionary and str((slot as Dictionary).get("week", "")) == week:
		return slot
	if slot is Dictionary:
		_close_stale_weekly(uid, slot)
	var fresh := {"week": week, "run": null, "result": null, "finished": null}
	entry[WEEKLY_KEY] = fresh
	if slot != null:
		_commit(uid, entry)
	return fresh


## 週が変わったとき、終わっていなかった遠征をその時点の勝った数で締めて順位表へ送る。
static func _close_stale_weekly(uid: String, slot: Dictionary) -> void:
	var raw: Variant = slot.get("run", null)
	if raw is Dictionary:
		var run := SoloRun.from_dict(raw)
		WeeklyBoard.submit(uid, str(slot.get("week", "")), run.wins, run.hp)


static func _entry(uid: String) -> Dictionary:
	_ensure_loaded()
	var key := _key(uid)
	var current: Variant = _data.get(key, null)
	if not (current is Dictionary) or not (current as Dictionary).has("best_wins"):
		current = {"run": null, "best_wins": 0, "clears": 0, "milestones": []}
		_data[key] = current
	return current


## 記録を変えたときの書き込み。送れていない印を付けて控え、アカウントへ送る。
static func _commit(uid: String, entry: Dictionary) -> void:
	entry[SYNC_DIRTY] = true
	entry[SYNC_REVISION] = int(entry.get(SYNC_REVISION, 0)) + 1
	_data[_key(uid)] = entry
	_save()
	AccountSyncService.push_solo(uid)


static func _key(uid: String) -> String:
	return uid if not uid.is_empty() else "local"


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
