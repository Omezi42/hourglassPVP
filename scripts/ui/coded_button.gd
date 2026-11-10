class_name CodedButton
extends RefCounted
## v5.0の画面がコードで組み立てるボタンの生成をここへ集める。
## 各画面が個別に `theme_override` を並べると、文字色やスタイルの指定が抜けた
## ボタンが混ざる(実際に「真鍮のボタンの上でテーマ既定の暗い文字色が沈む」不具合が出た)。

const STYLE_PATH := "res://resources/theme/buttons/img_%s_%s.tres"
const WIDE_GROUP := "wide_text"
const ICON_GROUP := "icon_square"
## 真鍮の面。その画面でいちばん押してほしい操作と、選ばれているタブ。
const PRIMARY_ACTION_GROUP := "primary_action"
## 硝子に赤い縁。削除・投了など取り返せない操作。
const DANGER_GROUP := "danger_text"
const STATES: Array[String] = ["normal", "hover", "pressed", "disabled"]


## 横長のテキストボタン。
static func make(label: String, button_size: Vector2) -> Button:
	return _build(label, button_size, WIDE_GROUP)


## 一覧の行などに置く小さな正方形のボタン。横長の画像は潰れるため別グループを使う。
static func make_icon(label: String, button_size: Vector2) -> Button:
	return _build(label, button_size, ICON_GROUP)


## 紋章つきなど、グループを指定して作るボタン(公式Discordへの導線・メニューなど)。
static func make_in_group(label: String, button_size: Vector2, group: String) -> Button:
	return _build(label, button_size, group)


## 既に .tscn に置かれているボタンのスタイルだけを差し替える。StyleBoxはリソース参照の
## ため .tscn のパッチ(値がJSON)では差し替えられず、ここを通す必要がある。
## 字の色は面の役割で決める(真鍮の面 = 彫った暗い字 / 硝子の面 = 象牙 / 赤い縁 = 明るい赤)。
## 押せない字は沈めた灰にする(面は変えない。GameDesign.md 9章)。
static func apply_styles(button: Button, group: String) -> void:
	var base: StyleBox = load(STYLE_PATH % [group, STATES[0]])
	if base is CodedButtonStyle:
		ButtonFeel.attach(button, base)
		_apply_font_colors(button, base)
	else:
		for state in STATES:
			var style: StyleBox = load(STYLE_PATH % [group, state])
			if style != null:
				button.add_theme_stylebox_override(state, style)
	# 押せるときだけ指カーソルにする(GameDesign.md 9章「クリックできる要素は共通の挙動」)。
	# `disabled` には変更の信号が無いため、乗った瞬間に決め直す。
	_update_cursor(button)
	var update := _update_cursor.bind(button)
	if not button.mouse_entered.is_connected(update):
		button.mouse_entered.connect(update)


static func _apply_font_colors(button: Button, style: CodedButtonStyle) -> void:
	var normal := UiPalette.IVORY
	var lit := Color.WHITE
	if style.filled:
		normal = UiPalette.BRASS_INK
		lit = UiPalette.BRASS_INK
	elif style.danger:
		normal = UiPalette.DANGER_TEXT
	button.add_theme_color_override("font_color", normal)
	button.add_theme_color_override("font_hover_color", lit)
	button.add_theme_color_override("font_pressed_color", lit)
	button.add_theme_color_override("font_hover_pressed_color", lit)
	button.add_theme_color_override("font_focus_color", normal)
	button.add_theme_color_override("font_disabled_color", UiPalette.FAINT)


static func _update_cursor(button: Button) -> void:
	button.mouse_default_cursor_shape = (
		Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND
	)


static func _build(label: String, button_size: Vector2, group: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = button_size
	button.size = button_size
	apply_styles(button, group)
	return button
