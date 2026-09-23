class_name TurnClockDial
extends Control
## 行動の列に置く持ち時間の丸い時計(GameDesign.md 5章・9章)。
## いま手番の側の残り時間を1つだけ出す(1手番ごとに60秒へ戻る仕組みのため、
## 両者ぶんを並べる理由が無い)。**時計を持たない対局(CPU戦・持ち時間を切った
## ルームマッチ・再生・観戦)は「∞」**。
##
## 文字盤は真鍮の器に12の目盛を彫った懐中時計の面として描き、語の見出しを持たない
## (目盛があれば時計だと読める)。危険域(半分以下)は赤、残り15秒以下で手番中なら脈打つ。

const DIAMETER := 56.0
const RING_WIDTH := 3.0
const TICK_COUNT := 12
const CRITICAL_SECONDS := 15.0
const FONT_SIZE := 16
const INFINITY_FONT_SIZE := 24
const INFINITY_TEXT := "∞"

## 残り秒。負なら時計を持たない対局(∞)。
var seconds := -1.0
## 1手番の持ち時間。危険域(半分以下)の境目に使う。
var total := MatchClock.DEFAULT_TURN_SECONDS
## いま自分の手番か。残り15秒の脈打ちは自分の手番だけに出す。
var my_turn := false

var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font
	custom_minimum_size = Vector2.ONE * DIAMETER
	size = custom_minimum_size
	set_process(true)


func _process(_delta: float) -> void:
	if seconds >= 0.0 and seconds <= CRITICAL_SECONDS and my_turn:
		queue_redraw()


func set_time(remaining: float, turn_total: float, is_my_turn: bool) -> void:
	seconds = remaining
	total = turn_total
	my_turn = is_my_turn
	queue_redraw()


func _draw() -> void:
	var ci := get_canvas_item()
	var center := size * 0.5
	var radius := DIAMETER * 0.5
	var has_clock := seconds >= 0.0
	var is_critical := has_clock and seconds <= CRITICAL_SECONDS and my_turn
	var is_low := has_clock and seconds <= maxf(total, 1.0) * 0.5
	var pulse := (sin(Time.get_ticks_msec() * 0.008) + 1.0) * 0.5

	UiPaint.fill_circle(ci, center + Vector2(0, 2.5), radius + 1.5, Color(0, 0, 0, 0.45), 32)
	UiPaint.draw_ring(ci, center, radius + 0.5, UiPalette.OUTLINE_DARK, 1.0, 32)
	UiPaint.fill_gradient_polygon(
		ci,
		UiPaint.circle_points(center, radius, 32),
		Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0),
		[[0.0, UiPalette.BRASS_HIGHLIGHT], [0.5, UiPalette.BRASS_MID], [1.0, UiPalette.BRASS_DARK]]
	)
	var face_r := radius - RING_WIDTH
	UiPaint.fill_gradient_polygon(
		ci,
		UiPaint.circle_points(center, face_r, 32),
		Rect2(center - Vector2.ONE * face_r, Vector2.ONE * face_r * 2.0),
		[[0.0, UiPalette.NAVY_PANEL_BOTTOM], [1.0, UiPalette.NAVY_PANEL_TOP]]
	)
	UiPaint.apply_grain(ci, Rect2(center - Vector2.ONE * face_r, Vector2.ONE * face_r * 2.0), 0.05)
	_draw_ticks(center, face_r)

	var ring_color := UiPalette.BRASS_HIGHLIGHT
	var ring_width := 1.0
	if is_critical:
		ring_color = UiPalette.WARNING_RED.lerp(UiPalette.GLOW_AMBER, pulse * 0.4)
		ring_width = 2.5
		UiPaint.draw_ring(ci, center, radius + 3.0, Color(ring_color, 0.35 * pulse), 3.0, 32)
	elif is_low:
		ring_color = Color(UiPalette.WARNING_RED, 0.9)
		ring_width = 2.0
	elif my_turn and has_clock:
		ring_color = UiPalette.GLOW_AMBER
		ring_width = 1.5
	UiPaint.draw_ring(ci, center, face_r, ring_color, ring_width, 32)

	var text := INFINITY_TEXT
	var font_size := INFINITY_FONT_SIZE
	var color := UiPalette.TEXT_OFFWHITE
	if has_clock:
		text = "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
		font_size = FONT_SIZE
		if is_critical:
			color = Color(1.0, 0.35 + 0.35 * pulse, 0.35 + 0.35 * pulse, 1.0)
		elif is_low:
			color = UiPalette.WARNING_RED
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := center + Vector2(-width * 0.5, font_size * 0.36)
	draw_string(
		_font, at + Vector2.ONE, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.8)
	)
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## 文字盤の目盛。12時・3時・6時・9時だけ長く、他は短く。
func _draw_ticks(center: Vector2, face_r: float) -> void:
	for i in TICK_COUNT:
		var angle := TAU * float(i) / float(TICK_COUNT) - PI * 0.5
		var dir := Vector2(cos(angle), sin(angle))
		var length := 4.0 if i % 3 == 0 else 2.0
		var outer := center + dir * (face_r - 2.0)
		draw_line(outer - dir * length, outer, Color(UiPalette.BRASS_HIGHLIGHT, 0.7), 1.0)
