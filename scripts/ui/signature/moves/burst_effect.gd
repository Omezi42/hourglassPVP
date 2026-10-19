extends SignatureMove
## バーストの余砂(GameDesign.md 9章):銘板が赤く膨らんで弾け、火の破片が相手の駒それぞれへ放射状に
## 飛び散って当たる(打撃)。

const SWELL := 0.24
const FLIGHT := 0.26
## 膨らむ玉の置き場所(銘板から上へ)と大きさ、脈打つ回数、弾けた輪の広がり、破片の尾の長さ。
const LIFT := 22.0
const CORE := 14.0
const THROBS := 2.0
const POP := 40.0
const SHARD := 18.0
const HOT := Color(1.0, 0.42, 0.16, 1.0)
const CORE_COLOR := Color(1.0, 0.9, 0.6, 1.0)


func impact_at() -> float:
	return SWELL + FLIGHT


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var core := from - Vector2(0.0, LIFT)
	var swell := phase(t, 0.0, SWELL)
	if swell < 1.0:
		var size := CORE * ease(swell, 0.5) * (1.0 + 0.15 * sin(swell * TAU * THROBS))
		if size > 1.0:
			ShapePaint.circle(ci, core, size * 1.6, Color(HOT, alpha * 0.3))
			ShapePaint.circle(ci, core, size, Color(HOT, alpha))
			ShapePaint.circle(ci, core, size * 0.5, Color(CORE_COLOR, alpha))
		return
	var flight := phase(t, SWELL, FLIGHT)
	var pop := ease(minf(flight * 2.0, 1.0), 0.4)
	if pop < 1.0:
		ShapePaint.arc(
			ci, core, CORE + POP * pop, 0.0, TAU, 36, Color(HOT, alpha * (1.0 - pop)), 3.0, true
		)
	if t >= impact_at():
		return
	for target: Vector2 in targets:
		var dir := (target - core).normalized()
		var head := core.lerp(target, ease(flight, 1.4))
		var tail := head - dir * SHARD * minf(flight * 4.0, 1.0)
		item.draw_line(tail, head, Color(HOT, alpha * 0.5), 5.0, true)
		item.draw_line(tail, head, Color(CORE_COLOR, alpha), 2.0, true)
