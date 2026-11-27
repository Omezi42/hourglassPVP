extends SignatureMove
## リザーバーの落砂(GameDesign.md 9章):駒の頭上に緑青の貯水槽が現れ、胴の窓の水位が下がるぶん、
## 下の蛇口から青緑の水が弧を描いて味方の駒へ注がれ、しぶきが跳ねて金色の輪が広がる(恵与)。

const APPEAR := 0.1
const FLOW := 0.34
## 槽の中心(駒の中心から)と半幅・半高、窓の半幅、蛇口(槽の中心から)、弧の高さ、注ぎ先(対象の中心から)。
const TANK := Vector2(0.0, -104.0)
const TANK_HALF := Vector2(20.0, 16.0)
const WINDOW := 4.5
const TAP := Vector2(22.0, 10.0)
const ARC := 36.0
const MOUTH := Vector2(0.0, -36.0)
const TOP := 130.0


func top_extent() -> float:
	return TOP * zoom


func impact_at() -> float:
	return APPEAR + FLOW


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t) * minf(phase(t, 0.0, APPEAR) * 1.5, 1.0)
	var center := from + TANK * zoom
	var flow := phase(t, APPEAR, FLOW)
	_tank(item, center, 0.85 - 0.6 * flow, alpha)
	var tap := center + TAP * zoom
	var mouth := targets[0] + MOUTH
	var settle := phase(t, impact_at(), FADE)
	PourPaint.stream(item, tap, mouth, ARC, ease(flow, 0.7), settle, alpha)
	if t >= impact_at():
		PourPaint.splash(item, mouth, settle, alpha)
		SignaturePaint.boon_ring(item, targets[0], settle, alpha)


## 緑青の貯水槽。円錐の屋根、胴の窓に `level`(0→1)まで溜まった水、右下に真鍮の蛇口。
func _tank(item: CanvasItem, center: Vector2, level: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var half := TANK_HALF * zoom
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
	ShapePaint.convex_polygon(ci, body, Color(UiPalette.TIDE, alpha))
	var roof := PackedVector2Array(
		[
			center + Vector2(-half.x - 3.0, -half.y),
			center + Vector2(0.0, -half.y - 12.0 * zoom),
			center + Vector2(half.x + 3.0, -half.y),
		]
	)
	ShapePaint.convex_polygon(ci, roof, Color(UiPalette.BASALT, alpha))
	var w := WINDOW * zoom
	var bottom := center.y + half.y - 3.0
	var top := center.y - half.y + 3.0
	ShapePaint.convex_polygon(
		ci,
		PackedVector2Array(
			[
				Vector2(center.x - w, top),
				Vector2(center.x + w, top),
				Vector2(center.x + w, bottom),
				Vector2(center.x - w, bottom)
			]
		),
		Color(UiPalette.INK_950, alpha)
	)
	var surface := lerpf(bottom, top, clampf(level, 0.0, 1.0))
	ShapePaint.convex_polygon(
		ci,
		PackedVector2Array(
			[
				Vector2(center.x - w, surface),
				Vector2(center.x + w, surface),
				Vector2(center.x + w, bottom),
				Vector2(center.x - w, bottom)
			]
		),
		Color(UiPalette.POUR_WATER, alpha)
	)
	var tap := center + TAP * zoom
	item.draw_line(
		center + Vector2(half.x, 6.0 * zoom), tap, Color(UiPalette.BRASS, alpha), 4.0 * zoom, true
	)
