extends SignatureMove
## ブロックの余砂(GameDesign.md 9章):銘板の上に石のブロックがせり上がり、まん中から割れて、
## 片方は崩れ落ち、もう片方が転がるように自分の情報帯へ飛んで光る(ドロー)。

const RISE := 0.18
const CRACK := 0.12
const FLY := 0.4
## ブロックの大きさとせり上がる高さ、割れた半分が離れる幅。
const SIZE := Vector2(26.0, 16.0)
const LIFT := 30.0
const GAP := 3.0
## 飛ぶ半分の山なりの高さと回転、崩れる半分の落ちる距離。
const ARC := 34.0
const SPIN := TAU * 0.75
const DROP := 22.0
const GLOW := Vector2(26.0, 9.0)
const STONE := Color(0.62, 0.68, 0.78, 1.0)
const STONE_EDGE := Color(0.32, 0.36, 0.44, 1.0)
const GLOW_COLOR := Color(0.82, 0.9, 1.0, 1.0)


func impact_at() -> float:
	return RISE + CRACK + FLY


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var rise := ease(phase(t, 0.0, RISE), 0.5)
	var center := from - Vector2(0.0, LIFT * rise)
	var crack := phase(t, RISE, CRACK)
	var fly := phase(t, RISE + CRACK, FLY)
	var half := Vector2(SIZE.x * 0.5, SIZE.y)
	var left_at := center - Vector2(half.x * 0.5 + GAP * crack, 0.0)
	var right_at := center + Vector2(half.x * 0.5 + GAP * crack, 0.0)
	if crack <= 0.0:
		_stone(ci, center, SIZE, 0.0, alpha * rise)
		return
	if fly < 1.0:
		var fall := left_at + Vector2(-6.0 * fly, DROP * fly * fly)
		_stone(ci, fall, half, -0.5 * fly, alpha * (1.0 - fly))
	if fly < 1.0:
		var s := ease(fly, 1.3)
		var at := right_at.lerp(targets[0], s) - Vector2(0.0, sin(fly * PI) * ARC)
		_stone(ci, at, half * (1.0 - 0.3 * s), SPIN * s, alpha)
	if fly <= 0.0:
		_crack_line(ci, center, crack, alpha)
	var glow := phase(t, impact_at(), FADE)
	if glow > 0.0:
		UiPaint.draw_ellipse_ring(
			ci,
			targets[0],
			GLOW * (0.5 + ease(glow, 0.4)),
			Color(GLOW_COLOR, 0.8 * (1.0 - glow)),
			2.0,
			28
		)


## 石1つ。`size` の長方形を `turn` だけ回し、縁取りとまん中の目地を描く。
func _stone(ci: RID, at: Vector2, size: Vector2, turn: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var h := size * 0.5
	var corners := PackedVector2Array(
		[Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]
	)
	var shape := PackedVector2Array()
	for c in corners:
		shape.append(at + c.rotated(turn))
	ShapePaint.colored_polygon(ci, shape, Color(STONE, alpha))
	var outline := shape.duplicate()
	outline.append(shape[0])
	ShapePaint.polyline(ci, outline, Color(STONE_EDGE, alpha), 1.6, true)
	var seam := PackedVector2Array(
		[at + Vector2(-h.x, 0.0).rotated(turn), at + Vector2(h.x, 0.0).rotated(turn)]
	)
	ShapePaint.polyline(ci, seam, Color(STONE_EDGE, alpha * 0.6), 1.0, true)


## まん中を上から下へ走るひび。`progress` で伸びる。
func _crack_line(ci: RID, center: Vector2, progress: float, alpha: float) -> void:
	const STEPS := 4
	var top := center - Vector2(0.0, SIZE.y * 0.5)
	var line := PackedVector2Array([top])
	for i in range(1, STEPS + 1):
		var s := float(i) / float(STEPS)
		if s > progress:
			break
		var zig := 2.5 if i % 2 == 1 else -2.5
		line.append(top + Vector2(zig, SIZE.y * s))
	if line.size() > 1:
		ShapePaint.polyline(ci, line, Color(STONE_EDGE, alpha), 1.6, true)
