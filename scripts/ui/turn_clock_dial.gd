class_name TurnClockDial
extends Control
## 行動の列に置く持ち時間の丸い時計(GameDesign.md 5章・9章)。
## いま手番の側の残り時間を1つだけ出す(1手番ごとに60秒へ戻る仕組みのため、
## 両者ぶんを並べる理由が無い)。**時計を持たない対局(CPU戦・持ち時間を切った
## ルームマッチ・再生)は「∞」**。
##
## 丸い計器の面に、残りを縁の砂の輪と中の数字で出す。危険域(半分以下)は赤、
## 残り15秒以下で手番中なら脈打つ。

const DIAMETER := 60.0
const CRITICAL_SECONDS := 15.0
const FONT_SIZE := UiPalette.T_BODY
const INFINITY_FONT_SIZE := UiPalette.T_HEAD
const INFINITY_TEXT := "∞"
## 砂の輪の位置(半径に対する比)・太さ・分割数。
const RING_RATIO := 0.80
const RING_WIDTH := 3.0
const RING_SEGMENTS := 48
const RING_TRACK := Color(1, 1, 1, 0.14)
const PULSE_SPEED := 0.008

## 残り秒。負なら時計を持たない対局(∞)。
var seconds := -1.0
## 1手番の持ち時間。危険域(半分以下)の境目に使う。
var total := MatchClock.DEFAULT_TURN_SECONDS
## いま自分の手番か。残り15秒の脈打ちは自分の手番だけに出す。
var my_turn := false

## 縦では計器を出さず、ターン終了のボタンの縁へ同じ輪と数字を映す(GameDesign.md 9章「縦の対局画面」)。
var mirror: RoundActionButton:
	set(value):
		if mirror != null and mirror != value:
			mirror.ring_ratio = -1.0
			mirror.sub_label = ""
		mirror = value
		visible = mirror == null
		_sync_mirror()

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
		_sync_mirror()


func set_time(remaining: float, turn_total: float, is_my_turn: bool) -> void:
	seconds = remaining
	total = turn_total
	my_turn = is_my_turn
	queue_redraw()
	_sync_mirror()


func _sync_mirror() -> void:
	if mirror == null:
		return
	if seconds < 0.0:
		mirror.ring_ratio = -1.0
		mirror.sub_label = ""
		return
	mirror.ring_color = _sand_color()
	mirror.ring_ratio = seconds / maxf(total, 1.0)
	mirror.sub_label = _time_text()


func _time_text() -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


## 砂の輪の色。危険域(半分以下)は赤、残り15秒以下で手番中なら脈打つ。
func _sand_color() -> Color:
	if seconds <= CRITICAL_SECONDS and my_turn:
		var pulse := (sin(Time.get_ticks_msec() * PULSE_SPEED) + 1.0) * 0.5
		return UiPalette.HEALTH.lerp(UiPalette.SAND_HI, pulse * 0.4)
	if seconds <= maxf(total, 1.0) * 0.5:
		return UiPalette.HEALTH
	return UiPalette.SAND_HI


func _draw() -> void:
	var ci := get_canvas_item()
	var center := size * 0.5
	var radius := DIAMETER * 0.5 - UiKit.ROUND_RIM_MAX
	var has_clock := seconds >= 0.0
	var is_critical := has_clock and seconds <= CRITICAL_SECONDS and my_turn
	var is_low := has_clock and seconds <= maxf(total, 1.0) * 0.5
	var pulse := (sin(Time.get_ticks_msec() * PULSE_SPEED) + 1.0) * 0.5
	UiKit.round_face(ci, center, radius)
	var text := INFINITY_TEXT
	var font_size := INFINITY_FONT_SIZE
	var color := UiPalette.IVORY
	if has_clock:
		if is_critical:
			color = UiPalette.HEALTH.lerp(Color.WHITE, pulse * 0.5)
		elif is_low:
			color = UiPalette.DANGER_TEXT
		draw_ring(
			ci, center, radius * RING_RATIO, seconds / maxf(total, 1.0), _sand_color(), RING_WIDTH
		)
		text = _time_text()
		font_size = FONT_SIZE
	var box := Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
	UiKit.text_in(ci, _font, text, box, font_size, color, 2)


## 残りの割合ぶんの砂の輪(12時から時計回り)と、減ったぶんの薄い輪。
## 縦ではターン終了のボタンが同じ輪を自分の縁へ描く(GameDesign.md 9章「縦の対局画面」)。
static func draw_ring(
	ci: RID, center: Vector2, radius: float, ratio: float, color: Color, width: float
) -> void:
	var kept := clampf(ratio, 0.0, 1.0)
	var split := -PI * 0.5 + TAU * kept
	if kept < 1.0:
		ShapePaint.arc(ci, center, radius, split, PI * 1.5, RING_SEGMENTS, RING_TRACK, width, true)
	if kept > 0.0:
		ShapePaint.arc(ci, center, radius, -PI * 0.5, split, RING_SEGMENTS, color, width, true)
