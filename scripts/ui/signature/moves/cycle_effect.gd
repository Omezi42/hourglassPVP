extends SignatureMove
## サイクル(GameDesign.md 9章):返った駒の足元で矢印の輪(循環の印)が一回転し、そこから光の弧が
## 味方の駒へ左から順に跳んで、届いた駒から金色の輪が広がる。

const ROTATE := 0.28
const HOP := 0.24
const STAGGER := 0.06
const RING := 0.3
## 矢印の輪(駒の足元に寝かせた楕円)と、その上の矢じりの数・大きさ。
const WHEEL := Vector2(44.0, 12.0)
const ARROWS := 3
const ARROW := 7.0
const ARC_SEGMENTS := 12
## 光の弧が山なりに持ち上がる高さ。
const ARC_HEIGHT := 46.0
const MOTE_RADIUS := 4.5

var _order: Array[int] = []


func impact_at() -> float:
	return _arrive(maxi(targets.size() - 1, 0))


func duration() -> float:
	return impact_at() + RING


func reaches(index: int, t: float) -> bool:
	return t >= _arrive(_rank(index))


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var base := from + Vector2(0.0, CardView.BOARD_ART_SIDE * 0.5)
	_wheel(item, base, ease(phase(t, 0.0, ROTATE), -1.6), alpha)
	for i in range(targets.size()):
		var rank := _rank(i)
		var hop := phase(t, _arrive(rank) - HOP, HOP)
		if hop > 0.0 and hop < 1.0:
			var at := _arc(base, targets[i], ease(hop, -1.4))
			UiPaint.fill_circle(
				ci, at, MOTE_RADIUS * 2.2, Color(SignaturePaint.BOON, alpha * 0.3), 12
			)
			UiPaint.fill_circle(ci, at, MOTE_RADIUS, Color(SignaturePaint.BOON, alpha), 10)
		SignaturePaint.boon_ring(item, targets[i], phase(t, _arrive(rank), RING), alpha)


## 左から何番目に届くか。
func _rank(index: int) -> int:
	if _order.is_empty():
		for i in range(targets.size()):
			_order.append(i)
		_order.sort_custom(func(a: int, b: int) -> bool: return targets[a].x < targets[b].x)
	return _order.find(index)


func _arrive(rank: int) -> float:
	return ROTATE + HOP + STAGGER * float(rank)


func _arc(a: Vector2, b: Vector2, s: float) -> Vector2:
	return a.lerp(b, s) - Vector2(0.0, ARC_HEIGHT * sin(s * PI))


## 寝かせた矢印の輪。`spin` は回った量(0→1で一回転)。
func _wheel(item: CanvasItem, center: Vector2, spin: float, alpha: float) -> void:
	var ci := item.get_canvas_item()
	var color := Color(SignaturePaint.BOON, alpha)
	UiPaint.draw_ellipse_ring(
		ci, center, WHEEL, Color(UiPalette.OUTLINE_DARK, alpha * 0.6), 3.6, 40
	)
	UiPaint.draw_ellipse_ring(ci, center, WHEEL, color, 2.0, 40)
	for i in range(ARROWS):
		var angle := TAU * (spin + float(i) / float(ARROWS))
		var at := center + Vector2(cos(angle) * WHEEL.x, sin(angle) * WHEEL.y)
		var tangent := Vector2(-sin(angle) * WHEEL.x, cos(angle) * WHEEL.y).normalized()
		var across := tangent.orthogonal() * ARROW * 0.6
		var head := PackedVector2Array([at + tangent * ARROW, at + across, at - across])
		item.draw_colored_polygon(head, color)
	if spin > 0.0 and spin < 1.0:
		var segments := PackedVector2Array()
		for k in range(ARC_SEGMENTS + 1):
			var angle := TAU * spin * float(k) / float(ARC_SEGMENTS)
			segments.append(center + Vector2(cos(angle) * WHEEL.x, sin(angle) * WHEEL.y))
		item.draw_polyline(segments, Color(SignaturePaint.SPARK_HOT, alpha), 2.6, true)
