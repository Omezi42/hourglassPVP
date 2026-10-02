class_name SoloRouteView
extends Control
## 遠征(ソロモード)の道の画面(GameDesign.md 27章「画面」)。6段の地図を描き、
## いま選ぶ段の行ける駒だけを押せるようにする。駒を押しても対局は始めず、選んだ駒に
## 真鍮の輪を付けて`destination_selected`を出すだけにとどめる(実際に選ぶのは
## `SoloDestinationPanel`の「挑む」)。

## 駒を押した(取り消せない選択ではない)。-1は選択解除。
signal destination_selected(index: int)

const SELECTED_RING_GAP := 6.0
const SELECTED_RING_WIDTH := 4.0

const PATH_COLUMNS := SoloRun.FLOOR_COUNT
const NODE_RADIUS := 34.0
const FINAL_RADIUS := 44.0
const ROW_GAP := 132.0
const LABEL_FONT_SIZE_1 := 14
const LABEL_FONT_SIZE_2 := 12
const LABEL_GAP_1 := 20.0
const LABEL_GAP_2 := 38.0
const CURRENT_GLOW_ALPHA := 0.14
const CURRENT_GLOW_SCALE := 1.5
const CURRENT_GLOW_PULSE := 0.3
const CURRENT_RING_GAP := 8.0
const CURRENT_RING_WIDTH := 3.0
## いまの位置から行けなくなった道の濃さと、行けなくなった駒に重ねる影(GameDesign.md 27章「画面」)。
const CUT_ROAD_ALPHA := 0.3
const CUT_NODE_SHADE := Color(0, 0, 0, 0.45)
## 押した駒から次の段へ出る道を示す線。
const PREVIEW_ROAD_ALPHA := 0.8
const PREVIEW_ROAD_WIDTH := 4.0

var _canvas: Control
var _buttons: Array[Button] = []
var _route: Array = []
var _floor := 0
var _chosen: Array[int] = []
var _centers: Array = []
var _selected := -1
## 表示モード(遠征の記録・27章「画面」)では駒を押せず、明滅も出さない。
var _record_mode := false
var _record_lost := -1
## CPUが上級になる段(`SoloRun.expert_from_floor()`)。深さで前倒しになる
## (GameDesign.md 27章「砂の深さ」)。
var _expert_from := SoloRun.EXPERT_FROM_FLOOR
## いまの位置から行ける駒(`SoloRun.reachable()`)。表示モードでは空。
var _reachable := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_route)
	add_child(_canvas)


## いま選ぶ段の駒の明滅(GameDesign.md 27章「画面」)を動かすため、見えている間だけ
## 描き直す。
func _process(_delta: float) -> void:
	if visible and not _route.is_empty():
		_canvas.queue_redraw()


## `SoloRun.route`・いま選ぶ段・段ごとに選んだindexの履歴から道を描き直す。
## `expert_from`は`SoloRun.expert_from_floor()`(深さで前倒しになる)。
func show_data(route: Array, floor: int, chosen: Array[int], expert_from: int) -> void:
	_record_mode = false
	_record_lost = -1
	_selected = -1
	_route = route
	_floor = floor
	_chosen = chosen
	_expert_from = expert_from
	_reachable = SoloRun.reachable(route, floor, chosen)
	_rebuild(true)


## 遠征の記録(GameDesign.md 27章「画面」)。押せない表示だけで、選んだ段は真鍮、
## 負けた段には×を重ねる。`lost_floor`は負けた段のindex(踏破・やめたときは-1)。
func show_record(route: Array, chosen: Array[int], lost_floor: int, expert_from: int) -> void:
	_record_mode = true
	_record_lost = lost_floor
	_selected = -1
	_route = route
	_floor = chosen.size()
	_chosen = chosen
	_expert_from = expert_from
	_reachable = {}
	_rebuild(false)


func _rebuild(interactive: bool) -> void:
	for button in _buttons:
		remove_child(button)
		button.queue_free()
	_buttons = []
	_canvas.position = Vector2.ZERO
	_canvas.size = size
	var col_w: float = size.x / float(PATH_COLUMNS)
	_centers = _column_centers(col_w)
	_canvas.queue_redraw()
	if interactive:
		_add_current_buttons()


