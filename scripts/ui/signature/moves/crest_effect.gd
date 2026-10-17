extends SignatureMove
## クレスト(GameDesign.md 9章):駒の頭上に五つの尖りを持つ王冠の紋が現れて尖りが1本ずつ灯り、
## 5本そろったところで対象の真上へ飛んで打ち下ろされ、対象が砕ける(打撃。盤面が揺れる)。

const LIGHT := 0.34
const FLY := 0.2
const SLAM := 0.1
const POINTS := 5
## 王冠の置き場所(駒の中心から上へ)と、打ち下ろす前に対象の上で止まる高さ。
const LIFT := 72.0
const HOVER := 56.0
## 王冠の帯の幅・高さと、尖りの高さ。
const BAND := Vector2(40.0, 8.0)
const SPIKE := 14.0
const JEWEL := 2.6
const UNLIT := Color(0.42, 0.36, 0.28, 1.0)


func impact_at() -> float:
	return LIGHT + FLY + SLAM


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var start := from - Vector2(0.0, LIFT)
	var above := targets[0] - Vector2(0.0, HOVER)
	var fly := ease(phase(t, LIGHT, FLY), -1.6)
	var slam := ease(phase(t, LIGHT + FLY, SLAM), 2.0)
	var at := start.lerp(above, fly).lerp(targets[0], slam * 0.6)
	var lit := int(floor(phase(t, 0.0, LIGHT) * float(POINTS) + 0.001))
	if t >= impact_at():
		return
	_crown(item, at, lit, alpha * ease(phase(t, 0.0, LIGHT * 0.3), 0.5))


## 下の中心が `base` の王冠。左から `lit` 本の尖りが灯っている。
func _crown(item: CanvasItem, base: Vector2, lit: int, alpha: float) -> void:
	var ci := item.get_canvas_item()
	var left := base.x - BAND.x * 0.5
	var top := base.y - BAND.y
	var outline := PackedVector2Array([Vector2(left, base.y), Vector2(left + BAND.x, base.y)])
	for i in range(POINTS, -1, -1):
		var x := left + BAND.x * float(i) / float(POINTS)
		outline.append(Vector2(x, top))
		if i > 0:
			var mid := left + BAND.x * (float(i) - 0.5) / float(POINTS)
			outline.append(Vector2(mid, top - SPIKE))
	ShapePaint.colored_polygon(item.get_canvas_item(), outline, Color(UiPalette.BRASS_MID, alpha))
	var closed := outline.duplicate()
	closed.append(outline[0])
	ShapePaint.polyline(
		item.get_canvas_item(), closed, Color(UiPalette.OUTLINE_DARK, alpha * 0.8), 1.4, true
	)
	for i in range(POINTS):
		var mid := left + BAND.x * (float(i) + 0.5) / float(POINTS)
		var tip := Vector2(mid, top - SPIKE)
		var on := i < lit
		var color := SignaturePaint.BOON if on else UNLIT
		UiPaint.fill_circle(ci, tip, JEWEL, Color(color, alpha), 10)
		if on:
			UiPaint.fill_circle(ci, tip, JEWEL * 2.6, Color(SignaturePaint.BOON, alpha * 0.3), 12)
	item.draw_line(
		Vector2(left, base.y - BAND.y * 0.5),
		Vector2(left + BAND.x, base.y - BAND.y * 0.5),
		Color(UiPalette.BRASS_HIGHLIGHT, alpha),
		1.6
	)
