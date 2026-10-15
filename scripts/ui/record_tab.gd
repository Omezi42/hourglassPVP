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
signal rank_requested

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
const HISTORY_TILE_SIZE := Vector2(306, 150)
const HISTORY_TILE_TOP := 54.0
const HISTORY_FONT_SIZE := 28
const HISTORY_GAP := 327.0

## 縦画面(GameDesign.md 9章「縦画面」)。今日の3つはミッションの札の下へ、
## これまでの対局の3枚は縦に積む。
const PORTRAIT_TILE_W := 628.0
const PORTRAIT_TILE_TOP := 52.0
const PORTRAIT_MISSION_HEIGHT := 110.0
const PORTRAIT_MISSION_FONT := 34
const PORTRAIT_ROWS_GAP := 18.0
const PORTRAIT_ROWS_LEFT := 30.0
## 「12 / 20」が右の余白の内側へ収まる位置。
const PORTRAIT_COUNT_RIGHT := 110.0
const PORTRAIT_HISTORY_HEIGHT := 104.0
const PORTRAIT_HISTORY_GAP := 12.0
const PORTRAIT_HISTORY_FONT := 32

var _mission_frame: HomeFrame
var _history_frame: HomeFrame
var _mission_tile: HomeTile
var _stats_tile: HomeTile
var _replay_tile: HomeTile
var _rank_tile: HomeTile
## 今日の3つ(`DailyMissionService.missions()` の行)。`_draw()` が読む。
var _rows: Array[Dictionary] = []
var _portrait := false


func _ready() -> void:
	_mission_frame = HomeFrame.make(MISSION_FRAME, "今日の課題")
	add_child(_mission_frame)
	_mission_tile = HomeTile.make("ミッション", "", "halo", MISSION_TILE_SIZE, MISSION_FONT_SIZE, true)
	_mission_tile.pressed.connect(func() -> void: mission_requested.emit())
	add_child(_mission_tile)

	_history_frame = HomeFrame.make(HISTORY_FRAME, "これまでの対局")
	add_child(_history_frame)
	_stats_tile = HomeTile.make("戦績", "", "crown", HISTORY_TILE_SIZE, HISTORY_FONT_SIZE)
	_stats_tile.pressed.connect(func() -> void: stats_requested.emit())
	add_child(_stats_tile)
	_replay_tile = HomeTile.make("リプレイ", "", "eye", HISTORY_TILE_SIZE, HISTORY_FONT_SIZE)
	_replay_tile.pressed.connect(func() -> void: replay_list_requested.emit())
	add_child(_replay_tile)
	_rank_tile = HomeTile.make("ランク", "", "tower", HISTORY_TILE_SIZE, HISTORY_FONT_SIZE)
	_rank_tile.pressed.connect(func() -> void: rank_requested.emit())
	add_child(_rank_tile)
	_layout()
	refresh()


## 縦横が変わったときに `HomeScreen` から呼ばれる(Architecture.md 4.7節)。
func apply_orientation(portrait: bool) -> void:
	_portrait = portrait
	if _mission_tile != null:
		_layout()


func _layout() -> void:
	var history: Array[HomeTile] = [_stats_tile, _replay_tile, _rank_tile]
	_mission_frame.set_portrait(_portrait)
	_history_frame.set_portrait(_portrait)
	HomeTile.set_portrait_text(_mission_tile, _portrait, PORTRAIT_MISSION_FONT, MISSION_FONT_SIZE)
	for tile in history:
		HomeTile.set_portrait_text(tile, _portrait, PORTRAIT_HISTORY_FONT, HISTORY_FONT_SIZE)
	if _portrait:
		_layout_portrait(history)
		return
	HomeFrame.place(_mission_frame, MISSION_FRAME)
	# 今日の3つは枠の右側へ並べる。**押して開くまで何も分からないと、日課は
	# 存在ごと忘れられる**(GameDesign.md 9章)。
	_mission_frame.rows_left = PROGRESS_X
	_mission_frame.rows_count_left = PROGRESS_COUNT_X
	_mission_frame.rows_top = PROGRESS_TOP
	HomeFrame.place(
		_mission_tile,
		Rect2(MISSION_FRAME.position + Vector2(TILE_PAD, MISSION_TILE_TOP), MISSION_TILE_SIZE)
	)
	HomeFrame.place(_history_frame, HISTORY_FRAME)
	for i in history.size():
		var at := Vector2(TILE_PAD + HISTORY_GAP * float(i), HISTORY_TILE_TOP)
		HomeFrame.place(history[i], Rect2(HISTORY_FRAME.position + at, HISTORY_TILE_SIZE))


