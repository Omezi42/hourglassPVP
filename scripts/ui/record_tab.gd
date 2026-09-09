class_name RecordTab
extends Control
## ホーム画面の「きろく」タブ(GameDesign.md 9章)。
##
## **対局そのものではなく、済んだことを振り返る場所**をまとめる。以前はミッション・戦績・
## リプレイがバトルタブの中に対局の入口と並んでおり、そのタブが「対戦する」「振り返る」
## 「日課」の3つの性格を同時に抱えていた。
##
## `RulesTab` / `CardSoloMapScreen` と同じく `.tscn` を持たず、`HomeScreen` がコードで生成する。

signal mission_requested
signal stats_requested
signal replay_list_requested

## アカウント帯を避ける上端。他のタブと同じ値。
const TOP_BAND := 112.0
const FRAME_X := 140.0
const FRAME_W := 1000.0
const TILE_PAD := 20.0

const MISSION_FRAME := Rect2(FRAME_X, TOP_BAND + 26.0, FRAME_W, 144.0)
const MISSION_TILE_SIZE := Vector2(620, 88)
const MISSION_FONT_SIZE := 28
const MISSION_TILE_TOP := 40.0
## 今日の3つを並べる列。**押す前に進み具合が読める**ようにするため(GameDesign.md 9章)。
const PROGRESS_X := 664.0
const PROGRESS_TOP := 44.0
const PROGRESS_COUNT_X := 880.0

const HISTORY_FRAME := Rect2(FRAME_X, TOP_BAND + 200.0, FRAME_W, 234.0)
const HISTORY_TILE_SIZE := Vector2(470, 150)
const HISTORY_TILE_TOP := 54.0
const HISTORY_FONT_SIZE := 28
const HISTORY_GAP := 490.0

var _mission_frame: HomeFrame
var _mission_tile: HomeTile
var _stats_tile: HomeTile
var _replay_tile: HomeTile
## 今日の3つ(`DailyMissionService.missions()` の行)。`_draw()` が読む。
var _rows: Array[Dictionary] = []


func _ready() -> void:
	_mission_frame = HomeFrame.make(MISSION_FRAME, "今日の課題")
	# 今日の3つは枠の右側へ並べる。**押して開くまで何も分からないと、日課は
	# 存在ごと忘れられる**(GameDesign.md 9章)。
	_mission_frame.rows_left = PROGRESS_X
	_mission_frame.rows_count_left = PROGRESS_COUNT_X
	_mission_frame.rows_top = PROGRESS_TOP
	add_child(_mission_frame)
	_mission_tile = HomeTile.make("ミッション", "", "halo", MISSION_TILE_SIZE, MISSION_FONT_SIZE, true)
	_mission_tile.position = MISSION_FRAME.position + Vector2(TILE_PAD, MISSION_TILE_TOP)
	_mission_tile.pressed.connect(func() -> void: mission_requested.emit())
	add_child(_mission_tile)

	add_child(HomeFrame.make(HISTORY_FRAME, "これまでの対局"))
	_stats_tile = HomeTile.make("戦績", "", "crown", HISTORY_TILE_SIZE, HISTORY_FONT_SIZE)
	_stats_tile.position = HISTORY_FRAME.position + Vector2(TILE_PAD, HISTORY_TILE_TOP)
	_stats_tile.pressed.connect(func() -> void: stats_requested.emit())
	add_child(_stats_tile)
	_replay_tile = HomeTile.make("リプレイ", "", "eye", HISTORY_TILE_SIZE, HISTORY_FONT_SIZE)
	_replay_tile.position = (
		HISTORY_FRAME.position + Vector2(TILE_PAD + HISTORY_GAP, HISTORY_TILE_TOP)
	)
	_replay_tile.pressed.connect(func() -> void: replay_list_requested.emit())
	add_child(_replay_tile)
	refresh()


## 他のタブと同じく、開くたびに読み直す(GameDesign.md 9章)。日課は日付で入れ替わり、
## 戦績は対局から戻るたびに増える。
func refresh() -> void:
	if _mission_tile == null:
		return
	var uid := _uid()
	_rows = DailyMissionService.missions(uid)
	var claimable := 0
	for row in _rows:
		if row["done"] and not row["claimed"]:
			claimable += 1
	_mission_tile.badge_count = claimable
	_mission_tile.set_subtitle("%d つ受け取れます" % claimable if claimable > 0 else "今日の3つに挑む")
	_stats_tile.set_subtitle(_stats_line())
	_replay_tile.set_subtitle("直近%d件を残しています" % LocalReplayService.RETENTION_LIMIT)
	var lines: Array[Dictionary] = []
	for row in _rows:
		(
			lines
			. append(
				{
					"text": str(row["text"]),
					"count": "%d / %d" % [int(row["progress"]), int(row["goal"])],
					"done": bool(row["done"]),
				}
			)
		)
	_mission_frame.rows = lines


## 受け取れるミッションがあるか。下部タブの印(`HomeScreen`)がこれを読む。
func claimable_count() -> int:
	var count := 0
	for row in _rows:
		if row["done"] and not row["claimed"]:
			count += 1
	return count


func _uid() -> String:
	if NetSession.client != null and NetSession.client.auth != null:
		return NetSession.client.auth.uid
	return ""


## 戦績の副題。**対局数が0のうちはその旨を出す**(19章と同じ扱い)。
func _stats_line() -> String:
	var totals := MatchStats.totals(_uid())
	var games := int(totals.get("games", 0))
	if games <= 0:
		return "まだ対局がありません"
	var wins := int(totals.get("wins", 0))
	return "%d戦  勝率 %.1f%%" % [games, float(wins) / float(games) * 100.0]
