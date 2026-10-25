extends SignatureMove
## ブルームの余砂(GameDesign.md 9章):銘板から花のつぼみが伸びて開き、花びらが1枚舞って空いた台座へ
## 降り、届いたところでモートが現れる(恵与。1体ごとに1回)。

const GROW := 0.16
const OPEN := 0.14
const DRIFT := 0.36
const RING := 0.32
## 茎の高さ、花びらの数・長さ・幅、舞う揺れの幅と回数。
const STEM := 28.0
const PETALS := 5
const PETAL := Vector2(9.0, 4.0)
const SWAY := 18.0
const WAVES := 2.0
const STEM_COLOR := Color(0.42, 0.68, 0.32, 1.0)
const PETAL_COLOR := Color(1.0, 0.7, 0.78, 1.0)
const HEART := Color(1.0, 0.9, 0.5, 1.0)


func impact_at() -> float:
	return GROW + OPEN + DRIFT


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var grow := ease(phase(t, 0.0, GROW), 0.6)
	var head := from - Vector2(0.0, STEM * grow)
	if grow > 0.05:
		item.draw_line(from, head, Color(STEM_COLOR, alpha), 2.4, true)
	var open := back_out(phase(t, GROW, OPEN))
	var drift := phase(t, GROW + OPEN, DRIFT)
	for i in range(PETALS):
		var angle := -PI * 0.5 + TAU * float(i) / float(PETALS)
		if i == 0 and drift > 0.0:
			continue
		_petal(item, head, angle, PETAL * clampf(open, 0.2, 1.1) * grow, alpha)
	ShapePaint.circle(ci, head, 3.4 * grow, Color(HEART, alpha))
	var floor_at := targets[0] + Vector2(0.0, CardView.BOARD_ART_SIDE * 0.5)
	if drift > 0.0 and drift < 1.0:
		var s := ease(drift, 1.1)
		var at := head.lerp(floor_at, s) - Vector2(0.0, 30.0 * sin(s * PI))
		at.x += sin(drift * PI * WAVES) * SWAY * (1.0 - s)
		_petal(item, at, -PI * 0.5 + drift * TAU, PETAL, alpha)
	SignaturePaint.boon_ring(item, floor_at, phase(t, impact_at(), RING), alpha)


## 根元 `root` から `angle` へ伸びる花びら1枚。
func _petal(item: CanvasItem, root: Vector2, angle: float, size: Vector2, alpha: float) -> void:
	if size.x <= 1.0:
		return
	var dir := Vector2.from_angle(angle)
	var across := dir.orthogonal()
	var shape := PackedVector2Array()
	for k in range(13):
		var s := float(k) / 12.0
		shape.append(root + dir * size.x * s + across * size.y * sin(s * PI))
	for k in range(11, 0, -1):
		var s := float(k) / 12.0
		shape.append(root + dir * size.x * s - across * size.y * sin(s * PI))
	ShapePaint.colored_polygon(item.get_canvas_item(), shape, Color(PETAL_COLOR, alpha))
