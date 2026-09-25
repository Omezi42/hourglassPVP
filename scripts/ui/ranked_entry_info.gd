class_name RankedEntryInfo
extends Control
## たたかうタブの「対戦する」の札に載せる中身(GameDesign.md 9章)。
## 右に段位の徽章(帯ごとの金属のメダル+★)、左に段位名と次の段位まで、下端の凹んだ行に
## 待っている人の数とシーズンの残り日数を描く。途中の対局があるときは下端の行が琥珀の知らせになる。
## 札(`HomeTile`)の子として全面に敷き、押下は札へ通す。光は左上から当たるものとして陰影を付ける。

## 帯ごとの金属の色 [明 / 中 / 暗]。
const METALS := {
	"bronze": [Color(0.90, 0.63, 0.40), Color(0.64, 0.38, 0.21), Color(0.34, 0.18, 0.09)],
	"silver": [Color(0.95, 0.96, 0.98), Color(0.68, 0.71, 0.76), Color(0.36, 0.38, 0.44)],
	"gold": [Color(1.00, 0.90, 0.55), Color(0.86, 0.64, 0.22), Color(0.48, 0.31, 0.07)],
	"platinum": [Color(0.93, 0.98, 1.00), Color(0.66, 0.80, 0.88), Color(0.32, 0.42, 0.53)],
}
## 真鍮へ彫り込んだ文字: 本体の暗色と、彫りの下縁に返る光。
const ENGRAVE_COLOR := Color(0.23, 0.14, 0.05)
const ENGRAVE_LIGHT := Color(1.0, 0.93, 0.74, 0.55)
const CAPTION_COLOR := Color(0.23, 0.14, 0.05, 0.72)
const SHADOW_COLOR := Color(0.10, 0.06, 0.02)
const SPECULAR_COLOR := Color(1.0, 1.0, 1.0, 0.5)
const STAR_EMPTY_FILL := Color(0.22, 0.13, 0.05, 0.38)
## 下端の凹んだ行。
const WELL_TOP := Color(0.11, 0.07, 0.04, 0.94)
const WELL_BOTTOM := Color(0.22, 0.15, 0.08, 0.94)
const WELL_RESUME_TOP := Color(0.36, 0.18, 0.03, 0.96)
const WELL_RESUME_BOTTOM := Color(0.55, 0.31, 0.07, 0.96)
const WELL_EDGE_LIGHT := Color(1.0, 0.9, 0.66, 0.4)
const WELL_TEXT := Color(0.96, 0.94, 0.89)
const WELL_MUTED := Color(0.78, 0.71, 0.58)
const RESUME_TEXT := Color(1.0, 0.9, 0.64)
const LIVE_DOT := Color(0.97, 0.40, 0.27)
const RESUME_DOT := Color(1.0, 0.78, 0.34)

const LEFT := 40.0
const CAPTION_BASELINE := 132.0
const TIER_SIZE := 46
const TIER_GAP := 12.0
const CAPTION_SIZE := 16
const LINE_SIZE := 19
const RULE_LENGTH := 250.0
## 徽章の半径は札の背に比例させ、上限で止める。
const MEDAL_RATIO := 0.2
const MEDAL_MAX_RADIUS := 80.0
const MEDAL_RIGHT := 64.0
const MEDAL_CENTER_RATIO := 0.4
## ★は徽章の半径に対する比で大きさと並びを決める。
const STAR_RATIO := 0.17
const STAR_ROW := 1.33
const STAR_SPACING := 2.7
const STAR_INNER := 0.45
const WELL_HEIGHT := 50.0
const WELL_INSET := 14.0
const WELL_RADIUS := 8.0
const WELL_SHADOW_LAYERS := 4
const WELL_SHADOW_ALPHA := 0.55
const WELL_TEXT_SIZE := 19
const WELL_SMALL_SIZE := 16
const DOT_RADIUS := 6.0
const DOT_TEXT_GAP := 10.0
const PULSE_SPEED := 3.2
const SEGMENTS := 48
const CORNER_SEGMENTS := 12
const ARC_SEGMENTS := 16

