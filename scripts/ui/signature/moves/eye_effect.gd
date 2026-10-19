extends SignatureMove
## アイの設置(GameDesign.md 9章):対象の真上に目が開いて瞳に渦巻きが回り、渦が止まったところで
## 対象が返る(反転。にらまれてひっくり返る)。

const OPEN := 0.14
const SPIRAL := 0.42
## 目の置き場所(対象の中心から上へ)と横・縦の半幅、瞳の半径と渦巻きの巻き数・回る量。
const LIFT := 76.0
const HALF := Vector2(24.0, 12.0)
const STEPS := 16
const IRIS := 9.0
const TURNS := 2.5
const SPIN_TURNS := 3.0
const SPIRAL_POINTS := 40
const WHITE := Color(1.0, 0.98, 0.94, 1.0)


func impact_at() -> float:
	return OPEN + SPIRAL


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var center := targets[0] - Vector2(0.0, LIFT)
	var open := ease(phase(t, 0.0, OPEN), 0.6) * (1.0 - phase(t, impact_at(), FADE))
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	for i in range(STEPS + 1):
		var s := float(i) / float(STEPS)
		var x := lerpf(-HALF.x, HALF.x, s)
		var bulge := sin(s * PI)
		upper.append(center + Vector2(x, -HALF.y * open * bulge))
		lower.append(center + Vector2(x, HALF.y * open * bulge))
	if open > 0.08:
		var shape := upper.duplicate()
		var back := lower.duplicate()
		back.reverse()
		shape.append_array(back)
		ShapePaint.colored_polygon(ci, shape, Color(WHITE, alpha * 0.92))
		var size := IRIS * minf(open * 1.3, 1.0)
		ShapePaint.circle(ci, center, size, Color(SignaturePaint.SPIN.darkened(0.35), alpha))
		var turn := -TAU * SPIN_TURNS * ease(phase(t, OPEN, SPIRAL), 0.4)
		var spiral := PackedVector2Array()
		for i in range(SPIRAL_POINTS + 1):
			var s := float(i) / float(SPIRAL_POINTS)
			spiral.append(center + Vector2.from_angle(turn + s * TAU * TURNS) * size * s)
		ShapePaint.polyline(ci, spiral, Color(WHITE, alpha), 1.6, true)
	var lid := Color(SignaturePaint.SPIN, alpha)
	ShapePaint.polyline(ci, upper, Color(UiPalette.OUTLINE_DARK, alpha * 0.6), 4.0, true)
	ShapePaint.polyline(ci, upper, lid, 2.4, true)
	ShapePaint.polyline(ci, lower, lid, 1.6, true)
