extends SignatureMove
## バームの被弾(GameDesign.md 9章):駒の上に軟膏の丸缶が開き、緑の光が2枚の葉になって自分のHPの
## 器へひらひら舞い降り、届いたところで金色の輪が広がる(恵与)。

const APPEAR := 0.12
const OPEN := 0.14
const FLUTTER := 0.46
const RING := 0.32
## 缶の置き場所(駒の中心から)と大きさ、蓋の持ち上がり。
const LIFT := 60.0
const TIN := Vector2(14.0, 5.0)
const TIN_HEIGHT := 7.0
const LID_LIFT := Vector2(-10.0, -12.0)
const LID_TURN := -0.6
## 葉の大きさと、舞う揺れの幅・回数、2枚目の遅れ。
const LEAF := Vector2(9.0, 4.0)
const SWAY := 18.0
const WAVES := 2.0
const LAG := 0.1
const TIN_COLOR := Color(0.78, 0.8, 0.84, 1.0)
const SALVE := Color(0.7, 0.92, 0.62, 1.0)
const LEAF_COLOR := Color(0.5, 0.86, 0.42, 1.0)


func impact_at() -> float:
	return APPEAR + OPEN + FLUTTER


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var a := alpha * ease(phase(t, 0.0, APPEAR), 0.5)
	var tin := from - Vector2(0.0, LIFT)
	UiPaint.fill_ellipse(
		ci, tin + Vector2(0.0, TIN_HEIGHT), TIN, Color(TIN_COLOR.darkened(0.3), a), 20
	)
	item.draw_rect(
		Rect2(tin - Vector2(TIN.x, 0.0), Vector2(TIN.x * 2.0, TIN_HEIGHT)),
		Color(TIN_COLOR.darkened(0.15), a)
	)
	UiPaint.fill_ellipse(ci, tin, TIN, Color(SALVE, a), 20)
	var open := back_out(phase(t, APPEAR, OPEN))
	var lid := tin + LID_LIFT * open
	var lid_shape := PackedVector2Array()
	for i in range(16):
		var angle := TAU * float(i) / 16.0
		lid_shape.append(
			lid + Vector2(cos(angle) * TIN.x, sin(angle) * TIN.y).rotated(LID_TURN * open)
		)
	ShapePaint.colored_polygon(ci, lid_shape, Color(TIN_COLOR, a))
	var flutter := phase(t, APPEAR + OPEN, FLUTTER)
	if flutter <= 0.0 or t >= impact_at():
		SignaturePaint.boon_ring(item, targets[0], phase(t, impact_at(), RING), alpha)
		return
	for k in range(2):
		var q := clampf((flutter - LAG * float(k)) / (1.0 - LAG), 0.0, 1.0)
		if q <= 0.0:
			continue
		var s := ease(q, 1.2)
		var side := -1.0 if k == 0 else 1.0
		var at := tin.lerp(targets[0], s)
		at.x += side * sin(q * PI * WAVES) * SWAY * (1.0 - s)
		_leaf(item, at, side * cos(q * PI * WAVES) * 0.9, alpha * minf(q * 5.0, 1.0))


## 葉1枚。`turn` だけ傾ける。
func _leaf(item: CanvasItem, at: Vector2, turn: float, alpha: float) -> void:
	var dir := Vector2.RIGHT.rotated(turn)
	var across := dir.orthogonal()
	var shape := PackedVector2Array()
	for i in range(13):
		var s := float(i) / 12.0 * 2.0 - 1.0
		shape.append(at + dir * LEAF.x * s + across * LEAF.y * cos(s * PI * 0.5))
	for i in range(11, 0, -1):
		var s := float(i) / 12.0 * 2.0 - 1.0
		shape.append(at + dir * LEAF.x * s - across * LEAF.y * cos(s * PI * 0.5))
	ShapePaint.colored_polygon(item.get_canvas_item(), shape, Color(LEAF_COLOR, alpha))
	item.draw_line(
		at - dir * LEAF.x, at + dir * LEAF.x, Color(LEAF_COLOR.darkened(0.3), alpha), 1.0, true
	)
