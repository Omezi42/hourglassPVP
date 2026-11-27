extends SignatureMove
## デリュージの設置(GameDesign.md 9章):自分の列の上に金の縁取りの雨雲が垂れこめて広がり、味方の駒すべてへ
## いっせいに光る雨が降り注いで、届いた駒からしぶきが跳ねて金色の輪が広がる(恵与)。

const GATHER := 0.2
const RAIN := 0.3
## 雲の高さ(列の駒の中心から)・雲の玉の半径と並び、雨の筋の数・長さ・傾き、雲が列の外へはみ出す幅。
const CLOUD_LIFT := 78.0
const PUFF := 22.0
const PUFF_STEP := 26.0
const STREAKS := 7
const STREAK := 16.0
const SLANT := 4.0
const MARGIN := 40.0
const MOUTH := Vector2(0.0, -30.0)
const TOP := 110.0


func top_extent() -> float:
	return TOP * zoom


func impact_at() -> float:
	return GATHER + RAIN


func draw(item: CanvasItem, t: float) -> void:
	var points: Array[Vector2] = []
	points.assign(targets)
	if points.is_empty():
		points.append(from)
	var left := points[0].x
	var right := points[0].x
	var floor_y := points[0].y
	for p in points:
		left = minf(left, p.x)
		right = maxf(right, p.x)
		floor_y = minf(floor_y, p.y)
	var alpha := fade_alpha(t)
	var gather := ease(phase(t, 0.0, GATHER), 0.5)
	var sky := floor_y - CLOUD_LIFT * zoom
	var mid := (left + right) * 0.5
	var span := (right - left) * 0.5 + MARGIN
	_cloud(item, Vector2(mid, sky), span * gather, alpha * minf(gather * 1.5, 1.0))
	var rain := phase(t, GATHER, RAIN + FADE)
	var settle := phase(t, impact_at(), FADE)
	for p in points:
		_rain(item, Vector2(p.x, sky + PUFF * 0.5), p + MOUTH, rain, alpha)
		if t >= impact_at():
			PourPaint.splash(item, p + MOUTH, settle, alpha)
			SignaturePaint.boon_ring(item, p, settle, alpha)


## 横に `span` だけ広がった雨雲。暗い腹に明るい頭、縁を金で取る。
func _cloud(item: CanvasItem, center: Vector2, span: float, alpha: float) -> void:
	if alpha <= 0.0 or span <= 1.0:
		return
	var ci := item.get_canvas_item()
	var count := maxi(int(span * 2.0 / PUFF_STEP), 2)
	for pass_i in range(3):
		for i in range(count + 1):
			var x := lerpf(center.x - span, center.x + span, float(i) / float(count))
			var bump := PUFF * (0.8 + 0.35 * SignaturePaint.jitter(i, 71))
			var at := Vector2(x, center.y - bump * 0.3)
			match pass_i:
				0:
					ShapePaint.circle(ci, at, bump + 3.0, Color(UiPalette.TOLL_BRASS, alpha))
				1:
					ShapePaint.circle(ci, at, bump, Color(UiPalette.STORM_CLOUD, alpha))
				_:
					ShapePaint.circle(
						ci,
						at - Vector2(0.0, bump * 0.35),
						bump * 0.55,
						Color(UiPalette.STORM_CLOUD.lightened(0.3), alpha)
					)


## 雲の腹から `to` へ降る光る雨の筋。`rain` は0→1で降り進み、筋が下へ流れる。
func _rain(item: CanvasItem, cloud: Vector2, to: Vector2, rain: float, alpha: float) -> void:
	if rain <= 0.0 or alpha <= 0.0:
		return
	var fall := to.y - cloud.y
	for i in range(STREAKS):
		var x := cloud.x + (float(i) / float(STREAKS - 1) - 0.5) * PUFF * 2.2
		var offset := fmod(rain * 2.0 + SignaturePaint.jitter(i, 72), 1.0)
		var y := cloud.y + fall * offset * minf(rain * 2.0, 1.0)
		var a := Vector2(x + SLANT * offset, y)
		var b := a + Vector2(-SLANT * 0.4, STREAK)
		item.draw_line(a, b, Color(UiPalette.POUR_DEEP, alpha * 0.6), 3.4, true)
		item.draw_line(a, b, Color(UiPalette.POUR_FOAM, alpha), 1.8, true)
