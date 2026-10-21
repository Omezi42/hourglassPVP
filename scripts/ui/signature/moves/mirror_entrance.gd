extends SignatureMove
## ミラーの登場(GameDesign.md 9章):駒の前に楕円の鏡が立ち、鏡面を光がよぎって斜め上へ反射光が跳ね返る
## (硝子=1度だけダメージを防ぐ膜の印)。

const APPEAR := 0.14
const SWEEP := 0.22
const BOUNCE := 0.24
## 鏡の中心(台座の上面から上へ)と半径、反射光の向きと長さ。
const LIFT := 48.0
const RADIUS := Vector2(19.0, 28.0)
const BEAM_DIR := Vector2(1.0, -1.2)
const BEAM := 110.0
const FACE := Color(0.78, 0.9, 1.0, 1.0)
const SHINE := Color(1.0, 1.0, 1.0, 1.0)


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + APPEAR + SWEEP + BOUNCE + FADE


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var appear := back_out(phase(t, impact_at(), APPEAR))
	var center := from - Vector2(0.0, LIFT)
	var radius := RADIUS * Vector2(1.0, clampf(appear, 0.0, 1.1))
	if radius.y <= 2.0:
		return
	var a := alpha * minf(phase(t, impact_at(), APPEAR) * 3.0, 1.0)
	UiPaint.fill_ellipse(ci, center, radius, Color(FACE, a * 0.75), 32)
	UiPaint.draw_ellipse_ring(ci, center, radius, Color(UiPalette.OUTLINE_DARK, a), 5.0, 32)
	UiPaint.draw_ellipse_ring(ci, center, radius, Color(UiPalette.BRASS_HIGHLIGHT, a), 3.0, 32)
	item.draw_line(center + Vector2(0.0, radius.y), from, Color(UiPalette.BRASS_DARK, a), 3.0, true)
	var sweep := phase(t, impact_at() + APPEAR, SWEEP)
	if sweep > 0.0 and sweep < 1.0:
		var x := lerpf(-0.8, 0.8, ease(sweep, -1.4))
		var half := sqrt(maxf(1.0 - x * x, 0.0)) * radius.y * 0.9
		var mid := center + Vector2(x * radius.x, 0.0)
		item.draw_line(
			mid - Vector2(-4.0, half), mid + Vector2(-4.0, half), Color(SHINE, a * 0.9), 3.0, true
		)
	var bounce := phase(t, impact_at() + APPEAR + SWEEP * 0.7, BOUNCE)
	if bounce > 0.0:
		var dir := BEAM_DIR.normalized()
		var head := center + dir * BEAM * ease(bounce, 0.6)
		var tail := center + dir * BEAM * ease(phase(bounce, 0.4, 0.6), 0.6)
		item.draw_line(tail, head, Color(SHINE, alpha * 0.35), 6.0, true)
		item.draw_line(tail, head, Color(SHINE, alpha), 2.0, true)
