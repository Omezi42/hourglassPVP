extends SignatureMove
## ペブルの設置(GameDesign.md 9章):駒の足元から小石が1つ弾き出され、水切りのように2度跳ねて
## 空いた台座で止まったところでモートが現れる(恵与)。

const FLIGHT := 0.5
const RING := 0.32
## 跳ねる区間ごとの距離の割合と弧の高さ(弾き出し → 1度目 → 2度目)。
const LEGS := [0.5, 0.3, 0.2]
const HEIGHTS := [44.0, 18.0, 7.0]
const STONE := Vector2(6.0, 4.0)
const TOUCH := Vector2(12.0, 4.0)
const TOUCH_TIME := 0.12
const STONE_LIGHT := Color(0.74, 0.71, 0.66, 1.0)
const STONE_DARK := Color(0.4, 0.38, 0.35, 1.0)


func impact_at() -> float:
	return FLIGHT


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var foot := Vector2(0.0, CardView.BOARD_ART_SIDE * 0.5)
	var start := from + foot
	var end := targets[0] + foot
	var flight := phase(t, 0.0, FLIGHT)
	var done := 0.0
	var at := end
	for i in range(LEGS.size()):
		var leg: float = LEGS[i]
		var a := start.lerp(end, done)
		var b := start.lerp(end, done + leg)
		var q := clampf((flight - done) / leg, 0.0, 1.0)
		if done > 0.0 and flight >= done:
			_touch(item, a, (t - FLIGHT * done) / TOUCH_TIME, alpha)
		if flight >= done and flight < done + leg:
			at = a.lerp(b, q) - Vector2(0.0, HEIGHTS[i] * sin(q * PI))
		done += leg
	UiPaint.fill_ellipse(
		ci, at, STONE + Vector2.ONE, Color(UiPalette.OUTLINE_DARK, alpha * 0.8), 14
	)
	UiPaint.fill_ellipse(ci, at, STONE, Color(STONE_DARK, alpha), 14)
	UiPaint.fill_ellipse(
		ci,
		at - Vector2(0.0, STONE.y * 0.35),
		STONE * Vector2(0.75, 0.5),
		Color(STONE_LIGHT, alpha),
		14
	)
	SignaturePaint.boon_ring(item, end, phase(t, impact_at(), RING), alpha)


## 小石が卓に触れた所に立つ、横に広がる輪。
func _touch(item: CanvasItem, at: Vector2, progress: float, alpha: float) -> void:
	if progress <= 0.0 or progress >= 1.0:
		return
	UiPaint.draw_ellipse_ring(
		item.get_canvas_item(),
		at,
		TOUCH * (0.4 + ease(progress, 0.4)),
		Color(SignaturePaint.SAND, alpha * (1.0 - progress) * 0.8),
		1.4,
		20
	)
