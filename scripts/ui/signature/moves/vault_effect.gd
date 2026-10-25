extends SignatureMove
## ヴォールトの被弾(GameDesign.md 9章):駒の前に金庫の扉が現れてダイヤルが回り、扉が開いて
## 金色の砂の塊が山なりに対象へ飛び、届いたところで金色の輪が広がる(恵与)。

const APPEAR := 0.1
const DIAL := 0.2
const OPEN := 0.14
const FLY := 0.34
const RING := 0.32
## 扉の大きさと置き場所(駒の中心から下へ)、ダイヤルの半径と回る量。
const DOOR := Vector2(30.0, 30.0)
const SPOT := 6.0
const DIAL_RADIUS := 7.0
const DIAL_TURN := PI * 1.5
## 飛ぶ塊の大きさと弧の高さ、こぼれる砂粒の数。
const NUGGET := 4.5
const ARC := 44.0
const SPARKS := 6
const IRON := Color(0.42, 0.45, 0.5, 1.0)
const IRON_DARK := Color(0.22, 0.24, 0.28, 1.0)
const RIVET := Color(0.7, 0.72, 0.76, 1.0)
const INSIDE := Color(0.1, 0.09, 0.08, 1.0)


func impact_at() -> float:
	return APPEAR + DIAL + OPEN + FLY


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var center := from + Vector2(0.0, SPOT)
	var a := alpha * ease(phase(t, 0.0, APPEAR), 0.5)
	var open := ease(phase(t, APPEAR + DIAL, OPEN), 0.6)
	var half := DOOR * 0.5
	item.draw_rect(Rect2(center - half, DOOR), Color(INSIDE, a))
	if open > 0.0:
		ShapePaint.circle(ci, center, half.x * 0.5, Color(SignaturePaint.BOON, a * 0.5 * open))
	_door(item, center, 1.0 - open, phase(t, APPEAR, DIAL), a)
	var fly := phase(t, APPEAR + DIAL + OPEN, FLY)
	if fly > 0.0 and fly < 1.0:
		var s := ease(fly, 0.8)
		var at := center.lerp(targets[0], s) - Vector2(0.0, ARC * sin(s * PI))
		ShapePaint.circle(ci, at, NUGGET, Color(SignaturePaint.BOON, alpha))
		for i in range(SPARKS):
			var lag := (float(i) + 1.0) * 0.035
			var back := clampf(s - lag, 0.0, 1.0)
			var trail := center.lerp(targets[0], back) - Vector2(0.0, ARC * sin(back * PI))
			ShapePaint.circle(ci, trail, 1.4, Color(SignaturePaint.BOON, alpha * (1.0 - lag * 4.0)))
	SignaturePaint.boon_ring(item, targets[0], phase(t, impact_at(), RING), alpha)


## 鉄の扉。左の蝶番を軸に `width`(1=閉じている→0=開ききった)だけ横へ縮み、
## 閉じている間はダイヤルが `dial` に応じて回る。
func _door(item: CanvasItem, center: Vector2, width: float, dial: float, alpha: float) -> void:
	if width <= 0.0 or alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var half := DOOR * 0.5
	var left := center.x - half.x
	var rect := Rect2(Vector2(left, center.y - half.y), Vector2(DOOR.x * width, DOOR.y))
	item.draw_rect(rect, Color(IRON, alpha))
	item.draw_rect(rect, Color(IRON_DARK, alpha), false, 1.6)
	for corner: Vector2 in [
		Vector2(0.15, 0.15), Vector2(0.85, 0.15), Vector2(0.15, 0.85), Vector2(0.85, 0.85)
	]:
		var at := Vector2(left + DOOR.x * width * corner.x, center.y - half.y + DOOR.y * corner.y)
		ShapePaint.circle(ci, at, 1.3, Color(RIVET, alpha))
	var hub := Vector2(left + half.x * width, center.y)
	var squeeze := Vector2(DIAL_RADIUS * width, DIAL_RADIUS)
	UiPaint.fill_ellipse(ci, hub, squeeze, Color(IRON_DARK, alpha), 16)
	UiPaint.draw_ellipse_ring(ci, hub, squeeze, Color(RIVET, alpha), 1.2, 16)
	var turn := DIAL_TURN * ease(dial, 0.6)
	var spoke := Vector2(cos(turn) * squeeze.x, sin(turn) * squeeze.y) * 0.8
	item.draw_line(hub, hub + spoke, Color(RIVET, alpha), 1.6, true)
