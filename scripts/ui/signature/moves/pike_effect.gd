extends SignatureMove
## パイクの設置(GameDesign.md 9章):駒の上に長柄の矛が現れて対象の脇へ斜めに突き立ち、穂先が光った
## ところで金色の輪が広がる(貫通を与える恵与)。

const APPEAR := 0.12
const FLY := 0.28
const GLINT := 0.16
const RING := 0.32
## 出る場所(駒の中心から上へ)、突き立つ場所(対象の足元から右へ)、柄の長さ、構えと立てた傾き。
const LIFT := 70.0
const PLANT := Vector2(40.0, 0.0)
const SHAFT := 92.0
const HELD := -PI * 0.5 + 1.3
const PLANTED := -PI * 0.5 + 0.25
const ARC := 40.0
## 穂先の長さ・半幅と、光の大きさ。
const HEAD := 16.0
const HEAD_HALF := 4.5
const GLEAM := 10.0
const STEEL := Color(0.86, 0.88, 0.94, 1.0)


func impact_at() -> float:
	return APPEAR + FLY + GLINT


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var a := alpha * ease(phase(t, 0.0, APPEAR), 0.5)
	var fly := ease(phase(t, APPEAR, FLY), 1.8)
	var butt_start := from - Vector2(0.0, LIFT) - Vector2.from_angle(HELD) * SHAFT * 0.5
	var butt_end := targets[0] + Vector2(0.0, CardView.BOARD_ART_SIDE * 0.5) + PLANT
	var butt := butt_start.lerp(butt_end, fly) - Vector2(0.0, ARC * sin(fly * PI))
	var dir := Vector2.from_angle(lerpf(HELD, PLANTED, fly))
	var neck := butt + dir * SHAFT
	item.draw_line(butt, neck, Color(UiPalette.OUTLINE_DARK, a * 0.8), 5.0, true)
	item.draw_line(butt, neck, Color(UiPalette.WOOD_TOP.lightened(0.25), a), 3.2, true)
	var across := dir.orthogonal()
	var tip := neck + dir * HEAD
	var head := PackedVector2Array([neck - across * HEAD_HALF, tip, neck + across * HEAD_HALF])
	ShapePaint.colored_polygon(ci, head, Color(STEEL, a))
	var closed := head.duplicate()
	closed.append(head[0])
	ShapePaint.polyline(ci, closed, Color(UiPalette.OUTLINE_DARK, a * 0.8), 1.2, true)
	item.draw_line(neck, neck - across * HEAD_HALF * 2.2 - dir * 4.0, Color(STEEL, a), 2.0, true)
	var glint := phase(t, APPEAR + FLY, GLINT)
	if glint > 0.0 and glint < 1.0:
		var size := GLEAM * sin(glint * PI)
		item.draw_line(
			tip - Vector2(size, 0.0), tip + Vector2(size, 0.0), Color(1, 1, 1, alpha), 1.6, true
		)
		item.draw_line(
			tip - Vector2(0.0, size), tip + Vector2(0.0, size), Color(1, 1, 1, alpha), 1.6, true
		)
	SignaturePaint.boon_ring(item, targets[0], phase(t, impact_at(), RING), alpha)
