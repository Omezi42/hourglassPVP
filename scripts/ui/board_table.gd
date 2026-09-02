class_name BoardTable
extends Control
## 対局盤面のテーブル面。AI生成イラストを使わず、コードのポリゴン描画のみで
## 「横長・軽い奥行きのある石テーブル」を表現する(無地でよいというユーザー指示に基づく)。
## 色はUiPalette、円弧・楕円の点列生成はUiPaint(coded_button_style.gd等と共通のライブラリ)
## を経由する(フェーズ12 Q-6)。Control._draw()はCanvasItemのdraw_*系を直接呼べるため、
## UiPaint(ci: RID第1引数)を使う箇所ではself.get_canvas_item()を渡す。

const TABLE_BORDER_WIDTH := 3.0
## 奥(上端)をわずかに狭くして軽い奥行きを出す比率。
const TOP_INSET_RATIO := 0.04
const DIVIDER_WIDTH := 2.0
const DIVIDER_RATIO := 0.5
const MEDALLION_OUTER_RADIUS := 22.0
const MEDALLION_INNER_RADIUS := 13.0

## 卓の縁は**他のパネルと同じ真鍮の縁**として描く。以前は明るい琥珀の線1本だったため、
## 面が塗られていても輪郭だけのワイヤーフレームに見えていた。
## 区切り線と中央の紋章だけは琥珀のまま残す(陣地の境目はアクセントで示すため)。
const DIVIDER_ALPHA := 0.5
const RIM_OUTER_WIDTH := 4.0

var _medallion_angle := 0.0
var _medallion_glow := 0.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var divider_y := size.y * DIVIDER_RATIO
			var center := Vector2(size.x * 0.5, divider_y)
			if mb.position.distance_to(center) <= MEDALLION_OUTER_RADIUS + 10.0:
				_interact_medallion()


func _interact_medallion() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	(
		_tween
		. parallel()
		. tween_property(self, "_medallion_angle", _medallion_angle + PI * 0.5, 0.35)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	_tween.parallel().tween_property(self, "_medallion_glow", 1.0, 0.1)
	_tween.chain().tween_property(self, "_medallion_glow", 0.0, 0.25)


func _process(_delta: float) -> void:
	if _medallion_glow > 0.0 or (_tween != null and _tween.is_valid()):
		queue_redraw()


func _draw() -> void:
	var ci := get_canvas_item()
	var top_inset := size.x * TOP_INSET_RATIO
	var points := PackedVector2Array(
		[
			Vector2(top_inset, 0.0),
			Vector2(size.x - top_inset, 0.0),
			Vector2(size.x, size.y),
			Vector2(0.0, size.y),
		]
	)
	(
		UiPaint
		. fill_gradient_polygon(
			ci,
			points,
			Rect2(Vector2.ZERO, size),
			[
				[0.0, Color(0.14, 0.12, 0.15, 0.98)],
				[0.5, Color(0.2, 0.17, 0.2, 0.98)],
				[1.0, Color(0.12, 0.1, 0.13, 0.98)],
			]
		)
	)
	UiPaint.apply_grain(ci, Rect2(Vector2.ZERO, size), 0.06)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, UiPalette.OUTLINE_DARK, RIM_OUTER_WIDTH, true)
	draw_polyline(outline, UiPalette.BRASS_LIGHT, TABLE_BORDER_WIDTH, true)

	var divider_color := _amber(DIVIDER_ALPHA)
	var divider_y := size.y * DIVIDER_RATIO
	var left_x: float = lerp(top_inset, 0.0, DIVIDER_RATIO)
	var right_x: float = lerp(size.x - top_inset, size.x, DIVIDER_RATIO)
	draw_line(Vector2(left_x, divider_y), Vector2(right_x, divider_y), divider_color, DIVIDER_WIDTH)

	var center := Vector2(size.x * 0.5, divider_y)
	var glow_color := divider_color.lerp(UiPalette.BRASS_HIGHLIGHT, _medallion_glow)
	UiPaint.draw_ring(
		ci, center, MEDALLION_OUTER_RADIUS, glow_color, 2.0 + _medallion_glow * 1.5, 32
	)
	UiPaint.draw_ring(ci, center, MEDALLION_INNER_RADIUS, glow_color, 1.5 + _medallion_glow, 32)

	# 歯車・クロスラインの装飾(回転)
	for i in 4:
		var rad := _medallion_angle + i * (PI * 0.5)
		var p1 := center + Vector2(cos(rad), sin(rad)) * MEDALLION_INNER_RADIUS
		var p2 := center + Vector2(cos(rad), sin(rad)) * MEDALLION_OUTER_RADIUS
		draw_line(p1, p2, glow_color, 1.5)


func _amber(alpha: float) -> Color:
	return Color(UiPalette.GLOW_AMBER.r, UiPalette.GLOW_AMBER.g, UiPalette.GLOW_AMBER.b, alpha)
