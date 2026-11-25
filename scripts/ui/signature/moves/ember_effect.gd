extends SignatureMove
## エンバーの打撃(GameDesign.md 9章):設置で、駒の頭上の灰の山の底から赤い燠が1つ掘り出されて明滅し、
## 火の粉の尾を引いて弧を描き対象へ落ち、当たった所で炎が噴き上がる(打撃。盤面を揺らし、対象が砕ける)。

const STIR := 0.26
const FLIGHT := 0.34
## 灰の山の位置(駒の中心から上へ)と大きさ、燠の大きさ、弧の高さ、尾の残像の数と遅れ。
const LIFT := 66.0
const ASH := Vector2(22.0, 8.0)
const COAL := 7.0
const ARC := 80.0
const GHOSTS := 4
const GHOST_LAG := 0.035
## 噴き上がる炎の舌の数・高さ・幅。
const TONGUES := 5
const FLARE := 46.0
const TONGUE_WIDTH := 9.0


func impact_at() -> float:
	return STIR + FLIGHT


func top_extent() -> float:
	return (LIFT + ASH.y + COAL * 3.0) * zoom


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var stir := phase(t, 0.0, STIR)
	var mound := from - Vector2(0.0, LIFT * zoom)
	var ash_alpha := alpha * minf(stir * 4.0, 1.0) * (1.0 - phase(t, STIR, FLIGHT))
	UiPaint.fill_ellipse(
		ci, mound, ASH * zoom + Vector2.ONE, Color(UiPalette.INK_950, ash_alpha * 0.8), 20
	)
	UiPaint.fill_ellipse(ci, mound, ASH * zoom, Color(UiPalette.BASALT, ash_alpha), 20)
	var coal_at := mound - Vector2(0.0, COAL * 1.4 * zoom * ease(stir, 0.5))
	var pulse := 0.5 + 0.5 * sin(stir * PI * 3.0)
	if t < STIR:
		_coal(ci, coal_at, COAL * zoom, pulse, alpha * minf(stir * 3.0, 1.0))
		SignaturePaint.ember_motes(item, mound, stir, alpha, 26.0 * zoom, 26.0 * zoom)
	for i in range(GHOSTS, -1, -1):
		var k := phase(t - GHOST_LAG * float(i), STIR, FLIGHT)
		if k <= 0.0 or k >= 1.0:
			continue
		var s := ease(k, -1.6)
		var at := coal_at.lerp(targets[0], s) - Vector2(0.0, ARC * sin(s * PI))
		var size := COAL * zoom * (1.0 - float(i) * 0.18)
		_coal(ci, at, size, 1.0, alpha * (1.0 if i == 0 else 0.4 / float(i)))
	var flare := phase(t, impact_at(), FADE)
	if flare > 0.0 and flare < 1.0:
		for i in range(TONGUES):
			var x := (float(i) - float(TONGUES - 1) * 0.5) * TONGUE_WIDTH * 0.9
			var h := (
				FLARE
				* (0.6 + 0.4 * SignaturePaint.jitter(i, 311))
				* sin(minf(flare * 1.6, 1.0) * PI * 0.5)
			)
			var base := targets[0] + Vector2(x, 8.0)
			var tongue := PackedVector2Array(
				[
					base + Vector2(-TONGUE_WIDTH * 0.5, 0.0),
					base + Vector2(0.0, -h),
					base + Vector2(TONGUE_WIDTH * 0.5, 0.0),
				]
			)
			var tongue_alpha := alpha * (1.0 - flare)
			ShapePaint.polygon(
				ci,
				tongue,
				PackedColorArray(
					[
						Color(UiPalette.EMBER_DEEP, tongue_alpha),
						Color(SignaturePaint.SPARK_HOT, tongue_alpha),
						Color(UiPalette.EMBER, tongue_alpha)
					]
				)
			)
		SignaturePaint.sparks(item, targets[0], flare, alpha)


## 赤く灼けた燠。`heat` が高いほど芯が白む。
func _coal(ci: RID, at: Vector2, radius: float, heat: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	ShapePaint.circle(ci, at, radius * 2.4, Color(UiPalette.EMBER, alpha * 0.25))
	ShapePaint.circle(ci, at, radius + 1.2, Color(UiPalette.INK_950, alpha * 0.7))
	ShapePaint.circle(ci, at, radius, Color(UiPalette.EMBER_DEEP, alpha))
	ShapePaint.circle(
		ci, at, radius * 0.62, Color(UiPalette.EMBER.lerp(SignaturePaint.SPARK_HOT, heat), alpha)
	)
