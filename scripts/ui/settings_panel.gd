class_name SettingsPanel
extends Control

## ホーム画面のメニュー(ハンバーガー)モーダル。ResultOverlay/SurrenderConfirm
## (match_screen)と同じ「暗幕+中央パネル」パターンを踏襲する。
## 効果音とBGMは別々に調整できる(BGMだけ切って操作音は残す、という遊び方のため)。
## 音量の下には公式Discordサーバーへの導線を置く。設定と外部リンクは性質が違うが、
## 「ホーム画面の右上から開く1つの引き出し」へまとめたほうが、画面上のボタンを
## 増やさずに済む(9章のレイアウト規約はヘッダーへ主アクションを3つまでしか置かない)。

## 公式Discordサーバー(GameDesign.md 11章の募集通知と同じサーバー)。
const DISCORD_INVITE_URL := "https://discord.gg/5dprcdtyQS"
const DISCORD_BUTTON_GROUP := "discord_link"
const DISCORD_BUTTON_SIZE := Vector2(300, 68)

var _discord_button: Button

@onready var dim: ColorRect = $Dim
@onready var sfx_slider: HSlider = $CenterBox/Panel/Margin/VBox/SfxRow/Slider
@onready var sfx_value_label: Label = $CenterBox/Panel/Margin/VBox/SfxRow/ValueLabel
@onready var bgm_slider: HSlider = $CenterBox/Panel/Margin/VBox/BgmRow/Slider
@onready var bgm_value_label: Label = $CenterBox/Panel/Margin/VBox/BgmRow/ValueLabel
@onready var close_button: Button = $CenterBox/Panel/Margin/VBox/CloseButton


func _ready() -> void:
	visible = false
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_build_discord_button()
	_sync_from_settings()
	sfx_slider.value_changed.connect(_on_sfx_changed)
	bgm_slider.value_changed.connect(_on_bgm_changed)
	close_button.pressed.connect(close)


## Discordへの導線はコードで組み立てて音量の下へ挿す(.tscn のパッチは値がJSONのため
## StyleBoxの差し替えができず、紋章つきのボタンをシーン側に持てない)。
func _build_discord_button() -> void:
	var vbox := close_button.get_parent() as VBoxContainer
	if vbox == null:
		return
	_discord_button = CodedButton.make_in_group(
		"公式Discordサーバー", DISCORD_BUTTON_SIZE, DISCORD_BUTTON_GROUP
	)
	_discord_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_discord_button.tooltip_text = DISCORD_INVITE_URL
	_discord_button.pressed.connect(_on_discord_pressed)
	vbox.add_child(_discord_button)
	vbox.move_child(_discord_button, close_button.get_index())


func _on_discord_pressed() -> void:
	OS.shell_open(DISCORD_INVITE_URL)


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
