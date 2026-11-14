extends SignatureMove
## グリモアの打撃(GameDesign.md 9章):駒の上に厚い魔導書が開いてページがばらばらとめくれ、墓地の砂術の
## 数だけ詠み文字が立ちのぼって頭上で1つの塊に重なり、相手のHPの器へ落ちて砕ける(打撃。盤面を揺らす)。

const OPEN := 0.2
const READ := 0.5
const GATHER := 0.1
const FALL := 0.15
## 文字の数の上限。墓地の砂術がこれ以上あっても6つのまま。
const MAX_RUNES := 6
## 本の置き場所(駒の中心から上へ)、片側のページの幅・高さ・背の反り、ページ送りの回数。
const LIFT := 44.0
const WIDTH := 28.0
const HEIGHT := 20.0
const SLANT := 6.0
const FLIPS := 4
const COVER := Color(0.45, 0.24, 0.18, 1.0)
## 文字が立ちのぼる高さ(本から上へ)、横の広がり、塊になる点(本から上へ)、文字の大きさ。
const RUN_RISE := 52.0
const SPREAD := 22.0
const CLUSTER_RISE := 78.0
const GLYPH := 11.0
const GLYPH_FALL := 16.0
const ARC := 60.0


func impact_at() -> float:
	return OPEN + READ + GATHER + FALL


func sound() -> int:
	return SoundBank.Sfx.SIG_GRIMOIRE


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var spine := from - Vector2(0.0, LIFT)
	var gather_at := OPEN + READ
	var falling := t >= gather_at + GATHER
	var book_alpha := alpha * (1.0 - phase(t, gather_at + GATHER, FALL))
	_book(item, spine, t, book_alpha)
	var count := clampi(grave_spells, 1, MAX_RUNES)
	var cluster := spine - Vector2(0.0, CLUSTER_RISE)
	var glow := phase(t, gather_at, GATHER + FALL)
	var settle := phase(t, gather_at, GATHER)
	for i in range(count):
		var born := OPEN + READ * float(i) / float(count + 1)
		var up := ease(phase(t, born, READ * 0.5), 0.5)
		if up <= 0.0:
			continue
		var x := (float(i) - float(count - 1) * 0.5) * SPREAD * 2.0 / float(maxi(count - 1, 1))
		var rest := spine + Vector2(x, -RUN_RISE * up)
		var at := rest.lerp(cluster, ease(settle, 0.5))
		if falling:
			var s := ease(phase(t, gather_at + GATHER, FALL), 1.6)
			at = cluster.lerp(targets[0], s) - Vector2(0.0, ARC * sin(s * PI))
		var size := lerpf(GLYPH, GLYPH_FALL, settle)
		var color := SignaturePaint.RECITE.lerp(Color.WHITE, glow * 0.7)
		if t < impact_at():
			SignaturePaint.rune(item, at, size, i, 1.0, alpha * up, color)
	var burst := phase(t, impact_at(), FADE)
	if burst > 0.0:
		for i in range(count + 3):
			var angle := TAU * float(i) / float(count + 3) + SignaturePaint.jitter(i, 41)
			var reach := 26.0 * ease(burst, 0.5)
			var at := targets[0] + Vector2.from_angle(angle) * reach
			SignaturePaint.rune(
				item, at, GLYPH * (1.0 - burst * 0.6), i, 1.0, alpha * (1.0 - burst)
			)


## 開いた厚い本。ページは生成り、表紙は赤茶。`t` に合わせて開き、ばらばらとめくれる。
func _book(item: CanvasItem, spine: Vector2, t: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var open := ease(phase(t, 0.0, OPEN), 0.5)
	var half := WIDTH * open
	var cover := PackedVector2Array(
		[
			spine + Vector2(-half - 3.0, -SLANT * open + 4.0),
			spine + Vector2(0.0, 4.0),
			spine + Vector2(half + 3.0, -SLANT * open + 4.0),
			spine + Vector2(half + 3.0, -SLANT * open - HEIGHT - 2.0),
			spine + Vector2(0.0, -HEIGHT),
			spine + Vector2(-half - 3.0, -SLANT * open - HEIGHT - 2.0),
		]
	)
	ShapePaint.colored_polygon(ci, cover, Color(COVER, alpha))
	for side: float in [-1.0, 1.0]:
		_page(item, spine, side * half, Color(SignaturePaint.PAPER, alpha))
	var flip := phase(t, OPEN, READ)
	if flip <= 0.0 or flip >= 1.0:
		return
	var turn := fmod(flip * float(FLIPS), 1.0)
	var reach := half * cos(turn * PI)
	_page(
		item,
		spine - Vector2(0.0, 2.0 * sin(turn * PI)),
		reach,
		Color(SignaturePaint.PAPER.lightened(0.3), alpha)
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
		item.get_canvas_item(), closed, Color(UiPalette.INK_950, color.a * 0.6), 1.0, true
	)