## 選択中の駒を切り替える(戻る・別の駒を押したときに呼び出し側から呼ぶ)。-1で解除。
func set_selected(index: int) -> void:
	_selected = index
	_canvas.queue_redraw()


func _column_centers(col_w: float) -> Array:
	var centers: Array = []
	for col in PATH_COLUMNS:
		var nodes: Array = _route[col] if col < _route.size() else []
		var cx := col_w * (float(col) + 0.5)
		var n := nodes.size()
		var top := size.y * 0.5 - ROW_GAP * float(maxi(n - 1, 0)) * 0.5
		var col_centers: Array = []
		for row in n:
			col_centers.append(Vector2(cx, top + ROW_GAP * float(row)))
		centers.append(col_centers)
	return centers


func _chosen_index(col: int) -> int:
	return _chosen[col] if col < _chosen.size() else 0


func _node_center(col: int, row: int) -> Vector2:
	if col < 0 or col >= _centers.size():
		return Vector2.ZERO
	var col_centers: Array = _centers[col]
	if row < 0 or row >= col_centers.size():
		return Vector2.ZERO
	return col_centers[row]


func _node_state(col: int, row: int) -> String:
	if _record_mode:
		if col < _chosen.size():
			return "past_chosen" if _chosen_index(col) == row else "past_unchosen"
		return "locked"
	if col < _floor:
		return "past_chosen" if _chosen_index(col) == row else "past_unchosen"
	if not _reachable.has(Vector2i(col, row)):
		return "past_unchosen" if col == _floor else "cut"
	if col == _floor:
		return "current"
	return "locked"


func _draw_route() -> void:
	var ci := _canvas.get_canvas_item()
	_draw_connections(ci)
	for col in _centers.size():
		var nodes: Array = _route[col] if col < _route.size() else []
		for row in nodes.size():
			_draw_node(ci, _node_center(col, row), nodes[row], col, row, col == PATH_COLUMNS - 1)


## 駒どうしのつながりをすべて素の道で描き、通った道には砂を敷く。いまの位置から行けなく
## なった道は沈め、押した駒から次の段へ出る道は琥珀の線で示す(GameDesign.md 27章「画面」)。
func _draw_connections(ci: RID) -> void:
	for col in range(_centers.size() - 1):
		for row in (_route[col] as Array).size():
			for next_row in SoloRun.next_rows(_route, col, row):
				var walked := _is_walked(col, row, next_row)
				_draw_road(
					ci,
					_node_center(col, row),
					_node_center(col + 1, next_row),
					walked,
					walked or _is_live_road(col, row, next_row),
					not _record_mode and col == _floor and row == _selected
				)


func _is_walked(col: int, row: int, next_row: int) -> bool:
	return col + 1 < _floor and _chosen_index(col) == row and _chosen_index(col + 1) == next_row


## 直前に選んだ駒からいまの段へ出る道と、いまの位置から行ける駒どうしの道。
func _is_live_road(col: int, row: int, next_row: int) -> bool:
	if not _reachable.has(Vector2i(col + 1, next_row)):
		return false
	if col < _floor:
		return col + 1 == _floor and _chosen_index(col) == row
	return _reachable.has(Vector2i(col, row))


func _draw_road(ci: RID, a: Vector2, b: Vector2, walked: bool, live: bool, preview: bool) -> void:
	var points := PackedVector2Array([a, b])
	var alpha := 1.0 if live else CUT_ROAD_ALPHA
	var edge := Color(0.05, 0.04, 0.03, 0.75 * alpha)
	var bed := Color(0.27, 0.21, 0.15, alpha)
	var sand := Color(0.93, 0.72, 0.36, 1.0)
	RenderingServer.canvas_item_add_polyline(
		ci, points, SoloUiPaint.fill_colors(points, edge), 20.0, true
	)
	RenderingServer.canvas_item_add_polyline(
		ci, points, SoloUiPaint.fill_colors(points, bed), 13.0, true
	)
	if walked:
		RenderingServer.canvas_item_add_polyline(
			ci, points, SoloUiPaint.fill_colors(points, sand), 7.0, true
		)
	elif preview:
		var glow := Color(UiPalette.GLOW_AMBER, PREVIEW_ROAD_ALPHA)
		RenderingServer.canvas_item_add_polyline(
			ci, points, SoloUiPaint.fill_colors(points, glow), PREVIEW_ROAD_WIDTH, true
		)


