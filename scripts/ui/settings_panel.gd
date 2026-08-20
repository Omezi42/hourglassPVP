class_name SettingsPanel
extends Control

## 音量調整モーダル。ResultOverlay/SurrenderConfirm(match_screen)と同じ
## 「暗幕+中央パネル」パターンを踏襲する。
## 効果音とBGMは別々に調整できる(BGMだけ切って操作音は残す、という遊び方のため)。

@onready var dim: ColorRect = $Dim
@onready var sfx_slider: HSlider = $CenterBox/Panel/Margin/VBox/SfxRow/Slider
@onready var sfx_value_label: Label = $CenterBox/Panel/Margin/VBox/SfxRow/ValueLabel
@onready var bgm_slider: HSlider = $CenterBox/Panel/Margin/VBox/BgmRow/Slider
@onready var bgm_value_label: Label = $CenterBox/Panel/Margin/VBox/BgmRow/ValueLabel
@onready var close_button: Button = $CenterBox/Panel/Margin/VBox/CloseButton


func _ready() -> void:
	visible = false
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_sync_from_settings()
	sfx_slider.value_changed.connect(_on_sfx_changed)
	bgm_slider.value_changed.connect(_on_bgm_changed)
	close_button.pressed.connect(close)


func open() -> void:
	_sync_from_settings()
	visible = true


func close() -> void:
	visible = false


func _on_sfx_changed(value: float) -> void:
	SoundBank.set_sfx_volume(value / 100.0)
	_refresh_value_labels()


func _on_bgm_changed(value: float) -> void:
	SoundBank.set_bgm_volume(value / 100.0)
	_refresh_value_labels()


func _sync_from_settings() -> void:
	sfx_slider.value = roundi(SoundBank.get_sfx_volume() * 100.0)
	bgm_slider.value = roundi(SoundBank.get_bgm_volume() * 100.0)
	_refresh_value_labels()


func _refresh_value_labels() -> void:
	sfx_value_label.text = "%d%%" % roundi(sfx_slider.value)
	bgm_value_label.text = "%d%%" % roundi(bgm_slider.value)
