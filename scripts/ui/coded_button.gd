class_name CodedButton
extends RefCounted
## v5.0の画面がコードで組み立てるボタンの生成をここへ集める。
## 各画面が個別に `theme_override` を並べると、文字色やスタイルの指定が抜けた
## ボタンが混ざる(実際に「真鍮のボタンの上でテーマ既定の暗い文字色が沈む」不具合が出た)。

const WIDE_STYLES := "res://resources/theme/buttons/img_wide_text_%s.tres"
const ICON_STYLES := "res://resources/theme/buttons/img_icon_square_%s.tres"
const STATES: Array[String] = ["normal", "hover", "pressed", "disabled"]


## 横長のテキストボタン。
static func make(label: String, button_size: Vector2) -> Button:
	return _build(label, button_size, WIDE_STYLES)


## 一覧の行などに置く小さな正方形のボタン。横長の画像は潰れるため別グループを使う。
static func make_icon(label: String, button_size: Vector2) -> Button:
	return _build(label, button_size, ICON_STYLES)


static func _build(label: String, button_size: Vector2, styles: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = button_size
	button.size = button_size
	for state in STATES:
		var style: StyleBox = load(styles % state)
		if style != null:
			button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_pressed_color", UiPalette.BRASS_HIGHLIGHT)
	return button
