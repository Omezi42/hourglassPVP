extends SignatureMove
## トーチの打撃(GameDesign.md 9章):設置で、駒の頭上に松明が掲げられて炎が大きく燃え上がり、
## 火の塊が駆ける火の筋を引いて自分のHPの器へ弧を描いて落ち、当たった所で炎が立つ(HPを払う。盤面を揺らす)。

const IGNITE := 0.26
const FLIGHT := 0.3
## 松明の柄の位置(駒の中心から上へ)・長さ・太さ、炎の高さと幅、弧の高さ、火の筋の長さと太さ。
const LIFT := 46.0
const HANDLE := 26.0
const HANDLE_WIDTH := 6.0
const FLAME_HEIGHT := 30.0
const FLAME_WIDTH := 18.0
const ARC := 60.0
const COMET := 46.0
const COMET_WIDTH := 12.0
## 当たった所に立つ炎の舌の数と高さ。
const TONGUES := 3
const BURST := 30.0


func impact_at() -> float:
	return IGNITE + FLIGHT


func top_extent() -> float:
	return (LIFT + FLAME_HEIGHT) * zoom


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var ignite := phase(t, 0.0, IGNITE)
	var grip := from - Vector2(0.0, (LIFT - HANDLE) * zoom)
	var head := from - Vector2(0.0, LIFT * zoom)
	var torch_alpha := alpha * minf(ignite * 4.0, 1.0) * (1.0 - phase(t, impact_at(), FADE))
	if torch_alpha > 0.0:
		ShapePaint.polyline(
			ci,
			PackedVector2Array([grip, head]),
			Color(UiPalette.INK_950, torch_alpha * 0.85),
			(HANDLE_WIDTH + 2.4) * zoom,
			true
		)
		ShapePaint.polyline(
			ci,
			PackedVector2Array([grip, head]),
			Color(UiPalette.BIRCH, torch_alpha),
			HANDLE_WIDTH * zoom,
			true
		)
		var flicker := 1.0 + 0.12 * sin(t * 48.0)
		var grow := ease(ignite, 0.4) * (1.0 - 0.5 * phase(t, IGNITE, FLIGHT))
		for side: float in [-1.0, 0.0, 1.0]:
			SignaturePaint.flame_tongue(
				item,
				head + Vector2(side * FLAME_WIDTH * 0.35, 0.0) * zoom,
				FLAME_HEIGHT * zoom * grow * flicker * (1.0 if side == 0.0 else 0.65),
				FLAME_WIDTH * zoom * (1.0 if side == 0.0 else 0.6),
				-6.0 * zoom,
				torch_alpha
			)
	var k := phase(t, IGNITE, FLIGHT)
	if k > 0.0 and k < 1.0:
		var s := ease(k, -1.6)
		var start := head - Vector2(0.0, FLAME_HEIGHT * 0.4 * zoom)
		var at := start.lerp(targets[0], s) - Vector2(0.0, ARC * sin(s * PI))
		var ahead := (
			start.lerp(targets[0], minf(s + 0.05, 1.0))
			- Vector2(0.0, ARC * sin(minf(s + 0.05, 1.0) * PI))
		)
		SignaturePaint.blaze_comet(item, at, ahead - at, COMET, COMET_WIDTH, alpha)
	var burst := phase(t, impact_at(), FADE)
	if burst > 0.0 and burst < 1.0:
		for i in range(TONGUES):
			var x := (float(i) - float(TONGUES - 1) * 0.5) * 10.0
			SignaturePaint.flame_tongue(
				item,
				targets[0] + Vector2(x, 8.0),
				(
					BURST
					* (0.7 + 0.3 * SignaturePaint.jitter(i, 401))
					* sin(minf(burst * 1.6, 1.0) * PI * 0.5)
				),
				12.0,
				-4.0,
				alpha * (1.0 - burst)
			)
		SignaturePaint.sparks(item, targets[0], burst, alpha)
