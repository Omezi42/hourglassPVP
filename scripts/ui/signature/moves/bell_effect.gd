extends SignatureMove
## ベルの恵与(GameDesign.md 9章):設置で、駒の頭上に木の柄の手振りの鈴が現れて左右に2度振られ、
## 振るたびに音の輪が広がり、2度目の音の輪が対象へ飛んで、届いたところで金色の輪が広がる
## (最大マナを1つ進め、味方の砂を1粒落とす)。

const RING := 0.36
const FLY := 0.26
## 鈴の吊り点(駒の中心から上へ)、振れ幅、柄の長さと太さ・握りの玉、音の輪の広がり、飛ぶ輪の大きさ。
const LIFT := 58.0
const SWING := 0.5
const HANDLE := 12.0
const HANDLE_WIDTH := 4.0
const KNOB := 4.5
const RING_REACH := 46.0
const FLIGHT_RADIUS := 17.0


func impact_at() -> float:
	return RING + FLY


func top_extent() -> float:
	return (LIFT + HANDLE + KNOB) * zoom


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var pivot := from - Vector2(0.0, LIFT * zoom)
	var ring := phase(t, 0.0, RING)
	var bell_alpha := alpha * minf(ring * 5.0, 1.0) * (1.0 - phase(t, RING + FLY * 0.5, FADE))
	if bell_alpha > 0.0:
		var swing := sin(ring * TAU * 2.0) * SWING * (1.0 - ring * 0.5)
		var grip := pivot + Vector2(0.0, -HANDLE * zoom).rotated(swing)
		item.draw_line(pivot, grip, Color(UiPalette.BRASS_DEEP, bell_alpha), HANDLE_WIDTH * zoom)
		ShapePaint.circle(
			item.get_canvas_item(), grip, KNOB * zoom, Color(UiPalette.BRASS_DEEP, bell_alpha)
		)
		SignaturePaint.bell(item, pivot, swing, bell_alpha)
	for k in range(2):
		var spread := phase(t, RING * (0.25 + 0.5 * float(k)), RING * 0.5)
		if spread > 0.0 and spread < 1.0:
			var center := pivot + Vector2(0.0, SignaturePaint.BELL_HEIGHT * 0.6)
			SignaturePaint.toll_arcs(
				item,
				center,
				Vector2.ZERO,
				RING_REACH * zoom * ease(spread, 0.5),
				alpha * (1.0 - spread)
			)
	var fly := phase(t, RING, FLY)
	for target in targets:
		SignaturePaint.toll_flight(item, pivot, target, fly, FLIGHT_RADIUS, alpha)
		SignaturePaint.boon_ring(item, target, phase(t, impact_at(), FADE), alpha)
