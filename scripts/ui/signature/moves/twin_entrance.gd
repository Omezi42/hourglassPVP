extends SignatureMove
## ツインの登場(GameDesign.md 9章):駒の左右に同じ形の光の残像が2つ現れ、駒へ重なるように寄って
## 消える(1ターンに2回攻撃できる印)。

const SPLIT := 0.16
const MERGE := 0.36
## 残像が出る左右のずれと、砂時計の輪郭の半幅・半高さ・くびれの半幅。
const OFFSET := 54.0
const HALF := Vector2(24.0, 40.0)
const WAIST := 4.0
const GHOST := Color(0.82, 0.92, 1.0, 1.0)


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + SPLIT + MERGE + FADE * 0.5


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var core := from - Vector2(0.0, CardView.BOARD_ART_SIDE * 0.5)
	var split := ease(phase(t, impact_at(), SPLIT), 0.5)
	var merge := ease(phase(t, impact_at() + SPLIT, MERGE), 1.8)
	var offset := OFFSET * split * (1.0 - merge)
	var alpha := fade_alpha(t) * split * (1.0 - merge * 0.6)
	for side: float in [-1.0, 1.0]:
		_outline(item, core + Vector2(side * offset, 0.0), alpha)
	if merge > 0.9:
		var flash := (merge - 0.9) / 0.1
		_outline(item, core, fade_alpha(t) * (1.0 - flash * 0.5))


## 砂時計の輪郭(上下の枠と、くびれで交わる2つの三角)。
func _outline(item: CanvasItem, at: Vector2, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var shape := PackedVector2Array(
		[
			at + Vector2(-HALF.x, -HALF.y),
			at + Vector2(HALF.x, -HALF.y),
			at + Vector2(WAIST, 0.0),
			at + Vector2(HALF.x, HALF.y),
			at + Vector2(-HALF.x, HALF.y),
			at + Vector2(-WAIST, 0.0),
			at + Vector2(-HALF.x, -HALF.y),
		]
	)
	ShapePaint.polyline(ci, shape, Color(GHOST, alpha * 0.35), 6.0, true)
	ShapePaint.polyline(ci, shape, Color(GHOST, alpha), 2.0, true)
	for y: float in [-HALF.y, HALF.y]:
		item.draw_line(
			at + Vector2(-HALF.x - 5.0, y),
			at + Vector2(HALF.x + 5.0, y),
			Color(GHOST, alpha),
			3.0,
			true
		)
