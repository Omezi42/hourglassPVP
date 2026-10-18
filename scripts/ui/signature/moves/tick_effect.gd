extends SignatureMove
## ティックの反転(GameDesign.md 9章):駒の上にメトロノームが現れて針が1度振れ、振り切った針先から
## 短い光の矢が相手のHPの器へ飛ぶ(打撃)。

const APPEAR := 0.12
const SWING := 0.2
const FLIGHT := 0.24
## 本体の置き場所(駒の中心から上へ、底辺の中心)と、底・頂の半幅と高さ。
const LIFT := 46.0
const BASE_HALF := 14.0
const TOP_HALF := 5.0
const HEIGHT := 34.0
## 針の長さと、振る前・振り切った傾き(ラジアン)、重りの大きさ。
const NEEDLE := 36.0
const FROM_ANGLE := -0.55
const TO_ANGLE := 0.55
const WEIGHT := Vector2(4.0, 3.0)
## 光の矢の長さ。
const BOLT := 26.0
const WOOD := Color(0.55, 0.34, 0.2, 1.0)
const WOOD_DARK := Color(0.32, 0.19, 0.11, 1.0)
const LIGHT := Color(1.0, 0.95, 0.75, 1.0)


func impact_at() -> float:
	return APPEAR + SWING + FLIGHT


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var appear := ease(phase(t, 0.0, APPEAR), 0.5)
	var base := from - Vector2(0.0, LIFT)
	var body := PackedVector2Array(
		[
			base + Vector2(-BASE_HALF, 0.0),
			base + Vector2(BASE_HALF, 0.0),
			base + Vector2(TOP_HALF, -HEIGHT),
			base + Vector2(-TOP_HALF, -HEIGHT),
		]
	)
	var a := alpha * appear
	UiPaint.fill_gradient_polygon(
		ci,
		body,
		Rect2(base - Vector2(BASE_HALF, HEIGHT), Vector2(BASE_HALF * 2.0, HEIGHT)),
		[[0.0, Color(WOOD, a)], [1.0, Color(WOOD_DARK, a)]]
	)
	var closed := body.duplicate()
	closed.append(body[0])
	ShapePaint.polyline(ci, closed, Color(UiPalette.OUTLINE_DARK, a * 0.8), 1.2, true)
	var swing := back_out(phase(t, APPEAR, SWING))
	var pivot := base - Vector2(0.0, 5.0)
	var tip := pivot + Vector2.UP.rotated(lerpf(FROM_ANGLE, TO_ANGLE, swing)) * NEEDLE
	item.draw_line(pivot, tip, Color(UiPalette.BRASS_HIGHLIGHT, a), 2.0, true)
	UiPaint.fill_ellipse(ci, pivot.lerp(tip, 0.7), WEIGHT, Color(UiPalette.BRASS_LIGHT, a), 12)
	var flight := phase(t, APPEAR + SWING, FLIGHT)
	if flight <= 0.0 or t >= impact_at():
		return
	var dir := (targets[0] - tip).normalized()
	var head := tip.lerp(targets[0], ease(flight, 1.6))
	var tail := head - dir * BOLT * minf(flight * 4.0, 1.0)
	item.draw_line(tail, head, Color(LIGHT, alpha * 0.45), 5.0, true)
	item.draw_line(tail, head, Color(LIGHT, alpha), 2.0, true)