var _tier := RankRules.INITIAL_TIER
var _stars := 0
var _rating := 0
var _days_left := 0
## 待っている人の数。負なら行を出さない(通信できない)。
var _waiting := -1
var _resume := false
var _phase := 0.0
var _font: Font
var _display: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font
	_display = UiFonts.display_font(_font)


func refresh() -> void:
	_tier = AccountService.rank_tier()
	_stars = AccountService.rank_stars()
	_rating = AccountService.rank_rating()
	# 前のシーズンの段位は、ランクマッチへ入った時点で初期化される(GameDesign.md 28章)。
	var season := AccountService.rank_season()
	if season != "" and season != RankProgress.current_season_key():
		_tier = RankRules.INITIAL_TIER
		_stars = 0
	_days_left = RankProgress.days_left_in_season()
	queue_redraw()


func set_waiting(count: int) -> void:
	_waiting = count
	queue_redraw()


## 途中の対局があるときは、下端の行を琥珀の知らせにする(GameDesign.md 9章)。
func set_resume(pending: bool) -> void:
	_resume = pending
	queue_redraw()


func _process(delta: float) -> void:
	if _resume or _waiting > 0:
		_phase = fmod(_phase + delta * PULSE_SPEED, TAU)
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if _font == null:
		return
	_draw_left_column()
	var radius: float = minf(size.y * MEDAL_RATIO, MEDAL_MAX_RADIUS)
	var center := Vector2(size.x - MEDAL_RIGHT - radius, size.y * MEDAL_CENTER_RATIO)
	_draw_medal(center, radius)
	_draw_stars(center + Vector2(0.0, radius * STAR_ROW), radius * STAR_RATIO)
	_draw_well()


func _draw_left_column() -> void:
	draw_string(
		_font,
		Vector2(LEFT, CAPTION_BASELINE),
		"いまの段位",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		CAPTION_SIZE,
		CAPTION_COLOR
	)
	var tier_baseline := CAPTION_BASELINE + TIER_GAP + float(TIER_SIZE)
	_draw_engraved(_display, Vector2(LEFT, tier_baseline), _tier_label(), TIER_SIZE)
	var rule_y := tier_baseline + TIER_GAP
	draw_line(
		Vector2(LEFT, rule_y), Vector2(LEFT + RULE_LENGTH, rule_y), Color(ENGRAVE_COLOR, 0.35), 1.0
	)
	draw_line(
		Vector2(LEFT, rule_y + 1.0), Vector2(LEFT + RULE_LENGTH, rule_y + 1.0), ENGRAVE_LIGHT, 1.0
	)
	draw_string(
		_font,
		Vector2(LEFT, rule_y + TIER_GAP + float(LINE_SIZE)),
		_next_line(),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		LINE_SIZE,
		ENGRAVE_COLOR
	)


## 段位名。段の数字は徽章にも打つが、名前として読めるよう左にも添える。
func _tier_label() -> String:
	var parsed := RankRules.parse(_tier)
	if _tier == RankRules.PLATINUM_KEY or parsed.is_empty():
		return RankRules.display_name(_tier)
	return "%s %d" % [RankRules.BRACKET_NAMES[parsed["bracket"]], int(parsed["step"])]


func _next_line() -> String:
	if _tier == RankRules.PLATINUM_KEY:
		return "レート %d" % _rating
	var need := RankRules.star_requirement(_tier)
	var next_tier: String = RankRules.advance_stars(_tier, need)["tier"]
	return "あと★%dつで %s" % [maxi(need - _stars, 1), RankRules.display_name(next_tier)]


## 彫り込んだ文字: 下縁へ返る光を1段下に置き、その上へ暗い本体を重ねる。
func _draw_engraved(font: Font, at: Vector2, text: String, font_size: int) -> void:
	var offset: float = maxf(1.0, float(font_size) * 0.03)
	draw_string(
		font,
		at + Vector2(0.0, offset),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		ENGRAVE_LIGHT
	)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ENGRAVE_COLOR)


func _metal() -> Array:
	return METALS.get(RankRules.bracket_of(_tier), METALS["bronze"])


