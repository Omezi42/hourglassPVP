extends SignatureMove
## シャフトの設置(GameDesign.md 9章):駒の頭上に竪坑櫓の滑車が現れて回り、綱に吊られた札が3枚、1枚ずつ駒の足元の
## 暗い坑口へ沈む。沈むたびに脇の星図に銀の星が1つ灯って線でつながり、3つ目で先の星が瞬いて光の輪が広がる(静止)。

const APPEAR := 0.1
const GAP := 0.17
const SINK := 0.26
const CARDS := 3
## 滑車の高さ(駒の中心から)と半径、坑口の深さと半径、吊られた札の高さ、星図の星の並び(駒の中心から)。
const LIFT := 74.0
const SHEAVE := 11.0
const PIT := 50.0
const PIT_RADII := Vector2(22.0, 6.0)
const CARD := 20.0
const CHART: Array[Vector2] = [
	Vector2(40.0, 22.0), Vector2(52.0, -6.0), Vector2(46.0, -34.0), Vector2(60.0, -58.0)
]


func top_extent() -> float:
	return (LIFT + SHEAVE + 4.0) * zoom


func impact_at() -> float:
	return APPEAR + GAP * float(CARDS - 1) + SINK


func draw(item: CanvasItem, t: float) -> void:
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t) * minf(phase(t, 0.0, APPEAR) * 1.5, 1.0)
	var wheel := from - Vector2(0.0, LIFT * zoom)
	var pit := from + Vector2(0.0, PIT * zoom)
	_pit(ci, pit, alpha)
	var sunk := 0
	for i in range(CARDS):
		var sink := phase(t, APPEAR + GAP * float(i), SINK)
		if sink >= 1.0:
			sunk += 1
			continue
		if sink <= 0.0:
			continue
		var at := wheel.lerp(pit, ease(sink, 1.6))
		item.draw_line(wheel, at, Color(UiPalette.FUSE_HEMP, alpha * 0.9), 1.6, true)
		var fade := 1.0 - phase(sink, 0.8, 0.2)
		ForesightPaint.tarot(item, at, CARD * zoom, 0.0, 0.0, alpha * fade)
	_sheave(item, wheel, t, alpha)
	var points := PackedVector2Array()
	for offset in CHART:
		points.append(from + offset * zoom)
	var drawn := float(sunk) / float(CARDS)
	ForesightPaint.star_chart(item, points, drawn, alpha, zoom)
	if t >= impact_at():
		var lit := phase(t, impact_at(), FADE)
		ForesightPaint.next_star(item, points[CARDS], zoom * (1.0 + 0.4 * lit), alpha, lit)
		SignaturePaint.pulse_ring(item, from, lit, alpha)


func _pit(ci: RID, at: Vector2, alpha: float) -> void:
	var radii := PIT_RADII * zoom
	ShapePaint.convex_polygon(
		ci, _ellipse(at, radii + Vector2(3.0, 2.0)), Color(UiPalette.MINE_RUST, alpha)
	)
	ShapePaint.convex_polygon(ci, _ellipse(at, radii), Color(UiPalette.INK_950, alpha))


static func _ellipse(at: Vector2, radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(20):
		var a := TAU * float(i) / 20.0
		points.append(at + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return points


func _sheave(item: CanvasItem, at: Vector2, t: float, alpha: float) -> void:
	var ci := item.get_canvas_item()
	var r := SHEAVE * zoom
	for side: float in [-1.0, 1.0]:
		item.draw_line(
			at, at + Vector2(side * r * 1.8, r * 2.2), Color(UiPalette.MINE_RUST, alpha), 3.0, true
		)
	ShapePaint.arc(ci, at, r, 0.0, TAU, 24, Color(UiPalette.INK_950, alpha * 0.8), 4.5, true)
	ShapePaint.arc(ci, at, r, 0.0, TAU, 24, Color(UiPalette.GOLD, alpha), 2.6, true)
	for i in range(3):
		var dir := Vector2.from_angle(t * 9.0 + TAU * float(i) / 6.0)
		item.draw_line(at - dir * r, at + dir * r, Color(UiPalette.GOLD, alpha), 1.6, true)
	ShapePaint.circle(ci, at, 2.4 * zoom, Color(UiPalette.BRASS_DEEP, alpha))
