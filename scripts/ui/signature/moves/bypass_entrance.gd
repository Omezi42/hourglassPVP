extends SignatureMove
## 抜け道の登場(GameDesign.md 9章):駒の足元から光る小道がうねりながら相手の側へ伸び、
## 先に矢じりが灯ってから消える(守護の脇をすり抜ける印)。

const GROW := 0.42
const HOLD := 0.18
## 小道の長さ(上へ)・うねりの幅と回数・点の数、矢じりの大きさ。
const LENGTH := 150.0
const WAVE := 18.0
const TURNS := 1.5
const STEPS := 28
const HEAD := 8.0
const PATH_COLOR := Color(0.62, 0.92, 0.72, 1.0)


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + GROW + HOLD + FADE


func sound() -> int:
	return SoundBank.Sfx.SIG_BYPASS


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var grow := ease(phase(t, impact_at(), GROW), 0.6)
	var path := PackedVector2Array()
	var count := maxi(2, roundi(STEPS * grow))
	for i in range(count + 1):
		var s := float(i) / float(STEPS)
		path.append(from + Vector2(sin(s * TAU * TURNS) * WAVE, -LENGTH * s))
	ShapePaint.polyline(ci, path, Color(UiPalette.INK_950, alpha * 0.5), 5.0, true)
	ShapePaint.polyline(ci, path, Color(PATH_COLOR, alpha), 2.4, true)
	var tip := path[path.size() - 1]
	var dir := (tip - path[path.size() - 2]).normalized()
	var head := PackedVector2Array(
		[
			tip + dir * HEAD,
			tip - dir * HEAD * 0.5 + dir.orthogonal() * HEAD * 0.7,
			tip - dir * HEAD * 0.5 - dir.orthogonal() * HEAD * 0.7,
		]
	)
	ShapePaint.colored_polygon(ci, head, Color(PATH_COLOR, alpha))
