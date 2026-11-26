extends SignatureMove
## 未来視(GameDesign.md 9章):撃った位置の上に深い藍の札が浮かんで表へ返り、三日月の札から銀の星図の線が
## 星をたどって行き先(場に出るなら空いた台座、手札に加えるなら自分の情報帯)へ伸び、札が線を歩くように下って、
## 届いたところで金色の輪(手札なら光の輪)が広がる。

const APPEAR := 0.12
const FLIP := 0.2
const WALK := 0.36
## 札の位置(撃った位置から)と高さ、星図が途中で寄る星(行き先までの3分の1・3分の2から)。
const LIFT := Vector2(0.0, -30.0)
const CARD := 40.0
const BENDS: Array[Vector2] = [Vector2(-18.0, -26.0), Vector2(16.0, -18.0)]


func impact_at() -> float:
	return APPEAR + FLIP + WALK


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var shown := minf(phase(t, 0.0, APPEAR) * 1.5, 1.0)
	var card_at := from + LIFT
	var target := targets[0]
	var points := PackedVector2Array([card_at])
	for i in BENDS.size():
		points.append(card_at.lerp(target, float(i + 1) / float(BENDS.size() + 1)) + BENDS[i])
	points.append(target)
	var walk := phase(t, APPEAR + FLIP, WALK)
	ForesightPaint.star_chart(item, points, minf(walk * 1.6, 1.0), alpha * 0.9)
	if t < impact_at():
		var at := ForesightPaint.along(points, ease(walk, 1.4))
		var turn := ease(phase(t, APPEAR, FLIP), 0.6)
		var sway := sin(walk * TAU * 2.0) * 0.12 * walk
		ForesightPaint.tarot(item, at, CARD * (1.0 - 0.4 * walk), turn, sway, alpha * shown)
		return
	var land := phase(t, impact_at(), FADE)
	if style == CardEnums.EffectVisualStyle.DESCEND:
		SignaturePaint.boon_ring(item, target, land, alpha)
	else:
		ForesightPaint.next_star(item, target, 1.0 + 0.5 * land, alpha, land)
		SignaturePaint.pulse_ring(item, target, land, alpha)
