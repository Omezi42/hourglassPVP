extends SignatureMove
## ワイヤーの被弾(GameDesign.md 9章):駒の頭上に張った銅線がびんと震え、まん中で青白い火花を散らして弾け切れ、
## 垂れた片端を火の点が駆け下りて駒へ戻り、届いたところで金色の輪が広がる(触れたら弾ける。自分の砂を落とす代償)。

const TREMBLE := 0.22
const SNAP := 0.08
const RUN := 0.2
## 線の高さ(駒の中心から上へ)と半幅、震えの振れ幅、弾けた火花の大きさ、垂れた端の長さ。
const LIFT := 46.0
const SPAN := 34.0
const SHAKE := 4.0
const FLASH := 14.0
const DROOP := 26.0
const WIDTH := 2.4


func impact_at() -> float:
	return TREMBLE + SNAP + RUN


func top_extent() -> float:
	return (LIFT + FLASH) * zoom


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var line_alpha := alpha * minf(phase(t, 0.0, 0.06) * 3.0, 1.0)
	var y := from.y - LIFT * zoom
	var left := Vector2(from.x - SPAN * zoom, y)
	var right := Vector2(from.x + SPAN * zoom, y)
	var mid := Vector2(from.x, y)
	for end in [left, right]:
		ShapePaint.circle(ci, end, 4.0 * zoom, Color(UiPalette.INK_950, line_alpha * 0.8))
		ShapePaint.circle(ci, end, 3.0 * zoom, Color(UiPalette.IVORY, line_alpha))
	if t < TREMBLE:
		var swing := sin(t * 70.0) * SHAKE * zoom * (0.4 + 0.6 * phase(t, 0.0, TREMBLE))
		var wire := PackedVector2Array([left, mid + Vector2(0.0, swing), right])
		ShapePaint.polyline(ci, wire, Color(UiPalette.INK_950, line_alpha * 0.8), WIDTH + 2.0, true)
		ShapePaint.polyline(ci, wire, Color(UiPalette.COPPER, line_alpha), WIDTH, true)
		return
	var hang := ease(phase(t, TREMBLE, SNAP + RUN * 0.5), 0.5)
	var ends: Array[PackedVector2Array] = []
	for side: float in [-1.0, 1.0]:
		var anchor := right if side > 0.0 else left
		var tip := mid.lerp(anchor + Vector2(-side * 6.0, DROOP) * zoom, hang)
		var bend := anchor.lerp(tip, 0.5) + Vector2(0.0, 6.0 * hang) * zoom
		ends.append(PackedVector2Array([anchor, bend, tip]))
	for wire in ends:
		ShapePaint.polyline(ci, wire, Color(UiPalette.INK_950, line_alpha * 0.8), WIDTH + 2.0, true)
		ShapePaint.polyline(ci, wire, Color(UiPalette.COPPER, line_alpha), WIDTH, true)
	var snap := phase(t, TREMBLE, SNAP * 2.0)
	if snap > 0.0 and snap < 1.0:
		ShapePaint.circle(
			ci, mid, FLASH * zoom * (0.5 + snap), Color(UiPalette.ZAP, alpha * (1.0 - snap) * 0.5)
		)
		for i in range(6):
			var dir := Vector2.from_angle(TAU * float(i) / 6.0 + 0.3)
			item.draw_line(
				mid + dir * FLASH * zoom * 0.3,
				mid + dir * FLASH * zoom * (0.6 + snap),
				Color(SignaturePaint.SPARK_HOT, alpha * (1.0 - snap)),
				1.8,
				true
			)
	var run := phase(t, TREMBLE + SNAP, RUN)
	var land := phase(t, impact_at(), FADE)
	for target in targets:
		if run > 0.0 and run < 1.0:
			var tip: Vector2 = ends[1][2]
			var at := tip.lerp(target, ease(run, 1.6))
			SignaturePaint.fuse_spark(item, at, zoom, alpha, t * 9.0)
		SignaturePaint.boon_ring(item, target, land, alpha)
