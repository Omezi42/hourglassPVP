extends SignatureMove
## ホールドの登場(GameDesign.md 9章):着地すると、駒の前へ丸盾が3枚、左右と下から寄って重なり合い、
## 縁を燠火の光がひと回りしてから薄れる(守護。数で押されている間は静止する構え)。

const GATHER := 0.3
const RIM := 0.3
## 盾の止まる位置(台座の上面から)、半径、寄ってくる距離、左右の盾が遅れる割合。
const CENTER_AT := Vector2(0.0, -24.0)
const SIDE_AT := Vector2(30.0, -30.0)
const RADIUS := 20.0
const SIDE_RADIUS := 17.0
const SLIDE := 54.0
const SIDE_LAG := 0.25
const BOSS := 0.3
const RIM_WIDTH := 3.0


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + GATHER + RIM + FADE


func sound() -> int:
	return SoundBank.Sfx.SIG_HOLD


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var gather := phase(t, impact_at(), GATHER)
	var lit := phase(t, impact_at() + GATHER, RIM)
	for side: float in [-1.0, 1.0]:
		var k := back_out(clampf((gather - SIDE_LAG) / (1.0 - SIDE_LAG), 0.0, 1.0))
		var at := from + Vector2(side * (SIDE_AT.x + SLIDE * (1.0 - k)), SIDE_AT.y)
		_shield(ci, at, SIDE_RADIUS, side, alpha * minf(k * 3.0, 1.0), lit)
	var rise := back_out(clampf(gather / (1.0 - SIDE_LAG), 0.0, 1.0))
	var center := from + CENTER_AT + Vector2(0.0, SLIDE * 0.6 * (1.0 - rise))
	_shield(ci, center, RADIUS, 0.0, alpha * minf(rise * 3.0, 1.0), lit)


## 丸盾。2色に塗り分けた板、真鍮の縁と中央の突起。`lit` が進むと縁を燠火の光が回る。
func _shield(ci: RID, at: Vector2, radius: float, turn: float, alpha: float, lit: float) -> void:
	if alpha <= 0.0:
		return
	ShapePaint.circle(ci, at, radius + 1.6, Color(UiPalette.INK_950, alpha * 0.85))
	ShapePaint.circle(ci, at, radius, Color(UiPalette.IVORY, alpha))
	var half := PackedVector2Array([at])
	const SEGMENTS := 16
	for i in range(SEGMENTS + 1):
		var a := PI * 0.5 + turn + PI * float(i) / float(SEGMENTS)
		half.append(at + Vector2(cos(a), sin(a)) * radius)
	ShapePaint.colored_polygon(ci, half, Color(UiPalette.SHIELD_PAINT, alpha))
	ShapePaint.arc(
		ci, at, radius - 1.0, 0.0, TAU, 32, Color(UiPalette.GOLD, alpha), RIM_WIDTH, true
	)
	ShapePaint.circle(ci, at, radius * BOSS + 1.0, Color(UiPalette.INK_950, alpha * 0.8))
	ShapePaint.circle(ci, at, radius * BOSS, Color(UiPalette.GOLD, alpha))
	if lit > 0.0 and lit < 1.0:
		var head := -PI * 0.5 + TAU * ease(lit, 0.8)
		var glow := alpha * sin(lit * PI)
		ShapePaint.arc(
			ci,
			at,
			radius - 1.0,
			head - 1.2,
			head,
			12,
			Color(UiPalette.EMBER, glow),
			RIM_WIDTH + 1.0,
			true
		)
		ShapePaint.circle(
			ci,
			at + Vector2(cos(head), sin(head)) * (radius - 1.0),
			3.0,
			Color(SignaturePaint.SPARK_HOT, glow)
		)
