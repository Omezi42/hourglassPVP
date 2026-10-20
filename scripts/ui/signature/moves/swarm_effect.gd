extends SignatureMove
## スウォームの設置(GameDesign.md 9章):駒から小さな羽虫の群れが飛び立ち、渦を巻きながら相手のHPの器へ
## 群がって当たる(打撃)。

const TAKEOFF := 0.16
const SWARM := 0.46
## 羽虫の数と、群れが集まる高さ(駒の中心から上へ)、渦の半径と回る量。
const BUGS := 8
const LIFT := 56.0
const ORBIT := 26.0
const TURNS := 1.6
## 羽虫の体・翅の大きさと羽ばたきの速さ。
const BODY := 2.4
const WING := Vector2(3.4, 2.0)
const FLUTTER := 70.0
const BUG := Color(0.3, 0.24, 0.16, 1.0)
const WING_COLOR := Color(0.95, 0.92, 0.8, 1.0)


func impact_at() -> float:
	return TAKEOFF + SWARM


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty() or t >= impact_at():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var hub := from - Vector2(0.0, LIFT)
	var swarm := ease(phase(t, TAKEOFF, SWARM), 1.6)
	var center := hub.lerp(targets[0], swarm)
	for i in range(BUGS):
		var takeoff := phase(t, TAKEOFF * SignaturePaint.jitter(i, 131), TAKEOFF)
		var angle := TAU * float(i) / float(BUGS) + t * TAU * TURNS
		var radius := ORBIT * (0.6 + 0.4 * SignaturePaint.jitter(i, 132)) * (1.0 - swarm)
		var orbit := center + Vector2(cos(angle), sin(angle) * 0.6) * radius
		var at := from.lerp(orbit, ease(takeoff, 0.5))
		var a := alpha * minf(takeoff * 4.0, 1.0)
		var flap := absf(sin(t * FLUTTER + float(i)))
		for side: float in [-1.0, 1.0]:
			UiPaint.fill_ellipse(
				ci,
				at + Vector2(side * WING.x * 0.8, -1.5),
				WING * Vector2(1.0, flap + 0.2),
				Color(WING_COLOR, a * 0.7),
				8
			)
		ShapePaint.circle(ci, at, BODY, Color(BUG, a))
