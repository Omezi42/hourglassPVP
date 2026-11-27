extends SignatureMove
## ポンプの落砂(GameDesign.md 9章):駒の頭上に赤い鋳鉄の手押しポンプが現れ、足元から銅の吸い管がいちばん攻撃力の高い相手の駒へ伸びる。
## 柄を2度こぐたびに他人の色の滴が管を登ってポンプの胴へ吸い込まれ、相手の駒に縮む渦が残って、吐き口から一滴こぼれる(払拭)。

const APPEAR := 0.1
const REACH := 0.18
const STROKES := 2
const STROKE := 0.17
## ポンプの胴の中心(駒の中心から)と半寸法、柄の支点(胴の中心から)・長さ・振れ幅、吐き口、吸い管の弧の高さ。
const BODY := Vector2(0.0, -92.0)
const BODY_HALF := Vector2(10.0, 20.0)
const PIVOT := Vector2(-4.0, -20.0)
const LEVER := 42.0
const SWING := 0.5
const SPOUT := Vector2(22.0, -8.0)
const ARC := 40.0
const TOP := 130.0


func top_extent() -> float:
	return TOP * zoom


func impact_at() -> float:
	return APPEAR + REACH + STROKE * float(STROKES)


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t) * minf(phase(t, 0.0, APPEAR) * 1.5, 1.0)
	var center := from + BODY * zoom
	var foot := center + Vector2(0.0, BODY_HALF.y) * zoom
	var target := targets[0]
	var strokes := phase(t, APPEAR + REACH, STROKE * float(STROKES))
	var lever := -SWING * absf(sin(strokes * PI * float(STROKES)))
	DrawSandPaint.tube(
		item,
		foot,
		target,
		ARC,
		ease(phase(t, APPEAR, REACH), 0.6),
		alpha * (1.0 - phase(t, impact_at(), FADE))
	)
	DrawSandPaint.beads(item, foot, target, ARC, strokes, alpha, 2)
	DrawSandPaint.gulp(item, target, strokes, alpha)
	SignaturePaint.drain_ring(item, target, phase(t, impact_at(), FADE), alpha)
	_pump(item, center, lever, alpha)
	var drip := phase(t, impact_at(), FADE)
	if drip > 0.0 and drip < 1.0:
		var mouth := center + (SPOUT + Vector2(0.0, 6.0)) * zoom
		SignaturePaint.water_drop(
			item, mouth + Vector2(0.0, 20.0 * drip * drip) * zoom, 3.6, Vector2.DOWN, alpha
		)


## 赤い鋳鉄の手押しポンプ。胴と鉄の帯、右へ曲がった吐き口、支点から左上へ伸びる柄(`lever` だけ振れる)。
func _pump(item: CanvasItem, center: Vector2, lever: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var half := BODY_HALF * zoom
	var spout := center + SPOUT * zoom
	item.draw_line(
		center + Vector2(0.0, -half.y * 0.4),
		spout,
		Color(UiPalette.INK_950, alpha),
		9.0 * zoom,
		true
	)
	item.draw_line(
		center + Vector2(0.0, -half.y * 0.4),
		spout,
		Color(UiPalette.PUMP_RED, alpha),
		6.0 * zoom,
		true
	)
	var body := PackedVector2Array(
		[
			center - half,
			center + Vector2(half.x, -half.y),
			center + half,
			center + Vector2(-half.x, half.y)
		]
	)
	ShapePaint.convex_polygon(
		ci, ForesightPaint.grown(body, center, 2.0), Color(UiPalette.INK_950, alpha)
	)
	ShapePaint.convex_polygon(ci, body, Color(UiPalette.PUMP_RED, alpha))
	for y: float in [-0.6, 0.6]:
		item.draw_line(
			center + Vector2(-half.x - 1.0, half.y * y),
			center + Vector2(half.x + 1.0, half.y * y),
			Color(UiPalette.CAST_IRON, alpha),
			3.0 * zoom
		)
	var pivot := center + PIVOT * zoom
	var grip := pivot + Vector2(-LEVER, 0.0).rotated(-0.35 + lever) * zoom
	item.draw_line(pivot, grip, Color(UiPalette.INK_950, alpha), 6.0 * zoom, true)
	item.draw_line(pivot, grip, Color(UiPalette.PUMP_RED, alpha), 3.6 * zoom, true)
	ShapePaint.circle(ci, grip, 4.6 * zoom, Color(UiPalette.INK_950, alpha))
	ShapePaint.circle(ci, grip, 3.4 * zoom, Color(UiPalette.CAST_IRON, alpha))
	ShapePaint.circle(ci, pivot, 3.0 * zoom, Color(UiPalette.KINTSUGI, alpha))
