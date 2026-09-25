class_name ResultPanelFrame
extends RefCounted
## 結果パネル本体の質感(Architecture.md 4章のコード描画方針: 多段グラデーション + 面取り +
## 内側の落ち込み影 + グレイン)。対局・リーサルパズル・ソロモードの結果パネルが共有する。
## 勝ち(bright)は琥珀、負けは冷えた石の色へ色調だけを差し替える。

const RADIUS := 20.0
const BEVEL_WIDTH := 3.0
const OUTLINE_WIDTH := 2.0
const GRAIN_ALPHA := 0.05
const BRIGHT_STOPS := [
	[0.0, Color(0.46, 0.28, 0.08, 0.98)],
	[0.35, Color(0.24, 0.15, 0.07, 0.98)],
	[1.0, Color(0.1, 0.08, 0.07, 0.98)],
]
const STONE_STOPS := [
	[0.0, Color(0.22, 0.22, 0.25, 0.98)],
	[0.4, Color(0.13, 0.13, 0.16, 0.98)],
	[1.0, Color(0.06, 0.06, 0.08, 0.98)],
]
const STONE_LIGHT_EDGE := Color(0.4, 0.4, 0.44, 1.0)
const STONE_DARK_EDGE := Color(0.05, 0.05, 0.06, 1.0)


static func draw(ci: RID, panel_size: Vector2, bright: bool) -> void:
	# 大きさが決まる前(中身に合わせて伸びるパネル)は描かない。角丸の点列が潰れる。
	if panel_size.x < RADIUS * 2.0 or panel_size.y < RADIUS * 2.0:
		return
	var rect := Rect2(Vector2.ZERO, panel_size)
	var points := UiPaint.rounded_rect_points_uniform(rect, RADIUS, 8)
	UiPaint.fill_gradient_polygon(ci, points, rect, BRIGHT_STOPS if bright else STONE_STOPS)
	UiPaint.draw_inner_shadow(ci, rect.grow(-3.0), 18.0, 26, 4, Color(0, 0, 0), 0.32)
	UiPaint.draw_bevel(
		ci,
		points,
		UiPalette.BRASS_HIGHLIGHT if bright else STONE_LIGHT_EDGE,
		UiPalette.BRASS_DARK if bright else STONE_DARK_EDGE,
		BEVEL_WIDTH,
		false
	)
	var outline := points.duplicate()
	outline.append(points[0])
	var outline_colors := PackedColorArray()
	outline_colors.resize(outline.size())
	outline_colors.fill(UiPalette.OUTLINE_DARK)
	RenderingServer.canvas_item_add_polyline(ci, outline, outline_colors, OUTLINE_WIDTH, true)
	UiPaint.apply_grain(ci, rect, GRAIN_ALPHA)
