extends SignatureMove
## 封砂(GameDesign.md 9章):対象の真上からくすんだ封蝋の印が降りて押し付けられ、刻まれた×の印が
## 浮かんだところで効果とキーワードの色が抜ける(払拭)。

const DESCEND := 0.26
const PRESS := 0.14
const SET := 0.18
## 印が降り始める高さと、封蝋の大きさ・縁の波の数。
const FALL := 80.0
const WAX := 22.0
const SQUASH := 0.25
const LOBES := 9
const MARK := 9.0
const WAX_COLOR := Color(0.50, 0.47, 0.52, 1.0)


func impact_at() -> float:
	return DESCEND + PRESS + SET


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t) * ease(phase(t, 0.0, DESCEND * 0.4), 0.5)
	var fall := ease(phase(t, 0.0, DESCEND), 2.2)
	var press := sin(phase(t, DESCEND, PRESS) * PI)
	var at := targets[0] - Vector2(0.0, FALL * (1.0 - fall))
	var size := Vector2(WAX * (1.0 + SQUASH * press), WAX * (1.0 - SQUASH * press))
	var shape := PackedVector2Array()
	for i in range(LOBES * 4):
		var a := TAU * float(i) / float(LOBES * 4)
		var wobble := 1.0 + 0.08 * sin(a * LOBES)
		shape.append(at + Vector2(cos(a) * size.x, sin(a) * size.y) * wobble)
	ShapePaint.colored_polygon(item.get_canvas_item(), shape, Color(WAX_COLOR, alpha))
	var closed := shape.duplicate()
	closed.append(shape[0])
	ShapePaint.polyline(
		item.get_canvas_item(), closed, Color(UiPalette.OUTLINE_DARK, alpha * 0.8), 1.4, true
	)
	ShapePaint.arc(
		item.get_canvas_item(),
		at,
		WAX * 0.7,
		0.0,
		TAU,
		32,
		Color(WAX_COLOR.darkened(0.3), alpha),
		1.6,
		true
	)
	var mark := phase(t, DESCEND + PRESS, SET)
	if mark > 0.0:
		var reach := MARK * ease(mark, 0.5)
		var dark := Color(UiPalette.OUTLINE_DARK, alpha)
		item.draw_line(at - Vector2(reach, reach), at + Vector2(reach, reach), dark, 2.6, true)
		item.draw_line(at - Vector2(reach, -reach), at + Vector2(reach, -reach), dark, 2.6, true)
