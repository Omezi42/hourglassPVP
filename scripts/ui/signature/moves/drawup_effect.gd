extends SignatureMove
## 汲み上げ(GameDesign.md 9章)。払拭では、撃った位置にゴムの球を付けた硝子のスポイトが現れ、先から銅の吸い管が相手の駒へ伸び、
## 球が縮んで膨らむと他人の色の滴が管を登ってスポイトへ吸い上げられ、相手の駒に縮む渦が残る。
## 続く恵与では、スポイトが味方の駒の頭上に傾いて現れ、吸い上げた滴を2粒落として金色の輪が広がる。

const APPEAR := 0.1
const REACH := 0.2
const SUCK := 0.3
const DROP := 0.26
const DROPS := 2
## スポイトの硝子の胴の半寸法、ゴムの球の半径、先の長さ、吸い管の弧の高さ、恵与での位置(対象の中心から)と傾き。
const BARREL := Vector2(8.0, 24.0)
const BULB := 12.0
const NOZZLE := 15.0
const ARC := 50.0
const OVER_ALLY := Vector2(0.0, -86.0)
const TILT := 0.35
const TOP := 110.0


func top_extent() -> float:
	return TOP if _giving() else 0.0


func impact_at() -> float:
	if _giving():
		return APPEAR + DROP
	return APPEAR + REACH + SUCK


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t) * minf(phase(t, 0.0, APPEAR) * 1.5, 1.0)
	var target := targets[0]
	if _giving():
		var center := target + OVER_ALLY
		_dropper(item, center, TILT, 1.0 - phase(t, APPEAR, DROP), 1.0, alpha)
		var tip := center + Vector2(0.0, BARREL.y + NOZZLE).rotated(TILT)
		for i in range(DROPS):
			var fall := phase(t, APPEAR + DROP * 0.45 * float(i), DROP * 0.55)
			if fall > 0.0 and fall < 1.0:
				SignaturePaint.water_drop(
					item,
					tip.lerp(target + Vector2(0.0, -16.0), fall * fall),
					4.0,
					Vector2.DOWN,
					alpha
				)
		SignaturePaint.boon_ring(item, target, phase(t, impact_at(), FADE), alpha)
		return
	var center := from + Vector2(0.0, -BARREL.y - BULB)
	var tip := center + Vector2(0.0, BARREL.y + NOZZLE)
	var reach := ease(phase(t, APPEAR, REACH), 0.6)
	var suck := phase(t, APPEAR + REACH, SUCK)
	var squeeze := sin(suck * PI) * 0.45
	_dropper(item, center, 0.0, suck, 1.0 - squeeze, alpha)
	DrawSandPaint.tube(item, tip, target, ARC, reach, alpha * (1.0 - phase(t, impact_at(), FADE)))
	DrawSandPaint.beads(item, tip, target, ARC, suck, alpha)
	DrawSandPaint.gulp(item, target, suck, alpha)
	SignaturePaint.drain_ring(item, target, phase(t, impact_at(), FADE), alpha)


## 硝子のスポイト。下へ細る先、`fill` まで他人の色が満ちた胴、`bulb` だけ横に縮むゴムの球。
func _dropper(
	item: CanvasItem, center: Vector2, angle: float, fill: float, bulb: float, alpha: float
) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var barrel := PackedVector2Array(
		[
			center + Vector2(-BARREL.x, -BARREL.y).rotated(angle),
			center + Vector2(BARREL.x, -BARREL.y).rotated(angle),
			center + Vector2(BARREL.x, BARREL.y).rotated(angle),
			center + Vector2(2.0, BARREL.y + NOZZLE).rotated(angle),
			center + Vector2(-2.0, BARREL.y + NOZZLE).rotated(angle),
			center + Vector2(-BARREL.x, BARREL.y).rotated(angle),
		]
	)
	ShapePaint.convex_polygon(
		ci, ForesightPaint.grown(barrel, center, 2.0), Color(UiPalette.INK_950, alpha)
	)
	ShapePaint.convex_polygon(ci, barrel, Color(UiPalette.CRYSTAL, alpha * 0.6))
	if fill > 0.0:
		var level := BARREL.y - 2.0 * BARREL.y * clampf(fill, 0.0, 1.0)
		var liquid := PackedVector2Array(
			[
				center + Vector2(-BARREL.x + 1.5, level).rotated(angle),
				center + Vector2(BARREL.x - 1.5, level).rotated(angle),
				center + Vector2(BARREL.x - 1.5, BARREL.y).rotated(angle),
				center + Vector2(-BARREL.x + 1.5, BARREL.y).rotated(angle),
			]
		)
		ShapePaint.convex_polygon(ci, liquid, Color(UiPalette.DRAW_FOREIGN, alpha))
	var top := center + Vector2(0.0, -BARREL.y - BULB * 0.8).rotated(angle)
	var rubber := PackedVector2Array()
	for i in range(17):
		var a := TAU * float(i) / 16.0
		rubber.append(top + Vector2(cos(a) * BULB * bulb, sin(a) * BULB).rotated(angle))
	ShapePaint.convex_polygon(
		ci, ForesightPaint.grown(rubber, top, 2.0), Color(UiPalette.INK_950, alpha)
	)
	ShapePaint.convex_polygon(ci, rubber, Color(UiPalette.RUBBER, alpha))
	ShapePaint.circle(
		ci,
		top + Vector2(-BULB * 0.35 * bulb, -BULB * 0.35),
		2.2,
		Color(UiPalette.IVORY, alpha * 0.5)
	)


func _giving() -> bool:
	return style == CardEnums.EffectVisualStyle.DESCEND
