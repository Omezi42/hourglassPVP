extends SignatureMove
## ランスの登場(GameDesign.md 9章):台座の左から長い槍が一直線に突き抜けて右へ消え、その軌跡に風の
## 筋が残る(疾走と貫通の印)。

const THRUST := 0.24
const TRAIL := 0.34
## 槍の高さ(台座の上面から上へ)、走り抜ける幅、柄の長さ、穂先の長さと半幅。
const LIFT := 56.0
const SWEEP := 170.0
const SHAFT := 110.0
const HEAD := 22.0
const HEAD_HALF := 6.0
## 残る風の筋の上下の間隔。
const STREAKS := [-9.0, 9.0]
const STEEL := Color(0.86, 0.88, 0.94, 1.0)
const WIND := Color(0.9, 0.96, 1.0, 1.0)


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + THRUST + TRAIL


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var y := from.y - LIFT
	var thrust := phase(t, impact_at(), THRUST)
	var tip_x := lerpf(from.x - SWEEP, from.x + SWEEP + SHAFT, ease(thrust, 1.6))
	var trail := phase(t, impact_at() + THRUST * 0.5, TRAIL)
	for offset: float in STREAKS:
		var left := maxf(from.x - SWEEP, tip_x - SHAFT * 2.0)
		var right := minf(tip_x, from.x + SWEEP)
		if right > left:
			var a := alpha * 0.7 * (1.0 - trail)
			item.draw_line(
				Vector2(left, y + offset), Vector2(right, y + offset), Color(WIND, a), 1.6, true
			)
	if thrust >= 1.0:
		return
	var a := alpha * (1.0 - phase(thrust, 0.8, 0.2))
	var neck := Vector2(tip_x - HEAD, y)
	item.draw_line(
		neck - Vector2(SHAFT, 0.0), neck, Color(UiPalette.OUTLINE_DARK, a * 0.8), 5.0, true
	)
	item.draw_line(
		neck - Vector2(SHAFT, 0.0), neck, Color(UiPalette.WOOD_TOP.lightened(0.25), a), 3.2, true
	)
	var head := PackedVector2Array(
		[neck - Vector2(0.0, HEAD_HALF), Vector2(tip_x, y), neck + Vector2(0.0, HEAD_HALF)]
	)
	ShapePaint.colored_polygon(ci, head, Color(STEEL, a))
	var closed := head.duplicate()
	closed.append(head[0])
	ShapePaint.polyline(ci, closed, Color(UiPalette.OUTLINE_DARK, a * 0.8), 1.2, true)
