extends SignatureMove
## リーチの登場(GameDesign.md 9章):着地すると台座の上を太った蛭が尾から頭へ弓なりに這い出し、頭の吸盤で台座に噛みつくと
## 赤い輪が縮み、頭から赤い滴が一つ垂れる(噛みついたまま離さない)。

const CRAWL := 0.3
const BITE := 0.16
const HOLD := 0.14
const SEGMENTS := 16
## 弧の半幅・高さ(台座の上面の中心から)、尾と頭の太さ、噛みつく輪の大きさ。
const SPAN := 42.0
const RISE := 30.0
const TAIL := 9.0
const HEAD := 5.0
const BITE_RING := 22.0
const TOP := 50.0


func top_extent() -> float:
	return TOP * zoom


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + CRAWL + BITE + HOLD + FADE


func sound() -> int:
	return SoundBank.Sfx.SIG_LEECH


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var crawl := ease(phase(t, impact_at(), CRAWL), 0.7)
	var bite := phase(t, impact_at() + CRAWL, BITE)
	var drip := phase(t, impact_at() + CRAWL + BITE * 0.5, HOLD + FADE)
	var shown := maxi(int(ceil(crawl * float(SEGMENTS))), 1)
	var points: Array[Vector2] = []
	var radii: Array[float] = []
	for i in range(shown):
		var u := float(i) / float(SEGMENTS - 1)
		var a := PI * (1.0 - u)
		var swell := 0.8 + 0.4 * sin(minf(u * 1.25, 1.0) * PI)
		points.append(from + Vector2(cos(a) * SPAN, -sin(a) * RISE) * zoom)
		radii.append(lerpf(TAIL, HEAD, u * u) * swell * zoom)
	for i in range(shown):
		ShapePaint.circle(ci, points[i], radii[i] + 2.0, Color(UiPalette.INK_950, alpha))
	for i in range(shown):
		var shade := 0.85 if i % 2 == 0 else 1.0
		ShapePaint.circle(ci, points[i], radii[i], Color(UiPalette.LEECH_OLIVE * shade, alpha))
	for i in range(shown):
		ShapePaint.circle(
			ci,
			points[i] + Vector2(0.0, -radii[i] * 0.4),
			radii[i] * 0.32,
			Color(UiPalette.LEECH_STRIPE, alpha * 0.9)
		)
	if bite > 0.0 and bite < 1.0:
		ShapePaint.arc(
			ci,
			from + Vector2(SPAN, 0.0) * zoom,
			BITE_RING * (1.0 - ease(bite, 0.6)) * zoom,
			0.0,
			TAU,
			28,
			Color(UiPalette.BLOOD, alpha * (1.0 - bite)),
			2.4,
			true
		)
	if drip > 0.0 and drip < 1.0:
		var at := from + Vector2(SPAN + 6.0, 6.0 + 26.0 * drip * drip) * zoom
		ShapePaint.circle(ci, at, 4.6 * zoom, Color(UiPalette.INK_950, alpha * (1.0 - drip)))
		ShapePaint.circle(ci, at, 3.4 * zoom, Color(UiPalette.BLOOD, alpha * (1.0 - drip)))
