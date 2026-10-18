extends SignatureMove
## フラスコの余砂(GameDesign.md 9章):銘板の上にフラスコが現れて栓が抜け、薬液の泡が3つ
## 立ちのぼって自分のHPの器へ流れ着き、はじけたところで金色の輪が広がる(恵与)。

const APPEAR := 0.12
const POP := 0.14
const FLOAT := 0.44
const RING := 0.32
## フラスコの置き場所(銘板から上へ、胴の中心)と、胴の半径・首の太さと長さ、栓の大きさ。
const LIFT := 40.0
const BULB := 12.0
const NECK := Vector2(4.0, 10.0)
const CORK := Vector2(4.5, 3.5)
const CORK_FLY := Vector2(10.0, -26.0)
## 泡の数と大きさ、立ちのぼる高さ、泡ごとの遅れと横揺れ。
const BUBBLES := 3
const BUBBLE := 5.0
const RISE := 34.0
const BUBBLE_LAG := 0.12
const SWAY := 7.0
const LIQUID := Color(0.62, 0.95, 0.66, 1.0)
const GLASS := Color(0.88, 0.95, 1.0, 1.0)
const CORK_COLOR := Color(0.72, 0.52, 0.32, 1.0)


func impact_at() -> float:
	return APPEAR + POP + FLOAT


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var appear := ease(phase(t, 0.0, APPEAR), 0.5)
	var bulb := from - Vector2(0.0, LIFT)
	var mouth := bulb - Vector2(0.0, BULB + NECK.y)
	_flask(item, bulb, alpha * appear)
	var pop := phase(t, APPEAR, POP)
	var cork := mouth - Vector2(0.0, CORK.y) + CORK_FLY * ease(pop, 0.5)
	var cork_alpha := alpha * appear * (1.0 - phase(t, APPEAR + POP, POP))
	UiPaint.fill_ellipse(ci, cork, CORK, Color(CORK_COLOR, cork_alpha), 12)
	for i in range(BUBBLES):
		var q := phase(
			t, APPEAR + POP + BUBBLE_LAG * float(i), FLOAT - BUBBLE_LAG * float(BUBBLES - 1)
		)
		if q <= 0.0 or q >= 1.0:
			continue
		var top := mouth - Vector2(0.0, RISE)
		var rise := ease(phase(q, 0.0, 0.4), 0.5)
		var drift := ease(phase(q, 0.35, 0.65), 1.4)
		var at := mouth.lerp(top, rise).lerp(targets[0], drift)
		at.x += sin((q + float(i) * 0.3) * TAU) * SWAY * (1.0 - drift)
		_bubble(item, at, BUBBLE * (0.7 + 0.15 * float(i)), alpha)
	SignaturePaint.boon_ring(item, targets[0], phase(t, impact_at(), RING), alpha)


## 丸底のフラスコ。胴に薬液を半分ほど入れて描く。
func _flask(item: CanvasItem, bulb: Vector2, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var neck := Rect2(bulb - Vector2(NECK.x, BULB + NECK.y), Vector2(NECK.x * 2.0, NECK.y + 2.0))
	ShapePaint.circle(ci, bulb, BULB + 1.4, Color(UiPalette.OUTLINE_DARK, alpha * 0.7))
	item.draw_rect(neck.grow(1.4), Color(UiPalette.OUTLINE_DARK, alpha * 0.7))
	ShapePaint.circle(ci, bulb, BULB, Color(GLASS, alpha * 0.85))
	item.draw_rect(neck, Color(GLASS, alpha * 0.85))
	ShapePaint.circle(ci, bulb + Vector2(0.0, BULB * 0.25), BULB * 0.72, Color(LIQUID, alpha))
	ShapePaint.circle(
		ci, bulb + Vector2(-BULB * 0.4, -BULB * 0.35), BULB * 0.18, Color(1, 1, 1, alpha * 0.8)
	)


## 縁の濃い透けた泡。
func _bubble(item: CanvasItem, at: Vector2, radius: float, alpha: float) -> void:
	var ci := item.get_canvas_item()
	ShapePaint.circle(ci, at, radius, Color(LIQUID, alpha * 0.35))
	ShapePaint.arc(ci, at, radius, 0.0, TAU, 20, Color(LIQUID, alpha), 1.4, true)
	ShapePaint.circle(
		ci, at + Vector2(-radius * 0.35, -radius * 0.35), radius * 0.22, Color(1, 1, 1, alpha)
	)
