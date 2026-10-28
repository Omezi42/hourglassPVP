extends SignatureMove
## 崩落(GameDesign.md 9章):対象の真上に砂岩の天井が現れてひび割れ、塊に割れて崩れ落ち、
## 重さで押し潰して砕く(打撃)。

const APPEAR := 0.2
const CRACK := 0.26
const FALL := 0.24
## 天井の大きさと、対象の中心からの高さ。
const SLAB := Vector2(64.0, 14.0)
const LIFT := 70.0
## 割れた塊の数と、落ちる途中で開く隙間・回る角度。
const CHUNKS := 4
const SPREAD := 5.0
const TUMBLE := 0.5
const STONE := Color(0.66, 0.55, 0.4, 1.0)
const STONE_EDGE := Color(0.4, 0.32, 0.22, 1.0)
const CRACK_COLOR := Color(0.2, 0.15, 0.1, 1.0)
const CRACK_WIDTH := 1.6
const EDGE_WIDTH := 1.2


func impact_at() -> float:
	return APPEAR + CRACK + FALL


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var target: Vector2 = targets[0]
	var alpha := fade_alpha(t)
	if t >= impact_at():
		SignaturePaint.sparks(item, target, phase(t, impact_at(), FADE), alpha)
		return
	var intro := ease(phase(t, 0.0, APPEAR), 0.5)
	var fall := phase(t, APPEAR + CRACK, FALL)
	var drop := (LIFT - SLAB.y * 0.5) * fall * fall
	var top := target - Vector2(SLAB.x * 0.5, LIFT + SLAB.y * 0.5) + Vector2(0.0, drop)
	var chunk_width := SLAB.x / CHUNKS
	for i in range(CHUNKS):
		var offset := (float(i) - (CHUNKS - 1) * 0.5) * SPREAD * fall
		var corner := top + Vector2(chunk_width * i + offset, 0.0)
		var spin := TUMBLE * fall * (SignaturePaint.jitter(i, 31) - 0.5)
		_chunk(item, Rect2(corner, Vector2(chunk_width, SLAB.y)), spin, intro * alpha)
	if fall <= 0.0:
		_cracks(item, top, phase(t, APPEAR, CRACK), intro * alpha)


## 塊1つ。中心のまわりに `spin` だけ傾ける。
func _chunk(item: CanvasItem, rect: Rect2, spin: float, alpha: float) -> void:
	var center := rect.get_center()
	var half := rect.size * 0.5
	var points := PackedVector2Array()
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		points.append(center + (half * corner).rotated(spin))
	ShapePaint.colored_polygon(item.get_canvas_item(), points, Color(STONE, alpha))
	points.append(points[0])
	ShapePaint.polyline(item.get_canvas_item(), points, Color(STONE_EDGE, alpha), EDGE_WIDTH, true)


## 塊の継ぎ目に沿って、上から下へ走るひび。
func _cracks(item: CanvasItem, top: Vector2, progress: float, alpha: float) -> void:
	if progress <= 0.0:
		return
	var chunk_width := SLAB.x / CHUNKS
	for i in range(1, CHUNKS):
		var start := top + Vector2(chunk_width * i, 0.0)
		var bend := (SignaturePaint.jitter(i, 32) - 0.5) * chunk_width * 0.4
		var mid := start + Vector2(bend, SLAB.y * 0.5)
		var end := start + Vector2(0.0, SLAB.y)
		var path := PackedVector2Array([start, mid, end])
		var reach := progress * 2.0
		if reach < 1.0:
			path = PackedVector2Array([start, start.lerp(mid, reach)])
		elif reach < 2.0:
			path = PackedVector2Array([start, mid, mid.lerp(end, reach - 1.0)])
		ShapePaint.polyline(
			item.get_canvas_item(), path, Color(CRACK_COLOR, alpha), CRACK_WIDTH, true
		)
