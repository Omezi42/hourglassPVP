extends SignatureMove
## クインテットの設置(GameDesign.md 9章):駒から5つの光の玉が五角形に回り、味方の駒それぞれへ飛んで、
## 届いた駒の台座に輪が灯る(総量が5にそろう)。

const CIRCLE := 0.36
const FLY := 0.3
## 玉の数・大きさと、回る輪の半径・高さ(駒の中心から上へ)・回る量(周)。
const ORBS := 5
const ORB := 6.0
const RADIUS := 30.0
const LIFT := 60.0
const TURNS := 0.6
const COLOR := Color(1.0, 0.45, 0.2, 1.0)


func impact_at() -> float:
	return CIRCLE + FLY


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var ci := item.get_canvas_item()
	var center := from - Vector2(0.0, LIFT * zoom)
	var circle := phase(t, 0.0, CIRCLE)
	var fly := ease(phase(t, CIRCLE, FLY), 1.8)
	var spin := TURNS * TAU * ease(circle, 0.6)
	var corners := PackedVector2Array()
	for i in range(ORBS):
		var angle := -PI * 0.5 + TAU * float(i) / float(ORBS) + spin
		var ring := center + Vector2.from_angle(angle) * RADIUS * zoom * ease(circle, 0.4)
		corners.append(ring)
		var at := ring.lerp(targets[i % targets.size()], fly)
		ShapePaint.circle(ci, at, ORB * zoom * 1.8, Color(COLOR, alpha * 0.3))
		ShapePaint.circle(ci, at, ORB * zoom, Color(COLOR, alpha))
		ShapePaint.circle(ci, at, ORB * zoom * 0.4, Color(1, 1, 1, alpha))
	if fly <= 0.0:
		corners.append(corners[0])
		ShapePaint.polyline(ci, corners, Color(COLOR, alpha * 0.5 * circle), 1.6, true)
	var landed := phase(t, impact_at(), FADE)
	if landed > 0.0:
		for target in targets:
			SignaturePaint.boon_ring(item, target, landed, alpha)
