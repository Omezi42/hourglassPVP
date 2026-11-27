extends SignatureMove
## 注ぎ砂(GameDesign.md 9章):対象の駒の頭上に素焼きの水差しが現れて傾き、口から青緑の水が
## 駒の頭へ注がれ、届いたところで水面が縁まで満ちてしぶきが跳ね、金色の輪が広がる(恵与)。

const APPEAR := 0.12
const TIP := 0.14
const POUR := 0.28
## 水差しの胴の中心(対象の中心から)・半径、口の位置(胴の中心から)、傾ききった角度、注ぎ先(対象の中心から)。
const JUG := Vector2(-34.0, -100.0)
const BODY := 15.0
const SPOUT := Vector2(17.0, -14.0)
const TILT := 0.75
const MOUTH := Vector2(0.0, -40.0)


func impact_at() -> float:
	return APPEAR + TIP + POUR


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var target := targets[0]
	var alpha := fade_alpha(t) * minf(phase(t, 0.0, APPEAR) * 1.5, 1.0)
	var center := target + JUG
	var angle := TILT * ease(phase(t, APPEAR, TIP), 0.6)
	_jug(item, center, angle, alpha)
	var spout := center + SPOUT.rotated(angle)
	var mouth := target + MOUTH
	var pour := phase(t, APPEAR + TIP, POUR)
	var drain := phase(t, impact_at(), FADE)
	PourPaint.stream(item, spout, mouth, 14.0, ease(pour, 0.7), drain, alpha)
	PourPaint.brim(item, mouth, 16.0, pour, alpha * (1.0 - drain))
	if t >= impact_at():
		PourPaint.splash(item, mouth, drain, alpha)
		SignaturePaint.boon_ring(item, target, drain, alpha)


## 素焼きの水差し。丸い胴に細い首、右上へ伸びる注ぎ口、左に把手。
func _jug(item: CanvasItem, center: Vector2, angle: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var body := PackedVector2Array()
	for i in range(20):
		var a := TAU * float(i) / 20.0
		body.append(center + Vector2(cos(a) * BODY, sin(a) * BODY * 1.1).rotated(angle))
	var neck := center + Vector2(4.0, -BODY).rotated(angle)
	var lip := center + SPOUT.rotated(angle)
	item.draw_line(neck, lip, Color(UiPalette.INK_950, alpha), 11.0, true)
	item.draw_line(neck, lip, Color(UiPalette.TERRACOTTA, alpha), 7.5, true)
	ShapePaint.convex_polygon(
		ci, ForesightPaint.grown(body, center, 2.0), Color(UiPalette.INK_950, alpha)
	)
	ShapePaint.convex_polygon(ci, body, Color(UiPalette.TERRACOTTA, alpha))
	ShapePaint.arc(
		ci,
		center + Vector2(-BODY - 2.0, -4.0).rotated(angle),
		7.0,
		angle + PI * 0.5,
		angle + PI * 1.5,
		10,
		Color(UiPalette.TERRACOTTA, alpha),
		3.0,
		true
	)
	ShapePaint.circle(
		ci, center + Vector2(-5.0, -5.0).rotated(angle), 3.0, Color(UiPalette.GOLD_HI, alpha * 0.6)
	)
