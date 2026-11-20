extends SignatureMove
## スクライブの恵与(GameDesign.md 9章):砂術に応えて、駒の頭上で羽根ペンが短く一筆走り、書かれた
## 藤白の一画が砂粒にほどけて駒へ落ち、届いたところで金色の輪が広がる(総量+1)。

const WRITE := 0.25
const DISSOLVE := 0.17
## 文字の置き場所(駒の中心から上へ)と大きさ、字形の番号。ほどけて落ちる砂粒の数。長さはすべて駒の拡大を掛ける。
const LIFT := 62.0
const GLYPH := 30.0
const SHAPE := 3
const GRAINS := 12
const GRAIN := 3.0
## 羽根ペンの軸の長さと傾き、羽根の幅。
const QUILL := 44.0
const QUILL_LEAN := -0.9
const VANE := 8.0


func impact_at() -> float:
	return WRITE + DISSOLVE


## 字の上端と、書いている筆の羽根の先まで。
func top_extent() -> float:
	return (LIFT + GLYPH * 0.5 + QUILL * absf(sin(QUILL_LEAN))) * zoom


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var glyph_at := from - Vector2(0.0, LIFT * zoom)
	var glyph := GLYPH * zoom
	var written := phase(t, 0.0, WRITE)
	var melt := phase(t, WRITE, DISSOLVE)
	SignaturePaint.rune(item, glyph_at, glyph, SHAPE, written, alpha * (1.0 - melt))
	if melt <= 0.0:
		_quill(item, SignaturePaint.rune_tip(glyph_at, glyph, SHAPE, written), alpha)
	for i in range(GRAINS):
		var start := SignaturePaint.rune_tip(glyph_at, glyph, SHAPE, float(i + 1) / float(GRAINS))
		var lag := SignaturePaint.jitter(i, 21) * 0.4
		var k := clampf((melt - lag) / (1.0 - lag), 0.0, 1.0)
		if k <= 0.0 or k >= 1.0:
			continue
		var at := start.lerp(targets[0], ease(k, 2.0))
		ShapePaint.circle(
			ci, at, GRAIN * zoom, Color(SignaturePaint.RECITE, alpha * (1.0 - k * 0.5))
		)
	var ring := phase(t, impact_at(), FADE)
	SignaturePaint.boon_ring(item, targets[0], ring, alpha)


## 筆先 `tip` に立つ羽根ペン。軸と羽根は生成り、先だけ暗い。
func _quill(item: CanvasItem, tip: Vector2, alpha: float) -> void:
	var ci := item.get_canvas_item()
	var dir := Vector2.from_angle(QUILL_LEAN)
	var quill := QUILL * zoom
	var vane_width := VANE * zoom
	var top := tip + dir * quill
	item.draw_line(tip, top, Color(UiPalette.INK_950, alpha * 0.7), 3.4, true)
	item.draw_line(tip, top, Color(SignaturePaint.PAPER, alpha), 1.8, true)
	var side := Vector2(-dir.y, dir.x)
	var vane := PackedVector2Array(
		[
			tip + dir * quill * 0.4,
			tip + dir * quill * 0.75 + side * vane_width,
			top + side * vane_width * 0.3,
			top,
		]
	)
	ShapePaint.colored_polygon(ci, vane, Color(SignaturePaint.PAPER, alpha * 0.9))
	ShapePaint.circle(ci, tip, 1.6, Color(UiPalette.INK_950, alpha))
