extends SignatureMove
## シビルの登場(GameDesign.md 9章):着地すると、台座の左右から銀の霊気が2筋うねりながら立ちのぼって頭上で合わさり、
## そこから星図の線が星を5つ結んで、いちばん先の星が瞬いてから薄れる(山札の一番上が見えている印)。

const RISE := 0.24
const CHART := 0.24
const HOLD := 0.16
## 霊気の根元の開き(台座の中心から)、合わさる高さ、うねりの幅と太さ、星図の星の並び(台座の中心から)。
const ROOT := 42.0
const MEET := 136.0
const SWAY := 10.0
const WISP := 5.0
const WISP_STEPS := 14
const STARS: Array[Vector2] = [
	Vector2(-52.0, -132.0),
	Vector2(-24.0, -150.0),
	Vector2(4.0, -140.0),
	Vector2(30.0, -158.0),
	Vector2(58.0, -146.0),
]


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + RISE + CHART + HOLD + FADE


func sound() -> int:
	return SoundBank.Sfx.SIG_SIBYL


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var alpha := fade_alpha(t)
	var rise := ease(phase(t, impact_at(), RISE), 0.7)
	var wisp_alpha := alpha * (1.0 - phase(t, impact_at() + RISE + CHART * 0.5, CHART))
	for side: float in [-1.0, 1.0]:
		_wisp(item, side, rise, wisp_alpha)
	var points := PackedVector2Array()
	for offset in STARS:
		points.append(from + offset)
	var chart := phase(t, impact_at() + RISE, CHART)
	ForesightPaint.star_chart(item, points, chart, alpha)
	var lit := phase(t, impact_at() + RISE + CHART, HOLD + FADE)
	if lit > 0.0:
		ForesightPaint.next_star(
			item, points[points.size() - 1], 1.0 + 0.6 * sin(lit * PI), alpha, lit * 2.0
		)


## 台座の `side` の側から頭上の合わさる所までの霊気。`rise` まで立ちのぼり、先ほど濃い。
func _wisp(item: CanvasItem, side: float, rise: float, alpha: float) -> void:
	if alpha <= 0.0 or rise <= 0.0:
		return
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for i in range(WISP_STEPS + 1):
		var s := rise * float(i) / float(WISP_STEPS)
		var x := side * ROOT * (1.0 - s) + side * sin(s * TAU * 1.5) * SWAY * (1.0 - s * 0.5)
		points.append(from + Vector2(x, -MEET * s))
		colors.append(Color(UiPalette.ORACLE_VAPOR, alpha * (0.35 + 0.5 * s / maxf(rise, 0.01))))
	ShapePaint.polyline_colors(item.get_canvas_item(), points, colors, WISP, true)
