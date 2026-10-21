extends SignatureMove
## ガードの登場(GameDesign.md 9章):駒の前に大きな凧形の盾が上から降りて卓に突き立ち、砂埃が立って
## 縁が光る(守護=先に殴らせる印)。

const DROP := 0.2
const DUST := 0.3
const SHINE := 0.3
## 盾の先端が刺さる位置(台座の上面から下へ)と、盾の半幅・高さ、降り始める高さ。
const TIP_SINK := 8.0
const HALF := 26.0
const HEIGHT := 78.0
const FALL := 90.0
## 砂埃の広がり。
const PUFF := Vector2(30.0, 7.0)
const FACE := Color(0.62, 0.66, 0.74, 1.0)
const FACE_DARK := Color(0.34, 0.37, 0.44, 1.0)


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + DROP + maxf(DUST, SHINE) + FADE


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var drop := ease(phase(t, impact_at(), DROP), 2.6)
	var tip := from + Vector2(0.0, TIP_SINK - FALL * (1.0 - drop))
	var shape := _kite(tip)
	var a := alpha * minf(phase(t, impact_at(), DROP) * 3.0, 1.0)
	UiPaint.fill_gradient_polygon(
		ci,
		shape,
		Rect2(tip - Vector2(HALF, HEIGHT), Vector2(HALF * 2.0, HEIGHT)),
		[[0.0, Color(FACE, a)], [1.0, Color(FACE_DARK, a)]]
	)
	var closed := shape.duplicate()
	closed.append(shape[0])
	ShapePaint.polyline(ci, closed, Color(UiPalette.OUTLINE_DARK, a), 4.0, true)
	ShapePaint.polyline(ci, closed, Color(UiPalette.BRASS_HIGHLIGHT, a), 2.2, true)
	var cross_top := tip - Vector2(0.0, HEIGHT * 0.9)
	item.draw_line(
		cross_top, tip - Vector2(0.0, HEIGHT * 0.2), Color(UiPalette.BRASS_LIGHT, a), 3.0, true
	)
	var bar := tip - Vector2(0.0, HEIGHT * 0.62)
	item.draw_line(
		bar - Vector2(HALF * 0.7, 0.0),
		bar + Vector2(HALF * 0.7, 0.0),
		Color(UiPalette.BRASS_LIGHT, a),
		3.0,
		true
	)
	var landed := impact_at() + DROP
	var dust := phase(t, landed, DUST)
	if dust > 0.0 and dust < 1.0:
		UiPaint.draw_ellipse_ring(
			ci,
			from + Vector2(0.0, TIP_SINK),
			PUFF * (0.3 + ease(dust, 0.4)),
			Color(SignaturePaint.SAND, alpha * (1.0 - dust)),
			2.0,
			24
		)
	var shine := phase(t, landed, SHINE)
	if shine > 0.0 and shine < 1.0:
		var k := int(ease(shine, 0.8) * float(closed.size() - 1))
		var head := closed[mini(k, closed.size() - 1)]
		ShapePaint.circle(ci, head, 4.0, Color(1, 1, 1, alpha * sin(shine * PI)))


## 先端 `tip` を下にした凧形の盾の輪郭。
func _kite(tip: Vector2) -> PackedVector2Array:
	var top := tip - Vector2(0.0, HEIGHT)
	var shape := PackedVector2Array()
	shape.append(top + Vector2(-HALF, 0.0))
	shape.append(top + Vector2(HALF, 0.0))
	for i in range(1, 9):
		var s := float(i) / 8.0
		shape.append(tip + Vector2(HALF * (1.0 - s * s), -HEIGHT * (1.0 - s)))
	for i in range(7, 0, -1):
		var s := float(i) / 8.0
		shape.append(tip + Vector2(-HALF * (1.0 - s * s), -HEIGHT * (1.0 - s)))
	return shape
