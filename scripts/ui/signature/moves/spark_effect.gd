extends SignatureMove
## スパークの恵与(GameDesign.md 9章):攻撃のたびに、駒の頭上で鋼の火打金が振り下ろされて火打石を打ち、
## 火花が散って、駆ける火の筋になって駒へ飛び込み、金色の輪が広がる(砂が1粒落ちる)。

const SWING := 0.2
const SCATTER := 0.3
## 打点の位置(駒の中心から上へ)、火打金の長さ・太さ・振りかぶる角度、火打石の大きさ。
const LIFT := 52.0
const STEEL_LENGTH := 30.0
const STEEL_WIDTH := 6.0
const WIND_UP := 1.1
const FLINT := Vector2(9.0, 7.0)
## 駒へ飛び込む火の筋の数・長さ・太さ。
const DIVES := 3
const COMET := 22.0
const COMET_WIDTH := 6.0


func impact_at() -> float:
	return SWING


func duration() -> float:
	return impact_at() + SCATTER + FADE


func top_extent() -> float:
	return (LIFT + STEEL_LENGTH) * zoom


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var strike := from - Vector2(0.0, LIFT * zoom)
	var swing := ease(phase(t, 0.0, SWING), 2.2)
	var tool_alpha := (
		alpha * minf(phase(t, 0.0, SWING) * 4.0, 1.0) * (1.0 - phase(t, impact_at() + 0.1, FADE))
	)
	if tool_alpha > 0.0:
		var flint_at := strike + Vector2(FLINT.x, 0.0) * zoom
		var flint := PackedVector2Array(
			[
				flint_at + Vector2(-FLINT.x, 0.0) * zoom,
				flint_at + Vector2(0.0, -FLINT.y) * zoom,
				flint_at + Vector2(FLINT.x, -FLINT.y * 0.2) * zoom,
				flint_at + Vector2(FLINT.x * 0.4, FLINT.y) * zoom,
			]
		)
		ShapePaint.convex_polygon(ci, flint, Color(UiPalette.FLINT, tool_alpha))
		var angle := -WIND_UP * (1.0 - swing)
		var pivot := strike + Vector2(-STEEL_LENGTH * 0.9, -4.0) * zoom
		var tip := pivot + Vector2.from_angle(angle) * STEEL_LENGTH * zoom
		var line := PackedVector2Array([pivot, tip])
		ShapePaint.polyline(
			ci, line, Color(UiPalette.INK_950, tool_alpha * 0.85), (STEEL_WIDTH + 2.4) * zoom, true
		)
		ShapePaint.polyline(ci, line, Color(UiPalette.STEEL, tool_alpha), STEEL_WIDTH * zoom, true)
	var scatter := phase(t, impact_at(), SCATTER)
	if scatter > 0.0 and scatter < 1.0:
		ShapePaint.circle(
			ci,
			strike,
			10.0 * zoom * (1.0 - scatter),
			Color(SignaturePaint.SPARK_HOT, alpha * (1.0 - scatter))
		)
		SignaturePaint.sparks(item, strike, scatter, alpha)
		for i in range(DIVES):
			var start := strike + Vector2((float(i) - 1.0) * 16.0, -6.0) * zoom
			var k := ease(scatter, 1.8)
			var head := start.lerp(targets[0], k)
			SignaturePaint.blaze_comet(
				item,
				head,
				targets[0] - start,
				COMET * zoom,
				COMET_WIDTH * zoom,
				alpha * (1.0 - k * 0.6)
			)
	SignaturePaint.boon_ring(
		item, targets[0], phase(t, impact_at() + SCATTER * 0.8, FADE + 0.1), alpha
	)
