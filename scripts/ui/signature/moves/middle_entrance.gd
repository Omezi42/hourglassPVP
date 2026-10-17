extends SignatureMove
## ミドルの登場(GameDesign.md 9章):着地した台座の縁に紫の砂粒が5つ灯り、輪を描いて回りながら
## 駒の中心へ吸い込まれ、駒が一度紫に脈打つ(総量が5の間、毒砂を持つ印)。

const LIGHT := 0.22
const SWIRL := 0.42
const PULSE := 0.24
const GRAINS := 5
## 粒が灯る輪(台座の上面の中心から見た半径)と、吸い込まれるまでに回る量。
const RING := Vector2(50.0, 13.0)
const TURN := PI * 1.2
const GRAIN_RADIUS := 4.5
const PULSE_RADIUS := 46.0


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + LIGHT + SWIRL + PULSE


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var violet := CardUnitFx.POISON_VIOLET
	var core := from - Vector2(0.0, CardView.BOARD_ART_SIDE * 0.5)
	var swirl := ease(phase(t, impact_at() + LIGHT, SWIRL), 2.2)
	if swirl < 1.0:
		for i in range(GRAINS):
			var light := phase(t, impact_at() + LIGHT * float(i) / float(GRAINS), LIGHT * 0.4)
			if light <= 0.0:
				continue
			var angle := TAU * float(i) / float(GRAINS) + PI * 0.5 + TURN * swirl
			var on_ring := from + Vector2(cos(angle) * RING.x, sin(angle) * RING.y)
			var at := on_ring.lerp(core, swirl)
			var size := GRAIN_RADIUS * light * (1.0 - swirl * 0.5)
			if size < 0.5:
				continue
			UiPaint.fill_circle(ci, at, size * 2.2, Color(violet, alpha * 0.25), 12)
			UiPaint.fill_circle(ci, at, size, Color(violet.lightened(0.35), alpha), 10)
	var pulse := phase(t, impact_at() + LIGHT + SWIRL, PULSE)
	if pulse > 0.02:
		var radius := PULSE_RADIUS * ease(pulse, 0.4)
		UiPaint.fill_circle(ci, core, radius, Color(violet, alpha * 0.28 * (1.0 - pulse)), 32)
		ShapePaint.arc(
			item.get_canvas_item(),
			core,
			radius,
			0.0,
			TAU,
			40,
			Color(violet, alpha * (1.0 - pulse)),
			2.2,
			true
		)
