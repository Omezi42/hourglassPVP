extends SignatureMove
## 導火線(GameDesign.md 9章):撃った位置から麻の導火線が長く波打って味方の駒へ繰り出され、駒の足もとをひと巻きして、
## 結んだ端に火の点が灯り、金色の輪が広がる(余砂を与える恵与。火は点るが、まだ燃え進まない)。

const LAY := 0.36
const COIL := 0.14
const LOOP_STEPS := 20
## 導火線の波の振れ幅、足もとに巻く輪の大きさ、灯る火の点の大きさ。
const SWAY := 12.0
const LOOP := Vector2(22.0, 7.0)
const SPARK := 1.3


func impact_at() -> float:
	return LAY + COIL


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var laid := ease(phase(t, 0.0, LAY), 0.7)
	var coil := phase(t, LAY, COIL)
	for target in targets:
		var foot := target + Vector2(0.0, CardView.BOARD_ART_SIDE * 0.32)
		var start := foot + Vector2(-LOOP.x, 0.0)
		SignaturePaint.fuse_cord(item, from, start, laid, 0.0, alpha, SWAY)
		if coil > 0.0:
			var loop := PackedVector2Array()
			for i in range(LOOP_STEPS + 1):
				var a := PI + TAU * coil * float(i) / float(LOOP_STEPS)
				loop.append(foot + Vector2(cos(a) * LOOP.x, -sin(a) * LOOP.y))
			ShapePaint.polyline(ci, loop, Color(UiPalette.INK_950, alpha * 0.8), 5.0, true)
			ShapePaint.polyline(ci, loop, Color(UiPalette.FUSE_HEMP, alpha), 3.0, true)
		if t >= impact_at():
			SignaturePaint.fuse_spark(item, start, SPARK, alpha, t * 9.0)
		SignaturePaint.boon_ring(item, target, phase(t, impact_at(), FADE), alpha)
