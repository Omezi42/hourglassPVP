extends SignatureMove
## オアシスの落砂(GameDesign.md 9章):駒の上に水が湧き、1滴が山なりに自分のHPの器へ落ちて、
## 届いたところで恵与の金色の水の輪が広がる。

const WELL := 0.2
const FLIGHT := 0.46
const RIPPLE := 0.34
## 水が湧く高さ(駒の中心から)と水面の大きさ。
const LIFT := 62.0
const POOL := Vector2(17.0, 4.5)
const ARC := 90.0
const DROP_RADIUS := 6.0
## 水滴の後ろに続く小さな粒。
const TRAIL := 4
const TRAIL_GAP := 0.05
const RING := Vector2(46.0, 14.0)


func impact_at() -> float:
	return WELL + FLIGHT


func duration() -> float:
	return impact_at() + RIPPLE


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var well := from - Vector2(0.0, LIFT)
	var rise := ease(phase(t, 0.0, WELL), 0.5)
	var drain := phase(t, WELL, FLIGHT)
	var pool := POOL * rise * (1.0 - drain)
	if pool.x > 0.5:
		UiPaint.fill_ellipse(ci, well, pool, Color(SignaturePaint.WATER, 0.7 * alpha), 24)
		UiPaint.draw_ellipse_ring(ci, well, pool, Color(1, 1, 1, 0.6 * alpha), 1.2, 24)
	if t < WELL:
		SignaturePaint.water_drop(
			item, well - Vector2(0.0, 10.0 * rise), DROP_RADIUS * rise, Vector2.UP, alpha
		)
	elif t < impact_at():
		var p := drain
		for i in range(TRAIL, 0, -1):
			var q := p - TRAIL_GAP * float(i)
			if q > 0.0:
				var size := DROP_RADIUS * 0.4 * (1.0 - float(i) / float(TRAIL + 1))
				UiPaint.fill_circle(
					ci, _path(well, q), size, Color(SignaturePaint.WATER, 0.6 * alpha), 8
				)
		var at := _path(well, p)
		SignaturePaint.water_drop(item, at, DROP_RADIUS, at - _path(well, p - 0.02), alpha)
	var ripple := phase(t, impact_at(), RIPPLE)
	if ripple > 0.0:
		for k in range(2):
			var r := ripple - 0.3 * float(k)
			if r > 0.0:
				UiPaint.draw_ellipse_ring(
					ci,
					targets[0],
					RING * ease(r, 0.4),
					Color(SignaturePaint.BOON, alpha * (1.0 - r)),
					2.4 - float(k) * 0.8,
					40
				)


## 水面から器までの山なりの道の上で、進み `p` の位置。
func _path(well: Vector2, p: float) -> Vector2:
	var x := clampf(p, 0.0, 1.0)
	return well.lerp(targets[0], x) - Vector2(0.0, ARC * 4.0 * x * (1.0 - x))
