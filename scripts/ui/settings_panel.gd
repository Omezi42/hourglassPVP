class_name SettingsPanel
extends Control

## ホーム画面のメニュー(ハンバーガー)モーダル。ResultOverlay/SurrenderConfirm
## (match_screen)と同じ「暗幕+中央パネル」パターンを踏襲する。
## 効果音とBGMは別々に調整できる(BGMだけ切って操作音は残す、という遊び方のため)。
## 音量の下には公式の窓口(Discord / X / YouTube)への導線を置く。設定と外部リンクは性質が違うが、
## 「ホーム画面の右上から開く1つの引き出し」へまとめたほうが、画面上のボタンを
## 増やさずに済む(9章のレイアウト規約はヘッダーへ主アクションを3つまでしか置かない)。
## 音量の上には「遊び方」(本の紋章)を置き、ルールを読む・覚える入口(`LearnMenu`)を開く。

## 「遊び方」を押した(GameDesign.md 9章)。開くのはホーム画面(`HomeScreen`)。
signal learn_requested

## 公式の窓口(GameDesign.md 9章)。左から順に並べる。
## Discordは11章の募集通知と同じサーバー。
const OFFICIAL_LINKS := [
	{
		"group": "icon_discord",
		"tooltip": "公式Discordサーバー",
		"url": "https://discord.gg/5dprcdtyQS",
	},
	{
		"group": "icon_x",
		"tooltip": "公式X",
		"url": "https://x.com/sunadokei_arena",
	},
	{
		"group": "icon_youtube",
		"tooltip": "公式YouTubeチャンネル",
		"url": "https://www.youtube.com/channel/UCl9x379YCy7HsSncs006oWg",
	},
]
const LINK_BUTTON_SIZE := Vector2(88, 88)
const LINK_ROW_SEPARATION := 22
const LEARN_BUTTON_SIZE := Vector2(376, 64)
const LEARN_ICON := preload("res://assets/hourglasses/emblems/page.png")
const LEARN_ICON_SIZE := 36

@onready var dim: ColorRect = $Dim
@onready var sfx_slider: HSlider = $CenterBox/Panel/Margin/VBox/SfxRow/Slider
@onready var sfx_value_label: Label = $CenterBox/Panel/Margin/VBox/SfxRow/ValueLabel
@onready var bgm_slider: HSlider = $CenterBox/Panel/Margin/VBox/BgmRow/Slider
@onready var bgm_value_label: Label = $CenterBox/Panel/Margin/VBox/BgmRow/ValueLabel
@onready var close_button: Button = $CenterBox/Panel/Margin/VBox/CloseButton


func _ready() -> void:
	visible = false
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_build_link_row()
	_build_learn_button()
	_sync_from_settings()
	sfx_slider.value_changed.connect(_on_sfx_changed)
	bgm_slider.value_changed.connect(_on_bgm_changed)
	close_button.pressed.connect(close)
	PortraitModal.watch(self, _fit)


## 窓口への導線はコードで組み立てて音量の下へ挿す(.tscn のパッチは値がJSONのため
## StyleBoxの差し替えができず、紋章つきのボタンをシーン側に持てない)。
## **文言を持たない正方形のアイコンボタン**を横1列に並べる。開く相手を説明する言葉より
## マークそのもののほうが速く読めるうえ、項目が増えても同じ形で並べられる。
func _build_link_row() -> void:
	var vbox := close_button.get_parent() as VBoxContainer
	if vbox == null:
		return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", LINK_ROW_SEPARATION)
	for link: Dictionary in OFFICIAL_LINKS:
		var button := CodedButton.make_in_group("", LINK_BUTTON_SIZE, link["group"])
		button.tooltip_text = link["tooltip"]
		button.pressed.connect(OS.shell_open.bind(link["url"]))
		row.add_child(button)
	vbox.add_child(row)
	vbox.move_child(row, close_button.get_index())


## 「遊び方」はタイトルのすぐ下(音量より上)へ挿す。ルールの入口はホームから外したため、
## メニューを開いた人がまず目にする位置に置く。
func _build_learn_button() -> void:
	var vbox := close_button.get_parent() as VBoxContainer
	if vbox == null:
		return
	var button := CodedButton.make("遊び方", LEARN_BUTTON_SIZE)
	button.icon = LEARN_ICON
	button.expand_icon = false
	button.add_theme_constant_override("icon_max_width", LEARN_ICON_SIZE)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void: learn_requested.emit())
	vbox.add_child(button)
	vbox.move_child(button, $CenterBox/Panel/Margin/VBox/TitleLabel.get_index() + 1)


func open() -> void:
	_sync_from_settings()
	_fit()
	visible = true


func _fit() -> void:
	PortraitModal.fit($CenterBox)


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
