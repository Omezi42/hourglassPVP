class_name DailyPuzzle
extends RefCounted
## 今日の1問(GameDesign.md 24章 / Architecture.md 10.12.2節)。
## 日本時間の日付で `data/daily_puzzles/<YYYY-MM-DD>.tres` を引く。
## 問題の中身は `tools/shorts/schedule.py` がXへ出す問題と同じものを書き出す。

const DAILY_DIR := "res://data/daily_puzzles"
const ID_PREFIX := "daily_"
const JST_OFFSET := 9 * 3600
const EYEBROW := "リーサルパズル ・ 今日の1問"
const DAY_SECONDS := 24 * 3600
## 解いた後に次の問題がいつ出るかを添える文(GameDesign.md 24章)。明日の問題が同梱されているときだけ出す。
const DONE_LINE := "今日の1問 クリア済み"
const DONE_NEXT_SUFFIX := " ・ 次は0:00"
const RESULT_NEXT_NOTE := "次の問題は明日0:00"


## 日本時間の日付("2026-09-28")。`at_unix_time` はテスト用(負値なら現在時刻)。
static func date_key(at_unix_time: int = -1) -> String:
	var unix_time := at_unix_time if at_unix_time >= 0 else int(Time.get_unix_time_from_system())
	var date := Time.get_date_dict_from_unix_time(unix_time + JST_OFFSET)
	return "%04d-%02d-%02d" % [date["year"], date["month"], date["day"]]


## 今日の問題。同梱されていなければ null(今日の1問を出さない)。
static func today(at_unix_time: int = -1) -> PuzzleStageData:
	return for_date(date_key(at_unix_time))


static func for_date(key: String) -> PuzzleStageData:
	# ファイルの有無は一覧で見る。書き出した版では "<name>.tres.remap" になり、
	# `ResourceLoader.exists()` は当てにならない(Pitfalls.md)。
	var dir := DirAccess.open(DAILY_DIR)
	if dir == null:
		return null
	var file_name := key + ".tres"
	for name in dir.get_files():
		if name.trim_suffix(".remap") == file_name:
			return load(DAILY_DIR + "/" + file_name) as PuzzleStageData
	return null


## 明日の問題が同梱されているか。無い日は「次は0:00」を約束しない。
static func has_tomorrow(at_unix_time: int = -1) -> bool:
	var unix_time := at_unix_time if at_unix_time >= 0 else int(Time.get_unix_time_from_system())
	return for_date(date_key(unix_time + DAY_SECONDS)) != null


## 解いた後のホームの1行。
static func done_line() -> String:
	return DONE_LINE + DONE_NEXT_SUFFIX if has_tomorrow() else DONE_LINE


static func is_daily(stage: PuzzleStageData) -> bool:
	return stage != null and stage.id.begins_with(ID_PREFIX)


## 今日の問題を解いたか。問題が無い日は false。
static func cleared_today(owner_uid: String) -> bool:
	var stage := today()
	return stage != null and PuzzleProgress.is_cleared(owner_uid, stage.id)
