class_name SoloEntryInfo
extends Control
## ホームの「ソロモード」の札に載せる中身(GameDesign.md 9章)。
## 見出し「ソロモード」の下に、遠征とリーサルパズルの状態を凹んだ枠で1つずつ見せる。
## 札が縦長なら枠を縦に、横長(縦画面)なら横に並べる。札(`HomeTile`)の子として全面に敷き、押下は札へ通す。

const TITLE := "ソロモード"
const TITLE_BASELINE := 70.0
const TITLE_SIZE := 38
const BOX_TOP := 112.0
const BOX_INSET := 24.0
const BOX_GAP := 20.0
const BOX_HEAD_BASELINE := 48.0
const BOX_HEAD_SIZE := 28
const BOX_LINE_TOP := 90.0
const BOX_LINE_STEP := 34.0
const BOX_PAD := 20.0
const LINE_SIZE := 18
const NOTE_SIZE := 16
const HEAD_COLOR := Color(0.96, 0.82, 0.45)
const PUZZLE_LINE := "1手番で仕留める"
const DAILY_OPEN := "今日の1問 まだ解いていません"
const DAILY_DONE := "今日の1問 クリア済み"

var _run: SoloRun = null
var _best_wins := 0
var _clears := 0
## 今日の1問の状態。0=無い日 / 1=まだ / 2=クリア済み(GameDesign.md 24章)。
var _daily := 0
var _font: Font
var _display: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font
	_display = UiFonts.display_font(_font)


func refresh(uid: String) -> void:
	_run = SoloProgress.load_run(uid)
	_best_wins = SoloProgress.best_wins(uid)
	_clears = SoloProgress.clears(uid)
	var daily := DailyPuzzle.today()
	_daily = 0 if daily == null else (2 if PuzzleProgress.is_cleared(uid, daily.id) else 1)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if _font == null:
		return
	draw_string(
		_display,
		Vector2(0.0, TITLE_BASELINE),
		TITLE,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		TITLE_SIZE,
		UiPalette.TEXT_OFFWHITE
	)
	var boxes := _box_rects()
	_draw_box(boxes[0], "遠征", _expedition_lines())
	_draw_box(boxes[1], "リーサルパズル", _puzzle_lines())


func _box_rects() -> Array[Rect2]:
	var area := Rect2(BOX_INSET, BOX_TOP, size.x - BOX_INSET * 2.0, size.y - BOX_TOP - BOX_INSET)
	if size.y > size.x:
		var h := (area.size.y - BOX_GAP) * 0.5
		return [
			Rect2(area.position, Vector2(area.size.x, h)),
			Rect2(area.position + Vector2(0.0, h + BOX_GAP), Vector2(area.size.x, h)),
		]
	var w := (area.size.x - BOX_GAP) * 0.5
	return [
		Rect2(area.position, Vector2(w, area.size.y)),
		Rect2(area.position + Vector2(w + BOX_GAP, 0.0), Vector2(w, area.size.y)),
	]


## 1行目は主な文、2行目は沈めた補足(琥珀は今日の1問がまだのとき)。
func _expedition_lines() -> Array:
	if _run == null:
		return [
			["作戦を選んで出発", EntryTilePaint.WELL_TEXT],
			["いちばん多く勝った数 %d ・ 踏破 %d回" % [_best_wins, _clears], EntryTilePaint.WELL_MUTED],
		]
	return [
		["%s で遠征中" % CardCpuDecks.name_of(_run.theme_id), EntryTilePaint.ACCENT_TEXT],
		["%d勝 ・ HP %d/%d" % [_run.wins, _run.hp, _run.max_hp], EntryTilePaint.WELL_MUTED],
	]


func _puzzle_lines() -> Array:
	var lines: Array = [[PUZZLE_LINE, EntryTilePaint.WELL_TEXT]]
	if _daily == 1:
		lines.append([DAILY_OPEN, UiPalette.GLOW_AMBER])
	elif _daily == 2:
		lines.append([DAILY_DONE, EntryTilePaint.WELL_MUTED])
	return lines


func _draw_box(rect: Rect2, head: String, lines: Array) -> void:
	EntryTilePaint.draw_well(self, rect, false)
	var width := rect.size.x - BOX_PAD * 2.0
	# 「遠征」の字は見出し用の明朝体のサブセットに無い。2つの枠の見出しを揃えて本文書体で描く。
	draw_string(
		_font,
		rect.position + Vector2(BOX_PAD, BOX_HEAD_BASELINE),
		head,
		HORIZONTAL_ALIGNMENT_LEFT,
		width,
		BOX_HEAD_SIZE,
		HEAD_COLOR
	)
	for i in lines.size():
		draw_string(
			_font,
			rect.position + Vector2(BOX_PAD, BOX_LINE_TOP + BOX_LINE_STEP * float(i)),
			str(lines[i][0]),
			HORIZONTAL_ALIGNMENT_LEFT,
			width,
			LINE_SIZE if i == 0 else NOTE_SIZE,
			lines[i][1]
		)
