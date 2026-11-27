extends SignatureMove
## 溢れ砂(GameDesign.md 9章):撃った位置に縁まで満ちた素焼きの鉢が現れて揺れ、波頭が縁を越えて
## 水の塊になり、弧を描いて対象の駒へ打ち当たってしぶきが散る(打撃。1点ごとに繰り返し、2回目からは短縮版)。

const BRIM := 0.14
const FLIGHT := 0.22
## 鉢の中心(出どころから)と半幅・高さ、揺れ、水の塊の弧の高さと大きさ。
const BOWL := Vector2(0.0, -20.0)
const BOWL_HALF := Vector2(24.0, 13.0)
const SLOSH := 0.2
const ARC := 50.0
const SLUG := 9.0


func impact_at() -> float:
	return BRIM + FLIGHT


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var center := from + BOWL
	var slosh := sin(phase(t, 0.0, BRIM) * PI * 2.0) * SLOSH
	_bowl(item, center, slosh, alpha * (1.0 - phase(t, impact_at(), FADE)))
	var lip := center + Vector2(BOWL_HALF.x * 0.7, -BOWL_HALF.y)
	var target := targets[0]
	var flight := phase(t, BRIM, FLIGHT)
	if flight > 0.0 and flight < 1.0:
		var s := ease(flight, -1.6)
		var at := PourPaint.along(lip, target, ARC, s)
		var tail := PourPaint.along(lip, target, ARC, maxf(s - 0.18, 0.0))
		PourPaint.stream(item, lip, target, ARC, s, maxf(s - 0.25, 0.0), alpha)
		ShapePaint.circle(ci, at, SLUG + 2.0, Color(UiPalette.POUR_DEEP, alpha * 0.85))
		ShapePaint.circle(ci, at, SLUG, Color(UiPalette.POUR_WATER, alpha))
		ShapePaint.circle(
			ci,
			at + (tail - at).normalized() * SLUG * 0.3,
			SLUG * 0.45,
			Color(UiPalette.POUR_FOAM, alpha)
		)
	if t >= impact_at():
		var burst := phase(t, impact_at(), FADE)
		PourPaint.splash(item, target, burst, alpha, 1.4)


## 縁まで満ちた素焼きの鉢。`slosh` だけ水面が傾き、高い側から泡が縁を越える。
func _bowl(item: CanvasItem, center: Vector2, slosh: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var shell := PackedVector2Array()
	for i in range(13):
		var a := PI * float(i) / 12.0
		shell.append(center + Vector2(cos(a) * BOWL_HALF.x, sin(a) * BOWL_HALF.y * 1.6 - 2.0))
	ShapePaint.convex_polygon(
		ci, ForesightPaint.grown(shell, center, 2.0), Color(UiPalette.INK_950, alpha)
	)
	ShapePaint.convex_polygon(ci, shell, Color(UiPalette.TERRACOTTA, alpha))
	var surface := center + Vector2(0.0, -2.0)
	var half := Vector2(BOWL_HALF.x, 0.0).rotated(slosh)
	item.draw_line(surface - half, surface + half, Color(UiPalette.POUR_WATER, alpha), 6.0, true)
	item.draw_line(surface - half, surface + half, Color(UiPalette.POUR_FOAM, alpha), 2.0, true)
