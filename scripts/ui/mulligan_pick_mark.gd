class_name MulliganPickMark
extends Control
## マリガンで引き直すと選んだ札へ重ねる「砂時計を裏返した印」(GameDesign.md 9章)。
## 札(`CardView`)の子として足す。**`Control._draw()` は子より背面に描かれる**ため、
## 札の `_draw()` ではなく独立したノードで札の絵の上へ重ねる。

const ICON := preload("res://assets/ui/icons/redraw.png")
const RADIUS := 30.0
const ICON_SIDE := 36.0
## 真鍮の面へ彫り込んだように、面より暗い色で乗せる。
const ICON_COLOR := Color(0.2, 0.13, 0.08, 0.92)
const POP_SCALE := 1.25
const POP_DURATION := 0.16

var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(RADIUS, RADIUS) * 2.0
	pivot_offset = size * 0.5
	visible = false


## 印を出す / 消す。出すときだけ小さく跳ねさせ、押したことへの手応えにする。
func set_shown(shown: bool) -> void:
	if shown == visible:
		return
	visible = shown
	if not shown:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	scale = Vector2.ONE * POP_SCALE
	_tween = create_tween()
	(
		_tween
		. tween_property(self, "scale", Vector2.ONE, POP_DURATION)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


func _draw() -> void:
	var ci := get_canvas_item()
	var center := size * 0.5
	var face := Rect2(Vector2.ZERO, size)
	UiPaint.fill_circle(ci, center + Vector2(0, 3), RADIUS, Color(0, 0, 0, 0.45), 28)
	UiPaint.fill_gradient_polygon(
		ci,
		UiPaint.circle_points(center, RADIUS, 28),
		face,
		[[0.0, UiPalette.BRASS_LIGHT], [0.55, UiPalette.BRASS_MID], [1.0, UiPalette.BRASS_DARK]]
	)
	UiPaint.draw_ring(ci, center, RADIUS - 1.0, UiPalette.BRASS_HIGHLIGHT, 2.0, 28)
	UiPaint.draw_ring(ci, center, RADIUS - 5.0, UiPalette.BRASS_DARK, 1.0, 28)
	var icon_rect := Rect2(
		center - Vector2(ICON_SIDE, ICON_SIDE) * 0.5, Vector2(ICON_SIDE, ICON_SIDE)
	)
	draw_texture_rect(ICON, icon_rect, false, ICON_COLOR)