func _layout_portrait(history: Array[HomeTile]) -> void:
	var rows_top: float = PORTRAIT_TILE_TOP + PORTRAIT_MISSION_HEIGHT + PORTRAIT_ROWS_GAP
	var mission_height: float = (
		rows_top
		+ HomeFrame.PORTRAIT_ROW_HEIGHT * float(DailyMissionData.DAILY_COUNT)
		+ HomeFrame.PORTRAIT_PAD
	)
	var mission_rect := Rect2(
		HomeFrame.PORTRAIT_X, HomeFrame.PORTRAIT_TOP, HomeFrame.PORTRAIT_W, mission_height
	)
	HomeFrame.place(_mission_frame, mission_rect)
	_mission_frame.rows_left = PORTRAIT_ROWS_LEFT
	_mission_frame.rows_count_left = HomeFrame.PORTRAIT_W - PORTRAIT_COUNT_RIGHT
	_mission_frame.rows_top = rows_top
	HomeFrame.place(
		_mission_tile,
		Rect2(
			mission_rect.position + Vector2(TILE_PAD, PORTRAIT_TILE_TOP),
			Vector2(PORTRAIT_TILE_W, PORTRAIT_MISSION_HEIGHT)
		)
	)
	var step := PORTRAIT_HISTORY_HEIGHT + PORTRAIT_HISTORY_GAP
	var history_rect := Rect2(
		HomeFrame.PORTRAIT_X,
		mission_rect.end.y + HomeFrame.PORTRAIT_GAP,
		HomeFrame.PORTRAIT_W,
		PORTRAIT_TILE_TOP + step * float(history.size()) - PORTRAIT_HISTORY_GAP + TILE_PAD
	)
	HomeFrame.place(_history_frame, history_rect)
	for i in history.size():
		var at := Vector2(TILE_PAD, PORTRAIT_TILE_TOP + step * float(i))
		HomeFrame.place(
			history[i],
			Rect2(history_rect.position + at, Vector2(PORTRAIT_TILE_W, PORTRAIT_HISTORY_HEIGHT))
		)


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
	_apply_subtitle(_mission_tile, "%d つ受け取れます" % claimable if claimable > 0 else "今日の3つに挑む")
	_apply_subtitle(_stats_tile, _stats_line())
	_replay_tile.set_subtitle("直近%d件を残しています" % LocalReplayService.RETENTION_LIMIT)
	_apply_subtitle(_rank_tile, _rank_line())
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


## 前回と文字列が変わっていたら、その行だけ短く光らせる
## (GameDesign.md 9章「押さなくても何かが変わったと分かるように」)。
func _apply_subtitle(tile: HomeTile, text_line: String) -> void:
	var changed := not tile.subtitle.is_empty() and tile.subtitle != text_line
	tile.set_subtitle(text_line)
	if changed:
		tile.flash_subtitle()


## ランクの副題はいまの段位(GameDesign.md 9章)。プラチナはレートを添える。
func _rank_line() -> String:
	var standing := RankProgress.standing()
	var tier: String = standing["tier"]
	if tier == RankRules.PLATINUM_KEY:
		return "%s レート%d" % [RankRules.display_name(tier), int(standing["rating"])]
	return "%s ★%d" % [RankRules.display_name(tier), int(standing["stars"])]


## 戦績の副題。**対局数が0のうちはその旨を出す**(19章と同じ扱い)。
func _stats_line() -> String:
	var totals := MatchStats.totals(_uid())
	var games := int(totals.get("games", 0))
	if games <= 0:
		return "まだ対局がありません"
	var wins := int(totals.get("wins", 0))
	return "%d戦  勝率 %.1f%%" % [games, float(wins) / float(games) * 100.0]
