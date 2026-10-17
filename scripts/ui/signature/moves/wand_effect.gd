extends SignatureMove
## ワンドの設置(GameDesign.md 9章):駒の上に細い杖が現れてくるりと一振りし、杖先から星の光が
## 弧を描いて対象へ飛び、届いたところで金色の輪が広がる(恵与)。

const APPEAR := 0.14
const SWING := 0.22
const FLIGHT := 0.3
const RING := 0.32
## 杖の握り(駒の中心から)と長さ、振る前と振り終わりの傾き(真上からのラジアン)。
const GRIP := Vector2(0.0, -58.0)
const LENGTH := 40.0
const RAISED := -1.0
const SWUNG := 0.75
## 星の大きさと、飛ぶ弧の高さ。
const STAR := 8.0
const ARC := 60.0
const TRAIL := 6
const WAND_COLOR := Color(0.36, 0.22, 0.14, 1.0)


func impact_at() -> float:
	return APPEAR + SWING + FLIGHT


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var appear := ease(phase(t, 0.0, APPEAR), 0.5)
	var swing := back_out(phase(t, APPEAR, SWING))
	var grip := from + GRIP
	var tip := grip + Vector2.UP.rotated(lerpf(RAISED, SWUNG, swing)) * LENGTH
	item.draw_line(grip, tip, Color(UiPalette.OUTLINE_DARK, alpha * appear * 0.8), 4.4, true)
	item.draw_line(grip, tip, Color(WAND_COLOR, alpha * appear), 2.8, true)
	var flight := phase(t, APPEAR + SWING, FLIGHT)
	if flight <= 0.0:
		_star(item, tip, STAR * appear * (0.6 + 0.4 * swing), t * 6.0, alpha * appear)
		return
	if t >= impact_at():
		SignaturePaint.boon_ring(item, targets[0], phase(t, impact_at(), RING), alpha)
		return
	for i in range(TRAIL, 0, -1):
		var q := maxf(flight - 0.06 * float(i), 0.0)
		var size := 2.6 * (1.0 - float(i) / float(TRAIL + 1))
		item.draw_circle(_arc_at(tip, q), size, Color(SignaturePaint.BOON, alpha * 0.6))
	_star(item, _arc_at(tip, flight), STAR, t * 6.0, alpha)


func _arc_at(start: Vector2, q: float) -> Vector2:
	var s := ease(q, 0.8)
	return start.lerp(targets[0], s) - Vector2(0.0, ARC * sin(s * PI))


## 4本の光の尖りを持つ星。`turn` は回った量(ラジアン)。
func _star(item: CanvasItem, at: Vector2, size: float, turn: float, alpha: float) -> void:
	if alpha <= 0.0 or size <= 1.0:
		return
	var shape := PackedVector2Array()
	for i in range(8):
		var r := size if i % 2 == 0 else size * 0.32
		shape.append(at + Vector2.UP.rotated(turn + TAU * float(i) / 8.0) * r)
	item.draw_colored_polygon(shape, Color(SignaturePaint.BOON, alpha))
	item.draw_circle(at, size * 0.3, Color(1, 1, 1, alpha))
