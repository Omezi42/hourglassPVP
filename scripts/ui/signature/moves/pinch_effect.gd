extends SignatureMove
## ひとつまみ(GameDesign.md 9章):対象の真上に指先が2本現れて砂をひとつまみし、開いた指先から
## こぼれた砂が対象へ降りたところで金色の輪が広がる(砂を落とす+攻撃力+1を1回で見せる)。

const APPEAR := 0.16
const PINCH := 0.2
const SPRINKLE := 0.26
const RING := 0.32
## 指先の置き場所(対象の中心から上へ)と、開いたとき・閉じたときの間隔、指の長さと太さ。
const LIFT := 74.0
const OPEN := 16.0
const CLOSED := 4.0
const FINGER := 26.0
const THICK := 9.0
const GRAINS := 8
const FINGER_COLOR := Color(0.93, 0.80, 0.66, 1.0)


func impact_at() -> float:
	return APPEAR + PINCH + SPRINKLE


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var appear := ease(phase(t, 0.0, APPEAR), 0.5)
	var tips := targets[0] - Vector2(0.0, LIFT)
	var close := back_out(phase(t, APPEAR, PINCH * 0.6))
	var release := ease(phase(t, APPEAR + PINCH, SPRINKLE * 0.4), 0.6)
	var gap := lerpf(OPEN, CLOSED, close * (1.0 - release)) if close > 0.0 else OPEN
	for side: float in [-1.0, 1.0]:
		var tip := tips + Vector2(side * gap * 0.5, 0.0)
		var root := tip + Vector2(side * FINGER * 0.35, -FINGER)
		_finger(item, root, tip, alpha * appear)
	var fall := phase(t, APPEAR + PINCH, SPRINKLE)
	if fall > 0.0 and fall < 1.0:
		for i in range(GRAINS):
			var s := fall - float(i) / float(GRAINS) * 0.4
			if s <= 0.0:
				continue
			var drift := (SignaturePaint.jitter(i, 29) - 0.5) * 10.0
			var at := tips.lerp(targets[0], minf(s * s, 1.0)) + Vector2(drift, 0.0)
			item.draw_circle(at, 2.0, Color(SignaturePaint.SAND, alpha))
	SignaturePaint.boon_ring(item, targets[0], phase(t, impact_at(), RING), alpha)


func _finger(item: CanvasItem, root: Vector2, tip: Vector2, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var dark := Color(UiPalette.OUTLINE_DARK, alpha * 0.7)
	item.draw_line(root, tip, dark, THICK + 2.0, true)
	item.draw_circle(tip, (THICK + 2.0) * 0.5, dark)
	item.draw_line(root, tip, Color(FINGER_COLOR, alpha), THICK, true)
	item.draw_circle(tip, THICK * 0.5, Color(FINGER_COLOR, alpha))
	var nail := tip.lerp(root, 0.22)
	item.draw_circle(nail, THICK * 0.22, Color(FINGER_COLOR.lightened(0.4), alpha))
