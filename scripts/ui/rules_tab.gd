class_name RulesTab
extends Control
## ホーム画面の「ルール」タブ(GameDesign.md 9章)。
##
## 入口は「遊び方」と「キーワード辞書」の2つ(GameDesign.md 16章・17章)。章の目次や
## 語の一覧はそれぞれの画面側にあり、ここへ並べると同じ一覧が2箇所に出て、
## どちらが本体か分からなくなるため、入口だけを置く。
## `DeckTab` / `BattleTab` と違い `.tscn` を持たず、`HomeScreen` がコードで生成する
## (`scenes/home_screen.tscn` を書き換えずに3つ目のタブを足すため)。

signal tutorial_requested
signal rules_requested
signal keyword_dict_requested

const OPEN_BUTTON_SIZE := Vector2(520, 136)
const CAPTION_SIZE := Vector2(720, 48)
const CAPTION_GAP := 14.0
const CAPTION_FONT_SIZE := 20
const OPEN_FONT_SIZE := 30
const DICT_BUTTON_SIZE := Vector2(360, 92)
const DICT_FONT_SIZE := 24
const CAPTION_TEXT := "砂時計の読み方から勝ち方まで、実際の盤面を動かしながら順に説明します。"
const DICT_CAPTION_TEXT := "守護・硝子・貫通といった語の意味と、その能力を持つ砂時計を引けます。"
## 誘導対局(GameDesign.md 18章)。**まだ遊んでいない間はいちばん大きく出す**。
## 読み物より先に、実際に手を指して覚えられることを示すため。終えたら他と同じ大きさへ下げる。
const TUTORIAL_BUTTON_SIZE := Vector2(520, 136)
const TUTORIAL_DONE_BUTTON_SIZE := Vector2(360, 92)
const TUTORIAL_CAPTION_TEXT := "実際に1局遊びながら、出す・ターンを終える・攻撃する・反転するを順に覚えます。"


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(CAPTION_GAP))
	center.add_child(column)

	var first_time := not UiState.has_done_tutorial()
	var tutorial_size := TUTORIAL_BUTTON_SIZE if first_time else TUTORIAL_DONE_BUTTON_SIZE
	var tutorial := CodedButton.make("1局遊んで覚える", tutorial_size)
	tutorial.add_theme_font_size_override(
		"font_size", OPEN_FONT_SIZE if first_time else DICT_FONT_SIZE
	)
	tutorial.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tutorial.pressed.connect(func() -> void: tutorial_requested.emit())
	column.add_child(tutorial)
	column.add_child(_make_caption(TUTORIAL_CAPTION_TEXT))

	var read_size := DICT_BUTTON_SIZE if first_time else OPEN_BUTTON_SIZE
	var button := CodedButton.make("遊び方を読む", read_size)
	button.add_theme_font_size_override(
		"font_size", DICT_FONT_SIZE if first_time else OPEN_FONT_SIZE
	)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void: rules_requested.emit())
	column.add_child(button)

	column.add_child(_make_caption(CAPTION_TEXT))

	var dict_button := CodedButton.make("キーワード辞書", DICT_BUTTON_SIZE)
	dict_button.add_theme_font_size_override("font_size", DICT_FONT_SIZE)
	dict_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dict_button.pressed.connect(func() -> void: keyword_dict_requested.emit())
	column.add_child(dict_button)

	column.add_child(_make_caption(DICT_CAPTION_TEXT))


func _make_caption(text: String) -> Label:
	var caption := Label.new()
	caption.text = text
	caption.custom_minimum_size = CAPTION_SIZE
	caption.add_theme_font_size_override("font_size", CAPTION_FONT_SIZE)
	caption.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return caption
