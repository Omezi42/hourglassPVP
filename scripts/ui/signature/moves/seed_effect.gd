extends SignatureMove
## シードの余砂(GameDesign.md 9章):銘板から種が1粒こぼれて空いた台座へ山なりに落ち、芽が出て
## 双葉が開いたところでモートが現れる(恵与)。

const FLIGHT := 0.34
const SPROUT := 0.26
const RING := 0.32
## 種の大きさと飛ぶ弧の高さ、芽の茎の高さと葉の大きさ・開く角度。
const SEED := Vector2(4.0, 5.5)
const ARC := 70.0
const STEM := 20.0
const LEAF := Vector2(11.0, 4.5)
const LEAF_OPEN := 0.5
const SEED_COLOR := Color(0.55, 0.38, 0.2, 1.0)
const LEAF_COLOR := Color(0.55, 0.82, 0.38, 1.0)
const STEM_COLOR := Color(0.4, 0.66, 0.28, 1.0)


func impact_at() -> float:
	return FLIGHT + SPROUT


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var floor_at := targets[0] + Vector2(0.0, CardView.BOARD_ART_SIDE * 0.5)
	var flight := phase(t, 0.0, FLIGHT)
	if flight < 1.0:
		var s := ease(flight, 0.9)
		var at := from.lerp(floor_at, s) - Vector2(0.0, ARC * sin(s * PI))
		UiPaint.fill_ellipse(ci, at, SEED + Vector2.ONE, Color(UiPalette.OUTLINE_DARK, alpha), 14)
		UiPaint.fill_ellipse(ci, at, SEED, Color(SEED_COLOR, alpha), 14)
		return
	var sprout := phase(t, FLIGHT, SPROUT)
	var grow := ease(phase(sprout, 0.0, 0.5), 0.5)
	var open := back_out(phase(sprout, 0.4, 0.6))
	UiPaint.fill_ellipse(ci, floor_at, SEED, Color(SEED_COLOR, alpha), 14)
	var top := floor_at - Vector2(0.0, STEM * grow)
	if grow > 0.05:
		item.draw_line(floor_at, top, Color(STEM_COLOR, alpha), 2.4, true)
	if open > 0.0:
		for side: float in [-1.0, 1.0]:
			_leaf(item, top, side, LEAF * minf(open, 1.0), LEAF_OPEN * open, alpha)
	SignaturePaint.boon_ring(item, floor_at, phase(t, impact_at(), RING), alpha)


## 茎の先から横へ開く葉1枚。`lift` だけ斜め上へ持ち上げる。
func _leaf(
	item: CanvasItem, root: Vector2, side: float, size: Vector2, lift: float, alpha: float
) -> void:
	if size.x <= 1.0:
		return
	var dir := Vector2(side, 0.0).rotated(-lift * side)
	var across := dir.orthogonal()
	var shape := PackedVector2Array()
	for i in range(13):
		var s := float(i) / 12.0
		shape.append(root + dir * size.x * s + across * size.y * sin(s * PI))
	for i in range(11, 0, -1):
		var s := float(i) / 12.0
		shape.append(root + dir * size.x * s - across * size.y * sin(s * PI) * 0.6)
	item.draw_colored_polygon(shape, Color(LEAF_COLOR, alpha))
