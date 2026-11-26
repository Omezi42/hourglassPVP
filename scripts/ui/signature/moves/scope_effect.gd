extends SignatureMove
## スコープの設置(GameDesign.md 9章):駒の頭上に真鍮の望遠鏡が現れて右上の空へ筒を3段に伸ばし、
## 覗いた先へ銀の星図の線が星を2つ結んで伸び、いちばん先の星が瞬いたところで光の輪が広がる(静止)。

const APPEAR := 0.1
const EXTEND := 0.26
const SIGHT := 0.3
## 筒の付け根(駒の中心から)・向き・伸びきった長さ、3段の太さ、覗いた先の星(筒先から)。
const MOUNT := Vector2(-20.0, -54.0)
const AIM := -0.55
const REACH := 46.0
const WIDTHS: Array[float] = [11.0, 9.0, 7.0]
const STARS: Array[Vector2] = [Vector2(24.0, -6.0), Vector2(44.0, -24.0)]
## 演出の最上端(駒の中心から。いちばん先の星の光芒まで)。
const TOP := 120.0


func top_extent() -> float:
	return TOP * zoom


func impact_at() -> float:
	return APPEAR + EXTEND + SIGHT


func draw(item: CanvasItem, t: float) -> void:
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t) * minf(phase(t, 0.0, APPEAR) * 1.5, 1.0)
	var base := from + MOUNT * zoom
	var dir := Vector2.from_angle(AIM)
	var out := ease(phase(t, APPEAR, EXTEND), 0.5)
	var steps := WIDTHS.size()
	var section := REACH * zoom / float(steps)
	var tip := base
	for i in range(steps):
		var grow := clampf(out * float(steps) - float(i), 0.0, 1.0)
		var start := base + dir * section * float(i) * 0.92
		var end := start + dir * section * maxf(grow, 0.35 if i == 0 else 0.0)
		if end == start:
			continue
		var w := WIDTHS[i] * zoom
		item.draw_line(start, end, Color(UiPalette.BRASS_INK, alpha), w + 3.0, true)
		item.draw_line(start, end, Color(UiPalette.TOLL_BRASS, alpha), w, true)
		item.draw_line(
			start - dir.orthogonal() * w * 0.22,
			end - dir.orthogonal() * w * 0.22,
			Color(UiPalette.GOLD_HI, alpha * 0.8),
			w * 0.25,
			true
		)
		ShapePaint.circle(ci, start, w * 0.62, Color(UiPalette.BRASS, alpha))
		tip = end
	for side: float in [-1.0, 0.0, 1.0]:
		item.draw_line(
			base,
			base + Vector2(side * 12.0, 20.0) * zoom,
			Color(UiPalette.WOOD_TOP, alpha),
			2.4,
			true
		)
	ShapePaint.circle(ci, tip, WIDTHS[steps - 1] * zoom * 0.5, Color(UiPalette.MORNING_SKY, alpha))
	var points := PackedVector2Array([tip])
	for offset in STARS:
		points.append(tip + offset * zoom)
	var sight := phase(t, APPEAR + EXTEND, SIGHT)
	ForesightPaint.star_chart(item, points, sight, alpha, zoom)
	if t >= impact_at():
		var lit := phase(t, impact_at(), FADE)
		ForesightPaint.next_star(
			item, points[points.size() - 1], zoom * (1.0 + 0.5 * lit), alpha, lit
		)
		SignaturePaint.pulse_ring(item, from, lit, alpha)
