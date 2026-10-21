extends SignatureMove
## グロウの反転(GameDesign.md 9章):駒の内側から暖かい光がふくらんで脈打ち、光の粒が駒の周りを1周して
## から金色の輪が広がる(恵与)。

const SWELL := 0.28
const ORBIT := 0.3
const RING := 0.32
## 光の大きさと脈打つ回数、粒が回る楕円の半径と尾の点の数。
const GLOW := 34.0
const THROBS := 2.0
const PATH := Vector2(44.0, 58.0)
const TAIL := 8
const WARM := Color(1.0, 0.86, 0.5, 1.0)


func impact_at() -> float:
	return SWELL + ORBIT


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var center := targets[0]
	var swell := phase(t, 0.0, SWELL)
	var glow := ease(minf(swell * 2.0, 1.0), 0.5) * (1.0 - phase(t, SWELL, ORBIT + RING) * 0.8)
	var throb := 1.0 + 0.15 * sin(swell * TAU * THROBS)
	if glow > 0.02:
		for k in range(3):
			var r := GLOW * throb * glow * (1.0 - float(k) * 0.28)
			ShapePaint.circle(ci, center, r, Color(WARM, alpha * 0.16))
	var orbit := phase(t, SWELL, ORBIT)
	if orbit > 0.0 and orbit < 1.0:
		var head := -PI * 0.5 + TAU * ease(orbit, -1.4)
		for i in range(TAIL, -1, -1):
			var a := head - 0.12 * float(i)
			var at := center + Vector2(cos(a) * PATH.x, sin(a) * PATH.y)
			var size := 3.6 * (1.0 - float(i) / float(TAIL + 1))
			ShapePaint.circle(ci, at, size, Color(WARM if i > 0 else Color.WHITE, alpha))
	SignaturePaint.boon_ring(item, center, phase(t, impact_at(), RING), alpha)
