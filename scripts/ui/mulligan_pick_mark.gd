class_name MulliganPickMark
extends Control
## マリガンで引き直すと選んだ札へ重ねる「砂時計を裏返した印」(GameDesign.md 9章)。
## 札(`CardView`)の子として足す。**`Control._draw()` は子より背面に描かれる**ため、
## 札の `_draw()` ではなく独立したノードで札の絵の上へ重ねる。

const ICON := preload("res://assets/ui/icons/redraw.png")
const RADIUS := 30.0
const ICON_SIDE := 36.0
## 真鍮の面へ彫り込んだように、面より暗い色で乗せる。
const ICON_COLOR := Color(UiPalette.BRASS_INK, 0.92)
## 付くとき: 大きめから収まり、不透明になりながら、やり直しの矢印が回って止まる。
const POP_SCALE := 1.25
const POP_DURATION := 0.16
const POP_FADE_DURATION := 0.08
const POP_START_ROTATION := -PI * 0.5
## 外すとき: 縮み、薄れ、逆へ少し回って消える。
const HIDE_SCALE := 0.6
const HIDE_DURATION := 0.12
const HIDE_ROTATION := -PI / 3.0

var _tween: Tween
var _shown := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(RADIUS, RADIUS) * 2.0
	pivot_offset = size * 0.5
	visible = false


## 印を出す / 消す。途中で反対の操作が来ても、今の値から続ける。
func set_shown(shown: bool) -> void:
	if shown == _shown:
		return
	_shown = shown
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	if shown:
		if not visible:
			visible = true
			scale = Vector2.ONE * POP_SCALE
			modulate.a = 0.0
			rotation = POP_START_ROTATION
		(
			_tween
			. tween_property(self, "scale", Vector2.ONE, POP_DURATION)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)
		_tween.tween_property(self, "modulate:a", 1.0, POP_FADE_DURATION)
		(
			_tween
			. tween_property(self, "rotation", 0.0, POP_DURATION)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_OUT)
		)
		return
	(
		_tween
		. tween_property(self, "scale", Vector2.ONE * HIDE_SCALE, HIDE_DURATION)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN)
	)
	(
		_tween
		. tween_property(self, "modulate:a", 0.0, HIDE_DURATION)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN)
	)
	(
		_tween
		. tween_property(self, "rotation", HIDE_ROTATION, HIDE_DURATION)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN)
	)
	_tween.chain().tween_callback(_hide_done)


func _hide_done() -> void:
	visible = false


func _draw() -> void:
	var ci := get_canvas_item()
	var center := size * 0.5
	UiKit.round_face(ci, center, RADIUS, UiKit.Role.MAIN)
	var icon_rect := Rect2(
		center - Vector2(ICON_SIDE, ICON_SIDE) * 0.5, Vector2(ICON_SIDE, ICON_SIDE)
	)
	draw_texture_rect(ICON, icon_rect, false, ICON_COLOR)
