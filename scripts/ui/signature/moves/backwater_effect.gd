extends SignatureMove
## 背水の陣(GameDesign.md 9章):撃った位置の足元から水が背後へ引いていき、引ききった水が大波になって
## 相手の列へ押し寄せ、波頭が届いた瞬間に相手の駒すべてへ打ち当たってしぶきが上がる(打撃。盤面を揺らす)。

const RECEDE := 0.2
const SURGE := 0.4
## 引き波の輪の数・広がり・潰す比。
const RIPPLES := 3
const RIPPLE := 56.0
const SQUASH := 0.34
## 大波の横のはみ出し、波頭の高さ・うねりの数、波の厚み、泡の数。
const OVERRUN := 70.0
const CREST := 22.0
const SWELLS := 3.0
const BODY := 72.0
## 大波が押し寄せ始める、相手の列からの最小の距離。
const RUN_UP := 150.0
const FOAM_DOTS := 26
const WAVE_STEPS := 32
## しぶきの粒の数と高さ。
const SPRAY := 8
const SPRAY_HEIGHT := 40.0


func impact_at() -> float:
	return RECEDE + SURGE


func draw(item: CanvasItem, t: float) -> void:
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var recede := phase(t, 0.0, RECEDE)
	if recede > 0.0 and recede < 1.0:
		for i in range(RIPPLES):
			var k := clampf(recede * 1.4 - float(i) * 0.2, 0.0, 1.0)
			if k <= 0.0 or k >= 1.0:
				continue
			var r := RIPPLE * (1.0 - ease(k, 0.6)) + 6.0
			UiPaint.draw_ellipse_ring(
				ci,
				from,
				Vector2(r, r * SQUASH),
				Color(UiPalette.FOAM, alpha * (1.0 - k) * 0.8),
				2.0,
				36
			)
	if targets.is_empty():
		return
	var row_y := 0.0
	var left := INF
	var right := -INF
	for target in targets:
		row_y += target.y
		left = minf(left, target.x)
		right = maxf(right, target.x)
	row_y /= float(targets.size())
	left = minf(left, from.x) - OVERRUN
	right = maxf(right, from.x) + OVERRUN
	var surge := phase(t, RECEDE, SURGE)
	if surge <= 0.0:
		return
	var toward := 1.0 if row_y > from.y else -1.0
	var start_y := row_y - toward * maxf(absf(row_y - from.y), RUN_UP)
	var front := lerpf(start_y, row_y, ease(surge, 1.6))
	var wave_alpha := alpha * (1.0 - phase(t, impact_at(), FADE))
	var crest := PackedVector2Array()
	for i in range(WAVE_STEPS + 1):
		var s := float(i) / float(WAVE_STEPS)
		var x := lerpf(left, right, s)
		var swell := sin((s * SWELLS + surge * 0.8) * TAU) * 0.5 + 0.5
		crest.append(Vector2(x, front - toward * CREST * swell * (0.4 + 0.6 * surge)))
	var body := crest.duplicate()
	for i in range(WAVE_STEPS, -1, -1):
		body.append(Vector2(crest[i].x, crest[i].y - toward * BODY))
	var colors := PackedColorArray()
	for i in range(body.size()):
		var deep := 0.0 if i <= WAVE_STEPS else 1.0
		colors.append(
			Color(
				UiPalette.TIDE.lerp(UiPalette.INK_950, deep * 0.4), wave_alpha * (0.88 - deep * 0.7)
			)
		)
	ShapePaint.polygon(ci, body, colors)
	ShapePaint.polyline(ci, crest, Color(UiPalette.FOAM, wave_alpha), 3.0, true)
	for i in range(FOAM_DOTS):
		var s := SignaturePaint.jitter(i, 301)
		var at := crest[int(s * float(WAVE_STEPS))]
		at.y -= toward * (2.0 + SignaturePaint.jitter(i, 302) * 6.0)
		ShapePaint.circle(
			ci, at, 1.6 + SignaturePaint.jitter(i, 303) * 1.6, Color(UiPalette.FOAM, wave_alpha)
		)
	var splash := phase(t, impact_at(), FADE)
	if splash > 0.0 and splash < 1.0:
		for target in targets:
			for i in range(SPRAY):
				var dir := Vector2.from_angle(-PI * (0.15 + 0.7 * SignaturePaint.jitter(i, 304)))
				var at := target + dir * SPRAY_HEIGHT * ease(splash, 0.5)
				at.y += 30.0 * splash * splash
				ShapePaint.circle(
					ci,
					at,
					2.6 * (1.0 - splash * 0.5),
					Color(UiPalette.FOAM, alpha * (1.0 - splash))
				)
