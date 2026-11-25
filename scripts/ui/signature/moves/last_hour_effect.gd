extends SignatureMove
## ラストアワーの打撃(GameDesign.md 9章):1点ごとに、駒の頭上で青銅の鐘が大きく振れて鳴り、
## 鐘の口から赤い音の輪が1つ放たれて対象へ飛び、打ち当たる(打撃。盤面を揺らす)。
## 差が開くほど鐘が何度も鳴る(2回目からは短縮版)。

const SWING := 0.22
const FLIGHT := 0.26
## 鐘の支点(駒の中心から上へ)、振れの角度と回数、音の輪の大きさ(放つとき→届くとき)と弧の高さ。
const LIFT := 92.0
const SWAY := 0.5
const SWINGS := 1.5
const RING_FROM := 10.0
const RING_TO := 22.0
const ARC := 30.0
const RING_WIDTH := 3.2
const ECHOES := 2
const ECHO_LAG := 0.05


func impact_at() -> float:
	return SWING + FLIGHT


func top_extent() -> float:
	return LIFT * zoom


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var pivot := from - Vector2(0.0, LIFT * zoom)
	var swing := phase(t, 0.0, SWING + FLIGHT)
	var angle := SWAY * sin(swing * PI * SWINGS) * (1.0 - swing * 0.5)
	var bell_alpha := alpha * minf(phase(t, 0.0, SWING) * 4.0, 1.0)
	SignaturePaint.bell(item, pivot, angle, bell_alpha)
	var mouth := pivot + Vector2(0.0, SignaturePaint.BELL_HEIGHT + 6.0)
	var toll := phase(t, SWING * 0.6, SWING)
	if toll > 0.0 and toll < 1.0:
		SignaturePaint.ripple(
			item, mouth, 20.0 + 30.0 * toll, alpha * (1.0 - toll), UiPalette.EMBER
		)
	for i in range(ECHOES, -1, -1):
		var k := phase(t - ECHO_LAG * float(i), SWING, FLIGHT)
		if k <= 0.0 or k >= 1.0:
			continue
		var s := ease(k, -1.4)
		var at := mouth.lerp(targets[0], s) - Vector2(0.0, ARC * sin(s * PI))
		var radius := lerpf(RING_FROM, RING_TO, s)
		var a := alpha * (1.0 if i == 0 else 0.35 / float(i))
		ShapePaint.arc(
			ci, at, radius, 0.0, TAU, 28, Color(UiPalette.EMBER, a * 0.35), RING_WIDTH * 3.0, true
		)
		ShapePaint.arc(
			ci,
			at,
			radius,
			0.0,
			TAU,
			28,
			Color(SignaturePaint.SPARK_HOT.lerp(UiPalette.EMBER, s), a),
			RING_WIDTH,
			true
		)
	var burst := phase(t, impact_at(), FADE)
	if burst > 0.0 and burst < 1.0:
		var r := RING_TO * (1.0 + 1.4 * ease(burst, 0.5))
		ShapePaint.arc(
			ci,
			targets[0],
			r,
			0.0,
			TAU,
			32,
			Color(UiPalette.EMBER, alpha * (1.0 - burst)),
			RING_WIDTH,
			true
		)
