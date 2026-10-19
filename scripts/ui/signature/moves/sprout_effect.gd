extends SignatureMove
## スプラウトの余砂(GameDesign.md 9章):銘板から若芽がくるりと巻きながら伸びて葉を1枚開き、その葉が
## 離れて自分の情報帯へひらりと流れ着いて光る(ドロー)。

const GROW := 0.26
const OPEN := 0.12
const FLY := 0.36
## 若芽の高さと巻き(先端の渦の半径・巻き数)、線を作る点の数。
const STEM := 34.0
const CURL := 7.0
const CURL_TURNS := 1.2
const POINTS := 24
## 葉の大きさと、舞う揺れの幅・回数、届いた所の光の輪。
const LEAF := Vector2(9.0, 4.0)
const SWAY := 16.0
const WAVES := 2.0
const GLOW := Vector2(26.0, 9.0)
const STEM_COLOR := Color(0.42, 0.7, 0.3, 1.0)
const LEAF_COLOR := Color(0.56, 0.86, 0.4, 1.0)


func impact_at() -> float:
	return GROW + OPEN + FLY


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var grow := ease(phase(t, 0.0, GROW), 0.6)
	var vine := PackedVector2Array()
	for i in range(POINTS + 1):
		var s := float(i) / float(POINTS) * grow
		vine.append(_vine_at(s))
	if grow > 0.05:
		ShapePaint.polyline(ci, vine, Color(STEM_COLOR, alpha), 2.4, true)
	var tip := _vine_at(grow)
	var open := back_out(phase(t, GROW, OPEN))
	var fly := phase(t, GROW + OPEN, FLY)
	if open > 0.0 and fly < 1.0:
		var s := ease(fly, 1.2)
		var at := tip.lerp(targets[0], s)
		at.x += sin(fly * PI * WAVES) * SWAY * (1.0 - s)
		var turn := -0.6 + cos(fly * PI * WAVES) * 0.8 * minf(fly * 4.0, 1.0)
		_leaf(item, at, turn, LEAF * minf(open, 1.0), alpha)
	var glow := phase(t, impact_at(), FADE)
	if glow > 0.0:
		UiPaint.draw_ellipse_ring(
			ci,
			targets[0],
			GLOW * (0.5 + ease(glow, 0.4)),
			Color(LEAF_COLOR, 0.8 * (1.0 - glow)),
			2.0,
			28
		)


## 若芽の上の点(0=根元、1=先端)。上へ伸び、終わりの3割で外へ渦を巻く。
func _vine_at(s: float) -> Vector2:
	var rise := minf(s / 0.7, 1.0)
	var at := from - Vector2(sin(rise * PI) * 4.0, STEM * rise)
	var curl := maxf((s - 0.7) / 0.3, 0.0)
	if curl > 0.0:
		var angle := PI + curl * TAU * CURL_TURNS
		at += Vector2(
			CURL + cos(angle) * CURL * (1.0 - curl * 0.5), sin(angle) * CURL * (1.0 - curl * 0.5)
		)
	return at


## 葉1枚。`turn` だけ傾ける。
func _leaf(item: CanvasItem, at: Vector2, turn: float, size: Vector2, alpha: float) -> void:
	if size.x <= 1.0:
		return
	var dir := Vector2.RIGHT.rotated(turn)
	var across := dir.orthogonal()
	var shape := PackedVector2Array()
	for i in range(13):
		var s := float(i) / 12.0 * 2.0 - 1.0
		shape.append(at + dir * size.x * s + across * size.y * cos(s * PI * 0.5))
	for i in range(11, 0, -1):
		var s := float(i) / 12.0 * 2.0 - 1.0
		shape.append(at + dir * size.x * s - across * size.y * cos(s * PI * 0.5))
	ShapePaint.colored_polygon(item.get_canvas_item(), shape, Color(LEAF_COLOR, alpha))
