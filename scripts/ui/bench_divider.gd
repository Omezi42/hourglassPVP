class_name BenchDivider
extends Control
## HourglassSlotStripの「場に出ている3枠」と「控えの2枠」の境目に立てる仕切り
## (GameDesign.md 9章「『場』の3マスと『控え』の2マスを視覚的に区切る」)。
## 控えは交代スキルを持つ駒でしか場へ出せないため、どこからが控えなのかが一目で
## 分かる必要がある。無地の矩形ではなく、上下へ向かって消える琥珀の線と中央の菱形で
## 他のコード描画UI(BoardTable/BarPanel)と質感を揃える。

const WIDTH := 14.0
## 線は上下端まで引かず、スロットの高さに対してこの割合だけを占める。
const LINE_HEIGHT_RATIO := 0.74
const LINE_WIDTH := 2.0
const DIAMOND_RADIUS := 4.5
const LINE_COLOR := Color(0.85, 0.62, 0.22, 0.55)
const LINE_FADE_COLOR := Color(0.85, 0.62, 0.22, 0.0)
const DIAMOND_COLOR := Color(0.96, 0.82, 0.5, 0.9)


func _ready() -> void:
	custom_minimum_size = Vector2(WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var ci := get_canvas_item()
	var center_x := size.x * 0.5
	var mid_y := size.y * 0.5
	var half := size.y * LINE_HEIGHT_RATIO * 0.5
	var line_rect := Rect2(center_x - LINE_WIDTH * 0.5, mid_y - half, LINE_WIDTH, half * 2.0)
	var stops := [[0.0, LINE_FADE_COLOR], [0.5, LINE_COLOR], [1.0, LINE_FADE_COLOR]]
	# 端が背景へ溶けるよう、中央を頂点として上下に分けた2枚の台形で塗る
	(
		UiPaint
		. fill_gradient_polygon(
			ci,
			PackedVector2Array(
				[
					line_rect.position,
					Vector2(line_rect.end.x, line_rect.position.y),
					Vector2(line_rect.end.x, mid_y),
					Vector2(line_rect.position.x, mid_y),
				]
			),
			line_rect,
			stops
		)
	)
	(
		UiPaint
		. fill_gradient_polygon(
			ci,
			PackedVector2Array(
				[
					Vector2(line_rect.position.x, mid_y),
					Vector2(line_rect.end.x, mid_y),
					line_rect.end,
					Vector2(line_rect.position.x, line_rect.end.y),
				]
			),
			line_rect,
			stops
		)
	)
	var diamond := PackedVector2Array(
		[
			Vector2(center_x, mid_y - DIAMOND_RADIUS),
			Vector2(center_x + DIAMOND_RADIUS, mid_y),
			Vector2(center_x, mid_y + DIAMOND_RADIUS),
			Vector2(center_x - DIAMOND_RADIUS, mid_y),
		]
	)
	UiPaint.fill_gradient_polygon(
		ci, diamond, line_rect, [[0.0, DIAMOND_COLOR], [1.0, DIAMOND_COLOR]]
	)
