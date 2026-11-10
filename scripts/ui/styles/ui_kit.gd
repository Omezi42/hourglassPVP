class_name UiKit
extends RefCounted
## UIの言語の面の素材と部品(GameDesign.md 9章「共通のレイアウト規約」/ Architecture.md 4.0節)。
## 硝子の面・彫り込み・真鍮の面・砂・紙と、その上に載る宝石・印・札をここ1箇所で描く。
## 第1引数は描き先の RID(`StyleBox._draw()` と `Control._draw()` の両方から使うため)。
## 枠線の太さ・角の丸み・影は部品の短辺から決め、部品の側で定数を持たない。

enum Role { MAIN, SUB, DANGER }

## 枠線の太さ = 短辺のこの比(下限〜上限)。
const LINE_RATIO := 0.022
const LINE_MIN := 2.0
const LINE_MAX := 4.5
## 角の丸み = 短辺のこの比(下限〜上限)。
const RADIUS_RATIO := 0.14
const RADIUS_MIN := 6.0
const RADIUS_MAX := 20.0
## これ以下の高さのボタンは両端を丸める。
const PILL_MAX_HEIGHT := 56.0
const CORNER_SEGMENTS_PER_PX := 0.7
const CORNER_SEGMENTS_MIN := 3
const CORNER_SEGMENTS_MAX := 12
const ELLIPSE_SEGMENTS := 48

## 影: 面の高さのこの比だけぼかす(上限あり)。芯は面より少し内側、落ちる向きは真下。
const SHADOW_BLUR_RATIO := 0.10
const SHADOW_BLUR_MAX := 18.0
const SHADOW_ALPHA := 0.5
const SHADOW_CORE_INSET := 0.2
const SHADOW_SPREAD := 0.65
const SHADOW_DROP := 0.45

## 硝子の面。
const GLASS_ALPHA := 0.86
const GLASS_BOTTOM_ALPHA_GAIN := 0.06
const GLASS_FOLD := 0.35
const GLASS_FILM := 0.075
const GLASS_FILM_END := 0.4
const GLASS_OUTER_ALPHA := 0.55
const GLASS_INNER_ALPHA := 0.045
const GLASS_INNER_GAP := 2.0
## 乗ったとき、縁を金から照りへ寄せ、面をこのぶん明るくする。
const HOVER_FACE_LIGHTEN := 0.10

## 彫り込み。
const WELL_RADIUS_MAX := 10.0
const WELL_TOP := Color(0.0, 0.0, 0.02, 0.72)
const WELL_BOTTOM := Color(0.02, 0.03, 0.07, 0.55)
const WELL_EDGE_TOP := Color(0, 0, 0, 0.7)
const WELL_EDGE_BOTTOM := Color(1, 1, 1, 0.10)

## 真鍮の面。
const BRASS_SHADOW_RATIO := 0.16
const BRASS_SHADOW_MAX := 16.0
const BRASS_SHADOW_ALPHA := 0.6
const BRASS_INNER_INSET := 1.6
const BRASS_INNER_INSET_MIN := 3.0
const BRASS_INNER_WIDTH := 0.6
const BRASS_INNER_LIGHT := Color(1, 1, 1, 0.55)
const BRASS_INNER_MID := Color(1, 1, 1, 0.05)
const BRASS_INNER_DARK := Color(0.3, 0.18, 0.04, 0.5)
## 押せない真鍮の面は藍へこのぶん沈める(明るいままだと押せるように見えるため)。
const BRASS_DISABLED_SINK := 0.72

## 砂のバー。
const SAND_INSET := 1.5
const SAND_GRAIN_AREA := 36.0
const SAND_GRAIN_BAND := 0.36
const SAND_GRAIN_COLOR := Color(1, 0.97, 0.8, 0.35)
const SAND_FOLD := 0.55

