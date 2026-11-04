extends SignatureMove
## ゲイルの設置(GameDesign.md 9章):砂を巻き上げた竜巻が相手の列を左から右へ渡り、
## 通り過ぎた駒から順に砂が散る(打撃)。

const CROSS := 0.6
## 竜巻の輪の数と、足元(列の中心から下)・高さ・輪の横幅(足元と頂上)。
const RINGS := 7
const FOOT := 34.0
const HEIGHT := 120.0
const WIDTH := Vector2(10.0, 46.0)
## 輪を楕円に潰す比と、うねりの幅・速さ。列の端からの張り出し。
const SQUASH := 0.28
const SWAY := 9.0
const SPIN := 14.0
const OVERRUN := 70.0
const RING_POINTS := 20
## 渦に巻かれて回る砂粒の数。
const GRAINS := 16


func impact_at() -> float:
	return CROSS


func reaches(index: int, t: float) -> bool:
	return _center_x(t) >= targets[index].x


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var foot := Vector2(_center_x(t), _row_y() + FOOT)
	for i in range(RINGS):
		var s := float(i) / float(RINGS - 1)
		var center := foot + Vector2(sin(t * SPIN + s * 4.0) * SWAY * s, -HEIGHT * s)
		var half := lerpf(WIDTH.x, WIDTH.y, s)
		var ring := PackedVector2Array()
		for k in range(RING_POINTS + 1):
			var angle := TAU * float(k) / float(RING_POINTS) + t * SPIN
			ring.append(center + Vector2(cos(angle) * half, sin(angle) * half * SQUASH))
		ShapePaint.polyline(ci, ring, Color(SignaturePaint.SAND_DARK, alpha * 0.55), 3.0, true)
		ShapePaint.polyline(ci, ring, Color(SignaturePaint.SAND, alpha * 0.8), 1.6, true)
	for i in range(GRAINS):
		var s := SignaturePaint.jitter(i, 171)
		var angle := t * SPIN * (1.0 + s) + TAU * SignaturePaint.jitter(i, 172)
		var half := lerpf(WIDTH.x, WIDTH.y, s) * 1.15
		var at := foot + Vector2(cos(angle) * half, -HEIGHT * s + sin(angle) * half * SQUASH)
		ShapePaint.circle(ci, at, 1.8, Color(SignaturePaint.SAND, alpha))


func _row_y() -> float:
	var y := 0.0
	for target: Vector2 in targets:
		y += target.y
	return y / float(targets.size())


func _center_x(t: float) -> float:
	var left := INF
	var right := -INF
	for target: Vector2 in targets:
		left = minf(left, target.x)
		right = maxf(right, target.x)
	return lerpf(left - OVERRUN, right + OVERRUN, ease(phase(t, 0.0, CROSS), -1.4))
