extends SignatureMove
## 前借りの恵与(GameDesign.md 9章):撃った位置に証文が開いて赤い封蝋が押され、押した弾みで金貨が3枚、
## 山なりに自分のHPの器へ跳んで、最後の1枚が届いたところで金色の輪が広がる(今の手番のマナを足し、次の手番を削る)。

const SEAL := 0.24
const TOSS := 0.34
## 証文の大きさ・文字の行、封蝋の半径と押す前の拡大、金貨の数・半径・山の高さ・跳ぶ間隔。
const NOTE := Vector2(26.0, 32.0)
const LINES := 4
const WAX := 7.0
const WAX_DROP := 2.2
const COINS := 3
const COIN := 6.0
const ARC := 60.0
const STAGGER := 0.25


func impact_at() -> float:
	return SEAL + TOSS


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var open := ease(phase(t, 0.0, SEAL * 0.6), 0.5)
	var note_alpha := alpha * minf(open * 3.0, 1.0) * (1.0 - phase(t, SEAL + TOSS * 0.6, FADE))
	if note_alpha > 0.0:
		var half := Vector2(NOTE.x, NOTE.y * open) * 0.5
		var rect := Rect2(from - half, half * 2.0)
		ShapePaint.convex_polygon(
			ci, _rect_points(rect.grow(1.5)), Color(UiPalette.INK_950, note_alpha * 0.8)
		)
		ShapePaint.convex_polygon(ci, _rect_points(rect), Color(SignaturePaint.PAPER, note_alpha))
		for i in range(LINES):
			var y := rect.position.y + rect.size.y * (0.2 + 0.15 * float(i))
			var right := rect.end.x - 4.0 - (8.0 if i == LINES - 1 else 0.0)
			item.draw_line(
				Vector2(rect.position.x + 4.0, y),
				Vector2(right, y),
				Color(UiPalette.BRASS_DEEP, note_alpha * 0.7),
				1.2
			)
		var press := phase(t, SEAL * 0.6, SEAL * 0.4)
		if press > 0.0:
			var wax_at := from + Vector2(NOTE.x * 0.22, NOTE.y * 0.28)
			var r := WAX * lerpf(WAX_DROP, 1.0, ease(press, 2.0))
			ShapePaint.circle(ci, wax_at, r + 1.4, Color(UiPalette.INK_950, note_alpha * 0.8))
			ShapePaint.circle(ci, wax_at, r, Color(UiPalette.SEAL_WAX, note_alpha))
			ShapePaint.circle(ci, wax_at, r * 0.45, Color(UiPalette.SIGNAL_RED, note_alpha))
			if press < 1.0:
				SignaturePaint.toll_arcs(
					item, wax_at, Vector2.ZERO, WAX + 16.0 * press, note_alpha * (1.0 - press)
				)
	var land := phase(t, impact_at(), FADE)
	for target in targets:
		for i in range(COINS):
			var span := TOSS * (1.0 - STAGGER * float(COINS - 1))
			var k := phase(t, SEAL + TOSS * STAGGER * float(i), span)
			if k <= 0.0 or k >= 1.0:
				continue
			var at := from.lerp(target, k) + Vector2(0.0, -sin(k * PI) * ARC)
			var squash := maxf(absf(cos(k * TAU * 1.5)), 0.25)
			var rim := Vector2(COIN * squash + 1.5, COIN + 1.5)
			ShapePaint.convex_polygon(ci, _ellipse(at, rim), Color(UiPalette.INK_950, alpha * 0.7))
			ShapePaint.convex_polygon(
				ci, _ellipse(at, Vector2(COIN * squash, COIN)), Color(UiPalette.TOLL_BRASS, alpha)
			)
		SignaturePaint.boon_ring(item, target, land, alpha)


static func _rect_points(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]
	)


static func _ellipse(at: Vector2, radius: Vector2) -> PackedVector2Array:
	const SEGMENTS := 16
	var points := PackedVector2Array()
	for j in range(SEGMENTS):
		var a := TAU * float(j) / float(SEGMENTS)
		points.append(at + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return points
