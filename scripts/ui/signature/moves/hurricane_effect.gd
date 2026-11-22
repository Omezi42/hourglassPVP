extends SignatureMove
## ハリケーンの設置(GameDesign.md 9章):卓の端から竜巻が相手の列を通り抜け、通った駒の砂が一気に下へ
## 吸い落ちる(砂の移動は進行役が出す)。

const SWEEP := 0.75
## 竜巻の高さ・上下の半幅・輪の数と、列の端からはみ出す量。
const HEIGHT := 96.0
const TOP_HALF := 34.0
const BOTTOM_HALF := 6.0
const RINGS := 9
const MARGIN := 70.0
const COLOR := Color(0.92, 0.95, 1.0, 1.0)


func impact_at() -> float:
	return SWEEP


func reaches(index: int, t: float) -> bool:
	return _x(t) >= targets[index].x


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var ci := item.get_canvas_item()
	var ground := Vector2(_x(t), _row())
	for i in range(RINGS):
		var k := float(i) / float(RINGS - 1)
		var half := lerpf(BOTTOM_HALF, TOP_HALF, k * k) * zoom
		var sway := sin(t * 18.0 + k * 4.0) * 6.0 * k * zoom
		var center := ground + Vector2(sway, -HEIGHT * k * zoom)
		var size := Vector2(half, half * 0.28)
		UiPaint.draw_ellipse_ring(ci, center, size, Color(UiPalette.INK_950, alpha * 0.35), 3.2, 24)
		UiPaint.draw_ellipse_ring(ci, center, size, Color(COLOR, alpha * (0.5 + 0.5 * k)), 2.0, 24)
	for i in range(6):
		var spin := t * 12.0 + float(i) * TAU / 6.0
		var k := fmod(float(i) * 0.17 + t * 1.3, 1.0)
		var half := lerpf(BOTTOM_HALF, TOP_HALF, k * k) * zoom
		var at := ground + Vector2(cos(spin) * half, -HEIGHT * k * zoom + sin(spin) * half * 0.28)
		ShapePaint.circle(ci, at, 2.2 * zoom, Color(SignaturePaint.SAND, alpha))


## 竜巻の足元のx。列の左端の外から右端の外まで。
func _x(t: float) -> float:
	var left := INF
	var right := -INF
	for target in targets:
		left = minf(left, target.x)
		right = maxf(right, target.x)
	var u := ease(phase(t, 0.0, SWEEP), -1.6)
	return lerpf(left - MARGIN * zoom, right + MARGIN * zoom, u)


func _row() -> float:
	var row := 0.0
	for target in targets:
		row += target.y
	return row / float(targets.size()) + HEIGHT * 0.3 * zoom
