extends SignatureMove
## フレアの演出(GameDesign.md 9章):設置で、駒から信号弾が煙の弧を引いて高く昇り、頭上で白く弾けて、
## 夜明けの色の光が駆ける火の筋になって対象へ降りそそぐ(HPを払う打撃では自分のHPの器へ、疾走を与える恵与では味方の駒それぞれへ)。

const RISE := 0.26
const POP := 0.1
const FALL := 0.26
## 昇る高さ、弧の横へのふくらみ、煙の太さ・尾の長さ、弾けた光の大きさ、降る火の筋の長さと太さ。
const APEX := 70.0
const DRIFT := 18.0
const SMOKE_WIDTH := 4.0
const TRAIL_STEPS := 10
const FLASH := 26.0
const RAYS := 8
const COMET := 30.0
const COMET_WIDTH := 9.0


func impact_at() -> float:
	return RISE + POP + FALL


func top_extent() -> float:
	return (APEX + FLASH) * zoom


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var apex := from + Vector2(DRIFT, -APEX) * zoom
	var rise := ease(phase(t, 0.0, RISE), 0.5)
	var smoke_alpha := alpha * (1.0 - phase(t, RISE, POP + FALL))
	if smoke_alpha > 0.0:
		var points := PackedVector2Array()
		for i in range(TRAIL_STEPS + 1):
			var s := rise * float(i) / float(TRAIL_STEPS)
			points.append(from + Vector2(DRIFT * s * s, -APEX * s) * zoom)
		ShapePaint.polyline(
			ci, points, Color(UiPalette.WIND, smoke_alpha * 0.8), SMOKE_WIDTH * zoom, true
		)
		if t < RISE:
			ShapePaint.circle(
				ci, points[TRAIL_STEPS], 4.0 * zoom, Color(SignaturePaint.SPARK_HOT, alpha)
			)
			ShapePaint.circle(
				ci, points[TRAIL_STEPS], 7.0 * zoom, Color(UiPalette.SIGNAL_RED, alpha * 0.5)
			)
	var pop := phase(t, RISE, POP + FALL)
	if pop > 0.0 and pop < 1.0:
		var r := FLASH * zoom * ease(minf(pop * 3.0, 1.0), 0.4)
		var pa := alpha * (1.0 - pop)
		ShapePaint.circle(ci, apex, r, Color(UiPalette.DAWN, pa * 0.35))
		ShapePaint.circle(ci, apex, r * 0.4, Color(SignaturePaint.SPARK_HOT, pa))
		for i in range(RAYS):
			var dir := Vector2.from_angle(TAU * float(i) / float(RAYS))
			ShapePaint.polyline(
				ci,
				PackedVector2Array([apex + dir * r * 0.5, apex + dir * r * 1.3]),
				Color(UiPalette.DAWN, pa),
				2.0,
				true
			)
	var fall := phase(t, RISE + POP, FALL)
	if fall > 0.0 and fall < 1.0:
		var k := ease(fall, 1.6)
		for target in targets:
			SignaturePaint.blaze_comet(
				item, apex.lerp(target, k), target - apex, COMET * zoom, COMET_WIDTH * zoom, alpha
			)
	var land := phase(t, impact_at(), FADE)
	for target in targets:
		if style == CardEnums.EffectVisualStyle.STRIKE:
			SignaturePaint.sparks(item, target, land, alpha)
		else:
			SignaturePaint.boon_ring(item, target, land, alpha)
