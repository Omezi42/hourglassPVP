extends SignatureMove
## キャンドルの余砂(GameDesign.md 9章):砕けた台座に灯った蝋燭が立ち、溶けて縮むあいだに炎が導火線へ移って
## 味方の駒まで這い、届いたところで溶けた蝋のしずくが落ちて金色の輪が広がる(溶けた蝋が隣の芯を守った)。

const LIGHT := 0.12
const LAY := 0.14
const BURN := 0.3
## 蝋燭の胴の半幅・高さ(駒の拡大を掛ける)、炎の高さ・幅、導火線の波、しずくの大きさと落ちる高さ。
const CANDLE := Vector2(7.0, 26.0)
const FLAME := Vector2(12.0, 8.0)
const SWAY := 6.0
const DROP := 4.0
const DROP_FALL := 26.0


func impact_at() -> float:
	return LIGHT + LAY + BURN


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var melt := phase(t, LIGHT, LAY + BURN)
	var candle_alpha := (
		alpha * minf(phase(t, 0.0, LIGHT) * 3.0, 1.0) * (1.0 - phase(t, impact_at(), FADE * 0.6))
	)
	if candle_alpha > 0.0:
		var h := CANDLE.y * zoom * (1.0 - 0.6 * melt)
		var w := CANDLE.x * zoom
		var body := Rect2(from + Vector2(-w, -h), Vector2(w * 2.0, h))
		ShapePaint.convex_polygon(
			ci,
			PackedVector2Array(
				[
					body.position - Vector2(1.5, 1.5),
					Vector2(body.end.x + 1.5, body.position.y - 1.5),
					body.end + Vector2(1.5, 0.0),
					Vector2(body.position.x - 1.5, body.end.y)
				]
			),
			Color(UiPalette.INK_950, candle_alpha * 0.8)
		)
		ShapePaint.convex_polygon(
			ci,
			PackedVector2Array(
				[
					body.position,
					Vector2(body.end.x, body.position.y),
					body.end,
					Vector2(body.position.x, body.end.y)
				]
			),
			Color(UiPalette.WAX, candle_alpha)
		)
		item.draw_line(
			body.position + Vector2(0.0, h * 0.4),
			Vector2(body.end.x, body.position.y + h * 0.4),
			Color(UiPalette.DYNAMITE, candle_alpha),
			1.6
		)
		var flicker := 1.0 + 0.12 * sin(t * 40.0)
		SignaturePaint.flame_tongue(
			item,
			from - Vector2(0.0, h),
			FLAME.x * zoom * flicker,
			FLAME.y * zoom,
			sin(t * 23.0) * 2.0,
			candle_alpha
		)
	var laid := ease(phase(t, LIGHT, LAY), 0.6)
	var burnt := phase(t, LIGHT + LAY, BURN)
	var cord_alpha := alpha * (1.0 - phase(t, impact_at(), FADE * 0.5))
	var head := from - Vector2(0.0, CANDLE.y * zoom * 0.5)
	var drop := phase(t, impact_at() - 0.1, 0.1)
	var land := phase(t, impact_at(), FADE)
	for target in targets:
		SignaturePaint.fuse_cord(item, head, target, laid, burnt, cord_alpha, SWAY)
		if drop > 0.0 and drop < 1.0:
			var at := target - Vector2(0.0, DROP_FALL * (1.0 - drop * drop))
			ShapePaint.circle(ci, at, DROP + 1.4, Color(UiPalette.INK_950, alpha * 0.7))
			ShapePaint.circle(ci, at, DROP, Color(UiPalette.WAX, alpha))
		SignaturePaint.boon_ring(item, target, land, alpha)
