extends SignatureMove
## イコライザーの設置(GameDesign.md 9章):駒の上にイコライザーの光の棒が並んで跳ね、相手の余った数だけ
## 棒が伸びて相手の駒へ落ち、当たった駒が砕ける。

const BOUNCE := 0.32
const DROP := 0.26
## 棒の本数・幅・間隔と、跳ねる高さの幅(最小・最大)。棒の並びの下端は駒の中心から上へ LIFT。
const BARS := 5
const BAR_WIDTH := 10.0
const BAR_GAP := 5.0
const BAR_MIN := 14.0
const BAR_MAX := 48.0
const LIFT := 70.0
## 対象へ落ちる光の柱の長さと幅。
const PILLAR := 70.0
const PILLAR_WIDTH := 9.0
const COLOR := Color(0.2, 0.62, 1.0, 1.0)


func impact_at() -> float:
	return BOUNCE + DROP


func draw(item: CanvasItem, t: float) -> void:
	var alpha := fade_alpha(t)
	var ci := item.get_canvas_item()
	var base := from - Vector2(0.0, LIFT * zoom)
	var bounce := phase(t, 0.0, BOUNCE)
	var span := (BAR_WIDTH + BAR_GAP) * zoom
	for i in range(BARS):
		var x := (float(i) - float(BARS - 1) * 0.5) * span
		var wave := absf(sin(bounce * TAU * 1.5 + float(i) * 1.3))
		# 跳ねたあと、最後にすべての棒の高さがそろう
		var height := lerpf(lerpf(BAR_MIN, BAR_MAX, wave), BAR_MAX * 0.7, ease(bounce, 3.0)) * zoom
		var rect := Rect2(
			base + Vector2(x - BAR_WIDTH * zoom * 0.5, -height), Vector2(BAR_WIDTH * zoom, height)
		)
		item.draw_rect(rect.grow(1.0), Color(UiPalette.INK_950, alpha * 0.6))
		item.draw_rect(rect, Color(COLOR, alpha))
		item.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2.0)), Color(1, 1, 1, alpha))
	var drop := phase(t, BOUNCE, DROP)
	if drop <= 0.0:
		return
	for target in targets:
		var tip := target.lerp(target - Vector2(0.0, PILLAR * zoom * 2.0), 1.0 - ease(drop, 2.2))
		var tail := tip - Vector2(0.0, PILLAR * zoom)
		item.draw_line(tail, tip, Color(COLOR, alpha * 0.35), PILLAR_WIDTH * zoom * 2.0, true)
		item.draw_line(tail, tip, Color(COLOR, alpha), PILLAR_WIDTH * zoom, true)
		item.draw_line(tail, tip, Color(1, 1, 1, alpha), PILLAR_WIDTH * zoom * 0.35, true)
	var landed := phase(t, impact_at(), FADE)
	if landed > 0.0:
		for target in targets:
			SignaturePaint.sparks(item, target, landed, alpha)
