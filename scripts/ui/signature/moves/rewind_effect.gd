extends SignatureMove
## 巻き戻し(GameDesign.md 9章):対象の上に時計の文字盤が現れ、長針が逆回りに2周
## (戻す砂の粒の数)してから、恵与の金色の輪が広がる。

const APPEAR := 0.2
const REWIND := 0.56
const RING := 0.3
const TURNS := 2.0
const RADIUS := 22.0
## 文字盤の置き場所(対象の中心から)と、現れるときに降りてくる量。
const LIFT := 72.0
const DROP := 12.0
## 長針の残像。回る速さに比例して長く引く。
const GHOSTS := 5
const GHOST_SPAN := 0.9


func impact_at() -> float:
	return APPEAR + REWIND


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var intro := ease(phase(t, 0.0, APPEAR), 0.5)
	var alpha := intro * fade_alpha(t)
	var center := targets[0] - Vector2(0.0, LIFT + DROP * (1.0 - intro))
	var radius := RADIUS * (0.6 + 0.4 * intro)
	var turn := phase(t, APPEAR, REWIND)
	var hand := -TAU * TURNS * (0.5 - 0.5 * cos(turn * PI))
	SignaturePaint.clock_dial(item, center, radius, hand, alpha)
	var trail := GHOST_SPAN * sin(turn * PI)
	for i in range(1, GHOSTS + 1):
		var k := float(i) / float(GHOSTS)
		var tip := center + Vector2.UP.rotated(hand + trail * k) * radius * 0.72
		item.draw_line(
			center, tip, Color(UiPalette.BRASS_DARK, alpha * 0.35 * (1.0 - k)), 1.6, true
		)
	SignaturePaint.boon_ring(item, targets[0], phase(t, impact_at(), RING), alpha)
