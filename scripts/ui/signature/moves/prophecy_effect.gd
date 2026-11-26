extends SignatureMove
## 予言(GameDesign.md 9章):撃った位置の上に深い藍の札が扇に5枚開き、まん中の札が抜け出して表へ返り太陽の札になる。
## 太陽の札は銀の星図の線を一息に駆けて空いた台座へ降り、届いたところで金色の輪が広がる(恵与)。

const FAN := 0.18
const DRAW := 0.2
const RUN := 0.26
const CARDS := 5
const MIDDLE := 2
## 扇の要(撃った位置から)・開く角度・札の高さ、抜け出す高さ、星図が寄る星(行き先までの半ばから)。
const PIVOT := Vector2(0.0, -6.0)
const SPREAD := 0.34
const CARD := 38.0
const PULL := 30.0
const BEND := Vector2(-24.0, -34.0)


func impact_at() -> float:
	return FAN + DRAW + RUN


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var fan := ease(phase(t, 0.0, FAN), 0.5)
	var pull := phase(t, FAN, DRAW)
	var run := phase(t, FAN + DRAW, RUN)
	var pivot := from + PIVOT
	var fan_alpha := alpha * minf(fan * 2.0, 1.0) * (1.0 - run)
	for i in range(CARDS):
		if i == MIDDLE:
			continue
		var tilt := (float(i) - float(MIDDLE)) * SPREAD * fan
		var at := pivot + Vector2(0.0, -CARD * 0.5).rotated(tilt)
		ForesightPaint.tarot(item, at, CARD, 0.0, tilt, fan_alpha)
	var lifted := pivot - Vector2(0.0, CARD * 0.5 + PULL * ease(pull, 0.6))
	var target := targets[0]
	var points := PackedVector2Array([lifted, lifted.lerp(target, 0.5) + BEND, target])
	ForesightPaint.star_chart(item, points, minf(run * 1.4, 1.0), alpha * 0.9)
	if t < impact_at():
		var at := ForesightPaint.along(points, ease(run, 1.6))
		ForesightPaint.tarot(
			item, at, CARD * (1.0 - 0.35 * run), pull, 0.0, alpha * minf(fan * 2.0, 1.0), true
		)
		return
	SignaturePaint.boon_ring(item, target, phase(t, impact_at(), FADE), alpha)
