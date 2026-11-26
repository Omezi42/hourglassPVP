extends SignatureMove
## ボイラーの恵与(GameDesign.md 9章):設置で、駒の頭上に銅の汽笛が現れて湯気を噴き上げ、短く鳴った音の輪と
## 湯気のかたまりが自分のHPの器へ流れ着き、届いたところで金色の輪が広がる(次の手番を削って体を早く立てる)。

const BUILD := 0.3
const DRIFT := 0.3
## 汽笛の位置(駒の中心から上へ)と胴・口金の大きさ、噴き上がる湯気の粒の数・高さ・大きさ、流れる湯気の大きさ。
const LIFT := 40.0
const PIPE := Vector2(8.0, 18.0)
const CAP := Vector2(12.0, 4.0)
const PUFFS := 5
const RISE := 34.0
const PUFF := 8.0
const CLOUD := 13.0
const FLIGHT_RADIUS := 15.0


func impact_at() -> float:
	return BUILD + DRIFT


func top_extent() -> float:
	return (LIFT + PIPE.y + RISE + PUFF * 2.0) * zoom


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var base := from - Vector2(0.0, LIFT * zoom)
	var mouth := base - Vector2(0.0, (PIPE.y + CAP.y) * zoom)
	var build := phase(t, 0.0, BUILD)
	var pipe_alpha := alpha * minf(build * 5.0, 1.0) * (1.0 - phase(t, impact_at(), FADE))
	if pipe_alpha > 0.0:
		var body := Rect2(
			base - Vector2(PIPE.x, PIPE.y) * zoom, Vector2(PIPE.x * 2.0, PIPE.y) * zoom
		)
		ShapePaint.convex_polygon(
			ci, _rect_points(body.grow(1.4)), Color(UiPalette.INK_950, pipe_alpha * 0.85)
		)
		ShapePaint.convex_polygon(ci, _rect_points(body), Color(UiPalette.COPPER, pipe_alpha))
		var cap := Rect2(mouth - Vector2(CAP.x, 0.0) * zoom, Vector2(CAP.x * 2.0, CAP.y) * zoom)
		ShapePaint.convex_polygon(
			ci, _rect_points(cap.grow(1.2)), Color(UiPalette.INK_950, pipe_alpha * 0.85)
		)
		ShapePaint.convex_polygon(ci, _rect_points(cap), Color(UiPalette.TOLL_BRASS, pipe_alpha))
	for i in range(PUFFS):
		var start := BUILD * 0.15 * float(i)
		var k := phase(t, start, BUILD)
		if k <= 0.0 or k >= 1.0:
			continue
		var sway := (SignaturePaint.jitter(i, 41) - 0.5) * 14.0
		var at := mouth + Vector2(sway * k, -RISE * k) * zoom
		ShapePaint.circle(
			ci, at, PUFF * zoom * (0.6 + k), Color(UiPalette.STEAM, alpha * (1.0 - k) * 0.85)
		)
	var blast := phase(t, BUILD * 0.8, DRIFT * 0.6)
	if blast > 0.0 and blast < 1.0:
		SignaturePaint.toll_arcs(
			item, mouth, Vector2.UP, 26.0 * zoom * ease(blast, 0.5), alpha * (1.0 - blast)
		)
	var drift := phase(t, BUILD, DRIFT)
	var land := phase(t, impact_at(), FADE)
	for target in targets:
		if drift > 0.0 and drift < 1.0:
			var head := mouth.lerp(target, ease(drift, 0.8)) + Vector2(0.0, -sin(drift * PI) * 24.0)
			for j in range(3):
				var r := CLOUD * zoom * (1.0 - 0.25 * float(j))
				var lag := head.lerp(mouth, 0.08 * float(j))
				ShapePaint.circle(
					ci, lag, r, Color(UiPalette.STEAM, alpha * (0.9 - 0.2 * float(j)))
				)
		SignaturePaint.toll_flight(item, mouth, target, drift, FLIGHT_RADIUS, alpha * 0.8)
		SignaturePaint.boon_ring(item, target, land, alpha)


static func _rect_points(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]
	)
