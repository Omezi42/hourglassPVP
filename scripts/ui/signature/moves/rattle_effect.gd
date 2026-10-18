extends SignatureMove
## ラトルの設置(GameDesign.md 9章):駒の上にガラガラが現れて左右に3度振れ、振れるたびに音の弧が
## 広がり、味方の駒それぞれへ砂粒が1粒ずつ降りて金色の輪が広がる(恵与)。

const APPEAR := 0.1
const SHAKE := 0.36
const FALL := 0.22
const RING := 0.32
## ガラガラの握り(駒の中心から)と柄の長さ・頭の半径、振れる幅と回数。
const GRIP := Vector2(0.0, -44.0)
const HANDLE := 22.0
const HEAD := 11.0
const SWING := 0.5
const SHAKES := 3
## 音の弧の広がり、砂粒が降り始める高さ。
const WAVE_REACH := 26.0
const DROP_HEIGHT := 70.0
const HEAD_COLOR := Color(0.95, 0.55, 0.45, 1.0)
const BAND_COLOR := Color(1.0, 0.92, 0.7, 1.0)


func impact_at() -> float:
	return APPEAR + SHAKE + FALL


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var appear := ease(phase(t, 0.0, APPEAR), 0.5)
	var shake := phase(t, APPEAR, SHAKE)
	var angle := SWING * sin(shake * PI * float(SHAKES)) * (1.0 if shake < 1.0 else 0.0)
	var grip := from + GRIP
	var head := grip + Vector2.UP.rotated(angle) * HANDLE
	var a := alpha * appear
	item.draw_line(grip, head, Color(UiPalette.OUTLINE_DARK, a * 0.8), 4.6, true)
	item.draw_line(grip, head, Color(UiPalette.WOOD_TOP.lightened(0.3), a), 3.0, true)
	ShapePaint.circle(ci, head, HEAD + 1.4, Color(UiPalette.OUTLINE_DARK, a * 0.8))
	ShapePaint.circle(ci, head, HEAD, Color(HEAD_COLOR, a))
	var across := Vector2.RIGHT.rotated(angle)
	item.draw_line(head - across * HEAD, head + across * HEAD, Color(BAND_COLOR, a), 3.0, true)
	for k in range(SHAKES):
		var q := phase(t, APPEAR + SHAKE * (float(k) + 0.5) / float(SHAKES), SHAKE * 0.6)
		if q <= 0.0 or q >= 1.0:
			continue
		var side := -1.0 if k % 2 == 0 else 1.0
		var mid := PI * (1.0 - side) * 0.5
		var color := Color(SignaturePaint.BOON, alpha * (1.0 - q))
		ShapePaint.arc(ci, head, HEAD + WAVE_REACH * q, mid - 0.6, mid + 0.6, 12, color, 2.0, true)
	var fall := phase(t, APPEAR + SHAKE, FALL)
	for target: Vector2 in targets:
		if fall > 0.0 and fall < 1.0:
			var at := target - Vector2(0.0, DROP_HEIGHT * (1.0 - ease(fall, 2.0)))
			ShapePaint.circle(ci, at, 3.6, Color(SignaturePaint.SAND_DARK, alpha))
			ShapePaint.circle(ci, at, 2.6, Color(SignaturePaint.SAND, alpha))
		SignaturePaint.boon_ring(item, target, phase(t, impact_at(), RING), alpha)
