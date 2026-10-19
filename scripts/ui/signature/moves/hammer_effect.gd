extends SignatureMove
## ハンマーの設置(GameDesign.md 9章):対象の上に大きな戦鎚が現れて後ろへ振りかぶり、弧を描いて
## 打ち下ろされ、当たった所で衝撃の輪が広がる(打撃)。

const APPEAR := 0.12
const WINDUP := 0.2
const STRIKE := 0.13
## 打つ点(対象の中心から上へ)、柄の長さ、構え・振りかぶり・打ち下ろしの柄の向き(ラジアン)。
const HIT_LIFT := 40.0
const HANDLE := 62.0
const READY := -PI * 0.55
const RAISED := -PI * 0.3
const DOWN := -PI
## 鎚の頭の大きさと、衝撃の輪の広がり。
const HEAD := Vector2(30.0, 18.0)
const SHOCK := Vector2(52.0, 16.0)
const IRON := Color(0.5, 0.5, 0.56, 1.0)
const IRON_DARK := Color(0.22, 0.22, 0.27, 1.0)


func impact_at() -> float:
	return APPEAR + WINDUP + STRIKE


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var hit := targets[0] - Vector2(0.0, HIT_LIFT)
	var pivot := hit + Vector2(HANDLE, 0.0)
	var appear := ease(phase(t, 0.0, APPEAR), 0.5)
	var angle := lerpf(READY, RAISED, ease(phase(t, APPEAR, WINDUP), -1.6))
	angle = lerpf(angle, DOWN, ease(phase(t, APPEAR + WINDUP, STRIKE), 2.6))
	if t < impact_at() + FADE * 0.6:
		_hammer(item, pivot, angle, alpha * appear)
	var shock := phase(t, impact_at(), FADE)
	if shock > 0.0:
		UiPaint.draw_ellipse_ring(
			ci, hit, SHOCK * (0.3 + ease(shock, 0.4)), Color(1, 0.95, 0.85, 1.0 - shock), 3.0, 32
		)


## 握り `pivot` から `angle` へ柄が伸び、先に柄と直交する頭が付く戦鎚。
func _hammer(item: CanvasItem, pivot: Vector2, angle: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var dir := Vector2.from_angle(angle)
	var across := dir.orthogonal()
	var head := pivot + dir * HANDLE
	item.draw_line(pivot, head, Color(UiPalette.OUTLINE_DARK, alpha * 0.8), 6.4, true)
	item.draw_line(pivot, head, Color(UiPalette.WOOD_TOP.lightened(0.25), alpha), 4.2, true)
	var half_long := across * HEAD.x * 0.5
	var half_short := dir * HEAD.y * 0.5
	var shape := PackedVector2Array(
		[
			head - half_long - half_short,
			head + half_long - half_short,
			head + half_long + half_short,
			head - half_long + half_short,
		]
	)
	UiPaint.fill_gradient_polygon(
		item.get_canvas_item(),
		shape,
		Rect2(head - Vector2.ONE * HEAD.x, Vector2.ONE * HEAD.x * 2.0),
		[[0.0, Color(IRON, alpha)], [1.0, Color(IRON_DARK, alpha)]]
	)
	var closed := shape.duplicate()
	closed.append(shape[0])
	ShapePaint.polyline(
		item.get_canvas_item(), closed, Color(UiPalette.OUTLINE_DARK, alpha), 1.6, true
	)
	item.draw_line(
		head - half_long * 0.8,
		head + half_long * 0.8,
		Color(UiPalette.BRASS_LIGHT, alpha),
		2.0,
		true
	)
