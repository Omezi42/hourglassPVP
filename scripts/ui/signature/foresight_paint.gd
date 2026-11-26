class_name ForesightPaint
extends RefCounted
## 先触の刻の演出(GameDesign.md 9章)の共通の部品。銀の星図の線と、その先で瞬く「まだ来ない」星、
## 深い藍の札(タロット)をコードで描く。`SignaturePaint` が行数の上限に近いため分けている。

const LINE := 2.0
const NODE := 3.2
const STAR_REACH := 14.0
const STAR_GLOW := 12.0
## 札の縦横比と、縁の太さ・表の印の大きさ(札の高さに対する比)。
const CARD_ASPECT := 0.64
const CARD_RIM := 0.08
const FACE_MARK := 0.2


## 星図の線。`points` の星を順に結び、`drawn`(0→1)まで引く。線が届いた星から灯る。
static func star_chart(
	item: CanvasItem, points: PackedVector2Array, drawn: float, alpha: float, size := 1.0
) -> void:
	if alpha <= 0.0 or drawn <= 0.0 or points.size() < 2:
		return
	var ci := item.get_canvas_item()
	var legs := points.size() - 1
	var reach := drawn * float(legs)
	for i in range(legs):
		var leg := clampf(reach - float(i), 0.0, 1.0)
		if leg <= 0.0:
			break
		var tip := points[i].lerp(points[i + 1], leg)
		item.draw_line(
			points[i], tip, Color(UiPalette.CHART_LAPIS, alpha * 0.7), (LINE + 2.0) * size, true
		)
		item.draw_line(points[i], tip, Color(UiPalette.STAR_CHART, alpha), LINE * size, true)
	for i in range(points.size()):
		if reach + 0.001 < float(i):
			break
		ShapePaint.circle(
			ci, points[i], (NODE + 1.4) * size, Color(UiPalette.CHART_LAPIS, alpha * 0.7)
		)
		ShapePaint.circle(ci, points[i], NODE * size, Color(UiPalette.STAR_CHART, alpha))


## まだ来ない星。淡い暈に長短2対の光芒、白い芯。`spin` で光芒がわずかに回る。
static func next_star(
	item: CanvasItem, at: Vector2, size: float, alpha: float, spin := 0.0
) -> void:
	if alpha <= 0.0 or size <= 0.0:
		return
	var ci := item.get_canvas_item()
	ShapePaint.circle(ci, at, STAR_GLOW * size, Color(UiPalette.NEXT_STAR, alpha * 0.28))
	for i in range(4):
		var dir := Vector2.from_angle(spin + TAU * float(i) / 4.0)
		var reach := STAR_REACH * size * (1.0 if i % 2 == 0 else 0.68)
		var side := dir.orthogonal() * 2.4 * size
		ShapePaint.colored_polygon(
			ci,
			PackedVector2Array([at + side, at + dir * reach, at - side]),
			Color(UiPalette.STAR_CHART, alpha)
		)
	ShapePaint.circle(ci, at, 3.0 * size, Color(SignaturePaint.SPARK_HOT, alpha))


## 深い藍の札。`turn` は表へ返る進み(0=裏・1=表、0.5で真横)、`tilt` は傾き(ラジアン)、
## `height` は札の高さ。裏は銀の縁と星、表は生成りに金の印(`sun` なら太陽、でなければ三日月)。
static func tarot(
	item: CanvasItem,
	center: Vector2,
	height: float,
	turn: float,
	tilt: float,
	alpha: float,
	sun := false
) -> void:
	if alpha <= 0.0 or height <= 0.0:
		return
	var ci := item.get_canvas_item()
	var squash := absf(cos(turn * PI))
	var half := Vector2(height * CARD_ASPECT * 0.5 * maxf(squash, 0.04), height * 0.5)
	var rim := height * CARD_RIM
	var faced := turn > 0.5
	var outer := _box(center, half, tilt)
	ShapePaint.colored_polygon(ci, outer, Color(UiPalette.INK_950, alpha * 0.85))
	var face_color := UiPalette.PAPER if faced else UiPalette.STAR_CHART
	ShapePaint.colored_polygon(
		ci, _box(center, half - Vector2(1.5, 1.5), tilt), Color(face_color, alpha)
	)
	var inner := half - Vector2(rim, rim) * Vector2(squash, 1.0)
	var field := UiPalette.PAPER if faced else UiPalette.CHART_LAPIS
	ShapePaint.colored_polygon(ci, _box(center, inner, tilt), Color(field, alpha))
	var mark := height * FACE_MARK
	if not faced:
		ForesightPaint.next_star(item, center, mark / STAR_REACH * squash, alpha * 0.9)
		return
	var gold := Color(UiPalette.GOLD, alpha)
	if sun:
		for i in range(8):
			var dir := Vector2.from_angle(tilt + TAU * float(i) / 8.0)
			item.draw_line(
				center + dir * mark * 0.7 * Vector2(squash, 1.0),
				center + dir * mark * 1.15 * Vector2(squash, 1.0),
				gold,
				maxf(1.5, mark * 0.16),
				true
			)
		ShapePaint.circle(ci, center, mark * 0.55 * maxf(squash, 0.3), gold)
		return
	ShapePaint.circle(ci, center, mark * maxf(squash, 0.3), gold)
	ShapePaint.circle(
		ci,
		center + Vector2(mark * 0.42 * squash, -mark * 0.18).rotated(tilt),
		mark * 0.86 * maxf(squash, 0.3),
		Color(UiPalette.PAPER, alpha)
	)


static func _box(center: Vector2, half: Vector2, tilt: float) -> PackedVector2Array:
	var box := PackedVector2Array()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		box.append(center + (corner * half).rotated(tilt))
	return box


## 星図の線 `points` の上を進み `s`(0→1)の位置。
static func along(points: PackedVector2Array, s: float) -> Vector2:
	var legs := points.size() - 1
	var reach := clampf(s, 0.0, 1.0) * float(legs)
	var i := mini(int(reach), legs - 1)
	return points[i].lerp(points[i + 1], reach - float(i))


## 凸な輪郭 `points` を中心 `at` から外へ `by` だけ広げた輪郭(縁取りの下地に使う)。
static func grown(points: PackedVector2Array, at: Vector2, by: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p + (p - at).normalized() * by)
	return out
