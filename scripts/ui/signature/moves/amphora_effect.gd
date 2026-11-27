extends SignatureMove
## アンフォラの余砂(GameDesign.md 9章):砕けた台座の上に両取っ手の素焼きの壺が現れ、胴にひびが走って左右に割れ、
## こぼれた砂の色の油が左の駒から順に弧を描いて注がれ、届いた駒からしぶきが跳ねて金色の輪が広がる(恵与)。

const APPEAR := 0.1
const CRACK := 0.16
## 1体ぶんの注ぎの長さ(駒が多いときは全体が `SPAN` に収まるよう縮める)。
const SERVE := 0.14
const SPAN := 0.56
## 壺の中心(出どころから)と半幅・半高、割れて開く幅と傾き、弧の高さ、注ぎ先(対象の中心から)。
const JAR := Vector2(0.0, -50.0)
const JAR_HALF := Vector2(16.0, 20.0)
const SPLIT := 12.0
const LEAN := 0.4
const ARC := 50.0
const MOUTH := Vector2(0.0, -36.0)


func impact_at() -> float:
	return APPEAR + CRACK + _step() * float(maxi(targets.size(), 1))


func reaches(index: int, t: float) -> bool:
	return t >= APPEAR + CRACK + _step() * float(index + 1)


func draw(item: CanvasItem, t: float) -> void:
	var alpha := fade_alpha(t) * minf(phase(t, 0.0, APPEAR) * 1.5, 1.0)
	var center := from + JAR
	var crack := phase(t, APPEAR, CRACK)
	var split := ease(phase(t, APPEAR + CRACK * 0.6, CRACK), 0.5)
	_halves(item, center, crack, split, alpha)
	var step := _step()
	for i in range(targets.size()):
		var start := APPEAR + CRACK + step * float(i)
		var serve := phase(t, start, step)
		if serve <= 0.0:
			break
		var mouth := targets[i] + MOUTH
		var after := phase(t, start + step, FADE)
		PourPaint.stream(
			item,
			center,
			mouth,
			ARC,
			ease(serve, 0.7),
			maxf(serve - 0.4, 0.0),
			alpha,
			0.9,
			UiPalette.OLIVE_OIL
		)
		PourPaint.splash(item, mouth, after, alpha)
		SignaturePaint.boon_ring(item, targets[i], after, alpha)


## 壺の左右の半分。`crack` まで胴に黒いひびが走り、`split` で左右へ開いて傾く。
func _halves(item: CanvasItem, center: Vector2, crack: float, split: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	for side: float in [-1.0, 1.0]:
		var pivot := center + Vector2(side * SPLIT * split, 0.0)
		var tilt := side * LEAN * split
		var half := PackedVector2Array([pivot + Vector2(0.0, -JAR_HALF.y - 6.0).rotated(tilt)])
		for i in range(9):
			var a := -PI * 0.5 + side * PI * float(i) / 8.0
			var r := Vector2(cos(a) * JAR_HALF.x, sin(a) * JAR_HALF.y)
			half.append(pivot + r.rotated(tilt))
		half.append(pivot + Vector2(0.0, JAR_HALF.y).rotated(tilt))
		ShapePaint.convex_polygon(
			ci, ForesightPaint.grown(half, pivot, 2.0), Color(UiPalette.INK_950, alpha)
		)
		ShapePaint.convex_polygon(ci, half, Color(UiPalette.TERRACOTTA, alpha))
		var band_y := 2.0
		item.draw_line(
			pivot + Vector2(0.0, band_y).rotated(tilt),
			pivot + Vector2(side * JAR_HALF.x * 0.95, band_y).rotated(tilt),
			Color(UiPalette.INK_950, alpha * 0.85),
			5.0,
			true
		)
		ShapePaint.arc(
			ci,
			pivot + Vector2(side * (JAR_HALF.x + 2.0), -JAR_HALF.y * 0.5).rotated(tilt),
			6.0,
			-PI * 0.5,
			PI * 0.5,
			8,
			Color(UiPalette.TERRACOTTA, alpha),
			3.0,
			true
		)
	if crack > 0.0 and split <= 0.0:
		var top := center + Vector2(0.0, -JAR_HALF.y)
		var zig := PackedVector2Array()
		for i in range(6):
			var k := float(i) / 5.0 * crack
			zig.append(top + Vector2(3.0 * (1.0 if i % 2 == 0 else -1.0), JAR_HALF.y * 2.0 * k))
		ShapePaint.polyline(ci, zig, Color(UiPalette.INK_950, alpha), 2.0, true)


func _step() -> float:
	return minf(SERVE, SPAN / float(maxi(targets.size(), 1)))
