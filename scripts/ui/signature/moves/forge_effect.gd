extends SignatureMove
## フォージの設置(GameDesign.md 9章):駒の上に小さな坩堝が現れて赤く灼け、傾いて溶けた金色の砂が
## 細い筋になって対象へ注がれ、届いたところで金色の輪が広がる(恵与)。

const APPEAR := 0.1
const HEAT := 0.18
const TILT := 0.12
const POUR := 0.26
const RING := 0.32
## 坩堝の置き場所(駒の中心から)と、口・底の半幅と高さ、傾ける量。
const LIFT := 62.0
const MOUTH_HALF := 13.0
const FOOT_HALF := 8.0
const DEPTH := 16.0
const LEAN := 0.8
## 注ぐ筋の弧の高さと点の数。
const ARC := 26.0
const STREAM_POINTS := 14
const IRON := Color(0.3, 0.28, 0.27, 1.0)
const GLOW := Color(1.0, 0.36, 0.12, 1.0)
const MOLTEN := Color(1.0, 0.78, 0.3, 1.0)


func impact_at() -> float:
	return APPEAR + HEAT + TILT + POUR


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var appear := ease(phase(t, 0.0, APPEAR), 0.5)
	var heat := phase(t, APPEAR, HEAT)
	var side := signf(targets[0].x - from.x) if absf(targets[0].x - from.x) > 1.0 else 1.0
	var angle := side * LEAN * ease(phase(t, APPEAR + HEAT, TILT), 0.6)
	var center := from - Vector2(0.0, LIFT)
	var cup := PackedVector2Array()
	for p: Vector2 in [
		Vector2(-MOUTH_HALF, -DEPTH * 0.5),
		Vector2(MOUTH_HALF, -DEPTH * 0.5),
		Vector2(FOOT_HALF, DEPTH * 0.5),
		Vector2(-FOOT_HALF, DEPTH * 0.5),
	]:
		cup.append(center + p.rotated(angle))
	var a := alpha * appear
	var hot := IRON.lerp(GLOW, heat * 0.55)
	ShapePaint.colored_polygon(ci, cup, Color(hot, a))
	var closed := cup.duplicate()
	closed.append(cup[0])
	ShapePaint.polyline(ci, closed, Color(UiPalette.OUTLINE_DARK, a * 0.8), 1.4, true)
	var rim := center + Vector2(0.0, -DEPTH * 0.5).rotated(angle)
	UiPaint.fill_ellipse(ci, rim, Vector2(MOUTH_HALF - 2.0, 3.0), Color(MOLTEN, a * heat), 16)
	var lip := center + Vector2(side * MOUTH_HALF, -DEPTH * 0.5).rotated(angle)
	var pour := phase(t, APPEAR + HEAT + TILT, POUR)
	if pour > 0.0 and t < impact_at() + RING * 0.4:
		var head := ease(pour, 1.2)
		var tail := phase(t, impact_at(), RING * 0.4)
		var points := PackedVector2Array()
		for i in range(STREAM_POINTS + 1):
			var s := lerpf(tail, head, float(i) / float(STREAM_POINTS))
			points.append(lip.lerp(targets[0], s) - Vector2(0.0, ARC * sin(s * PI)))
		ShapePaint.polyline(ci, points, Color(GLOW, alpha * 0.5), 5.0, true)
		ShapePaint.polyline(ci, points, Color(MOLTEN, alpha), 2.4, true)
	SignaturePaint.boon_ring(item, targets[0], phase(t, impact_at(), RING), alpha)
