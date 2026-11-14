class_name WelcomeDayPips
extends Control
## はじめの7日の日の粒(GameDesign.md 23章)。受け取った日は真鍮、今日は琥珀で脈打たせ、先の日は沈める。
## 粒の下にはその日の報酬を小さく添える(先の日に何があるかを初日から見せるため)。
##
## 止まっている粒と報酬の字はこのノードが `claimed` の変わったときだけ描き、
## 毎コマ動く「今日」の粒(光と琥珀の玉と日の数字)だけを子の `_PulseLayer` が描く。

const HEIGHT := 80.0
const RADIUS := 20.0
const PULSE_SPEED := 2.6
const PULSE_GLOW := 7.0
const PULSE_ALPHA := 0.35
const LABEL_SIZE := UiPalette.T_BODY
const REWARD_SIZE := UiPalette.T_SMALL
const REWARD_BASELINE := 66.0
## 縦(パネルごと1.4倍)で小さな見出しの目安(20px)以上にする大きさ。
const PORTRAIT_LABEL_SIZE := UiPalette.T_LEAD
const PORTRAIT_REWARD_SIZE := UiPalette.T_BODY

## 受け取った日数。次の日(claimed + 1)が「今日」。変わったときだけ報酬の文字列を引き直す
## (`_draw` で所有の判定を引かない)。
var claimed := 0:
	set(value):
		claimed = value
		_rebuild_rewards()
		queue_redraw()
		if _pulse != null:
			_pulse.queue_redraw()
var _rewards: Array[String] = []
var _pulse: _PulseLayer


func _ready() -> void:
	_rebuild_rewards()
	_pulse = _PulseLayer.new()
	_pulse.pips = self
	_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pulse.anchor_right = 1.0
	_pulse.anchor_bottom = 1.0
	add_child(_pulse)


func _rebuild_rewards() -> void:
	_rewards.clear()
	for day in range(1, WelcomeDays.DAYS + 1):
		_rewards.append(WelcomeDays.short_reward_text(day))


func _draw() -> void:
	var step := size.x / float(WelcomeDays.DAYS)
	var font := get_theme_default_font()
	var reward_size := PORTRAIT_REWARD_SIZE if ScreenOrientation.is_portrait() else REWARD_SIZE
	var ci := get_canvas_item()
	for i in WelcomeDays.DAYS:
		var day := i + 1
		var text_color := UiPalette.MUTED
		if day <= claimed:
			UiKit.round_face(ci, _pip_center(step, i), RADIUS, UiKit.Role.MAIN)
			text_color = UiPalette.BRASS_INK
		elif day > claimed + 1:
			UiKit.round_face(ci, _pip_center(step, i), RADIUS)
		if font == null:
			continue
		if day != claimed + 1:
			_draw_day_number(self, font, _pip_center(step, i), day, text_color)
		draw_string(
			font,
			Vector2(step * i, REWARD_BASELINE),
			_rewards[i],
			HORIZONTAL_ALIGNMENT_CENTER,
			step,
			reward_size,
			UiPalette.GOLD if day > claimed else UiPalette.MUTED
		)


static func _pip_center(step: float, index: int) -> Vector2:
	return Vector2(step * (index + 0.5), RADIUS + 2.0)


static func _draw_day_number(
	canvas: CanvasItem, font: Font, center: Vector2, day: int, color: Color
) -> void:
	var label_size := PORTRAIT_LABEL_SIZE if ScreenOrientation.is_portrait() else LABEL_SIZE
	var label := str(day)
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
	canvas.draw_string(
		font,
		center + Vector2(-width * 0.5, label_size * 0.35),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		label_size,
		color
	)


## 「今日」の粒。脈打つので毎コマ描き直す。
class _PulseLayer:
	extends Control

	var pips: WelcomeDayPips
	var _time := 0.0

	func _process(delta: float) -> void:
		if pips.claimed >= WelcomeDays.DAYS or not is_visible_in_tree():
			return
		_time += delta
		queue_redraw()

	func _draw() -> void:
		if pips.claimed >= WelcomeDays.DAYS:
			return
		var center := WelcomeDayPips._pip_center(size.x / float(WelcomeDays.DAYS), pips.claimed)
		var ci := get_canvas_item()
		var pulse := 0.5 + 0.5 * sin(_time * WelcomeDayPips.PULSE_SPEED)
		var glow_radius := WelcomeDayPips.RADIUS + WelcomeDayPips.PULSE_GLOW * pulse
		UiKit.glow(
			ci,
			center,
			Vector2(glow_radius, glow_radius),
			Color(UiPalette.SAND, WelcomeDayPips.PULSE_ALPHA * pulse)
		)
		UiKit.gem(ci, center, WelcomeDayPips.RADIUS, UiPalette.SAND_HI, UiPalette.SAND_DEEP)
		var font := get_theme_default_font()
		if font != null:
			WelcomeDayPips._draw_day_number(
				self, font, center, pips.claimed + 1, UiPalette.BRASS_INK
			)
