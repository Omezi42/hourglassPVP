extends SignatureMove
## キャスクの設置(GameDesign.md 9章):駒の頭上に横に寝た樫の樽が現れて傾き、鏡板の呑み口から
## 青緑の水が弧を描いて駒の頭へ注がれ、届いたところでしぶきが跳ねて金色の輪が広がる(恵与)。

const APPEAR := 0.12
const TIP := 0.12
const POUR := 0.3
## 樽の中心(駒の中心から)と半長・半高、傾ききった角度、注ぎ先(駒の中心から)、箍の位置(半長に対する比)。
const BARREL := Vector2(-30.0, -96.0)
const HALF := Vector2(26.0, 14.0)
const TILT := 0.32
const MOUTH := Vector2(0.0, -40.0)
const HOOPS: Array[float] = [-0.62, 0.62]
const TOP := 120.0


func top_extent() -> float:
	return TOP * zoom


func impact_at() -> float:
	return APPEAR + TIP + POUR


func draw(item: CanvasItem, t: float) -> void:
	var alpha := fade_alpha(t) * minf(phase(t, 0.0, APPEAR) * 1.5, 1.0)
	var center := from + BARREL * zoom
	var angle := TILT * ease(phase(t, APPEAR, TIP), 0.6)
	_barrel(item, center, angle, alpha)
	var tap := center + Vector2(HALF.x + 4.0, 4.0).rotated(angle) * zoom
	var mouth := from + MOUTH * zoom
	var pour := phase(t, APPEAR + TIP, POUR)
	var drain := phase(t, impact_at(), FADE)
	PourPaint.stream(item, tap, mouth, 10.0 * zoom, ease(pour, 0.7), drain, alpha, zoom)
	if t >= impact_at():
		PourPaint.splash(item, mouth, drain, alpha, zoom)
		SignaturePaint.boon_ring(item, from, drain, alpha)


## 横に寝た樽。樫の胴に箍を2本、右の鏡板に真鍮の呑み口。
func _barrel(item: CanvasItem, center: Vector2, angle: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var body := PackedVector2Array()
	for i in range(24):
		var a := TAU * float(i) / 24.0
		var x := cos(a)
		var bulge := 1.0 - 0.18 * x * x
		body.append(center + (Vector2(x * HALF.x, sin(a) * HALF.y * bulge) * zoom).rotated(angle))
	ShapePaint.convex_polygon(
		ci, ForesightPaint.grown(body, center, 2.0), Color(UiPalette.INK_950, alpha)
	)
	ShapePaint.convex_polygon(ci, body, Color(UiPalette.OAK, alpha))
	var across := Vector2(0.0, 1.0).rotated(angle)
	for k: float in HOOPS:
		var at := center + Vector2(k * HALF.x, 0.0).rotated(angle) * zoom
		var reach := HALF.y * (1.0 - 0.18 * k * k) * zoom
		item.draw_line(
			at - across * reach, at + across * reach, Color(UiPalette.STEEL, alpha), 3.0, true
		)
	var head := center + Vector2(HALF.x, 0.0).rotated(angle) * zoom
	item.draw_line(
		head, head + Vector2(6.0, 4.0).rotated(angle) * zoom, Color(UiPalette.BRASS, alpha), 4.0
	)
