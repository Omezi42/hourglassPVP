class_name CodedButton
extends RefCounted
## v5.0の画面がコードで組み立てるボタンの生成をここへ集める。
## 各画面が個別に `theme_override` を並べると、文字色やスタイルの指定が抜けた
## ボタンが混ざる(実際に「真鍮のボタンの上でテーマ既定の暗い文字色が沈む」不具合が出た)。

const STYLE_PATH := "res://resources/theme/buttons/img_%s_%s.tres"
const WIDE_GROUP := "wide_text"
const ICON_GROUP := "icon_square"
## 塗りつぶした真鍮の面(額縁と地続き)。凹んだパネル(WIDE_GROUP)と並べて使う
## 「もっとも頻繁に押す主要な操作」向けの第2の面。
const PRIMARY_ACTION_GROUP := "primary_action"
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
## 無効の文字は面と同じ規則(`disabled_tone`)で沈める。テーマ既定の無効色は明るい StyleBoxFlat 向けの
## 暗い茶色で、暗く沈めた真鍮の面の上ではほぼ同じ明るさになり文字だけが消える。
static func apply_styles(button: Button, group: String) -> void:
	for state in STATES:
		var style: StyleBox = load(STYLE_PATH % [group, state])
		if style != null:
			button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override(
		"font_disabled_color", UiPaint.disabled_tone(UiPalette.TEXT_OFFWHITE)
	)


static func _build(label: String, button_size: Vector2, group: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = button_size
	button.size = button_size
	apply_styles(button, group)
	button.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_pressed_color", UiPalette.BRASS_HIGHLIGHT)
	return button
