class_name ConfirmModal
extends Control

## 汎用モーダル。SettingsPanel/SurrenderConfirmと同じ「暗幕+content_panel.tres」パターンで、
## 「通知(OKのみ)」「確認(はい/いいえ)」の両方をカバーする共通コンポーネント。

signal confirmed
signal cancelled

const DIM_ALPHA := 0.6
## 縦(パネルごと拡大)で2つのボタンが画面の幅に収まる大きさ。
const PORTRAIT_BUTTON_SIZE := Vector2(168, 60)

var _button_size := Vector2.ZERO

@onready var dim: ColorRect = $Dim
@onready var title_label: Label = $CenterBox/Panel/Margin/VBox/TitleLabel
@onready var detail_label: Label = $CenterBox/Panel/Margin/VBox/DetailLabel
@onready var cancel_button: Button = $CenterBox/Panel/Margin/VBox/ButtonRow/CancelButton
@onready var confirm_button: Button = $CenterBox/Panel/Margin/VBox/ButtonRow/ConfirmButton


func _ready() -> void:
	visible = false
	dim.color = Color(UiPalette.INK_900, DIM_ALPHA)
	title_label.add_theme_color_override("font_color", UiPalette.GOLD)
	title_label.add_theme_font_size_override("font_size", UiPalette.T_HEAD)
	detail_label.add_theme_font_size_override("font_size", UiPalette.T_LEAD)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_button_size = confirm_button.custom_minimum_size
	cancel_button.pressed.connect(_on_cancel_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	PortraitModal.watch(self, _cover_viewport)
	EscClose.attach(self, _on_escape)


## OKのみの通知として表示する。
func open_notice(title: String, message: String, ok_text: String = "OK") -> void:
	title_label.text = title
	detail_label.text = message
	cancel_button.visible = false
	_set_confirm_style(ok_text, false)
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
	_set_confirm_style(confirm_text, danger)
	_cover_viewport()
	visible = true


## 暗幕を**画面全体**へ広げる。このモーダルは画面より小さい親の中に置かれることがあり、
## 親のまま伸ばすと画面の一部だけ暗幕が掛からず、そこだけ押せるように見える。親の位置を打ち消して画面と同じ矩形にする。
func _cover_viewport() -> void:
	var parent := get_parent() as Control
	anchor_right = 0.0
	anchor_bottom = 0.0
	position = Vector2.ZERO if parent == null else -parent.global_position
	size = get_viewport_rect().size
	var button_size := PORTRAIT_BUTTON_SIZE if ScreenOrientation.is_portrait() else _button_size
	cancel_button.custom_minimum_size = button_size
	confirm_button.custom_minimum_size = button_size
	PortraitModal.fit($CenterBox)


func close() -> void:
	visible = false


## 取り返せない操作(danger)は硝子に赤い縁のボタンにする。
func _set_confirm_style(text: String, danger: bool) -> void:
	confirm_button.text = text
	CodedButton.apply_styles(
		confirm_button, CodedButton.DANGER_GROUP if danger else CodedButton.WIDE_GROUP
	)


## Escは「キャンセル」と同じ。OKだけの通知はEscで閉じない(押して読んだことにしないため)。
func _on_escape() -> void:
	if cancel_button.visible:
		_on_cancel_pressed()


func _on_cancel_pressed() -> void:
	close()
	cancelled.emit()


func _on_confirm_pressed() -> void:
	close()
	confirmed.emit()
