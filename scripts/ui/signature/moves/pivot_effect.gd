extends SignatureMove
## ピボットの設置(GameDesign.md 9章):対象の足元に軸の印が立ち、そこを中心に光の弧が半回転した
## ところで対象が返る(反転)。

const PIN := 0.14
const TURN := 0.38
## 軸の高さと頭の大きさ、弧の回る楕円(足元の中心からの半径)と弧の長さ(ラジアン)。
const PIN_HEIGHT := 22.0
const PIN_HEAD := 3.6
const ORBIT := Vector2(46.0, 14.0)
const ARC_SPAN := 1.6
const ARC_POINTS := 18


func impact_at() -> float:
	return PIN + TURN


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var foot := targets[0] + Vector2(0.0, CardView.BOARD_ART_SIDE * 0.5)
	var pin := ease(phase(t, 0.0, PIN), 0.5)
	var top := foot - Vector2(0.0, PIN_HEIGHT * pin)
	UiPaint.draw_ellipse_ring(
		ci, foot, ORBIT * 0.3, Color(SignaturePaint.SPIN, alpha * pin * 0.7), 1.4, 20
	)
	item.draw_line(foot, top, Color(UiPalette.OUTLINE_DARK, alpha * pin * 0.8), 3.6, true)
	item.draw_line(foot, top, Color(UiPalette.BRASS_HIGHLIGHT, alpha * pin), 2.0, true)
	if pin > 0.2:
		ShapePaint.circle(ci, top, PIN_HEAD * pin, Color(SignaturePaint.SPIN, alpha))
	var turn := phase(t, PIN, TURN)
	if turn <= 0.0 or t >= impact_at() + FADE * 0.5:
		return
	var head := PI * 0.5 + PI * back_out(turn)
	var points := PackedVector2Array()
	for i in range(ARC_POINTS + 1):
		var a := head - ARC_SPAN * float(i) / float(ARC_POINTS)
		points.append(foot + Vector2(cos(a) * ORBIT.x, sin(a) * ORBIT.y) - Vector2(0.0, 6.0))
	ShapePaint.polyline(ci, points, Color(SignaturePaint.SPIN, alpha * 0.4), 6.0, true)
	ShapePaint.polyline(ci, points, Color(SignaturePaint.SPIN, alpha), 2.4, true)
	ShapePaint.circle(ci, points[0], 3.4, Color(1, 1, 1, alpha))
