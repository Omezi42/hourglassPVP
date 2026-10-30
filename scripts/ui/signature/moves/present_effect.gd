extends SignatureMove
## プレゼント(GameDesign.md 9章):自分の情報帯の上にリボンを掛けた箱が現れて蓋が跳ね上がり、中から砂粒が昇る(ドロー)。
## 続いて閉じた箱が弧を描いて相手の情報帯へ飛び、届いたところでリボンの光が弾ける(相手の手札へ加える)。

const APPEAR := 0.15
const POP := 0.18
const RISE := 0.25
const FLY := 0.5
## 箱の浮く高さ(出どころから上へ)・箱と蓋の大きさ・リボンの太さ・蓋の跳ねる高さ・飛ぶ弧の高さ。
const LIFT := 46.0
const BOX := Vector2(30.0, 22.0)
const LID := Vector2(34.0, 8.0)
const RIBBON := 5.0
const LID_JUMP := 18.0
const ARC_HEIGHT := 90.0
const BOX_COLOR := Color(0.78, 0.22, 0.24, 1.0)
const LID_COLOR := Color(0.88, 0.30, 0.30, 1.0)


func impact_at() -> float:
	return FLY if _giving() else APPEAR + POP + RISE


func draw(item: CanvasItem, t: float) -> void:
	if _giving():
		_draw_flight(item, t)
	else:
		_draw_opening(item, t)


func _draw_opening(item: CanvasItem, t: float) -> void:
	var alpha := fade_alpha(t)
	var grow := ease(phase(t, 0.0, APPEAR), 0.5)
	var pop := phase(t, APPEAR, POP)
	var center := from - Vector2(0.0, LIFT)
	_box(item, center, grow, LID_JUMP * back_out(pop), pop * 0.5, alpha)
	var rise := phase(t, APPEAR + POP * 0.5, RISE + SignatureMove.FADE)
	SignaturePaint.rising_grains(item, center - Vector2(0.0, BOX.y), rise, alpha)


func _draw_flight(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var start := from - Vector2(0.0, LIFT)
	var fly := phase(t, 0.0, FLY)
	if fly < 1.0:
		var q := ease(fly, -1.6)
		var at := start.lerp(targets[0], q) - Vector2(0.0, ARC_HEIGHT * sin(PI * q))
		_box(item, at, 1.0, 0.0, 0.0, alpha)
		return
	var burst := phase(t, FLY, SignatureMove.FADE)
	SignaturePaint.boon_ring(item, targets[0], burst, 1.0)
	SignaturePaint.sparks(item, targets[0], burst, 1.0 - burst)


## 箱を `center`(箱の胴の中心)へ描く。`grow` は現れる大きさ、`lid_up` は蓋の浮いた高さ、`tilt` は蓋の傾き。
func _box(
	item: CanvasItem, center: Vector2, grow: float, lid_up: float, tilt: float, alpha: float
) -> void:
	if grow <= 0.0 or alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var body := BOX * grow
	var body_rect := Rect2(center - body * 0.5, body)
	ShapePaint.colored_polygon(ci, _rect_points(body_rect, 0.0), Color(BOX_COLOR, alpha))
	var band := Rect2(center.x - RIBBON * grow * 0.5, body_rect.position.y, RIBBON * grow, body.y)
	ShapePaint.colored_polygon(ci, _rect_points(band, 0.0), Color(SignaturePaint.SAND, alpha))
	var lid := LID * grow
	var lid_center := Vector2(center.x, body_rect.position.y - lid.y * 0.5 - lid_up)
	var lid_rect := Rect2(lid_center - lid * 0.5, lid)
	ShapePaint.colored_polygon(ci, _rect_points(lid_rect, tilt), Color(LID_COLOR, alpha))
	var bow := lid_center - Vector2(0.0, lid.y * 0.5)
	for side: float in [-1.0, 1.0]:
		ShapePaint.circle(
			ci,
			bow + Vector2(side * RIBBON * grow, -RIBBON * 0.4 * grow),
			RIBBON * 0.8 * grow,
			Color(SignaturePaint.SAND, alpha)
		)


## 矩形の4隅を、中心の周りに `angle` だけ回して返す。
static func _rect_points(rect: Rect2, angle: float) -> PackedVector2Array:
	var center := rect.get_center()
	var points := PackedVector2Array()
	for corner in [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	]:
		points.append(center + (corner - center).rotated(angle))
	return points


func _giving() -> bool:
	return style == CardEnums.EffectVisualStyle.DESCEND
