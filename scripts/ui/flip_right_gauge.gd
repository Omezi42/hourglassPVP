class_name FlipRightGauge
extends Control
## 反転権(GameDesign.md 2章)ボタンの下に置く彫り込みの小さな札。
## 自分・相手それぞれの残り回数を、総回数ぶんの粒で並べて示す。

const GAUGE_SIZE := Vector2(108.0, 48.0)
const CORNER_RADIUS := 8.0
const PIP_RADIUS := 5.0
const PIP_STEP := 13.5
const PIP_START_X := 42.0
const PIP_SEGMENTS := 16
## 空きの粒は、くぼんだ受け皿(暗い塗り + 金の細い輪)で見せ、総回数を数えられるようにする。
const PIP_EMPTY_FILL := Color(0, 0, 0, 0.40)
const PIP_EMPTY_RIM := Color(UiPalette.GOLD_HI, 0.40)
const PIP_RIM_WIDTH := 1.25
const ROW_Y := [13.0, 35.0]
const LABEL_X := 8.0
const LABEL_FONT_SIZE := UiPalette.T_MICRO

var _own_remaining: int = 0
var _own_total: int = 0
var _foe_remaining: int = 0
var _foe_total: int = 0
var _font: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = GAUGE_SIZE
	size = GAUGE_SIZE


func _ready() -> void:
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font


func set_counts(own_remaining: int, own_total: int, foe_remaining: int, foe_total: int) -> void:
	_own_remaining = own_remaining
	_own_total = own_total
	_foe_remaining = foe_remaining
	_foe_total = foe_total
	queue_redraw()


func _draw() -> void:
	var face := Rect2(Vector2.ZERO, size)
	# 縦では卓のレールの金線がこの札を横切るため、不透明の下地を敷いて隠す。
	UiKit.fill(get_canvas_item(), UiKit.rr(face, CORNER_RADIUS), UiPalette.INK_900)
	UiKit.well(get_canvas_item(), face, CORNER_RADIUS)
	_draw_row(ROW_Y[0], "自分", _own_remaining, _own_total)
	_draw_row(ROW_Y[1], "相手", _foe_remaining, _foe_total)


## 語(自分/相手)の右へ、総回数ぶんの粒を並べる。相手の行も同じ語彙で描き、
## 色でなく行頭の語だけで区別する。効果やソロの恩恵で総回数を超えて得た残りも粒で見せる。
func _draw_row(y: float, label_text: String, remaining: int, total: int) -> void:
	if _font == null:
		return
	var ci := get_canvas_item()
	var baseline := (
		y + (_font.get_ascent(LABEL_FONT_SIZE) - _font.get_descent(LABEL_FONT_SIZE)) * 0.5
	)
	draw_string(
		_font,
		Vector2(LABEL_X, baseline),
		label_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		LABEL_FONT_SIZE,
		UiPalette.MUTED
	)
	for i in maxi(total, remaining):
		var pip := UiKit.ellipse(
			Vector2(PIP_START_X + i * PIP_STEP, y), Vector2(PIP_RADIUS, PIP_RADIUS), PIP_SEGMENTS
		)
		if i < remaining:
			UiKit.vgrad(ci, pip, [[0.0, UiPalette.GOLD_HI], [1.0, UiPalette.SAND_DEEP]], true)
		else:
			UiKit.fill(ci, pip, PIP_EMPTY_FILL)
			var center := Vector2(PIP_START_X + i * PIP_STEP, y)
			var rim_radius := PIP_RADIUS - PIP_RIM_WIDTH * 0.5
			ShapePaint.arc(
				ci, center, rim_radius, 0.0, TAU, PIP_SEGMENTS, PIP_EMPTY_RIM, PIP_RIM_WIDTH
			)
