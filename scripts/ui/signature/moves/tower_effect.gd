extends SignatureMove
## タワーの落砂(GameDesign.md 9章):駒の上に塔の頂の投石機が現れて腕を振り上げ、石が高い弧を描いて
## 相手のHPの器へ落ちる(打撃)。

const APPEAR := 0.12
const FLING := 0.14
const FLIGHT := 0.4
## 投石機の台の置き場所(駒の中心から上へ)と大きさ、腕の長さと振る前・振り切った向き、石の弧の高さ。
const LIFT := 56.0
const BASE := Vector2(28.0, 10.0)
const ARM := 30.0
const COCKED := PI * 0.85
const RELEASED := -PI * 0.4
const ARC := 120.0
const STONE := 5.0
const WOOD := Color(0.5, 0.33, 0.2, 1.0)
const STONE_COLOR := Color(0.55, 0.52, 0.48, 1.0)


func impact_at() -> float:
	return APPEAR + FLING + FLIGHT


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var a := alpha * ease(phase(t, 0.0, APPEAR), 0.5)
	var base := from - Vector2(0.0, LIFT)
	var deck := Rect2(base - Vector2(BASE.x * 0.5, 0.0), BASE)
	item.draw_rect(deck.grow(1.2), Color(UiPalette.OUTLINE_DARK, a * 0.8))
	item.draw_rect(deck, Color(WOOD, a))
	var pivot := base + Vector2(0.0, -2.0)
	var fling := ease(phase(t, APPEAR, FLING), 2.2)
	var arm := Vector2.from_angle(lerpf(COCKED, RELEASED, fling)) * ARM
	item.draw_line(pivot, pivot + arm, Color(UiPalette.OUTLINE_DARK, a * 0.8), 5.0, true)
	item.draw_line(pivot, pivot + arm, Color(WOOD.lightened(0.2), a), 3.2, true)
	ShapePaint.circle(ci, pivot, 3.0, Color(UiPalette.BRASS_HIGHLIGHT, a))
	var release := pivot + Vector2.from_angle(RELEASED) * ARM
	var flight := phase(t, APPEAR + FLING, FLIGHT)
	var stone := pivot + arm
	if flight > 0.0:
		if t >= impact_at():
			return
		var s := ease(flight, 1.2)
		stone = release.lerp(targets[0], s) - Vector2(0.0, ARC * sin(s * PI))
	ShapePaint.circle(ci, stone, STONE + 1.2, Color(UiPalette.OUTLINE_DARK, a))
	ShapePaint.circle(ci, stone, STONE, Color(STONE_COLOR, a))
