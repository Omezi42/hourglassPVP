extends SignatureMove
## ページの反転(GameDesign.md 9章):駒の上に開いた本が現れてページが1枚めくれ、めくれたページが光の札に
## なって自分の情報帯へ飛ぶ(ドロー)。

const APPEAR := 0.12
const TURN := 0.24
const FLY := 0.32
## 本の置き場所(駒の中心から上へ、背の下端)と、ページの幅・高さ・背の反り、札の大きさ、届いた所の輪。
const LIFT := 48.0
const WIDTH := 22.0
const HEIGHT := 26.0
const SLANT := 5.0
const CARD := 7.0
const GLOW := 30.0
const PAPER := Color(0.97, 0.94, 0.84, 1.0)
const COVER := Color(0.45, 0.24, 0.18, 1.0)


func impact_at() -> float:
	return APPEAR + TURN + FLY


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var a := alpha * ease(phase(t, 0.0, APPEAR), 0.5)
	var spine := from - Vector2(0.0, LIFT)
	var cover := PackedVector2Array(
		[
			spine + Vector2(-WIDTH - 3.0, -SLANT + 3.0),
			spine + Vector2(0.0, 3.0),
			spine + Vector2(WIDTH + 3.0, -SLANT + 3.0),
			spine + Vector2(WIDTH + 3.0, -SLANT - HEIGHT - 2.0),
			spine + Vector2(0.0, -HEIGHT),
			spine + Vector2(-WIDTH - 3.0, -SLANT - HEIGHT - 2.0),
		]
	)
	ShapePaint.colored_polygon(ci, cover, Color(COVER, a))
	for side: float in [-1.0, 1.0]:
		_page(item, spine, side * WIDTH, Color(PAPER, a))
	var turn := ease(phase(t, APPEAR, TURN), -1.4)
	var fly := phase(t, APPEAR + TURN, FLY)
	if turn > 0.0 and fly <= 0.0:
		var reach := WIDTH * cos(turn * PI)
		_page(
			item, spine - Vector2(0.0, 2.0 * sin(turn * PI)), reach, Color(PAPER.lightened(0.3), a)
		)
	if fly > 0.0 and fly < 1.0:
		var s := ease(fly, 1.3)
		var start := spine - Vector2(WIDTH * 0.5, HEIGHT * 0.5)
		var at := start.lerp(targets[0], s) - Vector2(0.0, 30.0 * sin(s * PI))
		SignaturePaint.card_glint(item, at, CARD, fly * 2.4, alpha)
	var glow := phase(t, impact_at(), FADE)
	if glow > 0.0:
		ShapePaint.arc(
			ci,
			targets[0],
			GLOW * ease(glow, 0.4),
			0.0,
			TAU,
			32,
			Color(SignaturePaint.BOON, 1.0 - glow),
			2.0,
			true
		)


## 背 `spine` から横へ `reach`(負なら左)だけ開いたページ1枚。
func _page(item: CanvasItem, spine: Vector2, reach: float, color: Color) -> void:
	if absf(reach) < 0.5:
		item.draw_line(spine, spine - Vector2(0.0, HEIGHT), color, 1.4, true)
		return
	var slant := SLANT * absf(reach) / WIDTH
	var page := PackedVector2Array(
		[
			spine,
			spine + Vector2(reach, -slant),
			spine + Vector2(reach, -slant - HEIGHT),
			spine - Vector2(0.0, HEIGHT)
		]
	)
	ShapePaint.colored_polygon(item.get_canvas_item(), page, color)
	var closed := page.duplicate()
	closed.append(page[0])
	ShapePaint.polyline(
		item.get_canvas_item(), closed, Color(UiPalette.OUTLINE_DARK, color.a * 0.6), 1.0, true
	)
