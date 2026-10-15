extends SignatureMove
## モス(GameDesign.md 9章):味方が壊れるたび、駒の足元から苔の蔓が這い上がって葉を2枚開き、
## 開ききったところで恵与の金色の輪が広がる。

const CLIMB := 0.38
const UNFURL := 0.22
const RING := 0.32
## 蔓の高さ・うねりの幅と回数。足元は台座の手前の縁の少し右から伸ばす。
const HEIGHT := 92.0
const SWAY := 9.0
const WAVES := 1.5
const ROOT_OFFSET := Vector2(22.0, -4.0)
const STEPS := 24
## 葉の付く高さ(蔓の長さに対する割合)と大きさ。
const LEAVES := [0.45, 0.8]
const LEAF := Vector2(13.0, 5.5)
const STEM := Color(0.36, 0.58, 0.26, 1.0)
const LEAF_LIGHT := Color(0.62, 0.84, 0.40, 1.0)


func impact_at() -> float:
	return CLIMB + UNFURL


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var root := targets[0] + Vector2(0.0, CardView.BOARD_ART_SIDE * 0.5) + ROOT_OFFSET
	var climb := ease(phase(t, 0.0, CLIMB), 0.6)
	var points := PackedVector2Array()
	var count := maxi(int(STEPS * climb), 1)
	for i in range(count + 1):
		points.append(_vine(root, climb * float(i) / float(count)))
	item.draw_polyline(points, Color(UiPalette.OUTLINE_DARK, alpha * 0.6), 4.2, true)
	item.draw_polyline(points, Color(STEM, alpha), 2.6, true)
	var unfurl := back_out(phase(t, CLIMB, UNFURL))
	for k in range(LEAVES.size()):
		var at: float = LEAVES[k]
		if climb < at:
			continue
		var side := 1.0 if k % 2 == 0 else -1.0
		_leaf(item, _vine(root, at), side, unfurl, alpha)
	SignaturePaint.boon_ring(item, targets[0], phase(t, impact_at(), RING), alpha)


## 蔓の上で、根元から `s`(0→1)進んだ位置。
func _vine(root: Vector2, s: float) -> Vector2:
	return root + Vector2(sin(s * WAVES * TAU) * SWAY, -HEIGHT * s)


## 蔓の脇へ開く葉。`open` は開いた量(0→1、わずかに行き過ぎる)。
func _leaf(item: CanvasItem, base: Vector2, side: float, open: float, alpha: float) -> void:
	if open <= 0.0:
		return
	var dir := Vector2(side, -0.6).normalized()
	var tip := base + dir * LEAF.x * 2.0 * open
	var across := dir.orthogonal() * LEAF.y * open
	var mid := base.lerp(tip, 0.5)
	var shape := PackedVector2Array([base, mid + across, tip, mid - across])
	var rect := Rect2(mid - Vector2.ONE * LEAF.x, Vector2.ONE * LEAF.x * 2.0)
	UiPaint.fill_gradient_polygon(
		item.get_canvas_item(),
		shape,
		rect,
		[[0.0, Color(LEAF_LIGHT, alpha)], [1.0, Color(STEM, alpha)]]
	)
	item.draw_line(base, tip, Color(STEM.darkened(0.3), alpha * 0.8), 1.0, true)
