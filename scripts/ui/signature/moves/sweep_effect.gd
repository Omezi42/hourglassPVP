extends SignatureMove
## スイープの設置(GameDesign.md 9章):大きな箒が相手の列を左から右へ掃き抜け、穂先が通り過ぎた駒から
## 順に砂が散る(打撃)。

const SWEEP := 0.56
## 箒の置き場所(相手の列の中心から下へ、穂先)と柄の長さ・傾き、穂の幅と長さ、列の端からの張り出し。
const DROP := 40.0
const HANDLE := 96.0
const LEAN := -0.45
const BRISTLE := Vector2(30.0, 26.0)
const OVERRUN := 80.0
## 掃いた跡に舞う砂粒の数。
const DUST := 18
const HANDLE_COLOR := Color(0.56, 0.38, 0.22, 1.0)
const STRAW := Color(0.9, 0.78, 0.46, 1.0)
const STRAW_DARK := Color(0.66, 0.52, 0.26, 1.0)


func impact_at() -> float:
	return SWEEP


func reaches(index: int, t: float) -> bool:
	return _front(t) >= targets[index].x


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var row := _row()
	var x := _front(t)
	var foot := Vector2(x, row.y + DROP)
	var swing := sin(phase(t, 0.0, SWEEP) * PI * 3.0) * 0.12
	var up := Vector2.UP.rotated(LEAN + swing)
	var top := foot + up * HANDLE
	item.draw_line(foot, top, Color(UiPalette.OUTLINE_DARK, alpha * 0.8), 6.0, true)
	item.draw_line(foot, top, Color(HANDLE_COLOR, alpha), 4.0, true)
	var across := up.orthogonal()
	var bristle := PackedVector2Array(
		[
			foot - across * BRISTLE.x * 0.3,
			foot + across * BRISTLE.x * 0.3,
			foot + across * BRISTLE.x * 0.6 - up * BRISTLE.y,
			foot - across * BRISTLE.x * 0.6 - up * BRISTLE.y,
		]
	)
	ShapePaint.colored_polygon(ci, bristle, Color(STRAW, alpha))
	for k in range(5):
		var s := (float(k) + 0.5) / 5.0 - 0.5
		item.draw_line(
			foot + across * BRISTLE.x * 0.6 * s,
			foot + across * BRISTLE.x * 1.2 * s - up * BRISTLE.y,
			Color(STRAW_DARK, alpha),
			1.0,
			true
		)
	for i in range(DUST):
		var lag := SignaturePaint.jitter(i, 141) * 90.0
		var dx := x - lag
		if dx < row.x - OVERRUN:
			continue
		var rise := lag * 0.35 * SignaturePaint.jitter(i, 142)
		var at := Vector2(dx, row.y + DROP - BRISTLE.y * 0.5 - rise)
		ShapePaint.circle(ci, at, 1.6, Color(SignaturePaint.SAND, alpha * (1.0 - lag / 90.0)))


## 相手の列の左端のxと、列の中心のy。
func _row() -> Vector2:
	var left := INF
	var y := 0.0
	for target: Vector2 in targets:
		left = minf(left, target.x)
		y += target.y
	return Vector2(left, y / float(targets.size()))


func _front(t: float) -> float:
	var left := INF
	var right := -INF
	for target: Vector2 in targets:
		left = minf(left, target.x)
		right = maxf(right, target.x)
	return lerpf(left - OVERRUN, right + OVERRUN, ease(phase(t, 0.0, SWEEP), -1.3))
