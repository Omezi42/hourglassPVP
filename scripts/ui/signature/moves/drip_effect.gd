extends SignatureMove
## ドリップの落砂(GameDesign.md 9章):駒の頭上に砂の雫が膨らんでぽたりと落ち、続いて味方の駒それぞれの
## 頭上からも雫が1つずつ落ちて、届いた駒から金色の輪が広がる(恵与)。

const SWELL := 0.2
const FIRST_FALL := 0.14
const FALL := 0.2
const STAGGER := 0.06
const RING := 0.32
## 雫が膨らむ高さ・落ちきる高さ(駒の中心から上へ)と、雫の大きさ。
const HANG := 78.0
const LAND := 42.0
const DROP := 5.0
const SPLASH := Vector2(12.0, 4.0)


func impact_at() -> float:
	return _arrival(targets.size() - 1)


func duration() -> float:
	return impact_at() + RING


func reaches(index: int, t: float) -> bool:
	return t >= _arrival(index)


func _arrival(index: int) -> float:
	return SWELL + FIRST_FALL + STAGGER * float(maxi(index, 0)) + FALL


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var swell := ease(phase(t, 0.0, SWELL), 0.6)
	var first := phase(t, SWELL, FIRST_FALL)
	if first < 1.0:
		var at := from - Vector2(0.0, lerpf(HANG, LAND, ease(first, 2.0)))
		_drop(item, at, DROP * swell, alpha)
	else:
		_splash(item, from - Vector2(0.0, LAND), phase(t, SWELL + FIRST_FALL, RING), alpha)
	for i in range(targets.size()):
		var start := _arrival(i) - FALL
		var q := phase(t, start, FALL)
		if q > 0.0 and q < 1.0:
			var at := targets[i] - Vector2(0.0, lerpf(HANG + 20.0, 0.0, ease(q, 2.0)))
			_drop(item, at, DROP * 0.8, alpha * minf(q * 5.0, 1.0))
		SignaturePaint.boon_ring(item, targets[i], phase(t, _arrival(i), RING), alpha)


## 上が尖った砂の雫。
func _drop(item: CanvasItem, at: Vector2, size: float, alpha: float) -> void:
	if size <= 1.0:
		return
	var ci := item.get_canvas_item()
	var shape := PackedVector2Array([at - Vector2(0.0, size * 2.2)])
	for k in range(13):
		var a := PI * float(k) / 12.0
		shape.append(at + Vector2(cos(a) * size, sin(a) * size))
	ShapePaint.colored_polygon(ci, shape, Color(SignaturePaint.SAND, alpha))
	ShapePaint.circle(
		ci, at + Vector2(-size * 0.35, -size * 0.2), size * 0.25, Color(1, 1, 1, alpha * 0.7)
	)


func _splash(item: CanvasItem, at: Vector2, progress: float, alpha: float) -> void:
	if progress <= 0.0 or progress >= 1.0:
		return
	UiPaint.draw_ellipse_ring(
		item.get_canvas_item(),
		at,
		SPLASH * (0.4 + ease(progress, 0.4)),
		Color(SignaturePaint.SAND, alpha * (1.0 - progress)),
		1.6,
		20
	)