func _draw_node(
	ci: RID, center: Vector2, node: Dictionary, col: int, row: int, is_final: bool
) -> void:
	var state := _node_state(col, row)
	var radius := FINAL_RADIUS if is_final else NODE_RADIUS
	if state == "current":
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		var glow_radius := radius * (CURRENT_GLOW_SCALE + pulse * CURRENT_GLOW_PULSE)
		UiPaint.fill_circle(
			ci, center, glow_radius, Color(UiPalette.GLOW_AMBER, CURRENT_GLOW_ALPHA), 32
		)
	UiPaint.fill_ellipse(
		ci, center + Vector2(0, 6), Vector2(radius, radius * 0.85), Color(0, 0, 0, 0.4), 28
	)
	var rim := UiPalette.BRASS_HIGHLIGHT
	var face_stops: Array
	match state:
		"past_chosen":
			face_stops = [[0.0, UiPalette.BRASS_HIGHLIGHT], [1.0, UiPalette.BRASS_MID]]
		"current":
			face_stops = [[0.0, UiPalette.NAVY_PANEL_TOP], [1.0, UiPalette.FELT_NAVY_TOP]]
		"past_unchosen":
			face_stops = [[0.0, UiPalette.PANEL_SLATE_TOP], [1.0, UiPalette.PANEL_SLATE_BOTTOM]]
			rim = UiPalette.BRASS_DARK
		_:
			face_stops = [[0.0, UiPalette.PANEL_SLATE_TOP], [1.0, UiPalette.PANEL_PRESSED_BOTTOM]]
			rim = UiPalette.BRASS_DARK
	UiPaint.fill_circle(ci, center, radius, UiPalette.OUTLINE_DARK, 40)
	UiPaint.fill_circle(ci, center, radius - 1.5, rim, 40)
	UiPaint.fill_gradient_polygon(
		ci,
		UiPaint.circle_points(center, radius - 4.0, 40),
		Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0),
		face_stops
	)
	if state == "current":
		UiPaint.draw_ring(
			ci, center, radius + CURRENT_RING_GAP, UiPalette.GLOW_AMBER, CURRENT_RING_WIDTH, 40
		)
	if not _record_mode and col == _floor and row == _selected:
		UiPaint.draw_ring(
			ci,
			center,
			radius + SELECTED_RING_GAP,
			UiPalette.BRASS_HIGHLIGHT,
			SELECTED_RING_WIDTH,
			40
		)
	_draw_kind_glyph(
		ci, center, radius, int(node.get("kind", SoloRun.Kind.BATTLE)), state, is_final
	)
	if _record_mode and col == _record_lost and row == _chosen_index(col):
		_draw_loss_mark(ci, center, radius)
	if state == "cut":
		UiPaint.fill_circle(ci, center, radius + 1.0, CUT_NODE_SHADE, 40)
	var label_color := (
		UiPalette.TEXT_MUTED if state == "locked" or state == "cut" else UiPalette.TEXT_OFFWHITE
	)
	_draw_label(
		center + Vector2(0, radius + LABEL_GAP_1),
		_kind_label(int(node.get("kind", SoloRun.Kind.BATTLE)), is_final, col),
		LABEL_FONT_SIZE_1,
		label_color
	)
	_draw_label(
		center + Vector2(0, radius + LABEL_GAP_2),
		_detail_label(node),
		LABEL_FONT_SIZE_2,
		label_color
	)


## 遠征の記録で負けた駒に重ねる×(GameDesign.md 27章「画面」)。
func _draw_loss_mark(ci: RID, center: Vector2, radius: float) -> void:
	var s := radius * 0.5
	var color := Color(0.75, 0.15, 0.12, 0.9)
	for offset in [Vector2(-s, -s), Vector2(-s, s)]:
		var points := PackedVector2Array([center + offset, center - offset])
		RenderingServer.canvas_item_add_polyline(
			ci, points, SoloUiPaint.fill_colors(points, color), 5.0, true
		)


