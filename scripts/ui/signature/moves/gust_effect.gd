extends SignatureMove
## 砂嵐(GameDesign.md 9章):相手の列の端からつむじ風が立ち、列を左から右へ渡っていく。風の柱が
## 通り過ぎた駒から順に砂が1粒落ちる(打撃)。

const CROSS := 0.8
## 柱の出入りの余白と、柱の高さ・底と頂の太さ・輪の数。
const MARGIN := 80.0
const HEIGHT := 130.0
const BOTTOM := 10.0
const TOP := 40.0
const RINGS := 7
const GRAINS := 16
const SWAY := 8.0

var _row := 0.0
var _left := 0.0
var _right := 0.0


func impact_at() -> float:
	return CROSS


func reaches(index: int, t: float) -> bool:
	_measure()
	return _x(t) >= targets[index].x


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	_measure()
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t) * phase(t, 0.0, CROSS * 0.15)
	var base := Vector2(_x(t), _row + CardView.BOARD_ART_SIDE * 0.5)
	for i in range(RINGS):
		var s := float(i) / float(RINGS - 1)
		var radius := Vector2(lerpf(BOTTOM, TOP, s), lerpf(BOTTOM, TOP, s) * 0.28)
		var at := base + Vector2(sin(t * 18.0 + s * 4.0) * SWAY * s, -HEIGHT * s)
		UiPaint.draw_ellipse_ring(ci, at, radius, Color(SignaturePaint.SAND, alpha * 0.7), 1.6, 24)
	for i in range(GRAINS):
		var s := SignaturePaint.jitter(i, 21)
		var angle := t * 14.0 + TAU * SignaturePaint.jitter(i, 23)
		var radius := lerpf(BOTTOM, TOP, s) * 1.1
		var at := base + Vector2(cos(angle) * radius, sin(angle) * radius * 0.28 - HEIGHT * s)
		ShapePaint.circle(item.get_canvas_item(), at, 1.8, Color(SignaturePaint.SAND_DARK, alpha))


func _measure() -> void:
	if _right > _left:
		return
	_left = INF
	_right = -INF
	for target in targets:
		_row += target.y / float(targets.size())
		_left = minf(_left, target.x)
		_right = maxf(_right, target.x)
	_left -= MARGIN
	_right += MARGIN


func _x(t: float) -> float:
	return lerpf(_left, _right, ease(phase(t, 0.0, CROSS), -1.3))
