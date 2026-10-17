extends SignatureMove
## レリックの登場(GameDesign.md 9章):着地した足元から古びた石の箱がせり上がって蓋が開き、
## 光の粒が1つ手札の側へ抜けていく(墓地から手札へ戻す設置を、登場で見せる)。

const RISE := 0.24
const OPEN := 0.2
const MOTE := 0.36
## 箱の置き場所(台座の上面の中心から)と大きさ。台座の手前の縁へ寄せて駒に重ねすぎない。
const BOX_OFFSET := Vector2(0.0, 12.0)
const BOX := Vector2(30.0, 16.0)
const LID_HEIGHT := 5.0
## 蓋が開ききった角度(後ろの辺を支点に)。
const LID_OPEN := 1.9
const SINK := 14.0
## 光の粒が抜けていく距離と大きさ。
const MOTE_REACH := 150.0
const MOTE_RADIUS := 5.0
const STONE_LIGHT := Color(0.66, 0.62, 0.54, 1.0)
const STONE_DARK := Color(0.36, 0.33, 0.29, 1.0)
const GLOW := Color(1.0, 0.92, 0.62, 1.0)


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + RISE + OPEN + MOTE


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var rise := ease(phase(t, impact_at(), RISE), 0.4)
	if rise <= 0.0:
		return
	var bottom := from + BOX_OFFSET + Vector2(0.0, SINK * (1.0 - rise))
	var top := bottom.y - BOX.y * rise
	var rect := Rect2(bottom.x - BOX.x * 0.5, top, BOX.x, bottom.y - top)
	UiPaint.fill_gradient_polygon(
		ci,
		PackedVector2Array(
			[
				rect.position,
				Vector2(rect.end.x, rect.position.y),
				rect.end,
				Vector2(rect.position.x, rect.end.y)
			]
		),
		rect,
		[[0.0, Color(STONE_LIGHT, alpha * rise)], [1.0, Color(STONE_DARK, alpha * rise)]]
	)
	item.draw_rect(rect, Color(UiPalette.OUTLINE_DARK, alpha * rise * 0.8), false, 1.2)
	# 箱の正面に刻んだ古い紋の線。
	item.draw_line(
		rect.get_center() - Vector2(BOX.x * 0.25, 0.0),
		rect.get_center() + Vector2(BOX.x * 0.25, 0.0),
		Color(STONE_DARK, alpha * rise),
		1.2
	)
	var open := back_out(phase(t, impact_at() + RISE, OPEN))
	var hinge := Vector2(rect.end.x, top)
	var lid := Vector2(-BOX.x, 0.0).rotated(open * LID_OPEN)
	var lift := Vector2(0.0, -LID_HEIGHT).rotated(open * LID_OPEN)
	var lid_shape := PackedVector2Array([hinge, hinge + lid, hinge + lid + lift, hinge + lift])
	if open > 0.0:
		UiPaint.fill_ellipse(
			ci,
			Vector2(rect.get_center().x, top),
			Vector2(BOX.x * 0.45, 3.0),
			Color(GLOW, alpha * open),
			16
		)
	ShapePaint.colored_polygon(item.get_canvas_item(), lid_shape, Color(STONE_LIGHT, alpha * rise))
	var closed := lid_shape.duplicate()
	closed.append(lid_shape[0])
	ShapePaint.polyline(
		item.get_canvas_item(), closed, Color(UiPalette.OUTLINE_DARK, alpha * rise * 0.8), 1.2, true
	)
	var mote := phase(t, impact_at() + RISE + OPEN * 0.6, MOTE)
	if mote > 0.0 and mote < 1.0:
		var at := (
			Vector2(rect.get_center().x, top)
			+ Vector2(0.0, _toward_hand() * MOTE_REACH * ease(mote, 1.8))
		)
		UiPaint.fill_circle(ci, at, MOTE_RADIUS * 2.2, Color(GLOW, 0.25 * (1.0 - mote)), 16)
		UiPaint.fill_circle(ci, at, MOTE_RADIUS, Color(GLOW, 1.0 - mote), 12)


## 手札のある向き(1=下、-1=上)。駒が卓の下半分にいれば自分の、上半分なら相手の駒。
func _toward_hand() -> float:
	return 1.0 if from.y > CardMatchLayout.current().table_rect.get_center().y else -1.0
