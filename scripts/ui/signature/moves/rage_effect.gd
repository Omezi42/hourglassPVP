extends SignatureMove
## レイジの恵与(GameDesign.md 9章):落砂で、追い詰められていると駒の頭の後ろから赤く灼けた2本の角が
## せり上がって震え、駒の縁を赤い熱がひと回りなぞったところで金色の輪が広がる(砂がもう1粒落ちる)。

const SURGE := 0.3
const TRACE := 0.24
const RING := 0.3
## 角の根元(駒の中心から上へ・左右へ)、長さ・太さ、せり上がる量、震えの幅と速さ。
const ROOT := Vector2(18.0, 40.0)
const HORN := 40.0
const HORN_WIDTH := 11.0
const RISE := 26.0
const SHAKE := 2.2
const SHAKE_SPEED := 70.0
const HORN_STEPS := 10
## 熱がなぞる楕円の半径と太さ。
const OUTLINE := Vector2(44.0, 58.0)
const OUTLINE_WIDTH := 3.0


func impact_at() -> float:
	return SURGE + TRACE


func duration() -> float:
	return impact_at() + RING


func top_extent() -> float:
	return (ROOT.y + HORN) * zoom


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var surge := ease(phase(t, 0.0, SURGE), 0.4)
	var shake := sin(t * SHAKE_SPEED) * SHAKE * zoom * (1.0 - phase(t, SURGE, TRACE))
	var horn_alpha := alpha * minf(surge * 2.0, 1.0) * (1.0 - phase(t, impact_at(), RING))
	for side: float in [-1.0, 1.0]:
		var root := from + Vector2(side * ROOT.x + shake, -ROOT.y + RISE * (1.0 - surge)) * zoom
		_horn(ci, root, side, horn_alpha)
	SignaturePaint.ember_motes(
		item,
		from - Vector2(0.0, ROOT.y * zoom),
		phase(t, 0.0, impact_at() + FADE),
		alpha,
		60.0 * zoom,
		50.0 * zoom
	)
	var trace := phase(t, SURGE, TRACE)
	if trace > 0.0 and t < impact_at() + FADE:
		var heat_alpha := alpha * (1.0 - phase(t, impact_at(), FADE))
		var sweep := ease(trace, 0.7) * TAU
		var radius := OUTLINE * zoom
		var points := PackedVector2Array()
		const SEGMENTS := 40
		for i in range(SEGMENTS + 1):
			var a := -PI * 0.5 + sweep * float(i) / float(SEGMENTS)
			points.append(from + Vector2(cos(a) * radius.x, sin(a) * radius.y))
		ShapePaint.polyline(
			ci, points, Color(UiPalette.EMBER, heat_alpha * 0.35), OUTLINE_WIDTH * 3.0, true
		)
		ShapePaint.polyline(ci, points, Color(UiPalette.EMBER, heat_alpha), OUTLINE_WIDTH, true)
		ShapePaint.circle(
			ci, points[SEGMENTS], OUTLINE_WIDTH * 1.4, Color(SignaturePaint.SPARK_HOT, heat_alpha)
		)
	SignaturePaint.boon_ring(item, targets[0], phase(t, impact_at(), RING), alpha)


## 外へ張り出してから上へ反る角。根元は赤く灼け、先は暗い角の色。
func _horn(ci: RID, root: Vector2, side: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var colors := PackedColorArray()
	var spine := PackedVector2Array()
	for i in range(HORN_STEPS + 1):
		var s := float(i) / float(HORN_STEPS)
		var at := (
			root + Vector2(side * HORN * 0.75 * (1.0 - (1.0 - s) * (1.0 - s)), -HORN * s * s) * zoom
		)
		spine.append(at)
	for i in range(HORN_STEPS + 1):
		var s := float(i) / float(HORN_STEPS)
		var a := spine[maxi(i - 1, 0)]
		var b := spine[mini(i + 1, HORN_STEPS)]
		var normal := (b - a).normalized().orthogonal()
		var half := HORN_WIDTH * 0.5 * (1.0 - s * 0.9) * zoom
		left.append(spine[i] + normal * half)
		right.append(spine[i] - normal * half)
	right.reverse()
	var shape := left + right
	var closed := shape.duplicate()
	closed.append(shape[0])
	ShapePaint.polyline(ci, closed, Color(UiPalette.INK_950, alpha * 0.85), 2.6, true)
	for i in range(shape.size()):
		var s := absf(float(i) - float(HORN_STEPS) - 0.5) / float(HORN_STEPS + 1)
		var heat := UiPalette.HORN.darkened(0.45).lerp(UiPalette.EMBER, s * s)
		colors.append(Color(heat, alpha))
	ShapePaint.polygon(ci, shape, colors)
