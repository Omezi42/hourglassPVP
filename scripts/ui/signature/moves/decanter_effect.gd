extends SignatureMove
## デカンタの設置(GameDesign.md 9章):駒の頭上に硝子のデカンタが現れ、口からくすんだ筋が味方の駒へ伸びて
## 届いたところでくすんだ輪が縮む(払拭)。続いて味方の駒から葡萄酒の色の筋がデカンタへ吸い上げられ、胴が満ちる。

const APPEAR := 0.12
const REACH := 0.3
## デカンタの胴の中心(駒の中心から)と半径、首の長さ、筋の弧の高さ。
const VESSEL := Vector2(0.0, -100.0)
const BULB := 15.0
const NECK := 16.0
const ARC := 40.0
const TOP := 140.0


func top_extent() -> float:
	return TOP * zoom


func impact_at() -> float:
	return APPEAR + REACH


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t) * minf(phase(t, 0.0, APPEAR) * 1.5, 1.0)
	var center := from + VESSEL * zoom
	var lip := center - Vector2(0.0, (BULB + NECK) * zoom)
	var target := targets[0]
	var reach := phase(t, APPEAR, REACH)
	var back := phase(t, impact_at(), FADE)
	var fill := 0.3 + 0.6 * back
	_decanter(item, center, fill, alpha)
	if t < impact_at():
		PourPaint.stream(
			item, lip, target, ARC, ease(reach, 0.7), 0.0, alpha * 0.8, 0.8, UiPalette.DRAIN_TRAIL
		)
		return
	SignaturePaint.drain_ring(item, target, back, alpha)
	PourPaint.stream(
		item, target, lip, ARC, ease(back, 0.6), back * back, alpha, 0.9, UiPalette.WINE
	)


## 硝子のデカンタ。平たい丸い胴に細い首と菱形の栓、胴の下を `fill` まで葡萄酒が満たす。
func _decanter(item: CanvasItem, center: Vector2, fill: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var r := BULB * zoom
	var neck_top := center - Vector2(0.0, (BULB + NECK) * zoom)
	item.draw_line(center, neck_top, Color(UiPalette.INK_950, alpha), 9.0 * zoom, true)
	item.draw_line(center, neck_top, Color(UiPalette.CRYSTAL, alpha * 0.9), 6.0 * zoom, true)
	ShapePaint.circle(ci, center, r + 2.0, Color(UiPalette.INK_950, alpha))
	ShapePaint.circle(ci, center, r, Color(UiPalette.CRYSTAL, alpha * 0.55))
	var level := center.y + r - 2.0 * r * fill
	var wine := PackedVector2Array()
	for i in range(17):
		var a := TAU * float(i) / 16.0
		var p := center + Vector2(cos(a), sin(a)) * (r - 1.5)
		wine.append(Vector2(p.x, maxf(p.y, level)))
	ShapePaint.convex_polygon(ci, wine, Color(UiPalette.WINE, alpha))
	ShapePaint.circle(
		ci, center + Vector2(-r * 0.45, -r * 0.4), r * 0.22, Color(UiPalette.IVORY, alpha * 0.6)
	)
	var stopper := neck_top - Vector2(0.0, 5.0 * zoom)
	var diamond := PackedVector2Array(
		[
			stopper + Vector2(0.0, -6.0) * zoom,
			stopper + Vector2(5.0, 0.0) * zoom,
			stopper + Vector2(0.0, 6.0) * zoom,
			stopper + Vector2(-5.0, 0.0) * zoom,
		]
	)
	ShapePaint.convex_polygon(ci, diamond, Color(UiPalette.CRYSTAL, alpha))
