extends SignatureMove
## ヴァンプの登場(GameDesign.md 9章):駒の頭上から赤いコウモリの影が2匹、羽ばたきながら左右へ
## 飛び去る(吸命=与えたダメージぶん回復する印)。

const FLY := 0.62
## 飛び立つ場所(台座の上面から上へ)と、左右へ飛ぶ距離・昇る高さ、羽ばたきの回数、2匹目の遅れ。
const LIFT := 120.0
const TRAVEL := 90.0
const CLIMB := 50.0
const FLAPS := 4.0
const LAG := 0.08
## 体の大きさと翼の長さ。
const BODY := Vector2(3.4, 5.0)
const WING := 15.0
const BAT := Color(0.62, 0.1, 0.16, 1.0)


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + FLY + LAG + FADE * 0.5


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var start := from - Vector2(0.0, LIFT)
	for k in range(2):
		var q := phase(t, impact_at() + LAG * float(k), FLY)
		if q <= 0.0 or q >= 1.0:
			continue
		var side := -1.0 if k == 0 else 1.0
		var s := ease(q, 1.3)
		var at := start + Vector2(side * TRAVEL * s, -CLIMB * s + 10.0 * sin(q * PI * 2.0))
		var flap := sin(q * TAU * FLAPS)
		var alpha := minf(q * 6.0, 1.0) * (1.0 - ease(q, 3.0))
		_bat(item, at, flap, 1.0 - q * 0.4, alpha)


## 翼を広げたコウモリの影。`flap` は-1(上)〜1(下)の翼の振り。
func _bat(item: CanvasItem, at: Vector2, flap: float, grow: float, alpha: float) -> void:
	var ci := item.get_canvas_item()
	var color := Color(BAT, alpha)
	for side: float in [-1.0, 1.0]:
		var tip := at + Vector2(side * WING, -6.0 + flap * 8.0) * grow
		var elbow := at + Vector2(side * WING * 0.5, -4.0 + flap * 4.0) * grow
		var wing := PackedVector2Array(
			[
				at + Vector2(side * BODY.x * 0.5, -2.0) * grow,
				elbow,
				tip,
				at + Vector2(side * WING * 0.75, 2.0 + flap * 4.0) * grow,
				at + Vector2(side * WING * 0.45, 0.5 + flap * 2.0) * grow,
				at + Vector2(side * WING * 0.25, 3.0) * grow,
				at + Vector2(side * BODY.x * 0.5, 2.0) * grow,
			]
		)
		ShapePaint.colored_polygon(ci, wing, color)
	UiPaint.fill_ellipse(ci, at, BODY * grow, color, 12)
	for side: float in [-1.0, 1.0]:
		var ear := PackedVector2Array(
			[
				at + Vector2(side * 0.5, -BODY.y * 0.8) * grow,
				at + Vector2(side * 2.8, -BODY.y * 1.6) * grow,
				at + Vector2(side * 2.8, -BODY.y * 0.6) * grow,
			]
		)
		ShapePaint.colored_polygon(ci, ear, color)
