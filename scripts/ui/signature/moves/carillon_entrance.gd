extends SignatureMove
## カリヨンの登場(GameDesign.md 9章):通常より高くから重く落ちて卓が揺れ、駒の頭上の梁に大きさの揃った七つの鐘が
## 並び、左の大きな鐘から右の小さな鐘へ順に振れて鳴り、鳴るたびに小さな音の輪が広がる(七つそろってから鳴らす曲)。

const APPEAR := 0.1
const STEP := 0.06
const RING := 0.1
## 鐘の数、梁の高さ(台座の上面から上へ)・鐘の間隔、いちばん大きい鐘・いちばん小さい鐘の大きさ、振れ幅、輪の広がり。
const BELLS := 7
const LIFT := 132.0
const GAP := 17.0
const BIG := Vector2(15.0, 17.0)
const SMALL := 0.55
const SWING := 0.45
const RING_REACH := 16.0


func impact_at() -> float:
	return CardUnitFx.HEAVY_LAND_DURATION


func duration() -> float:
	return impact_at() + APPEAR + STEP * float(BELLS - 1) + RING + FADE


func heavy_land() -> bool:
	return true


func sound() -> int:
	return SoundBank.Sfx.SIG_CARILLON


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t) * minf(phase(t, impact_at(), APPEAR) * 2.0, 1.0)
	var beam_y := from.y - LIFT
	var half := GAP * float(BELLS - 1) * 0.5 + BIG.x * 0.8
	var beam := PackedVector2Array([Vector2(from.x - half, beam_y), Vector2(from.x + half, beam_y)])
	ShapePaint.polyline(ci, beam, Color(UiPalette.INK_950, alpha * 0.85), 6.0, true)
	ShapePaint.polyline(ci, beam, Color(UiPalette.BRASS_DEEP, alpha), 3.6, true)
	for i in range(BELLS):
		var size := BIG * lerpf(1.0, SMALL, float(i) / float(BELLS - 1))
		var pivot := Vector2(from.x - GAP * float(BELLS - 1) * 0.5 + GAP * float(i), beam_y)
		var strike := impact_at() + APPEAR + STEP * float(i)
		var ring := phase(t, strike, RING * 2.0)
		var swing := sin(ring * TAU) * SWING * (1.0 - ring)
		_bell(ci, pivot, size, swing, alpha)
		if ring > 0.0 and ring < 1.0:
			SignaturePaint.toll_arcs(
				item,
				pivot + Vector2(0.0, size.y),
				Vector2.DOWN,
				RING_REACH * ease(ring, 0.5),
				alpha * (1.0 - ring)
			)


## 小さな鐘。`size` は口の横幅と高さ。支点のまわりに `swing` だけ傾く。
static func _bell(ci: RID, pivot: Vector2, size: Vector2, swing: float, alpha: float) -> void:
	var w := size.x * 0.5
	var h := size.y
	var outline := PackedVector2Array(
		[
			Vector2(-w * 0.45, 0.0),
			Vector2(w * 0.45, 0.0),
			Vector2(w * 0.62, h * 0.5),
			Vector2(w, h),
			Vector2(-w, h),
			Vector2(-w * 0.62, h * 0.5),
		]
	)
	var shape := PackedVector2Array()
	var rim := PackedVector2Array()
	for p in outline:
		shape.append(pivot + p.rotated(swing))
		rim.append(pivot + (p * 1.12 + Vector2(0.0, -0.6)).rotated(swing))
	ShapePaint.convex_polygon(ci, rim, Color(UiPalette.INK_950, alpha * 0.85))
	ShapePaint.convex_polygon(ci, shape, Color(UiPalette.TOLL_BRASS, alpha))
	ShapePaint.circle(
		ci, pivot + Vector2(0.0, h).rotated(swing), w * 0.22, Color(UiPalette.BRASS_DEEP, alpha)
	)
