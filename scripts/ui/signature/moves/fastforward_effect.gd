extends SignatureMove
## 早回しの恵与(GameDesign.md 9章):撃った位置に時計の文字盤が現れ、長針が指で押されたように2周早回りし、
## 回りきったところで鳴った音の輪が対象へ飛んで、届いたところで金色の輪が広がる
## (味方の砂を2粒落とし、今の手番のマナを1つ足す)。

const SPIN := 0.36
const FLY := 0.24
## 文字盤の半径、回す周回、残像の弧の長さ・太さ、飛ぶ輪の大きさ。
const RADIUS := 24.0
const TURNS := 2.0
const BLUR := 1.4
const BLUR_WIDTH := 3.0
const FLIGHT_RADIUS := 16.0


func impact_at() -> float:
	return SPIN + FLY


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var spin := phase(t, 0.0, SPIN)
	var dial_alpha := alpha * minf(spin * 5.0, 1.0) * (1.0 - phase(t, SPIN + FLY * 0.5, FADE))
	var hand := TAU * TURNS * ease(spin, 1.8)
	SignaturePaint.clock_dial(item, from, RADIUS, hand, dial_alpha)
	if spin > 0.0 and spin < 1.0:
		var lead := hand - PI * 0.5
		ShapePaint.arc(
			ci,
			from,
			RADIUS * 0.62,
			lead - BLUR * spin,
			lead,
			16,
			Color(UiPalette.MORNING_SKY, dial_alpha * 0.8),
			BLUR_WIDTH,
			true
		)
	var chime := phase(t, SPIN * 0.9, FLY)
	if chime > 0.0 and chime < 1.0:
		SignaturePaint.toll_arcs(
			item, from, Vector2.ZERO, RADIUS + 18.0 * ease(chime, 0.5), alpha * (1.0 - chime)
		)
	var fly := phase(t, SPIN, FLY)
	for target in targets:
		SignaturePaint.toll_flight(item, from, target, fly, FLIGHT_RADIUS, alpha)
		SignaturePaint.boon_ring(item, target, phase(t, impact_at(), FADE), alpha)
