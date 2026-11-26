extends SignatureMove
## ヴィジョンの設置(GameDesign.md 9章):駒の頭上に銀の瞼の大きな目が上下から開き、星を散らした藍の瞳が一度めぐる。
## 瞳から銀の光芒が相手の駒それぞれへ走り、届いた駒が砕ける(打撃。盤面を揺らす)。

const OPEN := 0.2
const GAZE := 0.14
const BEAM := 0.2
## 目の位置(駒の中心から)と半幅・半分の高さ、瞳の半径、瞳の星の数、光芒の太さ。
const EYE := Vector2(0.0, -76.0)
const HALF := Vector2(30.0, 13.0)
const IRIS := 10.0
const SPECKS := 6
const RAY := 3.2
const LID_STEPS := 16


func top_extent() -> float:
	return (-EYE.y + HALF.y + 4.0) * zoom


func impact_at() -> float:
	return OPEN + GAZE + BEAM


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var center := from + EYE * zoom
	var open := ease(phase(t, 0.0, OPEN), 0.5)
	var half := HALF * zoom * Vector2(1.0, open)
	var lids := _almond(center, half)
	ShapePaint.radial_glow(ci, center, HALF * zoom * 2.2, Color(UiPalette.CHART_LAPIS, alpha * 0.7))
	if open > 0.05:
		ShapePaint.convex_polygon(ci, lids, Color(UiPalette.STAR_CHART, alpha))
		var iris := IRIS * zoom * minf(open * 1.4, 1.0)
		ShapePaint.circle(ci, center, iris, Color(UiPalette.CHART_LAPIS, alpha))
		var turn := phase(t, OPEN, GAZE) * TAU
		for i in range(SPECKS):
			var spot := Vector2.from_angle(turn + TAU * float(i) / float(SPECKS)) * iris * 0.62
			ShapePaint.circle(ci, center + spot, 1.1 * zoom, Color(UiPalette.STAR_CHART, alpha))
		ShapePaint.circle(ci, center, iris * 0.32, Color(SignaturePaint.SPARK_HOT, alpha))
	var rim := lids.duplicate()
	rim.append(lids[0])
	ShapePaint.polyline(ci, rim, Color(UiPalette.INK_950, alpha * 0.85), 4.0, true)
	ShapePaint.polyline(ci, rim, Color(UiPalette.STEEL, alpha), 2.2, true)
	var beam := phase(t, OPEN + GAZE, BEAM)
	var land := phase(t, impact_at(), FADE)
	for target in targets:
		if beam > 0.0 and land < 1.0:
			var head := center.lerp(target, ease(beam, 0.6))
			var beam_alpha := alpha * (1.0 - land)
			item.draw_line(
				center, head, Color(UiPalette.NEXT_STAR, beam_alpha * 0.5), RAY * 2.4, true
			)
			item.draw_line(center, head, Color(UiPalette.STAR_CHART, beam_alpha), RAY, true)
			ForesightPaint.next_star(item, head, 0.6, beam_alpha, beam * 4.0)
		SignaturePaint.sparks(item, target, land, alpha)


static func _almond(center: Vector2, half: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(LID_STEPS * 2):
		var s := float(i) / float(LID_STEPS)
		var top := i < LID_STEPS
		var k := s if top else s - 1.0
		var x := lerpf(-half.x, half.x, k) if top else lerpf(half.x, -half.x, k)
		var bulge := sin(k * PI) * half.y
		points.append(center + Vector2(x, -bulge if top else bulge))
	return points
