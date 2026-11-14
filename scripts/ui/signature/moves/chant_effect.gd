extends SignatureMove
## チャントの打撃(GameDesign.md 9章):砂術に応えて、駒の足元に魔方陣が一瞬灯って詠み文字が1つ
## 立ちのぼり、文字のまま弧を描いて相手のHPの器へ飛んで打ち当たる(打撃。盤面を揺らす)。

const CIRCLE := 0.12
const FLIGHT := 0.33
## 魔方陣の大きさ(横の半径と、卓の奥行きに合わせて潰す比)と足元の位置、星の頂点数。
const SPAN := 62.0
const SQUASH := 0.32
const STAR := 5
## 文字の大きさ(飛び立つとき→届くとき)と、弧の高さ、尾に引く残像の数。
const GLYPH_FROM := 24.0
const GLYPH_TO := 34.0
const ARC := 90.0
const GHOSTS := 3
const GHOST_LAG := 0.05
const SHAPE := 1


func impact_at() -> float:
	return CIRCLE + FLIGHT


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var floor_at := from + Vector2(0.0, CardView.BOARD_ART_SIDE * 0.5)
	var lit := sin(clampf(t / (CIRCLE * 2.5), 0.0, 1.0) * PI)
	_circle(item, floor_at, alpha * lit)
	for i in range(GHOSTS + 1):
		var k := phase(t - GHOST_LAG * i, CIRCLE, FLIGHT)
		if k <= 0.0 or k >= 1.0:
			continue
		var s := ease(k, -1.5)
		var at := from.lerp(targets[0], s) - Vector2(0.0, ARC * sin(s * PI))
		var strength := alpha * (1.0 if i == 0 else 0.35 / float(i))
		SignaturePaint.rune(item, at, lerpf(GLYPH_FROM, GLYPH_TO, s), SHAPE, 1.0, strength)
	var burst := phase(t, impact_at(), FADE)
	if burst > 0.0:
		var grown := GLYPH_TO * (1.0 + 1.3 * ease(burst, 0.5))
		SignaturePaint.rune(item, targets[0], grown, SHAPE, 1.0, alpha * (1.0 - burst))


## 足元に灯る魔方陣。楕円の輪と、その中の星。
func _circle(item: CanvasItem, center: Vector2, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var color := Color(SignaturePaint.RECITE, alpha)
	var radius := Vector2(SPAN, SPAN * SQUASH)
	UiPaint.draw_ellipse_ring(item.get_canvas_item(), center, radius, color, 1.8, 40)
	var points: Array[Vector2] = []
	for i in range(STAR):
		var angle := -PI * 0.5 + TAU * float(i * 2 % STAR) / float(STAR)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * 0.9)
	points.append(points[0])
	ShapePaint.polyline(item.get_canvas_item(), PackedVector2Array(points), color, 1.4, true)
