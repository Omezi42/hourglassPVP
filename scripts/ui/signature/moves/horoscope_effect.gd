extends SignatureMove
## ホロスコープの落砂(GameDesign.md 9章):駒の頭上に金の渾天儀が現れて黄道の輪が回り、輪から星が1つこぼれて
## 駒の脇へ落ち、光の輪が広がる(山札の一番上を墓地へ。静止)。それが砂術だったときの1ダメージでは、
## こぼれた星が流れ星になって対象の駒へ弧を描いて落ち、当たって火花が散る(打撃。盤面を揺らす)。

const APPEAR := 0.1
const TURN := 0.3
const SPILL := 0.24
const SHOOT := 0.26
## 渾天儀の位置(駒の中心から)と半径、こぼれた星の落ちる先(駒の中心から)、流れ星の弧の高さ・尾の長さ(弧の上の進みの差)と刻み。
const SPHERE := Vector2(0.0, -70.0)
const RADIUS := 17.0
const SPILL_TO := Vector2(40.0, 30.0)
const ARC := 60.0
const TAIL := 0.2
const TAIL_STEPS := 8


func top_extent() -> float:
	return (-SPHERE.y + RADIUS + 6.0) * zoom


func impact_at() -> float:
	return APPEAR + TURN + (SHOOT if _striking() else SPILL)


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var shown := minf(phase(t, 0.0, APPEAR) * 1.5, 1.0)
	var center := from + SPHERE * zoom
	var spin := ease(phase(t, APPEAR, TURN), 0.7) * PI + t * 1.5
	_armillary(item, center, spin, alpha * shown)
	var ring_star := (
		center + Vector2(RADIUS * zoom, 0.0).rotated(-0.42 + spin * 0.5) * Vector2(1.0, 0.4)
	)
	var go := phase(t, APPEAR + TURN, impact_at() - APPEAR - TURN)
	if go <= 0.0:
		ForesightPaint.next_star(item, ring_star, 0.45 * zoom, alpha * shown, spin)
		return
	if _striking():
		_shoot(item, ring_star, targets[0], go, alpha)
		SignaturePaint.sparks(item, targets[0], phase(t, impact_at(), FADE), alpha)
		return
	var drop := from + SPILL_TO * zoom
	if go < 1.0:
		var at := ring_star.lerp(drop, ease(go, 1.8))
		ForesightPaint.next_star(item, at, 0.55 * zoom, alpha, spin)
	else:
		SignaturePaint.pulse_ring(item, drop, phase(t, impact_at(), FADE), alpha)


func _striking() -> bool:
	return style == CardEnums.EffectVisualStyle.STRIKE


func _shoot(item: CanvasItem, start: Vector2, end: Vector2, go: float, alpha: float) -> void:
	if go >= 1.0:
		return
	var head := _arc_at(start, end, ease(go, 1.3))
	var trail := PackedVector2Array()
	var colors := PackedColorArray()
	for i in range(TAIL_STEPS + 1):
		var k := float(i) / float(TAIL_STEPS)
		trail.append(_arc_at(start, end, maxf(ease(go, 1.3) - TAIL * (1.0 - k), 0.0)))
		colors.append(Color(UiPalette.NEXT_STAR, alpha * k * 0.8))
	ShapePaint.polyline_colors(item.get_canvas_item(), trail, colors, 3.0 * zoom, true)
	ForesightPaint.next_star(item, head, 0.7 * zoom, alpha, go * 6.0)


func _arc_at(start: Vector2, end: Vector2, s: float) -> Vector2:
	return start.lerp(end, s) - Vector2(0.0, ARC * zoom * sin(s * PI))


func _armillary(item: CanvasItem, center: Vector2, spin: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var r := RADIUS * zoom
	item.draw_line(
		center + Vector2(0.0, r),
		center + Vector2(0.0, r + 10.0 * zoom),
		Color(UiPalette.GOLD, alpha),
		2.4,
		true
	)
	ShapePaint.circle(
		ci, center + Vector2(0.0, r + 11.0 * zoom), 4.0 * zoom, Color(UiPalette.GOLD, alpha)
	)
	ShapePaint.circle(ci, center, r * 0.32, Color(UiPalette.CHART_LAPIS, alpha))
	_ellipse(ci, center, Vector2(r, r), 0.0, alpha)
	_ellipse(ci, center, Vector2(r, r * 0.3), 0.0, alpha)
	_ellipse(ci, center, Vector2(r * absf(cos(spin)), r), 0.0, alpha)
	_ellipse(ci, center, Vector2(r * 1.05, r * 0.42), -0.42, alpha)


static func _ellipse(ci: RID, center: Vector2, radii: Vector2, tilt: float, alpha: float) -> void:
	var points := PackedVector2Array()
	for i in range(25):
		var a := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(tilt))
	ShapePaint.polyline(ci, points, Color(UiPalette.BRASS_INK, alpha * 0.8), 3.4, true)
	ShapePaint.polyline(ci, points, Color(UiPalette.GOLD, alpha), 1.8, true)