## 帯の金属のメダル。縁は光を受けて上が明るく、内側の面は一段沈んで下が明るい。
func _draw_medal(center: Vector2, radius: float) -> void:
	var metal := _metal()
	var light: Color = metal[0]
	var mid: Color = metal[1]
	var dark: Color = metal[2]
	var edge: float = maxf(1.0, radius * 0.035)
	# 札へ落ちる影(下へずらして2段で柔らかく)。
	_fill_circle(center + Vector2(0.0, radius * 0.1), radius * 1.06, Color(SHADOW_COLOR, 0.18))
	_fill_circle(center + Vector2(0.0, radius * 0.06), radius * 1.01, Color(SHADOW_COLOR, 0.3))
	_fill_gradient_circle(center, radius, [[0.0, light], [0.45, mid], [1.0, dark]])
	_ring(center, radius, Color(SHADOW_COLOR, 0.75), edge)
	# 縁と面の境の溝。
	_ring(center, radius * 0.82, Color(dark.darkened(0.35), 0.9), edge * 1.6)
	var field := radius * 0.8
	_fill_gradient_circle(
		center, field, [[0.0, dark.lerp(mid, 0.35)], [0.6, mid], [1.0, light.lerp(mid, 0.3)]]
	)
	_ring(center, radius * 0.66, Color(dark, 0.45), edge)
	_ring(center + Vector2(0.0, edge), radius * 0.66, Color(light, 0.45), edge)
	_draw_medal_mark(center, radius, light, dark)
	# 左上の照り返し。
	_arc(center, radius * 0.92, PI * 1.08, PI * 1.55, SPECULAR_COLOR, radius * 0.05)
	_arc(center, field * 0.9, PI * 1.12, PI * 1.4, Color(SPECULAR_COLOR, 0.22), radius * 0.03)


