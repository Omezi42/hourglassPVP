class_name RulesTab
extends Control
## ホーム画面の「ルール」タブ(GameDesign.md 9章)。
##
## 入口を1つ持つだけにしてある。章の目次は `RuleScreen` 側にあり、ここへ並べると
## 同じ一覧が2箇所に出て、どちらが本体か分からなくなるため。
## `DeckTab` / `BattleTab` と違い `.tscn` を持たず、`HomeScreen` がコードで生成する
## (`scenes/home_screen.tscn` を書き換えずに3つ目のタブを足すため)。

signal rules_requested

const OPEN_BUTTON_SIZE := Vector2(520, 180)
const CAPTION_SIZE := Vector2(720, 72)
const CAPTION_GAP := 28.0
const CAPTION_FONT_SIZE := 20
const OPEN_FONT_SIZE := 30
const CAPTION_TEXT := "砂時計の読み方から勝ち方まで、実際の盤面を動かしながら順に説明します。"


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(CAPTION_GAP))
	center.add_child(column)

	var button := CodedButton.make("遊び方を読む", OPEN_BUTTON_SIZE)
	button.add_theme_font_size_override("font_size", OPEN_FONT_SIZE)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void: rules_requested.emit())
	column.add_child(button)

	var caption := Label.new()
	caption.text = CAPTION_TEXT
	caption.custom_minimum_size = CAPTION_SIZE
	caption.add_theme_font_size_override("font_size", CAPTION_FONT_SIZE)
	caption.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(caption)
