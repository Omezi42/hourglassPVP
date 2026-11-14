extends SignatureMove
## 砂占いの静止(GameDesign.md 9章):離した位置に水晶玉が浮かび、中で砂が渦を巻いてから澄みきり、
## 玉がひと光りして光の輪が広がる(玉の中に札は見せない。見つかったかは手札側の合図に任せる)。

const APPEAR := 0.12
const SWIRL := 0.40
const CLEAR := 0.15
## 玉の大きさと、浮かぶ高さ(離した位置から上へ)。渦の粒の数と巻き数。
const RADIUS := 34.0
const LIFT := 44.0
const GRAINS := 14
const TURNS := 2.2
const GRAIN := 3.0
const GLASS := Color(0.86, 0.95, 1.0, 1.0)


func impact_at() -> float:
	return SWIRL + CLEAR


func draw(item: CanvasItem, t: float) -> void:
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var rise := ease(phase(t, 0.0, APPEAR), 0.5)
	var center := from - Vector2(0.0, LIFT * rise)
	var radius := RADIUS * (0.5 + 0.5 * rise)
	var a := alpha * minf(rise * 1.5, 1.0)
	var swirl := phase(t, 0.0, SWIRL)
	var clear := phase(t, SWIRL, CLEAR)
	ShapePaint.circle(ci, center, radius, Color(GLASS, a * 0.16))
	for i in range(GRAINS):
		var lane := 0.25 + 0.7 * SignaturePaint.jitter(i, 31)
		var angle := TAU * TURNS * swirl * (1.0 + lane) + TAU * float(i) / float(GRAINS)
		var squeeze := lerpf(lane, 0.12, ease(swirl, 1.6))
		var at := center + Vector2(cos(angle), sin(angle) * 0.8) * radius * 0.8 * squeeze
		var grain := a * (1.0 - clear)
		ShapePaint.circle(ci, at, GRAIN, Color(SignaturePaint.SAND, grain))
	var glow := sin(clear * PI)
	ShapePaint.circle(ci, center, radius * 0.9, Color(SignaturePaint.RECITE, a * 0.5 * glow))
	ShapePaint.arc(ci, center, radius, 0.0, TAU, 32, Color(GLASS, a * 0.9), 1.8, true)
	ShapePaint.arc(
		ci, center, radius * 0.72, PI * 1.1, PI * 1.5, 8, Color(1, 1, 1, a * 0.8), 1.6, true
	)
	SignaturePaint.pulse_ring(item, center, phase(t, impact_at(), FADE), alpha)
