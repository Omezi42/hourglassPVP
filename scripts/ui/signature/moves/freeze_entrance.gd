extends SignatureMove
## フリーズの登場(GameDesign.md 9章):着地した足元から氷が駒を這い上がって包み、
## 頭の上で雪の結晶がきらめいてから溶ける(静止=砂が止まった印)。

const CLIMB := 0.28
const HOLD := 0.3
## 氷の覆い。台座の上面の中心から見た幅・高さと、下端が台座へ沈む量。
const SHELL := Vector2(86.0, 116.0)
const SHELL_SINK := 8.0
const SHELL_CORNER := 14.0
## 這い上がる氷の上端のぎざぎざ。
const JAGS := 7
const JAG_DEPTH := 7.0
const FROST_SCALE := 1.5
const GLINT_RADIUS := 13.0
const GLINT_OFFSET := Vector2(22.0, -100.0)


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + CLIMB + HOLD + FADE


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var climb := ease(phase(t, impact_at(), CLIMB), 0.5)
	var frost := CardView.PEDESTAL_RADIUS * FROST_SCALE * climb
	UiPaint.fill_ellipse(ci, from, frost, Color(SignaturePaint.ICE, 0.22 * alpha), 40)
	UiPaint.draw_ellipse_ring(ci, from, frost, Color(SignaturePaint.ICE, 0.7 * alpha), 1.4, 40)
	_shell(item, climb, alpha)
	var glint := phase(t, impact_at() + CLIMB * 0.7, HOLD)
	SignaturePaint.snowflake(
		item, from + GLINT_OFFSET, GLINT_RADIUS * sin(glint * PI), glint * TAU / 12.0, alpha
	)


## 下から `climb` の割合まで凍った覆い。凍りきるまでは上端をぎざぎざにして、這い上がって見せる。
func _shell(item: CanvasItem, climb: float, alpha: float) -> void:
	if climb <= 0.0:
		return
	var bottom := from.y + SHELL_SINK
	var top := bottom - SHELL.y * climb
	var left := from.x - SHELL.x * 0.5
	var right := from.x + SHELL.x * 0.5
	var shape := PackedVector2Array([Vector2(left, bottom), Vector2(right, bottom)])
	var corner := minf(SHELL_CORNER, SHELL.y * climb * 0.5)
	shape.append(Vector2(right, top + corner))
	var jag := minf(JAG_DEPTH * (1.0 - climb * 0.6), corner)
	for i in range(JAGS + 1):
		var x := lerpf(right - corner, left + corner, float(i) / float(JAGS))
		shape.append(Vector2(x, top + (jag if i % 2 == 1 else 0.0)))
	shape.append(Vector2(left, top + corner))
	var rect := Rect2(left, top, SHELL.x, bottom - top)
	(
		UiPaint
		. fill_gradient_polygon(
			item.get_canvas_item(),
			shape,
			rect,
			[
				[0.0, Color(SignaturePaint.ICE, 0.42 * alpha)],
				[1.0, Color(SignaturePaint.ICE, 0.18 * alpha)],
			]
		)
	)
	var closed := shape.duplicate()
	closed.append(shape[0])
	ShapePaint.polyline(
		item.get_canvas_item(), closed, Color(SignaturePaint.ICE, 0.85 * alpha), 1.6, true
	)
	# 氷の面に斜めの照り返しを1本入れて、透き通った塊に見せる。
	var shine_top := maxf(top + corner, bottom - SHELL.y * 0.85)
	if shine_top < bottom - SHELL.y * 0.2:
		item.draw_line(
			Vector2(left + SHELL.x * 0.22, bottom - SHELL.y * 0.2),
			Vector2(left + SHELL.x * 0.38, shine_top),
			Color(1, 1, 1, 0.5 * alpha),
			2.0,
			true
		)
