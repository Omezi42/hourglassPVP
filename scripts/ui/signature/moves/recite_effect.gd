extends SignatureMove
## 写し詠みの静止(GameDesign.md 9章):離した位置に詠み文字の行が浮かび、そのすぐ下へ同じ行が
## 左から右へなぞるように写され(書かれた先から金へ変わる)、写し終えたところで光の輪が広がって
## 砂術が撃ち直される(巻物は描かない)。

const SHOW := 0.12
const COPY := 0.28
## 行の置き場所(離した位置から上へ)、文字の大きさと間隔、2行の間隔。
const LIFT := 8.0
const GLYPH := 12.0
const PITCH := 31.0
const LINE_GAP := 20.0
const SHAPES := [0, 2, 3, 1]


func impact_at() -> float:
	return SHOW + COPY


func draw(item: CanvasItem, t: float) -> void:
	var alpha := fade_alpha(t)
	var shown := ease(phase(t, 0.0, SHOW), 0.5)
	var upper := from - Vector2(0.0, LIFT + LINE_GAP * 0.5)
	var lower := upper + Vector2(0.0, LINE_GAP)
	var count := SHAPES.size()
	var left := -PITCH * (float(count) - 1.0) * 0.5
	for i in range(count):
		var x := left + PITCH * float(i)
		SignaturePaint.rune(item, upper + Vector2(x, 0.0), GLYPH, SHAPES[i], 1.0, alpha * shown)
		var written := phase(t, SHOW + COPY * float(i) / float(count), COPY / float(count))
		var color := SignaturePaint.RECITE.lerp(SignaturePaint.BOON, ease(written, 0.6))
		SignaturePaint.rune(item, lower + Vector2(x, 0.0), GLYPH, SHAPES[i], written, alpha, color)
	SignaturePaint.pulse_ring(item, from - Vector2(0.0, LIFT), phase(t, impact_at(), FADE), alpha)
