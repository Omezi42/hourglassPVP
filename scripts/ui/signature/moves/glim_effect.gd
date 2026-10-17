extends SignatureMove
## グリムの被弾(GameDesign.md 9章):駒の表面に小さな光が3回またたき、最後のまたたきから光の針が
## 相手のHPの器へ走って刺さる(打撃)。

const TWINKLE := 0.12
const FLIGHT := 0.22
## またたく場所(駒の中心から)と光の大きさ、光の針の長さ。
const SPOTS := [Vector2(-18.0, -26.0), Vector2(16.0, 6.0), Vector2(-4.0, -6.0)]
const GLINT := 11.0
const NEEDLE := 34.0
const LIGHT := Color(1.0, 0.98, 0.82, 1.0)
const HALO := Color(1.0, 0.86, 0.5, 1.0)


func impact_at() -> float:
	return TWINKLE * SPOTS.size() + FLIGHT


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	for i in range(SPOTS.size()):
		var q := phase(t, TWINKLE * float(i), TWINKLE * 1.4)
		var last := i == SPOTS.size() - 1
		if q <= 0.0 or (q >= 1.0 and not last):
			continue
		var size := GLINT * sin(minf(q, 0.5 if last else 1.0) * PI)
		if last and t >= TWINKLE * float(SPOTS.size()):
			size *= 1.0 - phase(t, TWINKLE * float(SPOTS.size()), FLIGHT)
		_glint(item, from + SPOTS[i], size, alpha)
	var flight := phase(t, TWINKLE * float(SPOTS.size()), FLIGHT)
	if flight <= 0.0 or t >= impact_at():
		return
	var start: Vector2 = from + SPOTS[SPOTS.size() - 1]
	var dir := (targets[0] - start).normalized()
	var head := start.lerp(targets[0], ease(flight, 1.8))
	var tail := head - dir * NEEDLE * minf(flight * 3.0, 1.0)
	item.draw_line(tail, head, Color(HALO, alpha * 0.5), 5.0, true)
	item.draw_line(tail, head, Color(LIGHT, alpha), 2.0, true)


## 十字の光のまたたき。
func _glint(item: CanvasItem, at: Vector2, size: float, alpha: float) -> void:
	if size <= 1.0:
		return
	item.draw_line(at - Vector2(size, 0.0), at + Vector2(size, 0.0), Color(LIGHT, alpha), 1.6, true)
	item.draw_line(at - Vector2(0.0, size), at + Vector2(0.0, size), Color(LIGHT, alpha), 1.6, true)
	item.draw_circle(at, size * 0.35, Color(HALO, alpha * 0.5))
	item.draw_circle(at, size * 0.18, Color(1, 1, 1, alpha))