## 宝石・印・丸い計器。
const GEM_RIM_RATIO := 0.13
const GEM_RIM_MIN := 1.5
const GEM_RIM_MAX := 3.5
const GEM_TEXT_RATIO := 1.25
const GEM_OUTLINE_RATIO := 0.32
const GEM_SHINE := Color(1, 1, 1, 0.38)
const SEAL_RIM_RATIO := 0.10
const SEAL_RIM_MIN := 1.0
const SEAL_RIM_MAX := 2.5
const SEAL_ICON_RATIO := 1.25
const ROUND_RIM_RATIO := 0.07
const ROUND_RIM_MIN := 1.5
const ROUND_RIM_MAX := 4.0
const ROUND_SHADOW_RATIO := 0.3
const ROUND_SHADOW_ALPHA := 0.55
const ROUND_FACE_INSET := 1.8
const ROUND_SHINE := Color(1, 1, 1, 0.07)
const BADGE_TOP := Color(1.0, 0.42, 0.36)
const BADGE_BOTTOM := Color(0.72, 0.12, 0.12)
const BADGE_RING := 1.5
const BADGE_TEXT_RATIO := 1.3

## 罫線と細い線。
const RULE_ALPHA := 0.12
const HAIRLINE_ALPHA := 0.35
## 真鍮に彫った字の、下の明るい縁。
const ENGRAVE_LIGHT := Color(1.0, 0.95, 0.78, 0.55)
const ENGRAVE_DROP_RATIO := 0.035


# ---- 大きさから決まるもの ---------------------------------------------------
static func line_w(rect: Rect2) -> float:
	return clampf(minf(rect.size.x, rect.size.y) * LINE_RATIO, LINE_MIN, LINE_MAX)


static func radius(rect: Rect2) -> float:
	return clampf(minf(rect.size.x, rect.size.y) * RADIUS_RATIO, RADIUS_MIN, RADIUS_MAX)


## ボタンの角。低いボタンは両端を丸める。
static func button_radius(rect: Rect2) -> float:
	return rect.size.y * 0.5 if rect.size.y <= PILL_MAX_HEIGHT else radius(rect)


static func shadow_blur(rect: Rect2) -> float:
	return minf(rect.size.y * SHADOW_BLUR_RATIO, SHADOW_BLUR_MAX)


# ---- 形 ---------------------------------------------------------------------
static func rr(rect: Rect2, corner: float) -> PackedVector2Array:
	var half := minf(rect.size.x, rect.size.y) * 0.5
	var rad := clampf(corner, 0.0, half)
	if rad >= half and is_equal_approx(rect.size.x, rect.size.y):
		return UiPaint.circle_points(rect.get_center(), rad, _corner_segments(rad) * 4)
	return UiPaint.rounded_rect_points_uniform(rect, rad, _corner_segments(rad))


