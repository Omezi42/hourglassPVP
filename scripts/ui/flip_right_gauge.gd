class_name FlipRightGauge
extends Control
## 反転権(GameDesign.md 2章)ボタンの下に置く小さな真鍮の札。
## 自分・相手それぞれの残り回数を、総回数ぶんの粒で並べて示す
## (scratchpad/match_rebuild_phase4.md)。

const GAUGE_SIZE := Vector2(112.0, 44.0)
const CORNER_RADIUS := 6.0
const PIP_RADIUS := 5.0
const PIP_STEP := 14.0
const PIP_START_X := 34.0
const ROW_Y := [14.0, 30.0]
const LABEL_X := 8.0
const LABEL_FONT_SIZE := 10

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
	var ci := get_canvas_item()
	var rect := Rect2(Vector2.ZERO, size)
	var points := UiPaint.rounded_rect_points_uniform(rect, CORNER_RADIUS, 4)
	UiPaint.fill_gradient_polygon(
		ci, points, rect, [[0.0, UiPalette.BRASS_MID], [1.0, UiPalette.BRASS_DARK]]
	)
	UiPaint.apply_grain(ci, rect, 0.05)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, UiPalette.OUTLINE_DARK, 1.0, true)
	_draw_row(ROW_Y[0], "自分", _own_remaining, _own_total)
	_draw_row(ROW_Y[1], "相手", _foe_remaining, _foe_total)


## 語(自分/相手)の右へ、総回数ぶんの粒を並べる。相手の行も同じ語彙で描き、
## 色でなく行頭の語だけで区別する(scratchpad/match_rebuild_phase4.md)。
func _draw_row(y: float, label_text: String, remaining: int, total: int) -> void:
	_draw_engraved_label(Vector2(LABEL_X, y), label_text)
	var ci := get_canvas_item()
	for i in total:
		var center := Vector2(PIP_START_X + i * PIP_STEP, y)
		_draw_pip(ci, center, i < remaining)


## `PlayerInfoBar._draw_mana()`のマナの粒(暗い輪+面+小さなハイライト)と同じ
## 見た目を、この札の小さな粒(半径5)向けに最小限だけ複製したもの。共有クラスへ
## 切り出すほどの分量が無いため、対応関係だけコメントで残す。
func _draw_pip(ci: RID, center: Vector2, lit: bool) -> void:
	var base: Color = UiPalette.GLOW_AMBER if lit else PlayerInfoBar.MANA_EMPTY
	UiPaint.fill_circle(ci, center, PIP_RADIUS, base.darkened(0.25), 12)
	UiPaint.fill_circle(ci, center, PIP_RADIUS * 0.72, base, 10)
	var highlight_center := center + Vector2(-1, -1) * PIP_RADIUS * 0.34
	var highlight_alpha := 0.4 if lit else 0.14
	UiPaint.fill_circle(ci, highlight_center, PIP_RADIUS * 0.32, Color(1, 1, 1, highlight_alpha), 8)


## 彫り込み風の小さな見出し語。暗い文字の1px下へ真鍮のハイライトを敷いてから
## 重ねることで、板へ彫ったように見せる。
func _draw_engraved_label(pos: Vector2, text: String) -> void:
	if _font == null:
		return
	var origin := pos
	origin.y += (
		(float(_font.get_ascent(LABEL_FONT_SIZE)) - float(_font.get_descent(LABEL_FONT_SIZE))) * 0.5
	)
	draw_string(
		_font,
		origin + Vector2(0, 1),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		LABEL_FONT_SIZE,
		Color(UiPalette.BRASS_HIGHLIGHT, 0.5)
	)
	draw_string(
		_font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, UiPalette.OUTLINE_DARK
	)
