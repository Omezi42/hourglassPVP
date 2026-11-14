class_name ButtonFeel
extends RefCounted
## ボタンの「乗る・押す」へ尺を持たせる(GameDesign.md 9章「動きの尺は3つ」/ Architecture.md 4.0節)。
## StyleBox の状態の差し替えは一瞬で切り替わるため、ボタンごとに自分専用の `CodedButtonStyle` を
## 1つ持たせ、乗った量・押した量を `UiPalette.DUR_HOVER` / `DUR_PRESS` で動かして描き直す。
## 押せない・選ばれている(トグル)はスタイルがボタンから読む。

const STATES: Array[String] = ["normal", "hover", "pressed", "disabled", "hover_pressed"]
const META_STYLE := "button_feel_style"
const META_HOVER_TWEEN := "button_feel_hover_tween"
const META_PRESS_TWEEN := "button_feel_press_tween"


## `base` を複製してボタンへ当てる。同じボタンへ繰り返し呼んでよい(面の役割を替えるとき)。
static func attach(button: BaseButton, base: CodedButtonStyle) -> void:
	var previous := _style(button)
	var style := base.duplicate() as CodedButtonStyle
	style.variant = CodedButtonStyle.State.NORMAL
	style.bind_button(button)
	if previous != null:
		style.hover_amount = previous.hover_amount
		style.press_amount = previous.press_amount
		style.sync_content_offset()
	for state in STATES:
		button.add_theme_stylebox_override(state, style)
	button.set_meta(META_STYLE, style)
	if previous != null:
		return
	button.mouse_entered.connect(_animate.bind(button, "hover_amount", 1.0, UiPalette.DUR_HOVER))
	button.mouse_exited.connect(_animate.bind(button, "hover_amount", 0.0, UiPalette.DUR_HOVER))
	button.button_down.connect(_animate.bind(button, "press_amount", 1.0, UiPalette.DUR_PRESS))
	button.button_up.connect(_animate.bind(button, "press_amount", 0.0, UiPalette.DUR_PRESS))
	button.visibility_changed.connect(_reset.bind(button))


static func _animate(button: BaseButton, property: String, target: float, seconds: float) -> void:
	var style := _style(button)
	if style == null or not button.is_inside_tree():
		return
	if button.disabled and target > 0.0:
		return
	var key := META_HOVER_TWEEN if property == "hover_amount" else META_PRESS_TWEEN
	if button.has_meta(key):
		var running: Tween = button.get_meta(key)
		if running != null and running.is_valid():
			running.kill()
	var tween := button.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(_apply.bind(button, property), float(style.get(property)), target, seconds)
	button.set_meta(key, tween)


static func _apply(value: float, button: BaseButton, property: String) -> void:
	var style := _style(button)
	if style == null:
		return
	style.set(property, value)
	style.sync_content_offset()
	button.queue_redraw()


## 隠れた間に `mouse_exited` / `button_up` が届かないことがある(モーダルを閉じたとき)。量を戻しておく。
static func _reset(button: BaseButton) -> void:
	if button.is_visible_in_tree():
		return
	var style := _style(button)
	if style == null:
		return
	style.hover_amount = 0.0
	style.press_amount = 0.0
	style.sync_content_offset()


## `get_meta()` は既定値に null を渡しても、無いキーではエラーを出す。
static func _style(button: BaseButton) -> CodedButtonStyle:
	return button.get_meta(META_STYLE) if button.has_meta(META_STYLE) else null
