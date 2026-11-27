class_name PourPaint
extends RefCounted
## 注砂の刻の演出(GameDesign.md 9章)の共通の部品。器の縁から弧を描いて注がれる青緑の水の筋と、
## 届いた所で跳ねるしぶき・広がる波紋をコードで描く。`SignaturePaint` が行数の上限に近いため分けている。

const WIDTH := 5.0
const EDGE := 2.4
const SPLASH_DROPS := 7
const SPLASH_REACH := 22.0
const SPLASH_LIFT := 26.0
const RIPPLE := Vector2(30.0, 9.0)
const STEPS := 18


## `a` から `b` への注ぐ弧の上の `s`(0→1)の位置。`lift` は弧の中ほどを持ち上げる高さ(負なら垂れる)。
static func along(a: Vector2, b: Vector2, lift: float, s: float) -> Vector2:
	var mid := (a + b) * 0.5 - Vector2(0.0, lift)
	var u := clampf(s, 0.0, 1.0)
	return a.lerp(mid, u).lerp(mid.lerp(b, u), u)


## 注ぐ水の筋。弧の `tail` から `head`(どちらも0→1)までを、濃い縁・青緑の芯・白い筋で描き、
## 先頭に水滴を付ける。`color` で水の色を変える(葡萄酒・油など)。
static func stream(
	item: CanvasItem,
	a: Vector2,
	b: Vector2,
	lift: float,
	head: float,
	tail: float,
	alpha: float,
	size := 1.0,
	color := UiPalette.POUR_WATER
) -> void:
	if alpha <= 0.0 or head <= tail:
		return
	var points := PackedVector2Array()
	for i in range(STEPS + 1):
		points.append(along(a, b, lift, lerpf(tail, head, float(i) / float(STEPS))))
	var ci := item.get_canvas_item()
	ShapePaint.polyline(
		ci, points, Color(UiPalette.POUR_DEEP, alpha * 0.85), (WIDTH + EDGE) * size, true
	)
	ShapePaint.polyline(ci, points, Color(color, alpha), WIDTH * size, true)
	ShapePaint.polyline(
		ci, points, Color(UiPalette.POUR_FOAM, alpha * 0.8), WIDTH * 0.32 * size, true
	)
	var tip := points[points.size() - 1]
	var heading := tip - points[points.size() - 2]
	SignaturePaint.water_drop(item, tip, 3.6 * size, heading, alpha)


## 届いた所のしぶき。水滴が冠のように跳ねて落ち、足元に楕円の波紋が広がる。`progress` は0→1。
static func splash(
	item: CanvasItem, at: Vector2, progress: float, alpha: float, size := 1.0
) -> void:
	if alpha <= 0.0 or progress <= 0.0 or progress >= 1.0:
		return
	var ci := item.get_canvas_item()
	var fade := alpha * (1.0 - progress)
	var r := RIPPLE * size * (0.4 + 0.8 * ease(progress, 0.5))
	var ring := PackedVector2Array()
	for i in range(25):
		var a := TAU * float(i) / 24.0
		ring.append(at + Vector2(cos(a) * r.x, sin(a) * r.y))
	ShapePaint.polyline(ci, ring, Color(UiPalette.POUR_FOAM, fade * 0.8), 2.0, true)
	for i in range(SPLASH_DROPS):
		var spread := (float(i) / float(SPLASH_DROPS - 1) - 0.5) * 2.0
		var p := (
			at
			+ Vector2(
				spread * SPLASH_REACH * size * progress,
				-SPLASH_LIFT * size * sin(progress * PI) * (1.0 - absf(spread) * 0.4)
			)
		)
		ShapePaint.circle(ci, p, 2.4 * size, Color(UiPalette.POUR_WATER, fade))
		ShapePaint.circle(ci, p, 1.1 * size, Color(UiPalette.POUR_FOAM, fade))


## 器の口へ溜まって溢れる水面。`center` を中心に半幅 `half` の楕円の水面を、`level`(0→1)の濃さで描く。
static func brim(
	item: CanvasItem, center: Vector2, half: float, level: float, alpha: float
) -> void:
	if alpha <= 0.0 or level <= 0.0:
		return
	var ci := item.get_canvas_item()
	var surface := PackedVector2Array()
	for i in range(17):
		var a := TAU * float(i) / 16.0
		surface.append(center + Vector2(cos(a) * half, sin(a) * half * 0.28))
	ShapePaint.convex_polygon(ci, surface, Color(UiPalette.POUR_WATER, alpha * level))
	surface.append(surface[0])
	ShapePaint.polyline(ci, surface, Color(UiPalette.POUR_FOAM, alpha * level), 1.6, true)
