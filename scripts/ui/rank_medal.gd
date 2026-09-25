class_name RankMedal
extends RefCounted
## 帯の金属のメダルと★(GameDesign.md 9章・28章)。ホームの「対戦する」の札(`RankedEntryInfo`)と
## ランク画面が同じ絵を使うため、描き方をここへ1つにまとめる。光は左上から当たるものとして陰影を付ける。

## 帯ごとの金属の色 [明 / 中 / 暗]。
const METALS := {
	"bronze": [Color(0.90, 0.63, 0.40), Color(0.64, 0.38, 0.21), Color(0.34, 0.18, 0.09)],
	"silver": [Color(0.95, 0.96, 0.98), Color(0.68, 0.71, 0.76), Color(0.36, 0.38, 0.44)],
	"gold": [Color(1.00, 0.90, 0.55), Color(0.86, 0.64, 0.22), Color(0.48, 0.31, 0.07)],
	"platinum": [Color(0.93, 0.98, 1.00), Color(0.66, 0.80, 0.88), Color(0.32, 0.42, 0.53)],
}
## 順位の丸(1〜3位)に使う金属。
const PODIUM_BRACKETS: Array[String] = ["gold", "silver", "bronze"]
const SHADOW_COLOR := Color(0.10, 0.06, 0.02)
const SPECULAR_COLOR := Color(1.0, 1.0, 1.0, 0.5)
## 届いていない帯のメダルを沈める度合い。
const DIM_DARKEN := 0.58
const STAR_INNER := 0.45
const SEGMENTS := 48
const ARC_SEGMENTS := 16


static func metal(bracket: String) -> Array:
	return METALS.get(bracket, METALS["bronze"])


## 帯のメダル。縁は光を受けて上が明るく、内側の面は一段沈んで下が明るい。
## 面には段の数字(プラチナは砂時計)を打つ。`marked` が偽なら刻印を打たない(帯そのものを示すとき)。
static func draw_medal(
	item: CanvasItem,
	center: Vector2,
	radius: float,
	tier: String,
	font: Font,
	dim := false,
	marked := true
) -> void:
	var colors := metal(RankRules.bracket_of(tier))
	var light: Color = colors[0]
	var mid: Color = colors[1]
	var dark: Color = colors[2]
	if dim:
		light = light.darkened(DIM_DARKEN)
		mid = mid.darkened(DIM_DARKEN)
		dark = dark.darkened(DIM_DARKEN)
	var ci := item.get_canvas_item()
	var edge: float = maxf(1.0, radius * 0.035)
	# 下へ落ちる影(下へずらして2段で柔らかく)。
	UiPaint.fill_circle(
		ci, center + Vector2(0.0, radius * 0.1), radius * 1.06, Color(SHADOW_COLOR, 0.18), SEGMENTS
	)
	UiPaint.fill_circle(
		ci, center + Vector2(0.0, radius * 0.06), radius * 1.01, Color(SHADOW_COLOR, 0.3), SEGMENTS
	)
	fill_gradient_circle(item, center, radius, [[0.0, light], [0.45, mid], [1.0, dark]])
	item.draw_arc(center, radius, 0.0, TAU, SEGMENTS, Color(SHADOW_COLOR, 0.75), edge, true)
	# 縁と面の境の溝。
	item.draw_arc(
		center, radius * 0.82, 0.0, TAU, SEGMENTS, Color(dark.darkened(0.35), 0.9), edge * 1.6, true
	)
	var field := radius * 0.8
	fill_gradient_circle(
		item, center, field, [[0.0, dark.lerp(mid, 0.35)], [0.6, mid], [1.0, light.lerp(mid, 0.3)]]
	)
	item.draw_arc(center, radius * 0.66, 0.0, TAU, SEGMENTS, Color(dark, 0.45), edge, true)
	item.draw_arc(
		center + Vector2(0.0, edge),
		radius * 0.66,
		0.0,
		TAU,
		SEGMENTS,
		Color(light, 0.45),
		edge,
		true
	)
	if marked:
		_draw_mark(item, center, radius, tier, font, light, dark)
	# 左上の照り返し。
	var specular := Color(SPECULAR_COLOR, SPECULAR_COLOR.a * (0.4 if dim else 1.0))
	item.draw_arc(
		center, radius * 0.92, PI * 1.08, PI * 1.55, ARC_SEGMENTS, specular, radius * 0.05, true
	)
	item.draw_arc(
		center,
		field * 0.9,
		PI * 1.12,
		PI * 1.4,
		ARC_SEGMENTS,
		Color(specular, specular.a * 0.44),
		radius * 0.03,
		true
	)


static func _draw_mark(
	item: CanvasItem,
	center: Vector2,
	radius: float,
	tier: String,
	font: Font,
	light: Color,
	dark: Color
) -> void:
	if tier == RankRules.PLATINUM_KEY:
		var side := radius * 0.9
		var rect := Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side)
		item.draw_texture_rect(UiPaint.HOURGLASS_ICON, rect, false, Color(dark, 0.9))
		return
	var step := str(int(RankRules.parse(tier).get("step", 1)))
	draw_struck_number(item, center, radius, step, font, light, dark)


## 金属の面へ打ち込んだ数字。下縁へ返る光を1段下に置き、その上へ暗い本体を重ねる。
static func draw_struck_number(
	item: CanvasItem,
	center: Vector2,
	radius: float,
	number: String,
	font: Font,
	light: Color,
	dark: Color
) -> void:
	var font_size := int(radius * 1.05)
	var width := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var ascent := font.get_ascent(font_size) - font.get_descent(font_size)
	var at := center + Vector2(-width * 0.5, ascent * 0.5)
	var offset: float = maxf(1.0, radius * 0.025)
	item.draw_string(
		font,
		at + Vector2(0.0, offset),
		number,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color(light, 0.8)
	)
	item.draw_string(font, at, number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, dark.darkened(0.3))


## 取った★(琥珀に光る)。まだの★の見せ方は置き場所の地の色で変わるため、呼ぶ側が
## `star_points()` で描く。
static func draw_filled_star(item: CanvasItem, at: Vector2, radius: float) -> void:
	var points := star_points(at, radius)
	var rect := Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	UiPaint.fill_gradient_polygon(
		item.get_canvas_item(),
		points,
		rect,
		[[0.0, UiPalette.ROUND_FILLED_TOP], [1.0, UiPalette.ROUND_FILLED_BOTTOM]]
	)
	item.draw_polyline(closed(points), Color(SHADOW_COLOR, 0.8), star_outline(radius), true)


static func star_outline(radius: float) -> float:
	return maxf(1.0, radius * 0.09)


static func star_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var angle := -PI * 0.5 + PI * float(i) / 5.0
		var r := radius if i % 2 == 0 else radius * STAR_INNER
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	return points


static func closed(points: PackedVector2Array) -> PackedVector2Array:
	var ring := points.duplicate()
	ring.append(points[0])
	return ring


static func fill_gradient_circle(
	item: CanvasItem, center: Vector2, radius: float, stops: Array
) -> void:
	var rect := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	UiPaint.fill_gradient_polygon(
		item.get_canvas_item(), UiPaint.circle_points(center, radius, SEGMENTS), rect, stops
	)
