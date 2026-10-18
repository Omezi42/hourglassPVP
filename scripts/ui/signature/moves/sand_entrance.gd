extends SignatureMove
## サンドの登場(GameDesign.md 9章):着地と同時に台座の周りへ砂の波紋が1つ広がり、縁から砂粒が
## さらさらと外へこぼれる。

const SPREAD := 0.4
const SPILL := 0.4
## 波紋の広がり(台座の半径に対する倍率)と、こぼれる砂粒の数・距離。
const REACH := 1.9
const GRAINS := 18
const SPILL_REACH := 26.0
const SPILL_DROP := 10.0


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + maxf(SPREAD, SPILL) + FADE


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var spread := phase(t, impact_at(), SPREAD)
	if spread < 1.0:
		var radius := CardView.PEDESTAL_RADIUS * lerpf(1.0, REACH, ease(spread, 0.4))
		UiPaint.draw_ellipse_ring(
			ci, from, radius, Color(SignaturePaint.SAND, alpha * (1.0 - spread)), 2.2, 40
		)
	var spill := phase(t, impact_at() + 0.04, SPILL)
	if spill <= 0.0 or spill >= 1.0:
		return
	for i in range(GRAINS):
		var angle := TAU * (float(i) + SignaturePaint.jitter(i, 81) * 0.6) / float(GRAINS)
		var dir := Vector2(cos(angle), sin(angle))
		var rim := from + dir * CardView.PEDESTAL_RADIUS
		var q := clampf(spill - SignaturePaint.jitter(i, 82) * 0.3, 0.0, 1.0)
		var at := rim + dir * SPILL_REACH * ease(q, 0.6) * Vector2(1.0, 0.4)
		at.y += SPILL_DROP * q * q
		var color := SignaturePaint.SAND.lerp(
			SignaturePaint.SAND_DARK, SignaturePaint.jitter(i, 83)
		)
		ShapePaint.circle(ci, at, 1.6, Color(color, alpha * (1.0 - q)))
