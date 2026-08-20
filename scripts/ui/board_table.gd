class_name BoardTable
extends Control
## 対局盤面のテーブル面。AI生成イラストを使わず、コードのポリゴン描画のみで
## 「横長・軽い奥行きのある石テーブル」を表現する(無地でよいというユーザー指示に基づく)。
## 色はUiPalette、円弧・楕円の点列生成はUiPaint(coded_button_style.gd等と共通のライブラリ)
## を経由する(フェーズ12 Q-6)。Control._draw()はCanvasItemのdraw_*系を直接呼べるため、
## UiPaint(ci: RID第1引数)を使う箇所ではself.get_canvas_item()を渡す。

const TABLE_BORDER_WIDTH := 3.0
## 奥(上端)をわずかに狭くして軽い奥行きを出す比率。
const TOP_INSET_RATIO := 0.07
const DIVIDER_WIDTH := 2.0
const DIVIDER_RATIO := 0.5
const MEDALLION_OUTER_RADIUS := 22.0
const MEDALLION_INNER_RADIUS := 13.0
const CORNER_ORNAMENT_RADIUS := 26.0

## 琥珀アクセント(枠線・区切り線・隅飾り)は他のコード描画UIと共通のGLOW_AMBERを使い、
## 用途ごとにアルファのみ変える(CodedButtonStyleのホバーグロー等と同じ考え方)。
const TABLE_BORDER_ALPHA := 0.9
const DIVIDER_ALPHA := 0.55
const CORNER_ORNAMENT_ALPHA := 0.12


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
	var fill_color := UiPalette.BOARD_TABLE_FILL
	UiPaint.fill_gradient_polygon(
		ci, points, Rect2(Vector2.ZERO, size), [[0.0, fill_color], [1.0, fill_color]]
	)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, _amber(TABLE_BORDER_ALPHA), TABLE_BORDER_WIDTH, true)

	var divider_color := _amber(DIVIDER_ALPHA)
	var divider_y := size.y * DIVIDER_RATIO
	var left_x: float = lerp(top_inset, 0.0, DIVIDER_RATIO)
	var right_x: float = lerp(size.x - top_inset, size.x, DIVIDER_RATIO)
	draw_line(Vector2(left_x, divider_y), Vector2(right_x, divider_y), divider_color, DIVIDER_WIDTH)

	var center := Vector2(size.x * 0.5, divider_y)
	UiPaint.draw_ring(ci, center, MEDALLION_OUTER_RADIUS, divider_color, 2.0, 32)
	UiPaint.draw_ring(ci, center, MEDALLION_INNER_RADIUS, divider_color, 1.5, 32)

	var corner_color := _amber(CORNER_ORNAMENT_ALPHA)
	_draw_corner_ornament(ci, Vector2(top_inset * 0.6, size.y * 0.12), corner_color)
	_draw_corner_ornament(ci, Vector2(size.x - top_inset * 0.6, size.y * 0.12), corner_color)
	_draw_corner_ornament(ci, Vector2(size.x * 0.06, size.y * 0.9), corner_color)
	_draw_corner_ornament(ci, Vector2(size.x * 0.94, size.y * 0.9), corner_color)


func _amber(alpha: float) -> Color:
	return Color(UiPalette.GLOW_AMBER.r, UiPalette.GLOW_AMBER.g, UiPalette.GLOW_AMBER.b, alpha)


func _draw_corner_ornament(ci: RID, center: Vector2, color: Color) -> void:
	UiPaint.fill_ellipse(
		ci, center, Vector2(CORNER_ORNAMENT_RADIUS, CORNER_ORNAMENT_RADIUS * 0.5), color, 24
	)
