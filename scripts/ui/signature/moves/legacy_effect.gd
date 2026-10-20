extends SignatureMove
## レガシーの余砂(GameDesign.md 9章):銘板の上に古い巻物が広がり、金色の光の筋が味方の駒それぞれへ
## 伸びて、届いた駒から金色の輪が広がる(恵与)。

const UNROLL := 0.22
const BEAM := 0.3
const RING := 0.32
## 巻物の置き場所(銘板から上へ)と、広がりきった半幅・高さ、両端の芯の太さ、光の筋の弧の高さ。
const LIFT := 30.0
const HALF := 22.0
const HEIGHT := 14.0
const ROD := 3.0
const ARC := 36.0
const BEAM_POINTS := 14
const PAPER := Color(0.94, 0.88, 0.72, 1.0)


func impact_at() -> float:
	return UNROLL + BEAM


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var center := from - Vector2(0.0, LIFT)
	var unroll := back_out(phase(t, 0.0, UNROLL))
	var half := maxf(HALF * unroll, ROD)
	var a := alpha * minf(phase(t, 0.0, UNROLL) * 4.0, 1.0)
	item.draw_rect(
		Rect2(center - Vector2(half, HEIGHT * 0.5), Vector2(half * 2.0, HEIGHT)), Color(PAPER, a)
	)
	for k in range(3):
		var y := center.y - HEIGHT * 0.25 + float(k) * HEIGHT * 0.25
		var w := half * 0.7
		item.draw_line(
			Vector2(center.x - w, y),
			Vector2(center.x + w, y),
			Color(UiPalette.BRASS_DARK, a * 0.6),
			1.0
		)
	for side: float in [-1.0, 1.0]:
		var x := center.x + side * half
		item.draw_line(
			Vector2(x, center.y - HEIGHT * 0.65),
			Vector2(x, center.y + HEIGHT * 0.65),
			Color(UiPalette.WOOD_TOP, a),
			ROD * 2.0,
			true
		)
	var beam := ease(phase(t, UNROLL, BEAM), 1.2)
	var fade := 1.0 - phase(t, impact_at(), RING * 0.6)
	if beam > 0.0 and fade > 0.0:
		for target: Vector2 in targets:
			var points := PackedVector2Array()
			for i in range(BEAM_POINTS + 1):
				var s := beam * float(i) / float(BEAM_POINTS)
				points.append(center.lerp(target, s) - Vector2(0.0, ARC * sin(s * PI)))
			ShapePaint.polyline(
				ci, points, Color(SignaturePaint.BOON, alpha * 0.35 * fade), 5.0, true
			)
			ShapePaint.polyline(ci, points, Color(SignaturePaint.BOON, alpha * fade), 1.8, true)
	for target: Vector2 in targets:
		SignaturePaint.boon_ring(item, target, phase(t, impact_at(), RING), alpha)