static func ellipse(
	center: Vector2, radii: Vector2, segments := ELLIPSE_SEGMENTS
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points


static func _corner_segments(rad: float) -> int:
	return clampi(int(rad * CORNER_SEGMENTS_PER_PX), CORNER_SEGMENTS_MIN, CORNER_SEGMENTS_MAX)


## 影のぼかしの帯に使う角丸(重複を除かず、角ごとの点の数を固定する)。
static func _ring(rect: Rect2, corner: float, segments: int) -> PackedVector2Array:
	var rad := clampf(corner, 0.0, minf(rect.size.x, rect.size.y) * 0.5)
	var centers := [
		Vector2(rect.position.x + rad, rect.position.y + rad),
		Vector2(rect.end.x - rad, rect.position.y + rad),
		Vector2(rect.end.x - rad, rect.end.y - rad),
		Vector2(rect.position.x + rad, rect.end.y - rad),
	]
	var points := PackedVector2Array()
	for i in centers.size():
		var start := PI + PI * 0.5 * i
		for s in segments + 1:
			var angle := start + PI * 0.5 * float(s) / float(segments)
			points.append(centers[i] + Vector2(cos(angle), sin(angle)) * rad)
	return points


# ---- 塗りと線 ---------------------------------------------------------------
static func fill(ci: RID, points: PackedVector2Array, color: Color) -> void:
	ShapePaint.convex_polygon(ci, points, color)


## 縦のグラデーションで凸の形を塗る。`soft` で縁を1pxぼかす(線で縁取らない面に使う)。
static func vgrad(ci: RID, points: PackedVector2Array, stops: Array, soft := false) -> void:
	ShapePaint.gradient_convex(ci, points, stops)
	if soft:
		stroke_grad(ci, points, stops, ShapePaint.FEATHER)


## 閉じた線。`ShapePaint` は芯の両側へ1pxのぼかしを足すため、芯を「太さ − ぼかし」にして
## 細い線が倍の太さに見えないようにする。
static func stroke(ci: RID, points: PackedVector2Array, color: Color, width: float) -> void:
	var loop := points.duplicate()
	loop.append(points[0])
	ShapePaint.polyline(ci, loop, color, _core(width), true)


## 上から下へ色の変わる閉じた線(真鍮の細い縁)。
static func stroke_grad(ci: RID, points: PackedVector2Array, stops: Array, width: float) -> void:
	var top := INF
	var bottom := -INF
	for point in points:
		top = minf(top, point.y)
		bottom = maxf(bottom, point.y)
	var height := maxf(bottom - top, 0.001)
	var loop := points.duplicate()
	loop.append(points[0])
	var colors := PackedColorArray()
	for point in loop:
		colors.append(UiPaint.sample_gradient(stops, (point.y - top) / height))
	ShapePaint.polyline_colors(ci, loop, colors, _core(width), true)


static func _core(width: float) -> float:
	return maxf(width - ShapePaint.FEATHER, ShapePaint.FEATHER * 0.25)


static func glow(ci: RID, center: Vector2, radii: Vector2, color: Color) -> void:
	ShapePaint.radial_glow(ci, center, radii, color)


## 落ち影。芯を面の少し内側へ置き、外へ向けて消す。
static func shadow(ci: RID, rect: Rect2, corner: float, blur: float, alpha: float) -> void:
	if blur <= 0.0 or alpha <= 0.0:
		return
	var core := rect.grow(-minf(blur * SHADOW_CORE_INSET, minf(rect.size.x, rect.size.y) * 0.25))
	core.position.y += blur * SHADOW_DROP
	var spread := blur * (SHADOW_CORE_INSET + SHADOW_SPREAD)
	var segments := _corner_segments(corner + spread)
	var inner := _ring(core, maxf(corner - blur * SHADOW_CORE_INSET, 1.0), segments)
	var outer := _ring(core.grow(spread), corner + blur * SHADOW_SPREAD, segments)
	var color := Color(0, 0, 0, alpha)
	ShapePaint.convex_polygon(ci, inner, color)
	ShapePaint.ring_strip(ci, inner, outer, color, Color(0, 0, 0, 0))


## 両端へ消えていく細い線(見出しの下・ヘッダーの下)。
static func hairline(
	ci: RID, from: Vector2, to: Vector2, color := UiPalette.GOLD, alpha := HAIRLINE_ALPHA
) -> void:
	var clear := Color(color, 0.0)
	ShapePaint.polyline_colors(
		ci,
		PackedVector2Array([from, (from + to) * 0.5, to]),
		PackedColorArray([clear, Color(color, alpha), clear]),
		_core(LINE_MIN),
		true
	)


## 面の中の区切りの罫線。
static func rule(ci: RID, from: Vector2, to: Vector2, alpha := RULE_ALPHA) -> void:
	RenderingServer.canvas_item_add_line(ci, from, to, Color(1, 1, 1, alpha), 1.0)


# ---- 縁の色 -----------------------------------------------------------------
## 真鍮の細い縁(上が金、下が影)。`lit` 0〜1 で照りへ寄せる(乗ったとき・選ばれたとき)。
static func rim_brass(lit := 0.0) -> Array:
	return [
		[0.0, UiPalette.GOLD.lerp(UiPalette.GOLD_HI, lit)],
		[0.5, UiPalette.BRASS.lerp(UiPalette.GOLD, lit)],
		[1.0, UiPalette.BRASS_DEEP.lerp(UiPalette.BRASS, lit)],
	]


## 1色の縁(取り返せない操作の赤・選択の水色・砂術の青)。
static func rim_color(color: Color) -> Array:
	return [[0.0, color.lightened(0.2)], [1.0, color.darkened(0.25)]]


static func brass_stops() -> Array:
	return [
		[0.0, UiPalette.GOLD_HI],
		[0.10, UiPalette.GOLD_WARM],
		[0.48, UiPalette.GOLD],
		[0.52, UiPalette.GOLD_FOLD],
		[1.0, UiPalette.BRASS],
	]


# ---- 面の素材 ---------------------------------------------------------------
## 硝子の面: 透けた藍の板に真鍮の細い縁。同格の選択肢と情報の入れ物。
## `lift` は影の深さ(0で影なし)、`lit` は乗ったときの量、`film` は上から差す光の膜の量。
static func glass(
	ci: RID,
	rect: Rect2,
	corner := -1.0,
	lift := 1.0,
	alpha := GLASS_ALPHA,
	rim: Array = [],
	lit := 0.0,
	film := 1.0
) -> void:
	var rad := radius(rect) if corner < 0.0 else corner
	if lift > 0.0:
		shadow(ci, rect, rad, shadow_blur(rect) * lift, SHADOW_ALPHA)
	glass_shape(ci, rr(rect, rad), rect, alpha, rim, lit, film)
	var width := line_w(rect)
	var inner := rect.grow(-(width + GLASS_INNER_GAP))
	if inner.size.x > 0.0 and inner.size.y > 0.0:
		stroke(
			ci,
			rr(inner, maxf(rad - width - GLASS_INNER_GAP, GLASS_INNER_GAP)),
			Color(1, 1, 1, GLASS_INNER_ALPHA),
			LINE_MIN
		)


## 任意の凸の形へ硝子の面を張る(戻るボタンの五角形など)。`rect` は形の外接矩形。
static func glass_shape(
	ci: RID,
	points: PackedVector2Array,
	rect: Rect2,
	alpha := GLASS_ALPHA,
	rim: Array = [],
	lit := 0.0,
	film := 1.0
) -> void:
	var light := GLASS_FILM * film
	var top := UiPalette.INK_600.lightened(lit * HOVER_FACE_LIGHTEN)
	var mid := UiPalette.INK_700.lightened(lit * HOVER_FACE_LIGHTEN)
	var end_mix := (GLASS_FILM_END - GLASS_FOLD) / (1.0 - GLASS_FOLD)
	var stops := [
		[0.0, Color(top.lerp(Color.WHITE, light), alpha)],
		[
			GLASS_FOLD,
			Color(mid.lerp(Color.WHITE, light * (1.0 - GLASS_FOLD / GLASS_FILM_END)), alpha)
		],
		[GLASS_FILM_END, Color(mid.lerp(UiPalette.INK_900, end_mix), alpha)],
		[1.0, Color(UiPalette.INK_900, minf(alpha + GLASS_BOTTOM_ALPHA_GAIN, 1.0))],
	]
	ShapePaint.gradient_convex(ci, points, stops)
	var width := line_w(rect)
	stroke(ci, points, Color(0, 0, 0, GLASS_OUTER_ALPHA), width + LINE_MIN * 2.0)
	stroke_grad(ci, points, rim_brass(lit) if rim.is_empty() else rim, width)


## 彫り込み: 面より暗く沈んだ溝。バー・升・入力欄・地図。
static func well(ci: RID, rect: Rect2, corner := -1.0) -> void:
	var rad := minf(rect.size.y * 0.5, WELL_RADIUS_MAX) if corner < 0.0 else corner
	var points := rr(rect, rad)
	ShapePaint.gradient_convex(ci, points, [[0.0, WELL_TOP], [1.0, WELL_BOTTOM]])
	stroke_grad(ci, points, [[0.0, WELL_EDGE_TOP], [1.0, WELL_EDGE_BOTTOM]], LINE_MIN)


## 真鍮の面: 画面に1つだけの主の操作。`pressed` 0〜1 で照りが沈み、`lit` で明るくなる。
static func brass(
	ci: RID, rect: Rect2, corner := -1.0, pressed := 0.0, lit := 0.0, disabled := false
) -> void:
	var rad := radius(rect) if corner < 0.0 else corner
	shadow(
		ci,
		rect,
		rad,
		minf(rect.size.y * BRASS_SHADOW_RATIO, BRASS_SHADOW_MAX) * (1.0 - pressed * 0.5),
		BRASS_SHADOW_ALPHA
	)
	brass_shape(ci, rr(rect, rad), rect, pressed, lit, disabled)
	var width := line_w(rect)
	var inset := maxf(width * BRASS_INNER_INSET, BRASS_INNER_INSET_MIN)
	var inner := rect.grow(-inset)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0 or disabled:
		return
	stroke_grad(
		ci,
		rr(inner, maxf(rad - inset, GLASS_INNER_GAP)),
		[
			[0.0, Color(BRASS_INNER_LIGHT, BRASS_INNER_LIGHT.a * (1.0 - pressed))],
			[0.5, BRASS_INNER_MID],
			[1.0, BRASS_INNER_DARK]
		],
		maxf(width * BRASS_INNER_WIDTH, LINE_MIN)
	)


## 任意の凸の形へ真鍮の面を張る。
static func brass_shape(
	ci: RID, points: PackedVector2Array, rect: Rect2, pressed := 0.0, lit := 0.0, disabled := false
) -> void:
	var stops := brass_stops()
	var flat := [
		[0.0, UiPalette.BRASS],
		[0.10, UiPalette.BRASS],
		[0.48, UiPalette.GOLD_FOLD],
		[0.52, UiPalette.GOLD_FOLD],
		[1.0, UiPalette.GOLD]
	]
	for i in stops.size():
		var color: Color = stops[i][1]
		color = color.lerp(flat[i][1], pressed).lightened(lit * HOVER_FACE_LIGHTEN)
		if disabled:
			color = UiPaint.disabled_tone(color).lerp(UiPalette.INK_700, BRASS_DISABLED_SINK)
		stops[i][1] = color
	stroke(ci, points, UiPalette.BRASS_INK, line_w(rect) * 2.0 + LINE_MIN)
	vgrad(ci, points, stops, true)


## 砂のバー: 彫り込みの溝に砂が溜まる。進み具合・HP・残り時間。
static func sand_bar(
	ci: RID, rect: Rect2, ratio: float, light := UiPalette.SAND_HI, deep := UiPalette.SAND_DEEP
) -> void:
	well(ci, rect, rect.size.y * 0.5)
	if ratio <= 0.0:
		return
	var inner := rect.grow(-SAND_INSET)
	inner.size.x = maxf(inner.size.x * clampf(ratio, 0.0, 1.0), inner.size.y)
	vgrad(
		ci,
		rr(inner, inner.size.y * 0.5),
		[[0.0, light], [SAND_FOLD, light.lerp(deep, SAND_FOLD)], [1.0, deep]],
		true
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(rect.size.x * 7.0 + rect.size.y * 13.0)
	for i in int(inner.size.x * inner.size.y / SAND_GRAIN_AREA):
		var at := inner.position + Vector2(rng.randf() * inner.size.x, rng.randf() * inner.size.y)
		if absf(at.y - inner.get_center().y) < inner.size.y * SAND_GRAIN_BAND:
			RenderingServer.canvas_item_add_rect(ci, Rect2(at, Vector2.ONE), SAND_GRAIN_COLOR)


## 紙の帯: カードの名前。
static func paper(ci: RID, rect: Rect2, corner := 0.0) -> void:
	vgrad(ci, rr(rect, corner), [[0.0, UiPalette.PAPER], [1.0, UiPalette.PAPER_DEEP]], corner > 0.0)


# ---- 部品 -------------------------------------------------------------------
## 丸い計器の面。`role` が MAIN なら真鍮、それ以外は真鍮の輪に藍の面。
static func round_face(
	ci: RID, center: Vector2, rad: float, role := Role.SUB, pressed := 0.0, lit := 0.0
) -> void:
	var rim := clampf(rad * ROUND_RIM_RATIO, ROUND_RIM_MIN, ROUND_RIM_MAX)
	var box := Rect2(center - Vector2(rad, rad), Vector2(rad, rad) * 2.0)
	shadow(ci, box, rad, rad * ROUND_SHADOW_RATIO * (1.0 - pressed * 0.5), ROUND_SHADOW_ALPHA)
	fill(ci, ellipse(center, Vector2(rad + rim, rad + rim)), UiPalette.BRASS_INK)
	if role == Role.MAIN:
		var top := UiPalette.GOLD_HI.lerp(UiPalette.BRASS, pressed)
		var bottom := UiPalette.BRASS.lerp(UiPalette.GOLD, pressed)
		vgrad(
			ci,
			ellipse(center, Vector2(rad, rad)),
			[
				[0.0, top.lightened(lit * HOVER_FACE_LIGHTEN)],
				[0.45, UiPalette.GOLD.lightened(lit * HOVER_FACE_LIGHTEN)],
				[1.0, bottom]
			],
			true
		)
		stroke_grad(
			ci,
			ellipse(center, Vector2(rad, rad) * 0.86),
			[
				[0.0, Color(1, 1, 1, 0.6 * (1.0 - pressed))],
				[0.5, Color(1, 1, 1, 0.0)],
				[1.0, Color(0.3, 0.18, 0.04, 0.6)]
			],
			maxf(rim * 0.7, LINE_MIN)
		)
		return
	vgrad(ci, ellipse(center, Vector2(rad, rad)), rim_brass(lit), true)
	var face := rad - rim * ROUND_FACE_INSET
	vgrad(
		ci,
		ellipse(center, Vector2(face, face)),
		[[0.0, UiPalette.INK_600.lightened(lit * HOVER_FACE_LIGHTEN)], [1.0, UiPalette.INK_900]],
		true
	)
	glow(
		ci,
		center - Vector2(0, face * 0.35),
		Vector2(face, face * 0.7),
		Color(ROUND_SHINE, ROUND_SHINE.a * (1.0 - pressed))
	)
	if role == Role.DANGER:
		stroke(
			ci,
			ellipse(center, Vector2(face, face)),
			Color(UiPalette.FOE, 0.75),
			maxf(rim * 0.6, LINE_MIN)
		)


## 数値の宝石の面(コスト = 青 / 攻撃力 = 橙 / 体力 = 赤)。数字は `gem_text()` で載せる。
static func gem(ci: RID, center: Vector2, rad: float, light: Color, deep: Color) -> void:
	var rim := clampf(rad * GEM_RIM_RATIO, GEM_RIM_MIN, GEM_RIM_MAX)
	fill(
		ci,
		ellipse(center + Vector2(0, rad * 0.12), Vector2(rad + rim, rad + rim)),
		Color(0, 0, 0, 0.45)
	)
	vgrad(
		ci,
		ellipse(center, Vector2(rad + rim * 0.5, rad + rim * 0.5)),
		[[0.0, UiPalette.GOLD_HI], [0.5, UiPalette.BRASS], [1.0, UiPalette.BRASS_DEEP]],
		true
	)
	vgrad(
		ci,
		ellipse(center, Vector2(rad - rim * 0.6, rad - rim * 0.6)),
		[[0.0, light.lerp(Color.WHITE, 0.12)], [0.55, light.lerp(deep, 0.6)], [1.0, deep]],
		true
	)
	glow(ci, center - Vector2(rad * 0.25, rad * 0.38), Vector2(rad * 0.6, rad * 0.42), GEM_SHINE)


static func gem_text(
	ci: RID, font: Font, center: Vector2, rad: float, value: String, color := Color.WHITE
) -> void:
	var box := Rect2(center - Vector2(rad * 2.0, rad), Vector2(rad * 4.0, rad * 2.0))
	text_in(
		ci,
		font,
		value,
		box,
		int(rad * GEM_TEXT_RATIO),
		color,
		maxi(int(rad * GEM_OUTLINE_RATIO), 2)
	)


## 紋章の印(暗い円に真鍮の細い縁 + 紋章)。
static func seal(
	ci: RID, center: Vector2, rad: float, texture: Texture2D, tint := UiPalette.GOLD
) -> void:
	var rim := clampf(rad * SEAL_RIM_RATIO, SEAL_RIM_MIN, SEAL_RIM_MAX)
	fill(ci, ellipse(center, Vector2(rad + rim, rad + rim)), UiPalette.BRASS_INK)
	vgrad(
		ci,
		ellipse(center, Vector2(rad + rim * 0.4, rad + rim * 0.4)),
		[[0.0, UiPalette.GOLD], [1.0, UiPalette.BRASS_DEEP]],
		true
	)
	vgrad(
		ci,
		ellipse(center, Vector2(rad - rim * 0.6, rad - rim * 0.6)),
		[[0.0, UiPalette.INK_700], [1.0, UiPalette.INK_900]],
		true
	)
	if texture != null:
		var side := rad * SEAL_ICON_RATIO
		RenderingServer.canvas_item_add_texture_rect(
			ci,
			Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side)),
			texture.get_rid(),
			false,
			tint
		)


