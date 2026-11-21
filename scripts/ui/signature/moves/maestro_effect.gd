extends SignatureMove
## マエストロの合図(GameDesign.md 9章):反転トリガーが2回目に発動する直前、頭上の指揮棒が
## 返った駒へ向けてもう一度振られ、先から音符が2つ跳んで届く(「もう一度」)。

const RAISE := 0.12
const SWING := 0.18
const HOP := 0.3
## 指揮棒の握りの高さ(駒の中心から上へ)と、振りかぶる量(ラジアン)。
const LIFT := 70.0
const WIND_UP := 1.2
## 跳ぶ音符の数・大きさ・山なりの高さと、2つ目が跳びはじめる遅れ(HOP に対する割合)。
const NOTES := 2
const NOTE_SIZE := 4.5
const ARC_HEIGHT := 36.0
const NOTE_LAG := 0.3


func impact_at() -> float:
	return RAISE + SWING + HOP


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var grip := from - Vector2(0.0, LIFT * zoom)
	var aim := (targets[0] - grip).angle()
	var raise := ease(phase(t, 0.0, RAISE), 0.5)
	var swing := back_out(phase(t, RAISE, SWING))
	var angle := lerpf(aim - WIND_UP, aim, swing)
	SignaturePaint.baton(item, grip, angle, zoom, alpha * raise)
	var hop := phase(t, RAISE + SWING, HOP)
	if hop <= 0.0:
		return
	var tip := grip + Vector2.RIGHT.rotated(aim) * SignaturePaint.BATON_LENGTH * zoom
	for i in range(NOTES):
		var k := clampf((hop - NOTE_LAG * float(i)) / (1.0 - NOTE_LAG), 0.0, 1.0)
		if k <= 0.0 or k >= 1.0:
			continue
		var at := tip.lerp(targets[0], k) - Vector2(0.0, ARC_HEIGHT * zoom * sin(k * PI))
		SignaturePaint.note(item, at, NOTE_SIZE * zoom, SignaturePaint.MAESTRO, alpha)
	var landed := phase(t, impact_at(), FADE)
	if landed > 0.0:
		SignaturePaint.pulse_ring(item, targets[0], landed, alpha)
