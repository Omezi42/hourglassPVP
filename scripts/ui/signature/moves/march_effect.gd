extends SignatureMove
## マーチの設置(GameDesign.md 9章):駒の足元から砂の足跡が空いた台座へ1つずつ伸び、
## 届いたところでモートが現れる(恵与。1体ごとに1回)。

const WALK := 0.5
const RING := 0.32
## 足跡の数、1つの大きさ、左右の振れ幅、踏んでから薄れきるまでの秒。
const STEPS := 6
const PRINT := Vector2(3.0, 4.6)
const STRIDE := 5.0
const LINGER := 0.3
const PRINT_COLOR := Color(0.62, 0.46, 0.24, 1.0)


func impact_at() -> float:
	return WALK


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var start := from + Vector2(0.0, CardView.BOARD_ART_SIDE * 0.5)
	var floor_at := targets[0] + Vector2(0.0, CardView.BOARD_ART_SIDE * 0.5)
	var path := floor_at - start
	var side := path.orthogonal().normalized() if path.length() > 1.0 else Vector2.UP
	for i in range(STEPS):
		var stepped_at := WALK * float(i + 1) / float(STEPS + 1)
		if t < stepped_at:
			break
		var a := alpha * (1.0 - phase(t, stepped_at, LINGER) * 0.6)
		var s := float(i + 1) / float(STEPS + 1)
		var foot := 1.0 if i % 2 == 0 else -1.0
		var at := start.lerp(floor_at, s) + side * STRIDE * foot
		var pop := back_out(phase(t, stepped_at, LINGER * 0.4))
		UiPaint.fill_ellipse(ci, at, PRINT * pop, Color(PRINT_COLOR, a), 10)
	SignaturePaint.boon_ring(item, floor_at, phase(t, impact_at(), RING), alpha)
