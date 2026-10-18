extends SignatureMove
## アワーの落砂(GameDesign.md 9章):駒の上に時計の文字盤が現れて長針が時計回りに1周し、12時を
## 指した瞬間に文字盤から光の玉が相手のHPの器へ飛ぶ(打撃)。

const APPEAR := 0.12
const TURN := 0.4
const FLIGHT := 0.24
## 文字盤の置き場所(駒の中心から上へ)と半径、光の玉の大きさと尾の点の数。
const LIFT := 68.0
const RADIUS := 18.0
const ORB := 5.0
const TRAIL := 6
const LIGHT := Color(1.0, 0.94, 0.7, 1.0)


func impact_at() -> float:
	return APPEAR + TURN + FLIGHT


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var appear := ease(phase(t, 0.0, APPEAR), 0.5)
	var dial := from - Vector2(0.0, LIFT)
	var hand := TAU * ease(phase(t, APPEAR, TURN), 1.4)
	SignaturePaint.clock_dial(item, dial, RADIUS * appear, hand, alpha * appear)
	var flight := phase(t, APPEAR + TURN, FLIGHT)
	if flight <= 0.0 or t >= impact_at():
		return
	var start := dial - Vector2(0.0, RADIUS)
	for i in range(TRAIL, 0, -1):
		var q := maxf(ease(flight, 1.5) - 0.05 * float(i), 0.0)
		var size := ORB * 0.6 * (1.0 - float(i) / float(TRAIL + 1))
		ShapePaint.circle(ci, start.lerp(targets[0], q), size, Color(LIGHT, alpha * 0.5))
	var at := start.lerp(targets[0], ease(flight, 1.5))
	ShapePaint.circle(ci, at, ORB * 1.8, Color(LIGHT, alpha * 0.3))
	ShapePaint.circle(ci, at, ORB, Color(LIGHT, alpha))
