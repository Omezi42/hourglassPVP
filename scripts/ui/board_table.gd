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
	# 無地の一色だと輪郭だけの線画に見えるため、奥から手前へ明るくなる石の面として塗る。
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
	UiPaint.draw_ring(ci, center, MEDALLION_OUTER_RADIUS, divider_color, 2.0, 32)
	UiPaint.draw_ring(ci, center, MEDALLION_INNER_RADIUS, divider_color, 1.5, 32)


func _amber(alpha: float) -> Color:
	return Color(UiPalette.GLOW_AMBER.r, UiPalette.GLOW_AMBER.g, UiPalette.GLOW_AMBER.b, alpha)
