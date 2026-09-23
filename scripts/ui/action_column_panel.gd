class_name ActionColumnPanel
extends Control
## 対局画面右端「行動の列」の地(GameDesign.md 9章「対局画面の再構築」)。
## 壁ではなく**卓の脇に立てた真鍮枠の操作盤**として描く——
## 濃紺の板 + 真鍮の額 + 上下の飾り板(紋章入り)+ ターン終了を囲む彫り込みの輪 +
## 3つの群(`ActionColumnLayout`)の間の区切り線。
##
## `CardMatchScreen` の定数を実行時に読んで矩形を決める(Architecture.md 11章
## 「class_nameを持つ2つのスクリプトが、互いのconstをconstから参照してはいけない」)。
## ボタンより先に `add_child()` して背面へ置く。

const PLATE_HEIGHT := 22.0
const PLATE_EMBLEM_SIZE := 10.0
const FRAME_WIDTH := 4.0
const CORNER_RADIUS := 14.0
const DIVIDER_RATIO := 0.6


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(CardMatchScreen.ACTION_COLUMN_X + 6.0, 10.0)
	size = Vector2(1280.0 - position.x - 16.0, 700.0)


func _draw() -> void:
	var ci := get_canvas_item()
	var rect := Rect2(Vector2.ZERO, size)
	var points := UiPaint.rounded_rect_points_uniform(rect, CORNER_RADIUS, 5)
	UiPaint.fill_gradient_polygon(
		ci, points, rect, [[0.0, UiPalette.NAVY_PANEL_TOP], [1.0, UiPalette.NAVY_PANEL_BOTTOM]]
	)
	UiPaint.apply_grain(ci, rect, 0.06)
	UiPaint.draw_inner_shadow(ci, rect, CORNER_RADIUS, 5, 5, Color(0, 0, 0), 0.35)
	_draw_brass_frame(ci, rect, points)
	_draw_plate(ci, rect, true)
	_draw_plate(ci, rect, false)
	_draw_turn_end_ring(ci)
	for divider_y: float in ActionColumnLayout.DIVIDER_YS:
		_draw_divider(rect, divider_y - position.y)


## 板の外周を真鍮の帯として縁取る。外側にごく細い暗い輪郭、内側にごく細い明るい線を
## 添えて、額が板そのものに彫り込まれているように見せる。
func _draw_brass_frame(ci: RID, rect: Rect2, points: PackedVector2Array) -> void:
	var outer := UiPaint.rounded_rect_points_uniform(rect.grow(1.0), CORNER_RADIUS + 1.0, 5)
	_draw_closed(outer, UiPalette.OUTLINE_DARK, 1.0)
	UiPaint.draw_bevel(
		ci, points, UiPalette.BRASS_RIM_LIGHT, UiPalette.BRASS_DARK, FRAME_WIDTH, false
	)
	var inner := UiPaint.rounded_rect_points_uniform(
		rect.grow(-FRAME_WIDTH), maxf(CORNER_RADIUS - FRAME_WIDTH, 0.0), 5
	)
	_draw_closed(inner, Color(UiPalette.BRASS_RIM_LIGHT, 0.5), 1.0)


func _draw_closed(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width, true)


## 上端・下端の真鍮の飾り板。中央に小さな砂時計の紋章を置き、操作盤そのものが
## 「作りつけの器具」として読めるようにする。
func _draw_plate(ci: RID, rect: Rect2, top: bool) -> void:
	var plate_rect := Rect2(rect.position.x, rect.position.y, rect.size.x, PLATE_HEIGHT)
	if not top:
		plate_rect.position.y = rect.end.y - PLATE_HEIGHT
	var points := UiPaint.rounded_rect_points_uniform(plate_rect, 4.0, 3)
	UiPaint.fill_gradient_polygon(
		ci, points, plate_rect, [[0.0, UiPalette.BRASS_DARK], [1.0, UiPalette.BRASS_MID]]
	)
	UiPaint.draw_emblem(ci, UiPaint.Emblem.HOURGLASS, plate_rect.get_center(), PLATE_EMBLEM_SIZE)


## ターン終了ボタンの位置は`CardMatchScreen`の定数から求める(座標系はスクリーン共通)。
## パネル自身の`_draw()`はパネルのローカル座標のため、パネルの`position`ぶんを引く。
func _draw_turn_end_ring(ci: RID) -> void:
	var screen_center := Vector2(
		CardMatchScreen.ACTION_COLUMN_X + CardMatchScreen.ACTION_COLUMN_CENTER_OFFSET,
		ActionColumnLayout.TURN_END_Y
	)
	var center := screen_center - position
	var r: float = (
		ActionColumnLayout.TURN_END_DIAMETER * 0.5 + ActionColumnLayout.TURN_END_RING_MARGIN
	)
	UiPaint.draw_ring(ci, center, r, UiPalette.OUTLINE_DARK, 1.5, 30)
	UiPaint.draw_ring(ci, center, r - 2.0, Color(UiPalette.BRASS_HIGHLIGHT, 0.35), 1.0, 30)


func _draw_divider(rect: Rect2, local_y: float) -> void:
	var width := rect.size.x * DIVIDER_RATIO
	var x0 := rect.get_center().x - width * 0.5
	draw_line(
		Vector2(x0, local_y), Vector2(x0 + width, local_y), Color(UiPalette.BRASS_MID, 0.6), 1.5
	)
