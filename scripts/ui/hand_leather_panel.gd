class_name HandLeatherPanel
extends Control
## 手札の下に敷く「手元の面」(GameDesign.md 9章)。革の面を敷いてその上へ札を並べ、
## 盤面と同じく札が宙に浮いている状態にしないための下敷き。
##
## 手札の`CardView`より必ず先に(=背面へ)`add_child()` すること。主役は上に乗る手札の
## カードであり、この面は質感を持たせつつも控えめに留める。

## 革らしい質感の色。木材(`UiPalette.WOOD_*`)より赤みを寄せた焦げ茶で、卓の木の額
## (`RoomPaint.WOOD_*`)とも見分けが付くようにする。このパネル専用のため`UiPalette`へは
## 足さず、ここへ局所的に持つ(`RoomPaint`が自分の領域の木材色を個別に持つのと同じ流儀)。
const LEATHER_TOP := Color(0.30, 0.18, 0.12, 1.0)
const LEATHER_MID := Color(0.20, 0.12, 0.08, 1.0)
const LEATHER_DARK := Color(0.10, 0.06, 0.04, 1.0)
const LEATHER_HIGHLIGHT := Color(0.42, 0.27, 0.18, 1.0)

const CORNER_RADIUS := 14.0
const CORNER_SEGMENTS := 8
const GRAIN_ALPHA := 0.07
const BEVEL_WIDTH := 2.5
const INNER_SHADOW_LAYERS := 5
const INNER_SHADOW_ALPHA := 0.5

## 縫い目(ステッチ)を上下の縁からこれだけ内側へ通す。
const SEAM_INSET_Y := 10.0
const SEAM_INSET_X := 18.0
const STITCH_LENGTH := 6.0
const STITCH_GAP := 6.0
const STITCH_COLOR := Color(0.06, 0.04, 0.025, 0.6)
const STITCH_WIDTH := 1.5


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var ci := get_canvas_item()
	var rect := Rect2(Vector2.ZERO, size)
	var points := UiPaint.rounded_rect_points_uniform(rect, CORNER_RADIUS, CORNER_SEGMENTS)
	(
		UiPaint
		. fill_gradient_polygon(
			ci,
			points,
			rect,
			[
				[0.0, LEATHER_TOP],
				[0.5, LEATHER_MID],
				[1.0, LEATHER_DARK],
			]
		)
	)
	UiPaint.apply_grain(ci, rect, GRAIN_ALPHA)
	UiPaint.draw_inner_shadow(
		ci,
		rect,
		CORNER_RADIUS,
		CORNER_SEGMENTS,
		INNER_SHADOW_LAYERS,
		Color(0, 0, 0),
		INNER_SHADOW_ALPHA
	)
	UiPaint.draw_bevel(ci, points, LEATHER_HIGHLIGHT, LEATHER_DARK, BEVEL_WIDTH, false)
	_draw_stitch_line(ci, rect.position.y + SEAM_INSET_Y, rect)
	_draw_stitch_line(ci, rect.end.y - SEAM_INSET_Y, rect)


## 上下の縁ぞいに縫い目を1本ずつ通す。革の面らしさを足すディテールで、実際の刺繍と
## 同じダッシュ間隔で短い線分を並べる(1本の実線だと単なる罫線に見えてしまうため)。
func _draw_stitch_line(ci: RID, y: float, rect: Rect2) -> void:
	var x := rect.position.x + SEAM_INSET_X
	var end_x := rect.end.x - SEAM_INSET_X
	while x < end_x:
		var seg_end: float = minf(x + STITCH_LENGTH, end_x)
		RenderingServer.canvas_item_add_line(
			ci, Vector2(x, y), Vector2(seg_end, y), STITCH_COLOR, STITCH_WIDTH
		)
		x += STITCH_LENGTH + STITCH_GAP
