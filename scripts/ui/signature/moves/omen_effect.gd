extends SignatureMove
## 予兆(GameDesign.md 9章):撃った位置の上に深い藍の札が2枚並んで表へ返り、右の札だけが銀の星図の線をたどって
## 自分の情報帯(手札の側)へ飛び、届いたところで光の輪が広がる。左の札は傾きながら薄れて沈む(墓地へ)。

const APPEAR := 0.12
const FLIP := 0.2
const FLY := 0.34
## 2枚の位置(撃った位置から)と札の高さ、星図が途中で寄る星(撃った位置と行き先の中ほどから)、褪せた札の落ちる距離。
const PAIR := Vector2(24.0, -18.0)
const CARD := 40.0
const BEND := Vector2(-30.0, -40.0)
const DROP := 36.0


func impact_at() -> float:
	return APPEAR + FLIP + FLY


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var shown := minf(phase(t, 0.0, APPEAR) * 1.5, 1.0)
	var turn := ease(phase(t, APPEAR, FLIP), 0.6)
	var fly := phase(t, APPEAR + FLIP, FLY)
	var left := from + Vector2(-PAIR.x, PAIR.y)
	var right := from + PAIR
	var target := targets[0]
	var bend := from.lerp(target, 0.5) + BEND
	var points := PackedVector2Array([right, bend, target])
	ForesightPaint.star_chart(item, points, fly, alpha * 0.9)
	var fall := ease(fly, 2.0)
	ForesightPaint.tarot(
		item,
		left + Vector2(0.0, DROP * fall),
		CARD,
		turn,
		-0.08 - fall * 0.5,
		alpha * shown * (1.0 - fall)
	)
	var at := ForesightPaint.along(points, ease(fly, 0.7))
	var size := CARD * (1.0 - 0.45 * fly)
	if t < impact_at():
		ForesightPaint.tarot(item, at, size, turn, 0.08 * (1.0 - fly), alpha * shown, true)
	else:
		var lit := phase(t, impact_at(), FADE)
		ForesightPaint.next_star(item, target, 1.0 + 0.5 * lit, alpha, lit)
		SignaturePaint.pulse_ring(item, target, lit, alpha)
