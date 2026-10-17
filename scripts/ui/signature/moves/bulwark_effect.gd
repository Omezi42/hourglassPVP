extends SignatureMove
## 砂の壁(GameDesign.md 9章):対象の手前に砂が積もって低い砂の壁がせり上がり、上縁が光ったところで
## 金色の輪が広がる(守護を与える+総量+2を1回で見せる)。

const RISE := 0.4
const RING := 0.32
## 壁の置き場所(駒の足元から手前へ)と、幅・高さ・積み石の段数。
const FRONT := 10.0
const WALL := Vector2(104.0, 34.0)
const COURSES := 3
const BRICKS := 4


func impact_at() -> float:
	return RISE


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var rise := back_out(phase(t, 0.0, RISE))
	var bottom := targets[0].y + CardView.BOARD_ART_SIDE * 0.5 + FRONT
	var height := WALL.y * clampf(rise, 0.0, 1.1)
	if height > 1.0:
		var rect := Rect2(targets[0].x - WALL.x * 0.5, bottom - height, WALL.x, height)
		var shape := PackedVector2Array(
			[
				rect.position,
				Vector2(rect.end.x, rect.position.y),
				rect.end,
				Vector2(rect.position.x, rect.end.y)
			]
		)
		(
			UiPaint
			. fill_gradient_polygon(
				item.get_canvas_item(),
				shape,
				rect,
				[
					[0.0, Color(SignaturePaint.SAND, alpha * 0.95)],
					[1.0, Color(SignaturePaint.SAND_DARK, alpha * 0.95)],
				]
			)
		)
		_mortar(item, rect, alpha)
		item.draw_rect(rect, Color(UiPalette.OUTLINE_DARK, alpha * 0.8), false, 1.4)
		var glow := sin(phase(t, RISE * 0.7, RING) * PI)
		if glow > 0.0:
			item.draw_line(
				rect.position,
				Vector2(rect.end.x, rect.position.y),
				Color(SignaturePaint.BOON, alpha * glow),
				3.0
			)
	SignaturePaint.boon_ring(item, targets[0], phase(t, impact_at(), RING), alpha)


## 積み石の目地。段ごとに半個ずらす。せり上がる途中は見えている段だけ描く。
func _mortar(item: CanvasItem, rect: Rect2, alpha: float) -> void:
	var color := Color(SignaturePaint.SAND_DARK.darkened(0.3), alpha * 0.8)
	var course := WALL.y / float(COURSES)
	var brick := WALL.x / float(BRICKS)
	for row in range(COURSES):
		var y := rect.end.y - course * float(row)
		if y <= rect.position.y:
			break
		if row > 0:
			item.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), color, 1.0)
		var top := maxf(y - course, rect.position.y)
		var shift := brick * 0.5 * float(row % 2)
		for k in range(1, BRICKS + 1):
			var x := rect.position.x + brick * float(k) - shift
			if x <= rect.position.x or x >= rect.end.x:
				continue
			item.draw_line(Vector2(x, y), Vector2(x, top), color, 1.0)
