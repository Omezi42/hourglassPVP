extends SignatureMove
## アーカイブの設置(GameDesign.md 9章):駒の上に本の背が3冊並び、まん中の1冊が手前へ引き抜かれて、
## 背の詠み文字が光ったところで光の輪が広がる(墓地の砂術を手札へ戻す。何も飛ばさず駒の上で終える)。

const LINE_UP := 0.25
const PULL := 0.25
const GLOW := 0.12
## 本棚の置き場所(駒の中心から上へ)、背の幅・高さ、背の間隔、引き抜かれる量。
const LIFT := 52.0
const SPINE := Vector2(17.0, 50.0)
const GAP := 4.0
const PULL_OUT := 24.0
const SPINES := [
	Color(0.97, 0.94, 0.84, 1.0),
	Color(0.93, 0.78, 0.42, 1.0),
	Color(0.62, 0.45, 0.22, 1.0),
]
const MIDDLE := 1
const SHAPE := 2


func impact_at() -> float:
	return LINE_UP + PULL + GLOW


func draw(item: CanvasItem, t: float) -> void:
	var alpha := fade_alpha(t)
	var shelf := from - Vector2(0.0, LIFT)
	var pull := ease(phase(t, LINE_UP, PULL), 0.6)
	var glow := phase(t, LINE_UP + PULL, GLOW)
	for i in range(SPINES.size()):
		var rise := ease(phase(t, 0.07 * i, LINE_UP - 0.14), 0.5)
		var lift := PULL_OUT * pull if i == MIDDLE else 0.0
		var x := (float(i) - 1.0) * (SPINE.x + GAP)
		var base := shelf + Vector2(x, lift + (1.0 - rise) * 10.0)
		var grow := 1.0 + 0.12 * pull if i == MIDDLE else 1.0
		var rect := Rect2(base - Vector2(SPINE.x * grow * 0.5, SPINE.y * grow), SPINE * grow)
		var a := alpha * rise
		item.draw_rect(rect.grow(1.2), Color(UiPalette.INK_950, a * 0.8))
		item.draw_rect(rect, Color(SPINES[i], a))
		if i == MIDDLE and pull > 0.0:
			var mark := rect.get_center() + Vector2(0.0, 1.0)
			SignaturePaint.rune(item, mark, SPINE.x * 1.5, SHAPE, 1.0, a * glow * 2.0)
			ShapePaint.circle(
				item.get_canvas_item(),
				mark,
				SPINE.x * 1.5,
				Color(SignaturePaint.RECITE, a * 0.35 * glow)
			)
	SignaturePaint.pulse_ring(
		item, shelf - Vector2(0.0, SPINE.y * 0.5), phase(t, impact_at(), FADE), alpha
	)
