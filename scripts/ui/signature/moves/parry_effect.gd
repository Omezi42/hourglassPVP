extends SignatureMove
## パリィの払拭(GameDesign.md 9章):被弾で、駒の前に曲刀が現れて斜めに構え、打ち込みを払うように
## 跳ね上げた瞬間に火花が散り、くすんだ筋が殴ってきた駒へまっすぐ走って、くすんだ輪へ縮む
## (その駒の砂が1粒上へ戻る)。

const APPEAR := 0.1
const SWEEP := 0.14
const STREAK := 0.2
## 刀の握りの位置(駒の中心から)、刃の長さ・幅、構え(ラジアン。0で右)と跳ね上げた先の角度。
const GRIP := Vector2(-6.0, 22.0)
const BLADE := 64.0
const BLADE_WIDTH := 6.0
const GUARD := 12.0
const HILT := 14.0
const GUARD_ANGLE := -2.2
const SWEPT_ANGLE := -0.9
## 火花の出る位置(刃の根元からの割合)と、筋の太さ・尾の長さ。
const CLASH_AT := 0.62
const TRAIL_WIDTH := 3.0
const TRAIL_TAIL := 0.35


func impact_at() -> float:
	return APPEAR + SWEEP + STREAK


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var appear := ease(phase(t, 0.0, APPEAR), 0.5)
	var sweep := back_out(phase(t, APPEAR, SWEEP))
	var angle := lerpf(GUARD_ANGLE, SWEPT_ANGLE, sweep)
	var grip := from + GRIP * zoom
	var blade_alpha := alpha * appear * (1.0 - phase(t, impact_at(), FADE))
	_sabre(item, grip, angle, blade_alpha)
	var clash_t := APPEAR + SWEEP * 0.5
	var clash := phase(t, clash_t, FADE)
	if clash > 0.0:
		var tip_dir := Vector2.from_angle(angle)
		SignaturePaint.sparks(item, grip + tip_dir * BLADE * CLASH_AT * zoom, clash, alpha)
	var streak := phase(t, APPEAR + SWEEP, STREAK)
	if streak > 0.0 and t < impact_at() + FADE:
		var head := from.lerp(targets[0], ease(streak, 0.6))
		var tail := from.lerp(targets[0], ease(maxf(streak - TRAIL_TAIL, 0.0), 0.6))
		var trail_alpha := alpha * (1.0 - phase(t, impact_at(), FADE))
		item.draw_line(
			tail, head, Color(UiPalette.DRAIN_TRAIL, trail_alpha * 0.35), TRAIL_WIDTH * 3.0, true
		)
		item.draw_line(tail, head, Color(UiPalette.DRAIN_TRAIL, trail_alpha), TRAIL_WIDTH, true)
	SignaturePaint.drain_ring(item, targets[0], phase(t, impact_at(), FADE), alpha)


## 反りのある片刃の刀。`grip` は鍔の位置、`angle` は切っ先の向き。
func _sabre(item: CanvasItem, grip: Vector2, angle: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var dir := Vector2.from_angle(angle)
	var across := dir.orthogonal()
	var length := BLADE * zoom
	var width := BLADE_WIDTH * zoom
	var edge := PackedVector2Array()
	var back := PackedVector2Array()
	const STEPS := 8
	for i in range(STEPS + 1):
		var s := float(i) / float(STEPS)
		var bow := across * 0.12 * length * s * s
		var half := width * 0.5 * (1.0 - pow(s, 3.0))
		edge.append(grip + dir * length * s + bow + across * half)
		back.append(grip + dir * length * s + bow - across * half)
	back.reverse()
	var shape := edge + back
	var closed := shape.duplicate()
	closed.append(shape[0])
	ShapePaint.polyline(ci, closed, Color(UiPalette.INK_950, alpha * 0.8), 2.6, true)
	ShapePaint.colored_polygon(ci, shape, Color(UiPalette.STEEL, alpha))
	var hilt_end := grip - dir * HILT * zoom
	item.draw_line(grip, hilt_end, Color(UiPalette.INK_950, alpha * 0.8), 6.0 * zoom, true)
	item.draw_line(grip, hilt_end, Color(UiPalette.WOOD_TOP, alpha), 4.0 * zoom, true)
	var guard := across * GUARD * 0.5 * zoom
	item.draw_line(grip - guard, grip + guard, Color(UiPalette.INK_950, alpha * 0.8), 5.0, true)
	item.draw_line(grip - guard, grip + guard, Color(UiPalette.GOLD, alpha), 3.2, true)
