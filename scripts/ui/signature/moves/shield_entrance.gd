extends SignatureMove
## シールドの登場(GameDesign.md 9章):駒の前に円い盾の輪郭がせり上がり、縁を光が一周してから
## 薄れる(守護=先に殴らせる印)。

const RISE := 0.24
const ORBIT := 0.32
## 盾の中心(台座の上面から上へ)と半径、せり上がる距離、縁を回る光の尾の長さ(ラジアン)。
const LIFT := 52.0
const RADIUS := 34.0
const CLIMB := 36.0
const TAIL := 1.4
const BOSS := 6.0
const FACE := Color(0.82, 0.88, 0.96, 1.0)


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + RISE + ORBIT + FADE


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var rise := back_out(phase(t, impact_at(), RISE))
	var center := from - Vector2(0.0, LIFT - CLIMB * (1.0 - rise))
	var a := alpha * minf(rise * 2.0, 1.0)
	ShapePaint.circle(ci, center, RADIUS, Color(FACE, a * 0.22))
	ShapePaint.arc(
		ci, center, RADIUS, 0.0, TAU, 48, Color(UiPalette.OUTLINE_DARK, a * 0.6), 4.4, true
	)
	ShapePaint.arc(ci, center, RADIUS, 0.0, TAU, 48, Color(UiPalette.BRASS_HIGHLIGHT, a), 2.6, true)
	ShapePaint.arc(
		ci, center, RADIUS * 0.62, 0.0, TAU, 36, Color(UiPalette.BRASS_LIGHT, a * 0.6), 1.4, true
	)
	ShapePaint.circle(ci, center, BOSS, Color(UiPalette.BRASS_HIGHLIGHT, a))
	var orbit := phase(t, impact_at() + RISE, ORBIT)
	if orbit <= 0.0 or orbit >= 1.0:
		return
	var head := -PI * 0.5 + TAU * ease(orbit, 0.8)
	ShapePaint.arc(
		ci,
		center,
		RADIUS,
		head - TAIL * sin(orbit * PI),
		head,
		16,
		Color(1, 1, 1, alpha),
		3.2,
		true
	)
	ShapePaint.circle(ci, center + Vector2.from_angle(head) * RADIUS, 3.4, Color(1, 1, 1, alpha))
