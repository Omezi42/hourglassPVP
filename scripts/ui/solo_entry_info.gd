class_name SoloEntryInfo
extends Control
## ホームの「ソロモード」の札に載せる中身(GameDesign.md 9章)。
## 上に彫り込みの中の遠征の道の小さな地図、その下に見出し「ソロモード」、遠征とリーサルパズルの状態を罫線で区切って1つずつ。
## 札(`HomeTile`)の子として全面に敷き、押下は札へ通す。

const TITLE := "ソロモード"
## 文字と余白。横 / 縦(GameDesign.md 9章「縦画面」の目安)。
const PAD := UiPalette.S5 - UiPalette.S1
const PORTRAIT_PAD := UiPalette.S4 + 2.0
const HEAD_SIZE := UiPalette.T_HEAD
const PORTRAIT_HEAD_SIZE := 30
const BODY_SIZE := UiPalette.T_BODY
const PORTRAIT_BODY_SIZE := 24
const NOTE_SIZE := UiPalette.T_SMALL
const PORTRAIT_NOTE_SIZE := 20
const MIN_TEXT_SIZE := UiPalette.T_MICRO
## 地図の彫り込み。札の内側の余白から少し外へ出す。
const MAP_OUTSET := UiPalette.S1
const MAP_HEIGHT := 150.0
const PORTRAIT_MAP_HEIGHT := 128.0
const MAP_CORNER := 10.0
## 彫り込みの縁から道までの余白(左・上・右・下)。
const ROUTE_INSET := [14.0, 20.0, 14.0, 16.0]
const HEAD_GAP := UiPalette.S3
const PORTRAIT_HEAD_GAP := UiPalette.S1 + 2.0
const HEAD_LEADING := 1.45
const LABEL_LEADING := 1.3
const NOTE_LEADING := 1.25
const BOTTOM_PAD := 6.0

const ROAD_AHEAD := Color(1, 1, 1, 0.16)
const ROAD_WIDTH := 1.0
const WALKED_WIDTH := 2.0
const ROAD_DASH := 4.0
const NODE_RADIUS := 6.0
const FINAL_RADIUS := 9.0
const NODE_RING := 1.5
const NODE_SEGMENTS := 20
const NODE_EDGE := Color(1, 1, 1, 0.18)
const CURRENT_GLOW_RADIUS := 22.0
const CURRENT_GLOW := Color(1.0, 0.82, 0.45, 0.55)
## 遠征が無いときに描く道の形(段ごとの行き先の数)。隣り合う行き先どうしをつなぐ。
const SAMPLE_COUNTS := [1, 2, 3, 2, 3, 1]
const SAMPLE_LINK_REACH := 0.4

## 遠征が無いときの記録。縦は札の幅に目安の大きさで収まる短い言い方にする。
const RECORD := "いちばん多く勝った数 %d ・ 踏破 %d回"
const RECORD_SHORT := "最多 %d勝 ・ 踏破 %d回"
const PUZZLE_LINE := "1手番で仕留める"
const DAILY_OPEN := "今日の1問 まだ解いていません"
const DAILY_DONE := "今日の1問 クリア済み"

var portrait := false:
	set(value):
		portrait = value
		queue_redraw()

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
	var ci := get_canvas_item()
	var pad := PORTRAIT_PAD if portrait else PAD
	var head := PORTRAIT_HEAD_SIZE if portrait else HEAD_SIZE
	var width := size.x - pad * 2.0
	var map := Rect2(
		pad - MAP_OUTSET,
		pad - MAP_OUTSET,
		width + MAP_OUTSET * 2.0,
		PORTRAIT_MAP_HEIGHT if portrait else MAP_HEIGHT
	)
	UiKit.well(ci, map, MAP_CORNER)
	_draw_map(
		map.grow_individual(-ROUTE_INSET[0], -ROUTE_INSET[1], -ROUTE_INSET[2], -ROUTE_INSET[3])
	)
	var head_top := map.end.y + (PORTRAIT_HEAD_GAP if portrait else HEAD_GAP)
	draw_string(
		_display,
		Vector2(pad, head_top + _display.get_ascent(head)),
		TITLE,
		HORIZONTAL_ALIGNMENT_CENTER,
		width,
		head,
		UiPalette.IVORY
	)
	var top := head_top + head * HEAD_LEADING
	var row_height := (size.y - BOTTOM_PAD - top) * 0.5
	_draw_row(Rect2(pad, top, width, row_height), "遠征", _expedition_lines())
	_draw_row(Rect2(pad, top + row_height, width, row_height), "リーサルパズル", _puzzle_lines())


