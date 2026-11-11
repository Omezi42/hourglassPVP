class_name SettingsPanel
extends Control

## ホーム画面のメニュー(ハンバーガー)モーダル。ResultOverlay/SurrenderConfirm
## (match_screen)と同じ「暗幕+中央パネル」パターンを踏襲する。
## 効果音とBGMは別々に調整できる(BGMだけ切って操作音は残す、という遊び方のため)。
## 音量の下には公式の窓口(Discord / X / YouTube)への導線を置く。設定と外部リンクは性質が違うが、
## 「ホーム画面の右上から開く1つの引き出し」へまとめたほうが、画面上のボタンを
## 増やさずに済む(9章のレイアウト規約はヘッダーへ主アクションを3つまでしか置かない)。

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
## 文字の大きさ「標準 / 大」(GameDesign.md 9章)。並びは `TextSize.is_large()` の false / true の順。
const TEXT_SIZE_LABELS := ["標準", "大"]
const TEXT_SIZE_BUTTON_SIZE := Vector2(110, 56)
const ROW_CAPTION_FONT := UiPalette.T_LEAD
const DIM_ALPHA := 0.6
const SELECTED_GROUP := CodedButton.PRIMARY_ACTION_GROUP
const UNSELECTED_GROUP := "wide_text"

var _text_size_buttons: Array[Button] = []

@onready var dim: ColorRect = $Dim
@onready var sfx_slider: HSlider = $CenterBox/Panel/Margin/VBox/SfxRow/Slider
@onready var sfx_value_label: Label = $CenterBox/Panel/Margin/VBox/SfxRow/ValueLabel
@onready var bgm_slider: HSlider = $CenterBox/Panel/Margin/VBox/BgmRow/Slider
@onready var bgm_value_label: Label = $CenterBox/Panel/Margin/VBox/BgmRow/ValueLabel
@onready var close_button: Button = $CenterBox/Panel/Margin/VBox/CloseButton
@onready var title_label: Label = $CenterBox/Panel/Margin/VBox/TitleLabel


func _ready() -> void:
	visible = false
	dim.color = Color(UiPalette.INK_900, DIM_ALPHA)
	title_label.add_theme_color_override("font_color", UiPalette.GOLD)
	title_label.add_theme_font_size_override("font_size", UiPalette.T_HEAD)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_build_text_size_row()
	_build_link_row()
	_sync_from_settings()
	sfx_slider.value_changed.connect(_on_sfx_changed)
	bgm_slider.value_changed.connect(_on_bgm_changed)
	close_button.pressed.connect(close)
	PortraitModal.watch(self, _fit)
	EscClose.attach(self, close)


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


## 音量の下に「文字の大きさ 標準 / 大」を挿す。窓口の列と同じくボタンの面をコードで決めるため、シーンに持たない。
func _build_text_size_row() -> void:
	var vbox := close_button.get_parent() as VBoxContainer
	if vbox == null:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", LINK_ROW_SEPARATION)
	var caption := Label.new()
	caption.text = "文字の大きさ"
	caption.add_theme_font_size_override("font_size", ROW_CAPTION_FONT)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(caption)
	for i in TEXT_SIZE_LABELS.size():
		var button := CodedButton.make(TEXT_SIZE_LABELS[i], TEXT_SIZE_BUTTON_SIZE)
		button.pressed.connect(_on_text_size_pressed.bind(i == 1))
		row.add_child(button)
		_text_size_buttons.append(button)
	vbox.add_child(row)
	vbox.move_child(row, close_button.get_index())


func _on_text_size_pressed(large: bool) -> void:
	TextSize.set_large(large)
	_refresh_text_size_buttons()


func _refresh_text_size_buttons() -> void:
	for i in _text_size_buttons.size():
		var active: bool = (i == 1) == TextSize.is_large()
		CodedButton.apply_styles(
			_text_size_buttons[i], SELECTED_GROUP if active else UNSELECTED_GROUP
		)


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
	_refresh_text_size_buttons()


func _refresh_value_labels() -> void:
	sfx_value_label.text = "%d%%" % roundi(sfx_slider.value)
	bgm_value_label.text = "%d%%" % roundi(bgm_slider.value)