## 面に打つ刻印。星取りの帯は段の数字、プラチナは砂時計。
func _draw_medal_mark(center: Vector2, radius: float, light: Color, dark: Color) -> void:
	if _tier == RankRules.PLATINUM_KEY:
		var side := radius * 0.9
		var rect := Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side)
		draw_texture_rect(UiPaint.HOURGLASS_ICON, rect, false, Color(dark, 0.9))
		return
	var step := str(int(RankRules.parse(_tier).get("step", 1)))
	var font_size := int(radius * 1.05)
	var width := _display.get_string_size(step, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var ascent := _display.get_ascent(font_size) - _display.get_descent(font_size)
	var at := center + Vector2(-width * 0.5, ascent * 0.5)
	var offset: float = maxf(1.0, radius * 0.025)
	draw_string(
		_display,
		at + Vector2(0.0, offset),
		step,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color(light, 0.8)
	)
	draw_string(_display, at, step, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, dark.darkened(0.3))


## 徽章の下に★を並べる。取った★は琥珀に光り、まだの★は真鍮へ彫った窪みにする。
func _draw_stars(center: Vector2, radius: float) -> void:
	if _tier == RankRules.PLATINUM_KEY:
		return
	var need := RankRules.star_requirement(_tier)
	var spacing := radius * STAR_SPACING
	var left := center.x - spacing * float(need - 1) * 0.5
	var outline: float = maxf(1.0, radius * 0.09)
	for i in need:
		var at := Vector2(left + spacing * float(i), center.y)
		var points := _star_points(at, radius)
		var closed := points.duplicate()
		closed.append(points[0])
		if i < _stars:
			var rect := Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
			UiPaint.fill_gradient_polygon(
				get_canvas_item(),
				points,
				rect,
				[[0.0, UiPalette.ROUND_FILLED_TOP], [1.0, UiPalette.ROUND_FILLED_BOTTOM]]
			)
			draw_polyline(closed, Color(SHADOW_COLOR, 0.8), outline, true)
		else:
			draw_colored_polygon(points, STAR_EMPTY_FILL)
			draw_polyline(_offset(closed, Vector2(0.0, 1.0)), ENGRAVE_LIGHT, outline, true)
			draw_polyline(closed, Color(ENGRAVE_COLOR, 0.55), outline, true)


## 下端の凹んだ行。左に待っている人(または途中の対局の知らせ)、右にシーズンの残り日数。
func _draw_well() -> void:
	var rect := Rect2(
		WELL_INSET, size.y - WELL_INSET - WELL_HEIGHT, size.x - WELL_INSET * 2.0, WELL_HEIGHT
	)
	var points := UiPaint.rounded_rect_points_uniform(rect, WELL_RADIUS, CORNER_SEGMENTS)
	var stops := (
		[[0.0, WELL_RESUME_TOP], [1.0, WELL_RESUME_BOTTOM]]
		if _resume
		else [[0.0, WELL_TOP], [1.0, WELL_BOTTOM]]
	)
	UiPaint.fill_gradient_polygon(get_canvas_item(), points, rect, stops)
	UiPaint.draw_inner_shadow(
		get_canvas_item(),
		rect,
		WELL_RADIUS,
		CORNER_SEGMENTS,
		WELL_SHADOW_LAYERS,
		SHADOW_COLOR,
		WELL_SHADOW_ALPHA
	)
	draw_line(
		Vector2(rect.position.x + WELL_RADIUS, rect.end.y + 1.0),
		Vector2(rect.end.x - WELL_RADIUS, rect.end.y + 1.0),
		WELL_EDGE_LIGHT,
		1.0
	)
	var baseline := rect.get_center().y + float(WELL_TEXT_SIZE) * 0.36
	var dot_center := Vector2(rect.position.x + WELL_INSET + DOT_RADIUS, rect.get_center().y)
	var text_left := dot_center.x + DOT_RADIUS + DOT_TEXT_GAP
	if _resume:
		_draw_dot(dot_center, RESUME_DOT)
		_well_text(text_left, baseline, "途中の対局が残っています", WELL_TEXT_SIZE, RESUME_TEXT)
		return
	if _waiting > 0:
		_draw_dot(dot_center, LIVE_DOT)
		_well_text(text_left, baseline, "いま %d人が相手を待っています" % _waiting, WELL_TEXT_SIZE, WELL_TEXT)
	elif _waiting == 0:
		_well_text(
			rect.position.x + WELL_INSET, baseline, "待っている間はCPUと対戦できます", WELL_SMALL_SIZE, WELL_MUTED
		)
	draw_string(
		_font,
		Vector2(rect.position.x, baseline),
		"シーズン終了まで %d日" % _days_left,
		HORIZONTAL_ALIGNMENT_RIGHT,
		rect.size.x - WELL_INSET,
		WELL_SMALL_SIZE,
		WELL_MUTED
	)


func _well_text(x: float, baseline: float, text: String, font_size: int, color: Color) -> void:
	draw_string(_font, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## 脈打つ点。外側の光の輪だけを脈打たせ、点そのものは動かさない(読みやすさを保つ)。
func _draw_dot(center: Vector2, color: Color) -> void:
	var pulse := 0.5 + 0.5 * sin(_phase)
	_fill_circle(
		center, DOT_RADIUS * (1.6 + pulse * 0.6), Color(color, 0.08 + 0.18 * (1.0 - pulse))
	)
	_fill_circle(center, DOT_RADIUS, color)
	_fill_circle(center - Vector2.ONE * DOT_RADIUS * 0.25, DOT_RADIUS * 0.4, Color(1, 1, 1, 0.55))


func _fill_circle(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(UiPaint.circle_points(center, radius, SEGMENTS), color)


func _fill_gradient_circle(center: Vector2, radius: float, stops: Array) -> void:
	var rect := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(), UiPaint.circle_points(center, radius, SEGMENTS), rect, stops
	)


func _ring(center: Vector2, radius: float, color: Color, width: float) -> void:
	draw_arc(center, radius, 0.0, TAU, SEGMENTS, color, width, true)


func _arc(
	center: Vector2, radius: float, from: float, to: float, color: Color, width: float
) -> void:
	draw_arc(center, radius, from, to, ARC_SEGMENTS, color, width, true)


static func _star_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var angle := -PI * 0.5 + PI * float(i) / 5.0
		var r := radius if i % 2 == 0 else radius * STAR_INNER
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	return points


static func _offset(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var moved := PackedVector2Array()
	for point in points:
		moved.append(point + by)
	return moved
