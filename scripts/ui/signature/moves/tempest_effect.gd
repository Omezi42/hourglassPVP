extends SignatureMove
## 砂塵嵐(GameDesign.md 9章):卓の端から相手の列を砂の帯が横殴りに吹き抜け、
## 通り過ぎた駒から順に砂が散る。

const SWEEP := 0.62
const HALF_HEIGHT := 56.0
const OVERRUN := 60.0


func impact_at() -> float:
	return SWEEP


func reaches(index: int, t: float) -> bool:
	return _front(t) >= targets[index].x


func draw(item: CanvasItem, t: float) -> void:
	SignaturePaint.sand_band(item, _band(), _front(t), fade_alpha(t))


func _band() -> Rect2:
	var table := CardMatchLayout.current().table_rect
	var y := 0.0
	for target in targets:
		y += target.y
	y /= maxf(float(targets.size()), 1.0)
	return Rect2(
		table.position.x - OVERRUN, y - HALF_HEIGHT, table.size.x + OVERRUN * 2.0, HALF_HEIGHT * 2.0
	)


func _front(t: float) -> float:
	var band := _band()
	var x := phase(t, 0.0, SWEEP)
	return lerpf(band.position.x, band.end.x, 0.5 - 0.5 * cos(x * PI))
