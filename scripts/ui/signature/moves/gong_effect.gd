extends SignatureMove
## ゴングの演出(GameDesign.md 9章):設置で、駒の頭上に吊られた青銅の銅鑼へ綿の撥が打ち込まれ、銅鑼が震えて
## 大きな音の輪が卓へ広がり、輪が対象それぞれへ飛ぶ(味方へは金色の輪、相手へは当たって火花。打撃は盤面を揺らす)。

const STRIKE := 0.22
const BOOM := 0.18
const FLY := 0.2
## 銅鑼の中心(駒の中心から上へ)・半径・震え、撥の長さ・太さ・頭の半径と振りかぶる角度、広がる輪と飛ぶ輪の大きさ。
const LIFT := 56.0
const RADIUS := 20.0
const SHAKE := 2.5
const MALLET := 30.0
const MALLET_WIDTH := 3.5
const MALLET_HEAD := 6.0
const WIND_UP := 1.2
const BOOM_REACH := 70.0
const FLIGHT_RADIUS := 17.0


func impact_at() -> float:
	return STRIKE + BOOM + FLY


func top_extent() -> float:
	return (LIFT + RADIUS + 6.0) * zoom


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var center := from - Vector2(0.0, LIFT * zoom)
	var hit := phase(t, STRIKE, BOOM + FLY)
	var gong_alpha := (
		alpha * minf(phase(t, 0.0, STRIKE) * 4.0, 1.0) * (1.0 - phase(t, impact_at() - 0.05, FADE))
	)
	if gong_alpha > 0.0:
		var shiver := Vector2(sin(t * 90.0) * SHAKE * (1.0 - hit), 0.0) * zoom * signf(hit)
		var at := center + shiver
		var r := RADIUS * zoom
		item.draw_line(
			at + Vector2(-r * 0.5, -r),
			center + Vector2(-r * 0.7, -r * 1.5),
			Color(UiPalette.BRASS_DEEP, gong_alpha),
			1.6
		)
		item.draw_line(
			at + Vector2(r * 0.5, -r),
			center + Vector2(r * 0.7, -r * 1.5),
			Color(UiPalette.BRASS_DEEP, gong_alpha),
			1.6
		)
		ShapePaint.circle(ci, at, r + 1.6, Color(UiPalette.INK_950, gong_alpha * 0.85))
		ShapePaint.circle(ci, at, r, Color(UiPalette.BRONZE, gong_alpha))
		ShapePaint.arc(
			ci, at, r * 0.7, 0.0, TAU, 32, Color(UiPalette.BRASS_DEEP, gong_alpha * 0.6), 1.4, true
		)
		ShapePaint.circle(ci, at, r * 0.32, Color(UiPalette.TOLL_BRASS, gong_alpha))
		if hit > 0.0:
			ShapePaint.circle(
				ci,
				at,
				r * (1.0 - hit),
				Color(SignaturePaint.SPARK_HOT, gong_alpha * (1.0 - hit) * 0.6)
			)
		var swing := ease(phase(t, 0.0, STRIKE), 2.4)
		var grip := center + Vector2(RADIUS + MALLET * 0.9, RADIUS * 0.9) * zoom
		var angle := -PI * 0.85 - WIND_UP * (1.0 - swing)
		var head := grip + Vector2.from_angle(angle) * MALLET * zoom
		var line := PackedVector2Array([grip, head])
		ShapePaint.polyline(
			ci, line, Color(UiPalette.INK_950, gong_alpha * 0.8), (MALLET_WIDTH + 2.0) * zoom, true
		)
		ShapePaint.polyline(
			ci, line, Color(UiPalette.LACQUER_RED, gong_alpha), MALLET_WIDTH * zoom, true
		)
		ShapePaint.circle(
			ci, head, (MALLET_HEAD + 1.2) * zoom, Color(UiPalette.INK_950, gong_alpha * 0.8)
		)
		ShapePaint.circle(ci, head, MALLET_HEAD * zoom, Color(UiPalette.IVORY, gong_alpha))
	var boom := phase(t, STRIKE, BOOM + FLY * 0.5)
	if boom > 0.0 and boom < 1.0:
		SignaturePaint.toll_arcs(
			item, center, Vector2.ZERO, BOOM_REACH * zoom * ease(boom, 0.4), alpha * (1.0 - boom)
		)
	var fly := phase(t, STRIKE + BOOM, FLY)
	var land := phase(t, impact_at(), FADE)
	for target in targets:
		SignaturePaint.toll_flight(item, center, target, fly, FLIGHT_RADIUS, alpha)
		if style == CardEnums.EffectVisualStyle.STRIKE:
			SignaturePaint.sparks(item, target, land, alpha)
		else:
			SignaturePaint.boon_ring(item, target, land, alpha)
