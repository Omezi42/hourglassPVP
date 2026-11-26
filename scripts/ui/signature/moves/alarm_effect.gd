extends SignatureMove
## アラームの払拭(GameDesign.md 9章):設置で、駒の頭上に二つの鐘を背負った赤い目覚まし時計が現れて激しく震え、
## 鳴り続ける音の輪がくすんだ色で相手の駒それぞれへ飛び、届いた駒でくすんだ輪が縮む(寝過ごした駒から攻撃力が抜ける)。

const RATTLE := 0.32
const FLY := 0.24
## 時計の位置(駒の中心から上へ)・半径、鐘の半径と位置、震えの幅と速さ、鳴る輪の広がりと飛ぶ輪の大きさ。
const LIFT := 56.0
const RADIUS := 17.0
const BELL := 8.5
const BELL_AT := Vector2(12.0, -16.0)
const JITTER := 2.6
const RATE := 70.0
const RING_REACH := 30.0
const FLIGHT_RADIUS := 16.0


func impact_at() -> float:
	return RATTLE + FLY


func top_extent() -> float:
	return (LIFT + RADIUS + BELL * 2.0) * zoom


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var center := from - Vector2(0.0, LIFT * zoom)
	var rattle := phase(t, 0.0, RATTLE + FLY * 0.5)
	var clock_alpha := alpha * minf(rattle * 6.0, 1.0) * (1.0 - phase(t, impact_at(), FADE))
	if clock_alpha > 0.0:
		var shake := (
			Vector2(sin(t * RATE), cos(t * RATE * 1.3) * 0.4) * JITTER * zoom * (1.0 - rattle)
		)
		var at := center + shake
		var r := RADIUS * zoom
		for side: float in [-1.0, 1.0]:
			var bell_at := at + Vector2(BELL_AT.x * side, BELL_AT.y) * zoom
			ShapePaint.circle(
				ci, bell_at, (BELL + 1.4) * zoom, Color(UiPalette.INK_950, clock_alpha * 0.85)
			)
			ShapePaint.circle(ci, bell_at, BELL * zoom, Color(UiPalette.TOLL_BRASS, clock_alpha))
		var hammer := at + Vector2(sin(t * RATE * 1.7) * BELL_AT.x * 0.6, BELL_AT.y - 2.0) * zoom
		item.draw_line(at, hammer, Color(UiPalette.INK_950, clock_alpha), 2.0 * zoom)
		ShapePaint.circle(ci, hammer, 2.6 * zoom, Color(UiPalette.STEEL, clock_alpha))
		ShapePaint.circle(ci, at, r + 1.6, Color(UiPalette.INK_950, clock_alpha * 0.85))
		ShapePaint.circle(ci, at, r, Color(UiPalette.SIGNAL_RED, clock_alpha))
		ShapePaint.circle(ci, at, r * 0.76, Color(SignaturePaint.DIAL_FACE, clock_alpha))
		item.draw_line(at, at + Vector2(0.0, r * 0.55), Color(UiPalette.INK_950, clock_alpha), 1.6)
		item.draw_line(at, at + Vector2(0.0, -r * 0.62), Color(UiPalette.INK_950, clock_alpha), 1.2)
		for k in range(2):
			var spread := fmod(rattle * 3.0 + 0.5 * float(k), 1.0)
			SignaturePaint.toll_arcs(
				item,
				at,
				Vector2.ZERO,
				r + RING_REACH * zoom * spread,
				clock_alpha * (1.0 - spread) * 0.7
			)
	var fly := phase(t, RATTLE, FLY)
	var land := phase(t, impact_at(), FADE)
	for target in targets:
		SignaturePaint.toll_flight(
			item, center, target, fly, FLIGHT_RADIUS, alpha, UiPalette.DRAIN_TRAIL
		)
		SignaturePaint.drain_ring(item, target, land, alpha)
