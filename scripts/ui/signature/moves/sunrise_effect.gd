extends SignatureMove
## サンライズの払拭(GameDesign.md 9章):設置で、駒の頭上の地平から朝日が昇って光の矢を放つ一方、くすんだ音の輪が
## 相手のHPの器へ飛び、届いたところに夜の色の三日月が掛かってくすんだ輪が縮む(相手の朝はまだ来ない)。

const RISE := 0.3
const FLY := 0.26
## 地平の位置(駒の中心から上へ)・半幅、朝日の半径と昇る高さ、光の矢の数・長さ、三日月の半径、飛ぶ輪の大きさ。
const LIFT := 40.0
const HORIZON := 32.0
const SUN := 16.0
const CLIMB := 14.0
const RAYS := 9
const RAY := 11.0
const MOON := 13.0
const FLIGHT_RADIUS := 16.0


func impact_at() -> float:
	return RISE + FLY


func top_extent() -> float:
	return (LIFT + CLIMB + SUN + RAY + 4.0) * zoom


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var horizon := from - Vector2(0.0, LIFT * zoom)
	var rise := ease(phase(t, 0.0, RISE), 0.6)
	var sun_alpha := alpha * minf(phase(t, 0.0, RISE) * 4.0, 1.0)
	if sun_alpha > 0.0:
		var sun := horizon - Vector2(0.0, CLIMB * rise * zoom)
		var r := SUN * zoom
		ShapePaint.circle(ci, sun, r * 1.9, Color(UiPalette.DAYBREAK, sun_alpha * 0.25))
		for i in range(RAYS):
			var dir := Vector2.from_angle(PI + PI * (float(i) + 0.5) / float(RAYS))
			var reach := (RAY * (0.6 + 0.4 * float(i % 2))) * zoom * rise
			var ray := PackedVector2Array([sun + dir * (r + 2.0), sun + dir * (r + 2.0 + reach)])
			ShapePaint.polyline(ci, ray, Color(UiPalette.FLAME, sun_alpha), 2.4 * zoom, true)
		var disc := PackedVector2Array()
		for i in range(17):
			var a := PI + PI * float(i) / 16.0
			var p := sun + Vector2(cos(a), sin(a)) * r
			disc.append(Vector2(p.x, minf(p.y, horizon.y)))
		ShapePaint.convex_polygon(ci, disc, Color(UiPalette.FLAME, sun_alpha))
		var line := PackedVector2Array(
			[horizon - Vector2(HORIZON * zoom, 0.0), horizon + Vector2(HORIZON * zoom, 0.0)]
		)
		ShapePaint.polyline(ci, line, Color(UiPalette.INK_950, sun_alpha * 0.85), 4.4 * zoom, true)
		ShapePaint.polyline(ci, line, Color(UiPalette.TOLL_BRASS, sun_alpha), 2.6 * zoom, true)
	var fly := phase(t, RISE, FLY)
	var land := phase(t, impact_at(), FADE)
	for target in targets:
		SignaturePaint.toll_flight(
			item, horizon, target, fly, FLIGHT_RADIUS, alpha, UiPalette.DRAIN_TRAIL
		)
		if land > 0.0:
			_moon(
				ci,
				target - Vector2(0.0, MOON * 0.4),
				alpha * (1.0 - land * 0.6) * minf(land * 4.0, 1.0)
			)
		SignaturePaint.drain_ring(item, target, land, alpha)


## 夜の色の三日月(欠けは右上)。外の円のうち欠けの円の外側と、欠けの円のうち外の円の内側をつなぐ。
static func _moon(ci: RID, center: Vector2, alpha: float) -> void:
	const STEPS := 24
	const BITE := 0.82
	if alpha <= 0.0:
		return
	var bite := center + Vector2(MOON * 0.45, -MOON * 0.3)
	var away := (center - bite).angle()
	var points := PackedVector2Array()
	for i in range(STEPS + 1):
		var p := center + Vector2.from_angle(away - PI + TAU * float(i) / float(STEPS)) * MOON
		if p.distance_to(bite) >= MOON * BITE:
			points.append(p)
	for i in range(STEPS + 1):
		var p := bite + Vector2.from_angle(away + PI - TAU * float(i) / float(STEPS)) * MOON * BITE
		if p.distance_to(center) < MOON:
			points.append(p)
	if points.size() >= 3:
		ShapePaint.colored_polygon(ci, points, Color(UiPalette.NIGHT_VEIL, alpha))
