class_name SoloEntryInfo
extends Control
## ホームの「ソロモード」の札に載せる中身(GameDesign.md 9章)。
## 上に遠征の道の小さな地図、その下に見出し「ソロモード」、遠征とリーサルパズルの状態を凹んだ枠で1つずつ。
## 札(`HomeTile`)の子として全面に敷き、押下は札へ通す。

const TITLE := "ソロモード"
const TITLE_BASELINE := 212.0
const TITLE_SIZE := 30
const MAP_RECT := Rect2(40, 34, 0, 126)
const MAP_INSET := 40.0
## 地図の地(紺の紙)を道の外へはみ出させる幅。
const MAP_PAPER_PAD := Vector2(14, 10)
const MAP_PAPER := [[0.0, Color(0.10, 0.12, 0.22, 0.85)], [1.0, Color(0.05, 0.06, 0.12, 0.85)]]
const ROAD := Color(0.86, 0.66, 0.30)
const ROAD_ALPHA := 0.35
const ROAD_WIDTH := 2.0
const WALKED_WIDTH := 3.0
const ROAD_DASH := 6.0
const NODE_RADIUS := 7.0
const FINAL_RADIUS := 12.0
const NODE_RIM := 2.5
const NODE_INK := Color(0.07, 0.05, 0.03, 0.9)
const NODE_PASSED := Color(0.45, 0.42, 0.40)
const NODE_WALKED := Color(0.62, 0.42, 0.15)
const NODE_CURRENT := Color(1.0, 0.86, 0.5)
const NODE_AHEAD := Color(0.70, 0.60, 0.42)
const CURRENT_GLOW := 22.0
const FINAL_EMBLEM := 14.0
## 遠征が無いときに描く道の形(段ごとの行き先の数)。隣り合う行き先どうしをつなぐ。
const SAMPLE_COUNTS := [1, 2, 3, 2, 3, 1]
const SAMPLE_LINK_REACH := 0.4

const BOX_TOP := 222.0
const BOX_INSET := 18.0
const BOX_HEIGHT := 88.0
const BOX_STEP := 98.0
const BOX_PAD := 14.0
const BOX_HEAD_BASELINE := 28.0
const BOX_LINE_BASELINES := [54.0, 78.0]
const BOX_HEAD_SIZE := 18
const LINE_SIZE := 16
const NOTE_SIZE := 14
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
	_draw_map(Rect2(MAP_RECT.position, Vector2(size.x - MAP_INSET * 2.0, MAP_RECT.size.y)))
	draw_string(
		_display,
		Vector2(0.0, TITLE_BASELINE),
		TITLE,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		TITLE_SIZE,
		UiPalette.TEXT_OFFWHITE
	)
	_draw_box(0, "遠征", _expedition_lines())
	_draw_box(1, "リーサルパズル", _puzzle_lines())


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


func _draw_box(index: int, head: String, lines: Array) -> void:
	var rect := Rect2(
		BOX_INSET, BOX_TOP + BOX_STEP * float(index), size.x - BOX_INSET * 2.0, BOX_HEIGHT
	)
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
	for i in mini(lines.size(), BOX_LINE_BASELINES.size()):
		draw_string(
			_font,
			rect.position + Vector2(BOX_PAD, BOX_LINE_BASELINES[i]),
			str(lines[i][0]),
			HORIZONTAL_ALIGNMENT_LEFT,
			width,
			LINE_SIZE if i == 0 else NOTE_SIZE,
			lines[i][1]
		)


## 遠征の道を下から上へ6段(GameDesign.md 27章の道を縮めたもの)。遠征が無いときは道の形だけを沈めて描く。
func _draw_map(area: Rect2) -> void:
	var paper := Rect2(area.position - MAP_PAPER_PAD, area.size + MAP_PAPER_PAD * 2.0)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(), UiPaint.rounded_rect_points_uniform(paper, 8, 6), paper, MAP_PAPER
	)
	var counts: Array = []
	var links: Array = []
	if _run != null and not _run.route.is_empty():
		for col in _run.route.size():
			var row_list: Array = _run.route[col]
			counts.append(row_list.size())
			for row in row_list.size():
				for next_row in row_list[row].get("next", []):
					links.append([col, row, int(next_row)])
	else:
		counts = SAMPLE_COUNTS
		for col in counts.size() - 1:
			for a in counts[col]:
				for b in counts[col + 1]:
					var dx := absf(_node_x(a, counts[col]) - _node_x(b, counts[col + 1]))
					if dx <= SAMPLE_LINK_REACH:
						links.append([col, a, b])
	var rid := get_canvas_item()
	for link in links:
		var walked := _walked(link[0], link[1]) and _walked(link[0] + 1, link[2])
		ShapePaint.dashed_line(
			rid,
			_node_at(area, counts, link[0], link[1]),
			_node_at(area, counts, link[0] + 1, link[2]),
			Color(ROAD, 1.0 if walked else ROAD_ALPHA),
			WALKED_WIDTH if walked else ROAD_WIDTH,
			ROAD_DASH
		)
	for col in counts.size():
		for row in counts[col]:
			_draw_node(area, counts, col, row)


func _draw_node(area: Rect2, counts: Array, col: int, row: int) -> void:
	var at := _node_at(area, counts, col, row)
	var final := col == counts.size() - 1
	var radius := FINAL_RADIUS if final else NODE_RADIUS
	var fill := NODE_AHEAD
	if _run == null:
		fill = NODE_PASSED
	elif col == _run.chosen.size() - 1 and _walked(col, row):
		HomeProps.glow(self, at, CURRENT_GLOW)
		fill = NODE_CURRENT
	elif _walked(col, row):
		fill = NODE_WALKED
	elif col < _run.chosen.size():
		fill = NODE_PASSED
	ShapePaint.circle(get_canvas_item(), at, radius + NODE_RIM, NODE_INK)
	ShapePaint.circle(get_canvas_item(), at, radius, fill)
	if final:
		UiPaint.draw_emblem(get_canvas_item(), UiPaint.Emblem.STRIKE, at, FINAL_EMBLEM)


func _walked(col: int, row: int) -> bool:
	return _run != null and col < _run.chosen.size() and _run.chosen[col] == row


func _node_at(area: Rect2, counts: Array, col: int, row: int) -> Vector2:
	var step := area.size.y / float(counts.size() - 1)
	return Vector2(
		area.position.x + area.size.x * _node_x(row, counts[col]), area.end.y - step * float(col)
	)


static func _node_x(row: int, count: int) -> float:
	return (float(row) + 0.5) / float(count)
