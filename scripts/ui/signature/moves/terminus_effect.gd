extends SignatureMove
## テルミヌスの設置(GameDesign.md 9章。山札が0枚のときだけ働く):駒から自分の情報帯へ枕木を渡した二本のレールが
## 伸び、黄昏の色の灯がレールを走って、終わりの紅白の車止めに着いたところで光の輪が広がる(静止)。

const LAY := 0.24
const RUN := 0.3
## レールの間隔、枕木の間隔と半長、走る灯の大きさ、車止めの半幅・半高。
const GAUGE := 7.0
const TIE_STEP := 12.0
const TIE := 10.0
const LAMP := 6.0
const STOP := Vector2(5.0, 12.0)


func impact_at() -> float:
	return LAY + RUN


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var target := targets[0]
	var dir := (target - from).normalized()
	var across := dir.orthogonal()
	var length := from.distance_to(target)
	var lay := ease(phase(t, 0.0, LAY), 0.6)
	var end := from + dir * length * lay
	var ties := int(length * lay / TIE_STEP)
	for i in range(ties + 1):
		var at := from + dir * TIE_STEP * float(i)
		item.draw_line(at - across * TIE, at + across * TIE, Color(UiPalette.OAK, alpha), 3.0)
	for side: float in [-1.0, 1.0]:
		var off := across * GAUGE * side
		item.draw_line(from + off, end + off, Color(UiPalette.INK_950, alpha), 4.0, true)
		item.draw_line(from + off, end + off, Color(UiPalette.STEEL, alpha), 2.2, true)
	if lay >= 1.0:
		var corners := PackedVector2Array()
		for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			corners.append(target + dir * c.x * STOP.x + across * c.y * STOP.y)
		ShapePaint.convex_polygon(ci, corners, Color(UiPalette.SIGNAL_RED, alpha))
		item.draw_line(
			target - across * STOP.y * 0.3,
			target + across * STOP.y * 0.3,
			Color(UiPalette.IVORY, alpha),
			3.0
		)
	var run := phase(t, LAY, RUN)
	if run > 0.0 and t < impact_at():
		var at := from.lerp(target, ease(run, 1.6))
		ShapePaint.circle(ci, at, LAMP * 2.2, Color(UiPalette.DAYBREAK, alpha * 0.35))
		ShapePaint.circle(ci, at, LAMP, Color(UiPalette.TOLL_BRASS, alpha))
		ShapePaint.circle(ci, at, LAMP * 0.45, Color(SignaturePaint.SPARK_HOT, alpha))
	if t >= impact_at():
		var lit := phase(t, impact_at(), FADE)
		ShapePaint.circle(ci, target, LAMP * (2.0 + lit), Color(UiPalette.DAYBREAK, alpha * 0.4))
		SignaturePaint.pulse_ring(item, target, lit, alpha)
