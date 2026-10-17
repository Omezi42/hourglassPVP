extends SignatureMove
## グレインの登場(GameDesign.md 9章):駒の頭上から砂粒が3粒ぽつぽつと順に落ち、台座で小さく
## 跳ねるたびに小さな砂煙が立つ(ひと粒ずつの小ささ)。

const GAP := 0.14
const FALL := 0.2
const BOUNCE := 0.14
const GRAINS := 3
## 粒が落ち始める高さ(台座の上面から)と、着地する位置の左右のずれ、跳ね返りの高さ。
const DROP_HEIGHT := 150.0
const LANDINGS := [-22.0, 18.0, -2.0]
const HOP := 10.0
const GRAIN_RADIUS := 3.2
const PUFF := Vector2(16.0, 5.0)
const PUFF_DOTS := 5


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + GAP * float(GRAINS - 1) + FALL + BOUNCE + FADE


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var alpha := fade_alpha(t)
	for i in range(GRAINS):
		var start := impact_at() + GAP * float(i)
		var fall := phase(t, start, FALL)
		if fall <= 0.0:
			continue
		var land := from + Vector2(LANDINGS[i], 0.0)
		var hop := phase(t, start + FALL, BOUNCE)
		var at := land - Vector2(0.0, DROP_HEIGHT * (1.0 - ease(fall, 2.0)))
		if hop > 0.0:
			at = land - Vector2(0.0, HOP * sin(hop * PI))
			_puff(item, land, hop, alpha)
		var grain_alpha := alpha * (1.0 - hop * 0.7)
		ShapePaint.circle(
			item.get_canvas_item(),
			at,
			GRAIN_RADIUS + 1.0,
			Color(SignaturePaint.SAND_DARK, grain_alpha)
		)
		ShapePaint.circle(
			item.get_canvas_item(), at, GRAIN_RADIUS, Color(SignaturePaint.SAND, grain_alpha)
		)


## 着地した点から左右へ広がって薄れる砂煙。
func _puff(item: CanvasItem, at: Vector2, progress: float, alpha: float) -> void:
	var spread := ease(progress, 0.4)
	var fade := alpha * (1.0 - progress)
	UiPaint.draw_ellipse_ring(
		item.get_canvas_item(),
		at,
		PUFF * (0.4 + spread),
		Color(SignaturePaint.SAND, fade * 0.6),
		1.4,
		20
	)
	for k in range(PUFF_DOTS):
		var side := -1.0 if k % 2 == 0 else 1.0
		var reach := PUFF.x * (0.5 + SignaturePaint.jitter(k, 31)) * spread
		var rise := 6.0 * SignaturePaint.jitter(k, 32) * sin(progress * PI)
		ShapePaint.circle(
			item.get_canvas_item(),
			at + Vector2(side * reach, -rise),
			1.4,
			Color(SignaturePaint.SAND, fade * 0.8)
		)
