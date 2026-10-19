extends SignatureMove
## ブランクの設置(GameDesign.md 9章):対象の上をくすんだ灰色の布が左から右へ拭い、拭い終えた
## ところで効果とキーワードの色が抜ける(払拭)。

const APPEAR := 0.12
const WIPE := 0.42
## 布の大きさと傾き、拭う幅(対象の中心から左右へ)、上下に揺れる幅と回数。
const CLOTH := Vector2(18.0, 24.0)
const TILT := 0.25
const REACH := 46.0
const BOB := 10.0
const STROKES := 2.0
## 拭った跡の高さ。
const TRAIL_HEIGHT := 70.0
const CLOTH_COLOR := Color(0.6, 0.58, 0.62, 1.0)
const TRAIL_COLOR := Color(0.85, 0.84, 0.88, 1.0)


func impact_at() -> float:
	return APPEAR + WIPE


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var appear := ease(phase(t, 0.0, APPEAR), 0.5)
	var wipe := phase(t, APPEAR, WIPE)
	var x := lerpf(-REACH, REACH, ease(wipe, -1.6))
	var at := targets[0] + Vector2(x, sin(wipe * PI * 2.0 * STROKES) * BOB)
	if wipe > 0.0:
		var left := targets[0].x - REACH
		var trail := Rect2(left, targets[0].y - TRAIL_HEIGHT * 0.5, at.x - left, TRAIL_HEIGHT)
		item.draw_rect(
			trail, Color(TRAIL_COLOR, alpha * 0.18 * (1.0 - phase(t, impact_at(), FADE)))
		)
	if t >= impact_at():
		return
	var shape := PackedVector2Array()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -0.8), Vector2(0.9, 1), Vector2(-1, 0.85)]:
		shape.append(at + (corner * CLOTH).rotated(TILT))
	var a := alpha * appear
	ShapePaint.colored_polygon(ci, shape, Color(CLOTH_COLOR, a))
	var closed := shape.duplicate()
	closed.append(shape[0])
	ShapePaint.polyline(ci, closed, Color(UiPalette.OUTLINE_DARK, a * 0.7), 1.2, true)
	for k in range(2):
		var y := (float(k) - 0.5) * CLOTH.y * 0.7
		var fold_a := at + Vector2(-CLOTH.x * 0.6, y).rotated(TILT)
		var fold_b := at + Vector2(CLOTH.x * 0.6, y + 3.0).rotated(TILT)
		item.draw_line(fold_a, fold_b, Color(CLOTH_COLOR.darkened(0.25), a), 1.2, true)
