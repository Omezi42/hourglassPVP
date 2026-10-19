extends SignatureMove
## ボーラの設置(GameDesign.md 9章):駒の上で重りの付いた紐が回り、投げられて対象の駒へ
## 巻き付き、締め上げて砕く(打撃)。

const WIND := 0.34
const FLIGHT := 0.26
const WRAP := 0.2
const WIND_TURNS := 1.5
const FLIGHT_TURNS := 2.0
const WRAP_TURNS := 1.25
## 回す紐の長さ(重りから重りまでの半分)と、駒の中心からの高さ。
const REACH := 15.0
const LIFT := 34.0
## 巻き付き始めと締め終わりの輪の半径。
const WRAP_START := 26.0
const WRAP_END := 9.0
## 放物線の膨らみ(2点間の距離に対する割合)と重りの大きさ。
const ARC := 0.2
const WEIGHT := 4.0
const WEIGHT_COLOR := Color(0.5, 0.46, 0.42, 1.0)
const CORD_COLOR := Color(0.86, 0.78, 0.6, 1.0)
const CORD_WIDTH := 1.6
const ARC_POINTS := 16


func impact_at() -> float:
	return WIND + FLIGHT + WRAP


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var hub := from - Vector2(0.0, LIFT)
	var target: Vector2 = targets[0]
	if t < WIND:
		var angle := TAU * WIND_TURNS * ease(phase(t, 0.0, WIND), 0.6)
		_pair(item, hub, angle, REACH, alpha)
		return
	if t < WIND + FLIGHT:
		var flight := phase(t, WIND, FLIGHT)
		var spin := TAU * (WIND_TURNS + FLIGHT_TURNS * flight)
		_pair(item, _arc_point(hub, target, flight), spin, REACH, alpha)
		return
	if t < impact_at():
		var wrap := phase(t, WIND + FLIGHT, WRAP)
		var radius := lerpf(WRAP_START, WRAP_END, ease(wrap, 0.5))
		var turn := TAU * (WIND_TURNS + FLIGHT_TURNS + WRAP_TURNS * wrap)
		ShapePaint.arc(
			item.get_canvas_item(),
			target,
			radius,
			turn - PI,
			turn,
			ARC_POINTS,
			Color(CORD_COLOR, alpha),
			CORD_WIDTH,
			true
		)
		_pair(item, target, turn, radius, alpha)
		return
	SignaturePaint.sparks(item, target, phase(t, impact_at(), FADE), alpha)


## 中心を挟んで向かい合う2つの重りと、それをつなぐ紐。
func _pair(item: CanvasItem, center: Vector2, angle: float, reach: float, alpha: float) -> void:
	var offset := Vector2(cos(angle), sin(angle)) * reach
	item.draw_line(
		center - offset, center + offset, Color(CORD_COLOR, alpha * 0.8), CORD_WIDTH, true
	)
	for end in [center - offset, center + offset]:
		ShapePaint.circle(item.get_canvas_item(), end, WEIGHT, Color(WEIGHT_COLOR, alpha))


## 出どころから対象へ、上へ膨らむ弧の上の1点。
func _arc_point(start: Vector2, end: Vector2, progress: float) -> Vector2:
	var lift := start.distance_to(end) * ARC * 4.0 * progress * (1.0 - progress)
	return start.lerp(end, progress) - Vector2(0.0, lift)
