extends SignatureMove
## セージの登場(GameDesign.md 9章):駒の頭上にとんがり帽子がふわりと舞い降りて傾き、つばの下に浮かんだ
## 光の札から水色の玉が1つ抜けて昇り消える(砂術のコストが1下がる印)。

const SETTLE := 0.4
const SLIP := 0.34
## 帽子が止まる高さ(台座の上面から上へ)と、降りてくる前の高さの差、傾き(ラジアン)。
const LIFT := 148.0
const DROP := 34.0
const TILT := 0.22
## 帽子の高さ・つばの半幅と、帯の高さ。
const CONE := 24.0
const BRIM := 17.0
const BAND := 5.0
const FELT := Color(0.20, 0.17, 0.34, 1.0)
## 光の札の置き場所(帽子の中心から)と大きさ、玉の大きさと昇る高さ。
const CARD_AT := Vector2(26.0, 18.0)
const CARD := 6.0
const ORB := 4.6
const ORB_RISE := 38.0


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + SETTLE + SLIP


func sound() -> int:
	return SoundBank.Sfx.SIG_SAGE


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var alpha := fade_alpha(t)
	var settle := phase(t, impact_at(), SETTLE)
	var fall := 1.0 - ease(settle, 0.4)
	var tilt := TILT * sin(settle * PI * 1.5) * (1.0 - settle * 0.4)
	var hat := from - Vector2(0.0, LIFT + DROP * fall)
	_hat(item, hat, tilt, alpha * minf(settle * 3.0, 1.0))
	var slip := phase(t, impact_at() + SETTLE, SLIP)
	if slip <= 0.0:
		return
	var ci := item.get_canvas_item()
	var card_at := hat + CARD_AT
	var card_alpha := alpha * minf(slip * 4.0, 1.0)
	SignaturePaint.card_glint(item, card_at, CARD, 0.0, card_alpha)
	var rise := ease(slip, 0.7)
	var orb_at := card_at - Vector2(0.0, ORB_RISE * rise)
	var orb_alpha := alpha * (1.0 - ease(slip, 3.0))
	ShapePaint.circle(ci, orb_at, ORB * 1.8, Color(UiPalette.COST, orb_alpha * 0.25))
	ShapePaint.circle(ci, orb_at, ORB, Color(UiPalette.COST, orb_alpha))
	ShapePaint.circle(ci, orb_at - Vector2(1.2, 1.4), ORB * 0.35, Color(1, 1, 1, orb_alpha))


## とんがり帽子。`at` はつばの中心、`tilt` は傾き。
func _hat(item: CanvasItem, at: Vector2, tilt: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var cone := PackedVector2Array(
		[
			Vector2(-BRIM * 0.55, 0.0),
			Vector2(-BRIM * 0.18, -CONE * 0.7),
			Vector2(BRIM * 0.18, -CONE * 1.05),
			Vector2(BRIM * 0.5, -CONE * 0.75),
			Vector2(BRIM * 0.55, 0.0),
		]
	)
	var shape := PackedVector2Array()
	for p in cone:
		shape.append(at + p.rotated(tilt))
	var brim := Vector2(BRIM, BRIM * 0.3)
	UiPaint.fill_ellipse(ci, at, brim + Vector2.ONE, Color(UiPalette.INK_950, alpha * 0.8), 24)
	UiPaint.fill_ellipse(ci, at, brim, Color(FELT, alpha), 24)
	ShapePaint.colored_polygon(ci, shape, Color(FELT, alpha))
	var closed := shape.duplicate()
	closed.append(shape[0])
	ShapePaint.polyline(ci, closed, Color(SignaturePaint.RECITE, alpha), 1.6, true)
	UiPaint.draw_ellipse_ring(ci, at, brim, Color(SignaturePaint.RECITE, alpha), 1.4, 24)
	var band_a := at + Vector2(-BRIM * 0.55, -BAND).rotated(tilt)
	var band_b := at + Vector2(BRIM * 0.55, -BAND).rotated(tilt)
	item.draw_line(band_a, band_b, Color(UiPalette.GOLD, alpha), BAND * 0.6, true)