func _draw_kind_glyph(
	ci: RID, center: Vector2, radius: float, kind: int, state: String, is_final: bool
) -> void:
	var color := (
		UiPalette.TEXT_MUTED if state == "locked" or state == "cut" else UiPalette.TEXT_OFFWHITE
	)
	var s := radius * 0.42
	if is_final:
		UiPaint.draw_emblem(ci, UiPaint.Emblem.CHECK, center, s)
		return
	match kind:
		SoloRun.Kind.BATTLE:
			UiPaint.draw_ring(ci, center, s, color, 3.0, 20)
		SoloRun.Kind.GATE:
			var pts := PackedVector2Array(
				[
					center + Vector2(-s, s),
					center + Vector2(-s, -s * 0.3),
					center + Vector2(0, -s),
					center + Vector2(s, -s * 0.3),
					center + Vector2(s, s),
				]
			)
			RenderingServer.canvas_item_add_polyline(
				ci, pts, SoloUiPaint.fill_colors(pts, color), 3.0, true
			)
		SoloRun.Kind.SPRING:
			UiPaint.fill_ellipse(ci, center, Vector2(s, s * 0.6), Color(color, 0.85), 20)
		SoloRun.Kind.WORKSHOP:
			var half := s * 0.6
			RenderingServer.canvas_item_add_line(
				ci, center + Vector2(-half, half), center + Vector2(half, -half), color, 3.0
			)
			RenderingServer.canvas_item_add_line(
				ci,
				center + Vector2(-half * 0.3, half * 0.7),
				center + Vector2(half * 0.7, -half * 0.3),
				color,
				3.0
			)


func _draw_label(at: Vector2, text: String, font_size: int, color: Color) -> void:
	var font := _canvas.get_theme_default_font()
	if font == null:
		return
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_canvas.draw_string(
		font, at - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color
	)


## CPUが上級になる段(`_expert_from`以上。深さで前倒しになる)の対局・関門は
## 1行目へ「・ 上級」を添える(GameDesign.md 27章「道」「砂の深さ」)。泉には強さが無い。
func _kind_label(kind: int, is_final: bool, col: int) -> String:
	if kind == SoloRun.Kind.SPRING:
		return "泉"
	if kind == SoloRun.Kind.WORKSHOP:
		return "工房"
	var base := "最終戦" if is_final else ("関門" if kind == SoloRun.Kind.GATE else "対局")
	if col >= _expert_from:
		return "%s ・ 上級" % base
	return base


## 泉は`cpu_deck`が空文字のため「HP+8」だけを出す。関門は関門名、対局はCPUの作戦名。
## `cpu_deck`が(想定外に)空のまま渡ってきても崩れないよう、種類名だけへ落とす。
func _detail_label(dest: Dictionary) -> String:
	var kind: int = int(dest.get("kind", SoloRun.Kind.BATTLE))
	if kind == SoloRun.Kind.SPRING:
		return "HP +%d" % SoloRun.SPRING_HEAL
	if kind == SoloRun.Kind.WORKSHOP:
		return "抜く・複製"
	# 関門は関門名、最終戦は主の名前(`gate`に主のidが入る。GameDesign.md 27章「主」)。
	var gate := SoloGateLibrary.find_by_id(str(dest.get("gate", "")))
	if gate != null:
		return gate.display_name
	if kind == SoloRun.Kind.GATE:
		return "関門"
	var cpu_deck := str(dest.get("cpu_deck", ""))
	if cpu_deck.is_empty():
		return "対局"
	return "CPU ・ %s" % CardCpuDecks.name_of(cpu_deck)


func _add_current_buttons() -> void:
	if _floor < 0 or _floor >= _route.size() or _floor >= _centers.size():
		return
	var nodes: Array = _route[_floor]
	var col_centers: Array = _centers[_floor]
	var radius := FINAL_RADIUS if _floor == PATH_COLUMNS - 1 else NODE_RADIUS
	var open_rows := SoloRun.open_rows(_route, _floor, _chosen)
	for row in nodes.size():
		if not open_rows.has(row):
			continue
		var center: Vector2 = col_centers[row]
		var button := SoloUiPaint.transparent_button()
		button.position = center - Vector2.ONE * radius
		button.size = Vector2.ONE * radius * 2.0
		button.pressed.connect(_on_destination_pressed.bind(row))
		add_child(button)
		_buttons.append(button)


## 同じ駒をもう一度押すと選択を解除する(GameDesign.md 27章「画面」)。
func _on_destination_pressed(index: int) -> void:
	_selected = -1 if _selected == index else index
	_canvas.queue_redraw()
	destination_selected.emit(_selected)
