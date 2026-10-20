extends SignatureMove
## バーブの被弾(GameDesign.md 9章):駒から鉤の付いた棘の鎖が対象へ投げつけられ、引っかかったところで
## 刺さる(打撃)。

const THROW := 0.3
const CATCH := 0.1
## 鎖の弧の高さと輪の間隔、棘の長さ、鉤の大きさ。
const ARC := 34.0
const LINK := 9.0
const THORN := 4.0
const HOOK := 9.0
const STEEL := Color(0.72, 0.74, 0.8, 1.0)
const STEEL_DARK := Color(0.36, 0.38, 0.44, 1.0)


func impact_at() -> float:
	return THROW + CATCH


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var reach := ease(phase(t, 0.0, THROW), 0.6)
	var tug := sin(phase(t, THROW, CATCH) * PI)
	var head := _path(reach, tug)
	var length := from.distance_to(targets[0]) * reach
	var links := int(length / LINK)
	var prev := from
	for i in range(1, links + 1):
		var at := _path(reach * float(i) / float(maxi(links, 1)), tug)
		item.draw_line(prev, at, Color(STEEL_DARK, alpha), 2.4, true)
		var across := (at - prev).orthogonal().normalized()
		item.draw_line(at - across * THORN, at + across * THORN, Color(STEEL, alpha), 1.4, true)
		prev = at
	var dir := (head - prev).normalized() if head != prev else (targets[0] - from).normalized()
	var hook := PackedVector2Array()
	for k in range(9):
		var a := PI * float(k) / 8.0
		hook.append(head + dir * sin(a) * HOOK - dir.orthogonal() * (1.0 - cos(a)) * HOOK * 0.5)
	ShapePaint.polyline(ci, hook, Color(UiPalette.OUTLINE_DARK, alpha), 4.0, true)
	ShapePaint.polyline(ci, hook, Color(STEEL, alpha), 2.4, true)


## 鎖の上の点(0=出どころ、1=対象)。引っかかった瞬間に弧が少しだけ張って縮む。
func _path(s: float, tug: float) -> Vector2:
	return from.lerp(targets[0], s) - Vector2(0.0, ARC * (1.0 - tug * 0.7) * sin(s * PI))
