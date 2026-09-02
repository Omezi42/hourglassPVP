class_name CardMatchDamageAssist
extends Control
## 盤面総攻撃力(打点アシスト)表示(GameDesign.md 9章)。
## 自陣の即時攻撃可能な総打点を算出し、相手の守護の有無やリーサル(トドメ)の
## 機会をひと目で把握できるように支援する。

const PANEL_SIZE := Vector2(148, 30)
const PANEL_RADIUS := 5.0
## 行動の列の中で、コインのボタン(y=230)へ掛からない高さ。
const PANEL_TOP := 184.0

var _screen: CardMatchScreen
var _font: Font
var _total_attack := 0
var _has_guard := false
var _is_lethal := false
var _ready_count := 0


func _init(screen: CardMatchScreen) -> void:
	_screen = screen
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = TextGlyphs.ui_font()
	custom_minimum_size = PANEL_SIZE
	size = PANEL_SIZE
	# 行動の列の先頭側。コインのボタン(y=230)より上へ置く。
	position = Vector2(CardMatchScreen.ACTION_COLUMN_X, PANEL_TOP)


func sync() -> void:
	var state := _screen.state
	if state == null or state.is_match_over() or not _screen.is_interactive():
		visible = false
		return

	if state.current_turn != _screen.my_side:
		visible = false
		return

	_total_attack = 0
	_ready_count = 0
	var my_side := _screen.my_side
	var foe_side := MatchState.other_side(my_side)

	for i in MatchState.BOARD_SIZE:
		var unit: CardInstance = state.board[my_side][i]
		if unit != null and unit.can_attack():
			# 連撃は1ターンに2回殴れるため、残りの回数ぶんを数える。
			var swings: int = maxi(unit.max_attacks() - unit.attacks_this_turn, 0)
			_total_attack += unit.attack * swings
			_ready_count += 1

	_has_guard = false
	for i in MatchState.BOARD_SIZE:
		var foe_unit: CardInstance = state.board[foe_side][i]
		if foe_unit != null and foe_unit.has_keyword(CardEnums.Keyword.GUARD):
			_has_guard = true
			break

	var foe_hp: int = state.hp[foe_side]
	_is_lethal = not _has_guard and _total_attack >= foe_hp and foe_hp > 0

	visible = _ready_count > 0 or _total_attack > 0
	queue_redraw()


func _draw() -> void:
	if not visible:
		return

	var ci := get_canvas_item()
	var rect := Rect2(Vector2.ZERO, PANEL_SIZE)
	var points := UiPaint.rounded_rect_points_uniform(rect, PANEL_RADIUS, 5)

	# 背景グラデーション
	var bg_top := Color(0.16, 0.13, 0.11, 0.95)
	var bg_bottom := Color(0.09, 0.07, 0.06, 0.98)
	if _is_lethal:
		bg_top = Color(0.28, 0.20, 0.08, 0.95)
		bg_bottom = Color(0.14, 0.10, 0.04, 0.98)

	UiPaint.fill_gradient_polygon(ci, points, rect, [[0.0, bg_top], [1.0, bg_bottom]])

	var outline := points.duplicate()
	outline.append(points[0])

	var border_color := UiPalette.BRASS_LIGHT
	var border_width := 1.2
	if _is_lethal:
		var pulse := (sin(Time.get_ticks_msec() * 0.01) + 1.0) * 0.5
		border_color = UiPalette.GLOW_AMBER.lerp(UiPalette.BRASS_HIGHLIGHT, pulse)
		border_width = 2.0
		draw_rect(rect.grow(1.5), Color(UiPalette.GLOW_AMBER, 0.2 * pulse))
	elif _has_guard:
		border_color = UiPalette.BRASS_MID

	draw_polyline(outline, border_color, border_width, true)

	# テキスト描画
	if _is_lethal:
		draw_string(
			_font, Vector2(10, 20), "決着可能!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiPalette.GLOW_AMBER
		)
		draw_string(
			_font,
			Vector2(88, 21),
			"打点 %d" % _total_attack,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			UiPalette.BRASS_HIGHLIGHT
		)
	elif _has_guard:
		draw_string(
			_font, Vector2(10, 20), "守護あり", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiPalette.TEXT_MUTED
		)
		draw_string(
			_font,
			Vector2(76, 20),
			"総打点 %d" % _total_attack,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			13,
			UiPalette.TEXT_OFFWHITE
		)
	else:
		draw_string(
			_font, Vector2(12, 20), "直接打点", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiPalette.BRASS_LIGHT
		)
		draw_string(
			_font,
			Vector2(86, 21),
			str(_total_attack),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			UiPalette.GLOW_AMBER
		)
