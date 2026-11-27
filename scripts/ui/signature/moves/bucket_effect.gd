extends SignatureMove
## バケツの設置(GameDesign.md 9章):駒の頭上から縄に吊った木の桶が弧を描いて相手の駒の頭へ振り下ろされ、ひと汲みすると
## 相手の駒に縮む渦が残り、他人の色の砂を縁まで満たした桶が縄を手繰られて戻ってくる(払拭)。

const APPEAR := 0.08
const SWING := 0.26
const DIP := 0.1
const BACK := 0.26
## 縄の結び目(駒の中心から)、汲む位置(対象の中心から)、弧の高さ、桶の底と縁の半幅・高さ。
const ANCHOR := Vector2(0.0, -96.0)
const SCOOP := Vector2(0.0, -30.0)
const ARC := 40.0
const TUB := Vector3(10.0, 15.0, 20.0)
const TOP := 120.0


func top_extent() -> float:
	return TOP * zoom


func impact_at() -> float:
	return APPEAR + SWING + DIP


func duration() -> float:
	return impact_at() + BACK + FADE


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t) * minf(phase(t, 0.0, APPEAR) * 1.5, 1.0)
	var anchor := from + ANCHOR * zoom
	var target := targets[0]
	var scoop := target + SCOOP
	var out := ease(phase(t, APPEAR, SWING), -1.6)
	var back := ease(phase(t, impact_at(), BACK), -1.6)
	var dip := sin(phase(t, APPEAR + SWING, DIP) * PI) * 6.0
	var at := PourPaint.along(anchor, scoop, -ARC, out)
	if back > 0.0:
		at = PourPaint.along(scoop, anchor, ARC, back)
	at.y += dip
	var ci := item.get_canvas_item()
	ShapePaint.circle(ci, anchor, 3.4, Color(UiPalette.KINTSUGI, alpha))
	item.draw_line(anchor, at + Vector2(0.0, -TUB.z), Color(UiPalette.INK_950, alpha), 3.4, true)
	item.draw_line(anchor, at + Vector2(0.0, -TUB.z), Color(UiPalette.HORN, alpha), 1.8, true)
	DrawSandPaint.gulp(item, target, phase(t, APPEAR + SWING * 0.7, SWING * 0.3 + DIP), alpha)
	SignaturePaint.drain_ring(item, target, phase(t, impact_at(), FADE), alpha)
	_tub(item, at, 1.0 if t >= APPEAR + SWING + DIP * 0.5 else 0.0, alpha)


## 鉄の箍を締めた木の桶と針金の弦。`full` が1なら縁まで他人の色の砂が満ちている。
func _tub(item: CanvasItem, at: Vector2, full: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var rim := at + Vector2(0.0, -TUB.z * 0.5)
	ShapePaint.arc(ci, rim, TUB.y + 1.0, PI, TAU, 12, Color(UiPalette.INK_950, alpha), 3.0, true)
	ShapePaint.arc(ci, rim, TUB.y + 1.0, PI, TAU, 12, Color(UiPalette.CAST_IRON, alpha), 1.6, true)
	var body := PackedVector2Array(
		[
			rim + Vector2(-TUB.y, 0.0),
			rim + Vector2(TUB.y, 0.0),
			rim + Vector2(TUB.x, TUB.z),
			rim + Vector2(-TUB.x, TUB.z),
		]
	)
	ShapePaint.convex_polygon(
		ci, ForesightPaint.grown(body, at, 2.0), Color(UiPalette.INK_950, alpha)
	)
	ShapePaint.convex_polygon(ci, body, Color(UiPalette.OAK, alpha))
	for y: float in [0.3, 0.75]:
		var w := lerpf(TUB.y, TUB.x, y)
		item.draw_line(
			rim + Vector2(-w, TUB.z * y),
			rim + Vector2(w, TUB.z * y),
			Color(UiPalette.CAST_IRON, alpha),
			2.0
		)
	if full > 0.0:
		var heap := PackedVector2Array()
		for i in range(9):
			var a := PI + PI * float(i) / 8.0
			heap.append(rim + Vector2(cos(a) * (TUB.y - 1.0), sin(a) * 5.0))
		ShapePaint.convex_polygon(ci, heap, Color(UiPalette.DRAW_FOREIGN, alpha * full))