## 1行目は主な文、2行目は補足(砂色は今日の1問がまだのとき)。
func _expedition_lines() -> Array:
	if _run == null:
		return [
			["作戦を選んで出発", UiPalette.IVORY],
			[(RECORD_SHORT if portrait else RECORD) % [_best_wins, _clears], UiPalette.MUTED],
		]
	return [
		["%s ・ %d勝" % [CardCpuDecks.name_of(_run.theme_id), _run.wins], UiPalette.IVORY],
		["HP %d / %d" % [_run.hp, _run.max_hp], UiPalette.MUTED],
	]


func _puzzle_lines() -> Array:
	var lines: Array = [[PUZZLE_LINE, UiPalette.IVORY]]
	if _daily == 1:
		lines.append([DAILY_OPEN, UiPalette.SAND_HI])
	elif _daily == 2:
		lines.append([DAILY_DONE, UiPalette.MUTED])
	return lines


func _draw_row(rect: Rect2, label: String, lines: Array) -> void:
	var body := PORTRAIT_BODY_SIZE if portrait else BODY_SIZE
	var note := PORTRAIT_NOTE_SIZE if portrait else NOTE_SIZE
	UiKit.rule(get_canvas_item(), rect.position, Vector2(rect.end.x, rect.position.y))
	var block := note * LABEL_LEADING + body * LABEL_LEADING + note * NOTE_LEADING
	var at := Vector2(rect.position.x, rect.position.y + (rect.size.y - block) * 0.5)
	# 「遠征」の字は見出し用の明朝体のサブセットに無い。2つの行の小見出しを本文書体で揃える。
	_text(label, at, note, UiPalette.GOLD, rect.size.x)
	at.y += note * LABEL_LEADING
	_text(str(lines[0][0]), at, body, lines[0][1], rect.size.x)
	if lines.size() > 1:
		at.y += body * LABEL_LEADING
		_text(str(lines[1][0]), at, note, lines[1][1], rect.size.x)


## `at` は行の左上。幅へ収まらなければ下限まで縮める。
func _text(value: String, at: Vector2, px: int, color: Color, width: float) -> void:
	var fitted := px
	while (
		fitted > MIN_TEXT_SIZE
		and _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > width
	):
		fitted -= 1
	draw_string(
		_font,
		at + Vector2(0, _font.get_ascent(px)),
		value,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fitted,
		color
	)


## 遠征の道を下から上へ6段(GameDesign.md 27章の道を縮めたもの)。遠征が無いときは道の形だけを沈めて描く。
func _draw_map(area: Rect2) -> void:
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
	var ci := get_canvas_item()
	for link in links:
		var from := _node_at(area, counts, link[0], link[1])
		var to := _node_at(area, counts, link[0] + 1, link[2])
		if _walked(link[0], link[1]) and _walked(link[0] + 1, link[2]):
			ShapePaint.polyline(
				ci, PackedVector2Array([from, to]), UiPalette.GOLD, WALKED_WIDTH, true
			)
		else:
			ShapePaint.dashed_line(ci, from, to, ROAD_AHEAD, ROAD_WIDTH, ROAD_DASH)
	for col in counts.size():
		for row in counts[col]:
			_draw_node(area, counts, col, row)


## 通った駒は真鍮、いまの駒は光らせ、最終戦の駒は一回り大きく真鍮の輪で囲う。
func _draw_node(area: Rect2, counts: Array, col: int, row: int) -> void:
	var ci := get_canvas_item()
	var at := _node_at(area, counts, col, row)
	var final := col == counts.size() - 1
	var rad := FINAL_RADIUS if final else NODE_RADIUS
	var radii := Vector2(rad, rad)
	var walked := _walked(col, row)
	if walked and col == _run.chosen.size() - 1:
		UiKit.glow(ci, at, Vector2.ONE * CURRENT_GLOW_RADIUS, CURRENT_GLOW)
	UiKit.fill(
		ci, UiKit.ellipse(at, radii + Vector2.ONE * NODE_RING, NODE_SEGMENTS), UiPalette.INK_900
	)
	var points := UiKit.ellipse(at, radii, NODE_SEGMENTS)
	if walked:
		UiKit.vgrad(ci, points, [[0.0, UiPalette.GOLD_HI], [1.0, UiPalette.BRASS]], true)
		return
	UiKit.fill(ci, points, UiPalette.INK_500)
	UiKit.stroke(ci, points, UiPalette.BRASS if final else NODE_EDGE, UiKit.LINE_MIN)


func _walked(col: int, row: int) -> bool:
	return _run != null and col < _run.chosen.size() and _run.chosen[col] == row


func _node_at(area: Rect2, counts: Array, col: int, row: int) -> Vector2:
	var step := area.size.y / float(counts.size() - 1)
	return Vector2(
		area.position.x + area.size.x * _node_x(row, counts[col]), area.end.y - step * float(col)
	)


static func _node_x(row: int, count: int) -> float:
	return (float(row) + 0.5) / float(count)
