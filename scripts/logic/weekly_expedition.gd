class_name WeeklyExpedition
extends RefCounted
## 週替わりの遠征(GameDesign.md 27章「週替わりの遠征」、Architecture.md 10.15節)。
## 週のid(日本時間の月曜の日付)と、そこから決まる種・乱数・遠征1回ぶんを持つ。
## 同じ週なら全員に同じ作戦・主・道が出て、同じ選び方をした人には同じ候補が出る。

## 砂の深さは固定(いつもの遠征の段階的な解放を飛ばさせないため)。
const DEPTH := 2
const JST_OFFSET_SECONDS := 9 * 3600
const SECONDS_PER_DAY := 86400
## 1970-01-01(木曜)から数えた日数 + この値を7で割った余りが0の日が月曜。
const MONDAY_SHIFT := 3
const DAYS_PER_WEEK := 7
const SEED_PREFIX := "weekly_expedition:"
const DEADLINE_TEXT := "月曜0:00まで"


## いまの週のid。
static func current_week() -> String:
	return week_of(Time.get_unix_time_from_system())


## unix秒(UTC)が属する週のid。週は日本時間の月曜0:00で替わる。
static func week_of(unix_seconds: float) -> String:
	var days := floori((unix_seconds + JST_OFFSET_SECONDS) / SECONDS_PER_DAY)
	var monday := days - posmod(days + MONDAY_SHIFT, DAYS_PER_WEEK)
	var t := Time.get_datetime_dict_from_unix_time(monday * SECONDS_PER_DAY)
	return "%04d-%02d-%02d" % [t["year"], t["month"], t["day"]]


## 週の種。週idが同じなら、どの端末でも同じ値になる。
static func seed_of(week: String) -> int:
	return (SEED_PREFIX + week).hash()


## 週の種に用途の塩(「route」「offer:2」など。段・用途ごとに変える)を混ぜた乱数。
static func rng_for(week: String, salt: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%s|%s" % [seed_of(week), salt]).hash()
	return rng


## 今週の作戦(1つに決める)。
static func theme_of(week: String) -> String:
	var ids := CardCpuDecks.deck_ids()
	return ids[rng_for(week, "theme").randi_range(0, ids.size() - 1)]


## 今週の最終戦の主。
static func boss_of(week: String) -> String:
	return SoloRun.boss_choice(rng_for(week, "boss"))


## 今週の遠征の始まり。作戦・主・初期の山札・道が週から決まる。
static func create_run(week: String) -> SoloRun:
	var run := SoloRun.create(theme_of(week), DEPTH, rng_for(week, "route"), boss_of(week))
	run.weekly_id = week
	return run
