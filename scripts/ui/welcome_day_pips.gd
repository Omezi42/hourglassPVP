class_name WelcomeDayPips
extends Control
## はじめの7日の日の粒(GameDesign.md 23章)。受け取った日は真鍮、今日は琥珀で脈打たせ、先の日は沈める。
## 粒の下にはその日の報酬を小さく添える(先の日に何があるかを初日から見せるため)。

const HEIGHT := 80.0
const RADIUS := 20.0
const RIM_WIDTH := 2.0
const PULSE_SPEED := 2.6
const PULSE_GLOW := 7.0
const LABEL_SIZE := 15
const REWARD_SIZE := 13
const REWARD_BASELINE := 66.0

## 受け取った日数。次の日(claimed + 1)が「今日」。
var claimed := 0
var _time := 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	var step := size.x / float(WelcomeDays.DAYS)
	var font := get_theme_default_font()
	for i in WelcomeDays.DAYS:
		var center := Vector2(step * (i + 0.5), RADIUS + 2.0)
		var day := i + 1
		var fill := UiPalette.PANEL_PRESSED_TOP
		var rim := UiPalette.BRASS_DARK
		var text_color := UiPalette.TEXT_MUTED
		if day <= claimed:
			fill = UiPalette.BRASS_LIGHT
			rim = UiPalette.BRASS_HIGHLIGHT
			text_color = UiPalette.TEXT_OFFWHITE
		elif day == claimed + 1:
			var pulse := 0.5 + 0.5 * sin(_time * PULSE_SPEED)
			var glow := UiPalette.GLOW_AMBER
			glow.a = 0.35 * pulse
			draw_circle(center, RADIUS + PULSE_GLOW * pulse, glow, true, -1.0, true)
			fill = UiPalette.PANEL_AMBER_TOP
			rim = UiPalette.GLOW_AMBER
			text_color = UiPalette.TEXT_OFFWHITE
		draw_circle(center, RADIUS, fill, true, -1.0, true)
		draw_circle(center, RADIUS, rim, false, RIM_WIDTH, true)
		if font == null:
			continue
		var label := str(day)
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
		draw_string(
			font,
			center + Vector2(-width * 0.5, LABEL_SIZE * 0.35),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			LABEL_SIZE,
			text_color
		)
		draw_string(
			font,
			Vector2(step * i, REWARD_BASELINE),
			WelcomeDays.short_reward_text(day),
			HORIZONTAL_ALIGNMENT_CENTER,
			step,
			REWARD_SIZE,
			UiPalette.BRASS_HIGHLIGHT if day > claimed else UiPalette.TEXT_MUTED
		)
