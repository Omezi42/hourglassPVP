class_name ConfirmModal
extends Control

## 汎用モーダル。SettingsPanel/SurrenderConfirmと同じ「暗幕+content_panel.tres」パターンで、
## 「通知(OKのみ)」「確認(はい/いいえ)」の両方をカバーする共通コンポーネント。

signal confirmed
signal cancelled

const DEFAULT_CONFIRM_COLOR := Color(0.96, 0.94, 0.89, 1)
const DANGER_CONFIRM_COLOR := Color(1, 0.45, 0.4, 1)

@onready var dim: ColorRect = $Dim
@onready var title_label: Label = $CenterBox/Panel/Margin/VBox/TitleLabel
@onready var detail_label: Label = $CenterBox/Panel/Margin/VBox/DetailLabel
@onready var cancel_button: Button = $CenterBox/Panel/Margin/VBox/ButtonRow/CancelButton
@onready var confirm_button: Button = $CenterBox/Panel/Margin/VBox/ButtonRow/ConfirmButton


func _ready() -> void:
	visible = false
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	cancel_button.pressed.connect(_on_cancel_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)


## OKのみの通知として表示する。
func open_notice(title: String, message: String, ok_text: String = "OK") -> void:
	title_label.text = title
	detail_label.text = message
	cancel_button.visible = false
	_set_confirm_style(ok_text, DEFAULT_CONFIRM_COLOR)
	_cover_viewport()
	visible = true


## はい/いいえの確認として表示する。danger=trueで確定ボタンを警告色にする。
func open_confirm(
	title: String,
	message: String,
	confirm_text: String = "OK",
	cancel_text: String = "キャンセル",
	danger: bool = false
) -> void:
	title_label.text = title
	detail_label.text = message
	cancel_button.visible = true
	cancel_button.text = cancel_text
	_set_confirm_style(confirm_text, DANGER_CONFIRM_COLOR if danger else DEFAULT_CONFIRM_COLOR)
	_cover_viewport()
	visible = true


## 暗幕を**画面全体**へ広げる。このモーダルはホーム画面のタブ(高さ560px)の中に
## 置かれることがあり、親のまま伸ばすと下部タブだけ暗幕が掛からず、そこだけ
## 押せるように見える。親の位置を打ち消して画面と同じ矩形にする。
func _cover_viewport() -> void:
	var parent := get_parent() as Control
	anchor_right = 0.0
	anchor_bottom = 0.0
	position = Vector2.ZERO if parent == null else -parent.global_position
	size = get_viewport_rect().size


func close() -> void:
	visible = false


func _set_confirm_style(text: String, color: Color) -> void:
	confirm_button.text = text
	confirm_button.add_theme_color_override("font_color", color)
	confirm_button.add_theme_color_override("font_pressed_color", color)
	confirm_button.add_theme_color_override("font_hover_color", color)


func _on_cancel_pressed() -> void:
	close()
	cancelled.emit()


func _on_confirm_pressed() -> void:
	close()
	confirmed.emit()
