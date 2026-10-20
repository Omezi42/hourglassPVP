extends SignatureMove
## ホイールの反転(GameDesign.md 9章):駒の上に車輪が現れて勢いよく空回りし、転がり出して相手のHPの
## 器へ体当たりする(打撃)。

const APPEAR := 0.1
const SPIN := 0.24
const ROLL := 0.26
## 車輪の置き場所(駒の中心から上へ)と半径、輻の数、空回りの速さ。
const LIFT := 62.0
const RADIUS := 15.0
const SPOKES := 6
const SPIN_SPEED := 30.0
const WOOD := Color(0.56, 0.36, 0.2, 1.0)


func impact_at() -> float:
	return APPEAR + SPIN + ROLL


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty() or t >= impact_at():
		return
	var alpha := fade_alpha(t) * ease(phase(t, 0.0, APPEAR), 0.5)
	var hub := from - Vector2(0.0, LIFT)
	var spin := phase(t, APPEAR, SPIN)
	var roll := ease(phase(t, APPEAR + SPIN, ROLL), 2.0)
	var at := hub.lerp(targets[0], roll)
	var turn := SPIN_SPEED * (spin * spin * SPIN * 0.5 + roll * ROLL)
	_wheel(item, at, turn, alpha)
	if spin > 0.3 and roll <= 0.0:
		for k in range(2):
			var a := turn + PI * float(k)
			ShapePaint.arc(
				item.get_canvas_item(),
				at,
				RADIUS + 5.0,
				a,
				a + 0.9,
				8,
				Color(1, 1, 1, alpha * 0.6),
				1.4,
				true
			)


func _wheel(item: CanvasItem, at: Vector2, turn: float, alpha: float) -> void:
	var ci := item.get_canvas_item()
	ShapePaint.arc(
		ci, at, RADIUS, 0.0, TAU, 32, Color(UiPalette.OUTLINE_DARK, alpha * 0.8), 5.6, true
	)
	ShapePaint.arc(ci, at, RADIUS, 0.0, TAU, 32, Color(WOOD, alpha), 3.6, true)
	for i in range(SPOKES):
		var dir := Vector2.from_angle(turn + TAU * float(i) / float(SPOKES))
		item.draw_line(at, at + dir * RADIUS, Color(WOOD.lightened(0.15), alpha), 2.0, true)
	ShapePaint.circle(ci, at, 3.6, Color(UiPalette.BRASS_HIGHLIGHT, alpha))
