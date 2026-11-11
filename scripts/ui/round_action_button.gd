class_name RoundActionButton
extends Button
## 対局画面「行動の列」のボタン(GameDesign.md 9章「対局画面の見た目」)。
## 丸い計器(ターン終了 = 真鍮の面 / 反転権・コイン・メニュー = 硝子の計器)と、
## 横長の硝子のボタン(ログ・エモート・投了。`width` を入れたとき)の2つの形を持つ。
##
## `CodedButton` を使わないのは、直径だけが決まっている丸に文字の幅で伸びる矩形が合わないため。
## `Button` を継承するのは `disabled`・`pressed`・`SoundBank.wire_buttons()` をそのまま使うためで、
## **`text` は空のままにし、文言は `label` として自前で描く**。

const MIN_FONT_SIZE := UiPalette.T_MICRO
const MAX_FONT_SIZE := UiPalette.T_HEAD
## 文言を収める幅(直径に対する比)と、直径から文字の大きさを求める直線の2点。
const LABEL_WIDTH_RATIO := 0.78
const FONT_AT_SMALL := Vector2(48.0, 13.0)
const FONT_AT_LARGE := Vector2(112.0, 20.0)
## 紋章の下へ添える文言の大きさ(紋章に主役を譲る)。
const EMBLEM_LABEL_FONT_SIZE := UiPalette.T_MICRO
const STYLE_STATES := ["normal", "hover", "pressed", "disabled", "focus"]
## 紋章の半辺と、紋章・文言の上下の位置(いずれも直径に対する比)。
const ICON_HALF_RATIO := 0.21
const EMBLEM_RATIO := 0.30
const EMBLEM_RISE := 0.06
const EMBLEM_LABEL_DROP := 0.30
## 横長のボタンの文字の大きさ(高さに対する比)。
const PILL_FONT_RATIO := 0.40
## 押したとき面が縮む倍率と、乗ったとき浮く量(`CodedButtonStyle` と同じ)。
const PRESS_SCALE := CodedButtonStyle.PRESS_SCALE
const LIFT := CodedButtonStyle.LIFT
const DISABLED_ALPHA := 0.5
## 縁の砂の輪(縦のターン終了の持ち時間)。面の外へ出す量と太さ。
const RING_GAP := 4.5
const RING_WIDTH := 4.0
const SUB_LABEL_FONT_SIZE := UiPalette.T_BODY
## 見出しと下の数字の、中心からの上下の位置(直径に対する比)。
const TITLE_RISE := 0.10
const SUB_LABEL_DROP := 0.17

## ボタンの語。
var label: String = "":
	set(value):
		label = value
		queue_redraw()
## 丸の直径(横長のときは高さ)。
var diameter: float = 56.0:
	set(value):
		diameter = value
		_resize()
## 0 より大きいとき、この幅の横長のボタンにする。
var width: float = 0.0:
	set(value):
		width = value
		_resize()
## 真鍮の面(その画面の主の操作)か。
var filled: bool = false:
	set(value):
		filled = value
		queue_redraw()
## 取り返せない操作(投了)。硝子に赤い縁。
var danger: bool = false:
	set(value):
		danger = value
		queue_redraw()
## 語の後ろへ添える小さな数字(エモートの残り秒)。空なら出さない。
var badge: String = "":
	set(value):
		badge = value
		queue_redraw()
## 面の中央(文言があれば少し上)に描く紋章。
var emblem: UiPaint.Emblem = UiPaint.Emblem.NONE:
	set(value):
		emblem = value
		queue_redraw()
## `emblem` の代わりに描く取り込みアイコン(`assets/ui/icons/` の白いシルエット)。
var emblem_texture: Texture2D:
	set(value):
		emblem_texture = value
		queue_redraw()
## 0以上のとき、面の縁へ残りの割合ぶんの砂の輪を描く(縦のターン終了の持ち時間)。
var ring_ratio := -1.0:
	set(value):
		ring_ratio = value
		queue_redraw()
var ring_color := UiPalette.SAND_HI
## 見出しの下へ小さく出す字(残り時間)。空なら出さない。
var sub_label := "":
	set(value):
		sub_label = value
		queue_redraw()

var _font: Font
var _hover := 0.0
var _press := 0.0
var _hover_tween: Tween
var _press_tween: Tween


func _init(p_label: String = "", p_diameter: float = 56.0, p_filled: bool = false) -> void:
	label = p_label
	diameter = p_diameter
	filled = p_filled
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for state in STYLE_STATES:
		add_theme_stylebox_override(state, empty)
	mouse_entered.connect(_set_hover_target.bind(1.0))
	mouse_exited.connect(_set_hover_target.bind(0.0))
	button_down.connect(_set_press_target.bind(1.0))
	button_up.connect(_set_press_target.bind(0.0))


func _ready() -> void:
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font


func _get_minimum_size() -> Vector2:
	return Vector2(width if width > 0.0 else diameter, diameter)


func _resize() -> void:
	custom_minimum_size = _get_minimum_size()
	size = custom_minimum_size
	queue_redraw()


func _set_hover_target(target: float) -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	if not is_inside_tree() or (disabled and target > 0.0):
		return
	_hover_tween = create_tween()
	_hover_tween.tween_method(_set_hover, _hover, target, UiPalette.DUR_HOVER)


