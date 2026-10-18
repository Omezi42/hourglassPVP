extends SignatureMove
## スリングの設置(GameDesign.md 9章):駒の上で小石が2周振り回され、放たれて弧を描き、
## 狙った駒か相手のHPの器へ当たって火花が散る(打撃)。

const WIND := 0.36
const FLIGHT := 0.28
const TURNS := 2.0
## 振り回す輪の半径と、駒の中心からの高さ。
const ORBIT := 16.0
const LIFT := 34.0
## 放物線の膨らみ(2点間の距離に対する割合)と小石の大きさ。
const ARC := 0.22
const STONE := 4.5
const STONE_COLOR := Color(0.62, 0.56, 0.48, 1.0)
const STRING_COLOR := Color(0.86, 0.78, 0.6, 1.0)


func impact_at() -> float:
	return WIND + FLIGHT


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var hub := from - Vector2(0.0, LIFT)
	var target: Vector2 = targets[0]
	if t < WIND:
		var turn := phase(t, 0.0, WIND)
		var angle := TAU * TURNS * ease(turn, 0.6)
		var stone := hub + Vector2(cos(angle), sin(angle)) * ORBIT
		item.draw_line(hub, stone, Color(STRING_COLOR, alpha * 0.8), 1.4, true)
		ShapePaint.circle(item.get_canvas_item(), stone, STONE, Color(STONE_COLOR, alpha))
		return
	var flight := phase(t, WIND, FLIGHT)
	if t < impact_at():
		ShapePaint.circle(
			item.get_canvas_item(),
			_arc_point(hub, target, flight),
			STONE,
			Color(STONE_COLOR, alpha)
		)
		return
	SignaturePaint.sparks(item, target, phase(t, impact_at(), FADE), alpha)


## 出どころから対象へ、上へ膨らむ弧の上の1点。
func _arc_point(start: Vector2, end: Vector2, progress: float) -> Vector2:
	var lift := start.distance_to(end) * ARC * 4.0 * progress * (1.0 - progress)
	return start.lerp(end, progress) - Vector2(0.0, lift)
