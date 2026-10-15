extends SignatureMove
## ディレイの落砂(GameDesign.md 9章):駒の上にストップウォッチが現れ、針が1目盛りぶん遅れて
## 進んで止まった瞬間、光の拍が対象へ跳んで返る。

const APPEAR := 0.18
const WAIT := 0.2
const TICK := 0.12
const PULSE := 0.24
const RADIUS := 20.0
## 文字盤の置き場所(駒の中心から)と、現れるときに降りてくる量。
const LIFT := 70.0
const DROP := 10.0
## 竜頭(上のつまみ)の大きさ。
const CROWN := Vector2(8.0, 5.0)
## 光の拍の大きさと、跳ぶ弧の高さ。
const BEAT := 6.0
const ARC := 36.0
const TRAIL := 4
const TRAIL_GAP := 0.06


func impact_at() -> float:
	return APPEAR + WAIT + TICK + PULSE


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var intro := ease(phase(t, 0.0, APPEAR), 0.5)
	var alpha := intro * fade_alpha(t)
	var center := _center(intro)
	var tick := back_out(phase(t, APPEAR + WAIT, TICK))
	_crown(item, center, alpha)
	SignaturePaint.clock_dial(item, center, RADIUS, TAU / 12.0 * tick, alpha)
	var beat := phase(t, APPEAR + WAIT + TICK, PULSE)
	if beat > 0.0 and beat < 1.0:
		for i in range(TRAIL, -1, -1):
			var k := maxf(beat - TRAIL_GAP * i, 0.0)
			var at := _arc(center, targets[0], k)
			var a := alpha * (1.0 - float(i) / float(TRAIL + 1))
			item.draw_circle(at, BEAT * (1.0 - 0.15 * i), Color(SignaturePaint.SPIN, a), true)
	SignaturePaint.ripple(
		item, targets[0], 30.0 * phase(t, impact_at(), FADE), alpha, SignaturePaint.SPIN
	)


func _center(intro: float) -> Vector2:
	return from - Vector2(0.0, LIFT + DROP * (1.0 - intro))


func _crown(item: CanvasItem, center: Vector2, alpha: float) -> void:
	var top := center - Vector2(0.0, RADIUS + CROWN.y)
	var rect := Rect2(top - Vector2(CROWN.x * 0.5, 0.0), CROWN + Vector2(0.0, 2.0))
	item.draw_rect(rect.grow(1.2), Color(UiPalette.OUTLINE_DARK, alpha * 0.8))
	item.draw_rect(rect, Color(UiPalette.BRASS_HIGHLIGHT, alpha))


func _arc(start: Vector2, end: Vector2, k: float) -> Vector2:
	return start.lerp(end, k) - Vector2(0.0, ARC * sin(k * PI))
