extends SignatureMove
## アイオーンの設置(GameDesign.md 9章):駒を中心に尾をくわえた蛇の円環が卓いっぱいに広がって一周し、
## 輪が通った駒から順に返る。

const SPREAD := 0.72
## 輪の太さ・鱗の数と、いちばん遠い駒より外へ広がる量。
const BAND := 7.0
const SCALES := 40
const MARGIN := 40.0
const SERPENT := SignaturePaint.SPECTRAL


func impact_at() -> float:
	return SPREAD


func reaches(index: int, t: float) -> bool:
	return _radius(t) >= from.distance_to(targets[index])


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var ci := item.get_canvas_item()
	var r := _radius(t)
	if r <= 1.0:
		return
	var band := BAND * zoom
	ShapePaint.arc(
		ci, from, r, 0.0, TAU, 96, Color(UiPalette.INK_950, alpha * 0.6), band + 3.0, true
	)
	ShapePaint.arc(ci, from, r, 0.0, TAU, 96, Color(SERPENT, alpha), band, true)
	var turn := TAU * ease(phase(t, 0.0, SPREAD), 0.7)
	for i in range(SCALES):
		var a := turn + TAU * float(i) / float(SCALES)
		var at := from + Vector2.from_angle(a) * r
		ShapePaint.circle(ci, at, band * 0.22, Color(SERPENT.lightened(0.4), alpha))
	var head := from + Vector2.from_angle(turn) * r
	ShapePaint.circle(ci, head, band * 1.1, Color(UiPalette.INK_950, alpha * 0.7))
	ShapePaint.circle(ci, head, band * 0.95, Color(SERPENT, alpha))
	ShapePaint.circle(
		ci,
		head + Vector2.from_angle(turn + PI * 0.5) * band * 0.4,
		1.6 * zoom,
		Color(UiPalette.GOLD_HI, alpha)
	)


## 輪の半径。いちばん遠い対象の外まで広がる。
func _radius(t: float) -> float:
	var far := 0.0
	for target in targets:
		far = maxf(far, from.distance_to(target))
	return (far + MARGIN * zoom) * ease(phase(t, 0.0, SPREAD), 0.6)