func _set_press_target(target: float) -> void:
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
	if not is_inside_tree() or (disabled and target > 0.0):
		return
	_press_tween = create_tween()
	_press_tween.tween_method(_set_press, _press, target, UiPalette.DUR_PRESS)


func _set_hover(value: float) -> void:
	_hover = value
	queue_redraw()


func _set_press(value: float) -> void:
	_press = value
	queue_redraw()


func _draw() -> void:
	if _font == null:
		return
	var hover := 0.0 if disabled else _hover
	var press := 0.0 if disabled else _press
	if width > 0.0:
		_draw_pill(hover, press)
	else:
		_draw_round(hover, press)


func _draw_round(hover: float, press: float) -> void:
	var ci := get_canvas_item()
	var center := Vector2(diameter, diameter) * 0.5 - Vector2(0, LIFT * hover * (1.0 - press))
	var rim := clampf(
		diameter * 0.5 * UiKit.ROUND_RIM_RATIO, UiKit.ROUND_RIM_MIN, UiKit.ROUND_RIM_MAX
	)
	var radius := (diameter * 0.5 - rim) * lerpf(1.0, PRESS_SCALE, press)
	self_modulate.a = DISABLED_ALPHA if disabled else 1.0
	var role := UiKit.Role.MAIN if filled else (UiKit.Role.DANGER if danger else UiKit.Role.SUB)
	UiKit.round_face(ci, center, radius, role, press, hover)
	if ring_ratio >= 0.0:
		TurnClockDial.draw_ring(ci, center, radius + RING_GAP, ring_ratio, ring_color, RING_WIDTH)
	var tint := UiPalette.BRASS_INK if filled else UiPalette.GOLD
	if emblem_texture != null or emblem != UiPaint.Emblem.NONE:
		# 紋章は面の中央よりわずかに上、文言は紋章の下へ小さく描く
		# (反転権: 紋章だけでは何のボタンか伝わらないため語も添える)。
		var emblem_center := center + Vector2(0.0, -diameter * EMBLEM_RISE)
		if emblem_texture != null:
			UiPaint.draw_icon(
				ci, emblem_texture, emblem_center, diameter * ICON_HALF_RATIO, disabled, tint
			)
		else:
			UiPaint.draw_emblem(ci, emblem, emblem_center, diameter * EMBLEM_RATIO, tint)
		_draw_label(
			_with_badge(),
			center + Vector2(0.0, diameter * EMBLEM_LABEL_DROP),
			EMBLEM_LABEL_FONT_SIZE
		)
		return
	if sub_label.is_empty():
		_draw_label(_with_badge(), center, _fit_font_size())
		return
	_draw_label(label, center - Vector2(0.0, diameter * TITLE_RISE), _fit_font_size())
	_draw_label(
		sub_label, center + Vector2(0.0, diameter * SUB_LABEL_DROP), SUB_LABEL_FONT_SIZE, false
	)


func _draw_pill(hover: float, press: float) -> void:
	var ci := get_canvas_item()
	var face := Rect2(Vector2(0, -LIFT * hover * (1.0 - press)), size)
	var scaled := face.size * lerpf(1.0, PRESS_SCALE, press)
	face = Rect2(face.get_center() - scaled * 0.5, scaled)
	var rim: Array = []
	if danger:
		rim = UiKit.rim_color(UiPalette.FOE.lerp(UiPalette.DANGER_TEXT, hover))
	self_modulate.a = DISABLED_ALPHA if disabled else 1.0
	UiKit.glass(
		ci,
		face,
		face.size.y * 0.5,
		CodedButtonStyle.BUTTON_LIFT * (1.0 - press),
		UiKit.GLASS_ALPHA,
		rim,
		hover,
		1.0 - press
	)
	var color := UiPalette.DANGER_TEXT if danger else UiPalette.IVORY
	UiKit.text_in(ci, _font, _with_badge(), face, roundi(diameter * PILL_FONT_RATIO), color)


## 残り秒などの数字は語の後ろへ添える(語の頭は変えない。GameDesign.md 9章「エモート」)。
func _with_badge() -> String:
	return label if badge.is_empty() else "%s %s" % [label, badge]


func _draw_label(value: String, center: Vector2, font_size: int, heading := true) -> void:
	if value.is_empty():
		return
	var ci := get_canvas_item()
	var box := Rect2(center - Vector2(diameter, diameter) * 0.5, Vector2(diameter, diameter))
	if filled:
		var font := UiFonts.display_font_for(value, _font) if heading else _font
		UiKit.engraved(ci, font, value, box, font_size)
		return
	UiKit.text_in(ci, _font, value, box, font_size, UiPalette.IVORY, 2)


## 直径から求めた大きさを、文言が面へ収まるまで1pxずつ縮める(`MIN_FONT_SIZE` が下限)。
func _fit_font_size() -> int:
	var base := remap(diameter, FONT_AT_SMALL.x, FONT_AT_LARGE.x, FONT_AT_SMALL.y, FONT_AT_LARGE.y)
	var current := int(round(clampf(base, float(MIN_FONT_SIZE), float(MAX_FONT_SIZE))))
	var font := UiFonts.display_font_for(label, _font) if filled else _font
	var max_width := diameter * LABEL_WIDTH_RATIO
	var value := _with_badge()
	while current > MIN_FONT_SIZE:
		if font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, current).x <= max_width:
			break
		current -= 1
	return current
