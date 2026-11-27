class_name DrawSandPaint
extends RefCounted
## 汲砂の刻の演出(GameDesign.md 9章)の共通の部品。他人の器へ伸びる銅の吸い管と、そこを吸い上げられて戻る
## 他人の色の滴(奪った砂は自分の色に染まらない)、吸われた所で縮む渦をコードで描く。
## `SignaturePaint` が行数の上限に近いため分けている。

const WIDTH := 4.0
const EDGE := 2.2
const STEPS := 18
const BEAD := 3.4
const BEAD_GAP := 0.16
const GULP_REACH := 30.0


## 吸い管。`a`(出どころ)から `b`(相手)への弧のうち `reach`(0→1)までを、濃い縁・銅・照りの3本で描き、先に口の輪を付ける。
static func tube(
	item: CanvasItem, a: Vector2, b: Vector2, lift: float, reach: float, alpha: float, size := 1.0
) -> void:
	if alpha <= 0.0 or reach <= 0.0:
		return
	var points := PackedVector2Array()
	for i in range(STEPS + 1):
		points.append(PourPaint.along(a, b, lift, reach * float(i) / float(STEPS)))
	var ci := item.get_canvas_item()
	ShapePaint.polyline(
		ci, points, Color(UiPalette.DRAW_COPPER_DEEP, alpha), (WIDTH + EDGE) * size, true
	)
	ShapePaint.polyline(ci, points, Color(UiPalette.DRAW_COPPER, alpha), WIDTH * size, true)
	ShapePaint.polyline(ci, points, Color(UiPalette.IVORY, alpha * 0.55), WIDTH * 0.3 * size, true)
	var tip := points[points.size() - 1]
	ShapePaint.circle(ci, tip, 3.6 * size, Color(UiPalette.DRAW_COPPER_DEEP, alpha))
	ShapePaint.circle(ci, tip, 2.4 * size, Color(UiPalette.KINTSUGI, alpha))


## 管を戻る滴。`b`(相手)から `a`(出どころ)へ、`progress`(0→1)で `count` 粒が少しずつ遅れて登る。
## `spill` が正なら、その割合の粒が途中で管からこぼれて落ちる(サイフォンの「半分はこぼれる」)。
static func beads(
	item: CanvasItem,
	a: Vector2,
	b: Vector2,
	lift: float,
	progress: float,
	alpha: float,
	count := 3,
	color := UiPalette.DRAW_FOREIGN,
	spill := 0.0
) -> void:
	if alpha <= 0.0 or progress <= 0.0:
		return
	var ci := item.get_canvas_item()
	var span := 1.0 + BEAD_GAP * float(count - 1)
	for i in range(count):
		var s := progress * span - BEAD_GAP * float(i)
		if s <= 0.0 or s >= 1.0:
			continue
		var at := PourPaint.along(b, a, lift, s)
		var spilled := spill > 0.0 and float(i % 2) == 1.0 and s > 0.5
		if spilled:
			var fall := (s - 0.5) * 2.0
			at = PourPaint.along(b, a, lift, 0.5) + Vector2(6.0 * fall, 60.0 * fall * fall)
		var fade := alpha * (1.0 - (s - 0.5) * 2.0 if spilled else 1.0)
		ShapePaint.circle(ci, at, BEAD + 1.4, Color(UiPalette.DRAW_COPPER_DEEP, fade))
		ShapePaint.circle(ci, at, BEAD, Color(color, fade))
		ShapePaint.circle(
			ci, at + Vector2(-1.0, -1.0), BEAD * 0.35, Color(UiPalette.IVORY, fade * 0.8)
		)


## 吸われた所で縮む渦。外から中心へ巻きながら3本の筋が縮んでいく。`progress` は0→1。
static func gulp(item: CanvasItem, at: Vector2, progress: float, alpha: float) -> void:
	if alpha <= 0.0 or progress <= 0.0 or progress >= 1.0:
		return
	var ci := item.get_canvas_item()
	var fade := alpha * (1.0 - progress)
	for k in range(3):
		var points := PackedVector2Array()
		for i in range(9):
			var u := float(i) / 8.0
			var radius := GULP_REACH * (1.0 - progress) * (1.0 - u * 0.7)
			var angle := TAU * float(k) / 3.0 + u * 2.2 + progress * 3.0
			points.append(at + Vector2(cos(angle), sin(angle) * 0.45) * radius)
		ShapePaint.polyline(ci, points, Color(UiPalette.DRAW_COPPER, fade), 2.2, true)
