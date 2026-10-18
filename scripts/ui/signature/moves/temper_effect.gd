extends SignatureMove
## テンパーの被弾(GameDesign.md 9章):駒の縁が一瞬赤く灼けて光り、上から水が一筋かかって白い湯気が
## 立ち、湯気が消えたところで金色の輪が広がる(焼き入れ。恵与)。

const HEAT := 0.18
const QUENCH := 0.14
const STEAM := 0.32
const RING := 0.32
## 灼ける縁(駒の中心からの半径)と、水が落ち始める高さ・かかる所、湯気の数と昇る高さ。
const EDGE := Vector2(34.0, 52.0)
const WATER_FROM := 120.0
const WATER_TO := 48.0
const PUFFS := 6
const RISE := 46.0
const PUFF := 7.0
const HOT := Color(1.0, 0.34, 0.12, 1.0)
const STEAM_COLOR := Color(0.96, 0.97, 1.0, 1.0)


func impact_at() -> float:
	return HEAT + QUENCH + STEAM


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var center := targets[0]
	var heat := ease(phase(t, 0.0, HEAT), 0.5) * (1.0 - phase(t, HEAT, QUENCH + STEAM * 0.3))
	if heat > 0.0:
		UiPaint.draw_ellipse_ring(ci, center, EDGE, Color(HOT, alpha * heat * 0.4), 7.0, 40)
		UiPaint.draw_ellipse_ring(
			ci, center, EDGE, Color(HOT.lightened(0.3), alpha * heat), 2.4, 40
		)
	var quench := phase(t, HEAT, QUENCH)
	if quench > 0.0 and t < HEAT + QUENCH + STEAM * 0.3:
		var top := center - Vector2(0.0, WATER_FROM)
		var bottom := center - Vector2(0.0, WATER_TO)
		var head := top.lerp(bottom, ease(quench, 1.6))
		var tail := top.lerp(bottom, phase(t, HEAT + QUENCH, STEAM * 0.3))
		item.draw_line(tail, head, Color(SignaturePaint.WATER, alpha), 3.0, true)
	var steam := phase(t, HEAT + QUENCH, STEAM)
	if steam > 0.0 and steam < 1.0:
		for i in range(PUFFS):
			var q := clampf(steam - SignaturePaint.jitter(i, 91) * 0.3, 0.0, 1.0)
			if q <= 0.0:
				continue
			var x := (SignaturePaint.jitter(i, 92) - 0.5) * EDGE.x * 1.6
			var at := center + Vector2(x + sin(q * TAU) * 4.0, -WATER_TO - RISE * ease(q, 0.6))
			ShapePaint.circle(
				ci, at, PUFF * (0.5 + q), Color(STEAM_COLOR, alpha * 0.55 * (1.0 - q))
			)
	SignaturePaint.boon_ring(item, center, phase(t, impact_at(), RING), alpha)
