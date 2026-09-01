class_name EmoteBubble
extends Control
## 対局中に名札付近に出るエモートの吹き出し(GameDesign.md 9章、Architecture.md 6.6)。
## 表示後に自動でフェードアウトして消滅する。

const BUBBLE_PADDING := Vector2(16, 8)
const FADE_IN_DURATION := 0.3
const DISPLAY_DURATION := 6.0
const FADE_OUT_DURATION := 0.5
const FLOAT_OFFSET := 8.0

var text := ""
var is_opponent := false

var _font: Font
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font
	_start_animation()


func _start_animation() -> void:
	modulate.a = 0.0
	var original_y := position.y
	position.y = original_y + (FLOAT_OFFSET if is_opponent else -FLOAT_OFFSET)

	_tween = create_tween()
	# フェードイン & スライド
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION)
	_tween.tween_property(self, "position:y", original_y, FADE_IN_DURATION)
	_tween.set_parallel(false)

	# 待機
	_tween.tween_interval(DISPLAY_DURATION)

	# フェードアウト
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION)
	var target_y := original_y - (FLOAT_OFFSET if is_opponent else -FLOAT_OFFSET)
	_tween.tween_property(self, "position:y", target_y, FADE_OUT_DURATION)
	_tween.set_parallel(false)
	_tween.tween_callback(queue_free)


func _draw() -> void:
	if text.is_empty() or _font == null:
		return
	var font_size := 15
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var bubble_size := text_size + BUBBLE_PADDING * 2.0
	custom_minimum_size = bubble_size
	size = bubble_size

	var rect := Rect2(Vector2.ZERO, bubble_size)
	var points := UiPaint.rounded_rect_points_uniform(rect, 8.0, 5)
	var ci := get_canvas_item()
	UiPaint.fill_gradient_polygon(
		ci,
		points,
		rect,
		[[0.0, Color(0.16, 0.13, 0.1, 0.95)], [1.0, Color(0.08, 0.06, 0.05, 0.95)]]
	)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, UiPalette.BRASS_LIGHT, 1.5, true)

	draw_string(
		_font,
		Vector2(BUBBLE_PADDING.x, bubble_size.y - BUBBLE_PADDING.y - 2.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		UiPalette.TEXT_OFFWHITE
	)
