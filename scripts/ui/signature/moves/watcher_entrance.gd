extends SignatureMove
## ワッチャーの登場(GameDesign.md 9章):駒の頭上に目の紋がゆっくり開き、左右を一度見渡してから
## 閉じる(攻撃できない見張り役の印)。

const OPEN := 0.2
const LOOK := 0.44
const CLOSE := 0.16
## 目の置き場所(台座の上面から上へ)と、横の半幅・開ききった縦の半幅、瞳の大きさと動く幅。
const LIFT := 140.0
const HALF := Vector2(22.0, 10.0)
const STEPS := 16
const IRIS := 6.0
const GLANCE := 9.0
const WHITE := Color(1.0, 0.97, 0.88, 1.0)
const IRIS_COLOR := Color(0.36, 0.62, 0.78, 1.0)


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + OPEN + LOOK + CLOSE


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var ci := item.get_canvas_item()
	var center := from - Vector2(0.0, LIFT)
	var open := ease(phase(t, impact_at(), OPEN), 0.6)
	open *= 1.0 - ease(phase(t, impact_at() + OPEN + LOOK, CLOSE), 2.0)
	var alpha := minf(phase(t, impact_at(), OPEN * 0.5) * 2.0, 1.0)
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	for i in range(STEPS + 1):
		var s := float(i) / float(STEPS)
		var x := lerpf(-HALF.x, HALF.x, s)
		var bulge := sin(s * PI)
		upper.append(center + Vector2(x, -HALF.y * open * bulge))
		lower.append(center + Vector2(x, HALF.y * open * bulge * 0.8))
	var lid := Color(UiPalette.BRASS_HIGHLIGHT, alpha)
	if open > 0.08:
		var shape := upper.duplicate()
		var back := lower.duplicate()
		back.reverse()
		shape.append_array(back)
		ShapePaint.colored_polygon(ci, shape, Color(WHITE, alpha * 0.92))
		var look := phase(t, impact_at() + OPEN, LOOK)
		var iris := center + Vector2(sin(look * TAU) * GLANCE, 0.0)
		var size := IRIS * minf(open * 1.4, 1.0)
		ShapePaint.circle(ci, iris, size, Color(IRIS_COLOR, alpha))
		ShapePaint.circle(ci, iris, size * 0.45, Color(UiPalette.OUTLINE_DARK, alpha))
		ShapePaint.polyline(ci, lower, lid, 1.6, true)
	ShapePaint.polyline(ci, upper, Color(UiPalette.OUTLINE_DARK, alpha * 0.6), 4.0, true)
	ShapePaint.polyline(ci, upper, lid, 2.4, true)
