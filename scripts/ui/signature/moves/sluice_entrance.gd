extends SignatureMove
## スルースの登場(GameDesign.md 9章):着地すると台座の左右に石の橋脚がせり上がり、あいだへ板張りの門扉が
## 落ちて閉じる。扉の向こうに青緑の水がせり上がって縁まで溜まり、隙間から一滴だけこぼれる(堰を切るのは明日)。

const RAISE := 0.16
const DROP := 0.12
const FILL := 0.26
const HOLD := 0.12
## 橋脚の間隔(台座の中心から)・幅・高さ、門扉の半幅・高さ、扉の上に見える水の高さ。
const PIER_X := 46.0
const PIER_W := 10.0
const PIER_H := 70.0
const GATE := Vector2(36.0, 40.0)
const POOL := 18.0


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + RAISE + DROP + FILL + HOLD + FADE


func sound() -> int:
	return SoundBank.Sfx.SIG_SLUICE


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var raise := ease(phase(t, impact_at(), RAISE), 0.5)
	var drop := ease(phase(t, impact_at() + RAISE, DROP), 2.0)
	var fill := ease(phase(t, impact_at() + RAISE + DROP, FILL), 0.6)
	var leak := phase(t, impact_at() + RAISE + DROP + FILL * 0.6, HOLD + FADE)
	var foot := from
	var gate_top := foot.y - GATE.y
	if fill > 0.0:
		var surface := gate_top - POOL * fill
		var pool := PackedVector2Array(
			[
				Vector2(foot.x - GATE.x, gate_top + 4.0),
				Vector2(foot.x - GATE.x, surface),
				Vector2(foot.x + GATE.x, surface),
				Vector2(foot.x + GATE.x, gate_top + 4.0),
			]
		)
		ShapePaint.convex_polygon(ci, pool, Color(UiPalette.POUR_WATER, alpha * 0.9))
		item.draw_line(
			Vector2(foot.x - GATE.x, surface),
			Vector2(foot.x + GATE.x, surface),
			Color(UiPalette.POUR_FOAM, alpha),
			2.2,
			true
		)
	if drop > 0.0:
		var top := lerpf(foot.y - PIER_H, gate_top, drop)
		var bottom := top + GATE.y
		var gate := PackedVector2Array(
			[
				Vector2(foot.x - GATE.x, top),
				Vector2(foot.x + GATE.x, top),
				Vector2(foot.x + GATE.x, bottom),
				Vector2(foot.x - GATE.x, bottom),
			]
		)
		ShapePaint.convex_polygon(
			ci, ForesightPaint.grown(gate, foot, 2.0), Color(UiPalette.INK_950, alpha)
		)
		ShapePaint.convex_polygon(ci, gate, Color(UiPalette.OAK, alpha))
		for k in range(1, 4):
			var y := top + GATE.y * float(k) / 4.0
			item.draw_line(
				Vector2(foot.x - GATE.x, y),
				Vector2(foot.x + GATE.x, y),
				Color(UiPalette.WOOD_DARK, alpha * 0.8),
				1.4
			)
	for side: float in [-1.0, 1.0]:
		var x := foot.x + side * PIER_X
		var pier := PackedVector2Array(
			[
				Vector2(x - PIER_W, foot.y),
				Vector2(x - PIER_W, foot.y - PIER_H * raise),
				Vector2(x + PIER_W, foot.y - PIER_H * raise),
				Vector2(x + PIER_W, foot.y),
			]
		)
		ShapePaint.convex_polygon(
			ci, ForesightPaint.grown(pier, Vector2(x, foot.y), 2.0), Color(UiPalette.INK_950, alpha)
		)
		ShapePaint.convex_polygon(ci, pier, Color(UiPalette.BASALT.lightened(0.35), alpha))
	if leak > 0.0 and leak < 1.0:
		var at := Vector2(foot.x + 8.0, gate_top + GATE.y * 0.35 + 30.0 * leak * leak)
		SignaturePaint.water_drop(item, at, 3.4, Vector2.DOWN, alpha * (1.0 - leak))