## 赤い丸の知らせ(受け取れるものの数)。`value` が空なら丸だけ。
static func badge(ci: RID, font: Font, center: Vector2, rad: float, value := "") -> void:
	fill(ci, ellipse(center, Vector2(rad + BADGE_RING, rad + BADGE_RING)), UiPalette.INK_900)
	vgrad(ci, ellipse(center, Vector2(rad, rad)), [[0.0, BADGE_TOP], [1.0, BADGE_BOTTOM]], true)
	if not value.is_empty():
		var box := Rect2(center - Vector2(rad, rad), Vector2(rad, rad) * 2.0)
		text_in(ci, font, value, box, int(rad * BADGE_TEXT_RATIO), Color.WHITE)


## 小さな真鍮の札(「前回」「つぎはここ」)。
static func tag(ci: RID, font: Font, rect: Rect2, label: String, px: int) -> void:
	brass(ci, rect, rect.size.y * 0.5)
	engraved(ci, font, label, rect, px)


# ---- 文字 -------------------------------------------------------------------
## 矩形の中央へ1行を置く。
static func text_in(
	ci: RID, font: Font, value: String, rect: Rect2, px: int, color: Color, outline := 0
) -> void:
	var top := rect.get_center().y - (font.get_ascent(px) + font.get_descent(px)) * 0.5
	var base := Vector2(rect.position.x, top + font.get_ascent(px))
	if outline > 0:
		font.draw_string_outline(
			ci,
			base,
			value,
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x,
			px,
			outline,
			Color(0, 0, 0, 0.75)
		)
	font.draw_string(ci, base, value, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, px, color)


## 真鍮の面に彫った字(暗い字 + 下に明るい縁)。
static func engraved(ci: RID, font: Font, value: String, rect: Rect2, px: int) -> void:
	var low := rect
	low.position.y += maxf(px * ENGRAVE_DROP_RATIO, 1.0)
	text_in(ci, font, value, low, px, ENGRAVE_LIGHT)
	text_in(ci, font, value, rect, px, UiPalette.BRASS_INK)
