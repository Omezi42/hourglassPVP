class_name RulesTab
extends Control
## ホーム画面の「ルール」タブ(GameDesign.md 9章)。
##
## 入口は「1局遊んで覚える」「遊び方」「キーワード辞書」の3つ(GameDesign.md 16章〜18章)。
## 章の目次や語の一覧はそれぞれの画面側にあり、ここへ並べると同じ一覧が2箇所に出て、
## どちらが本体か分からなくなるため、入口だけを置く。
## `DeckTab` / `BattleTab` と違い `.tscn` を持たず、`HomeScreen` がコードで生成する
## (`scenes/home_screen.tscn` を書き換えずに3つ目のタブを足すため)。
##
## **入口は「ボタン + その右の説明」の横並び1行**とする。以前は説明をボタンの下へ
## 積んでいたが、3つ分を縦に積むとタブの高さ(下部タブとアカウント帯に挟まれた
## 448px)を超え、先頭のボタンが画面の外へはみ出していた。

signal tutorial_requested
signal rules_requested
signal keyword_dict_requested

## アカウント帯(ホーム画面のヘッダー)を避ける上端。`DeckTab` と同じ値。
const TOP_BAND := 112.0
const ROW_SEPARATION := 20
const BUTTON_SIZE := Vector2(300, 84)
## 誘導対局(GameDesign.md 18章)。**まだ遊んでいない間はいちばん大きく出す**。
## 読み物より先に、実際に手を指して覚えられることを示すため。終えたら他と同じ大きさへ下げる。
const TUTORIAL_BUTTON_SIZE := Vector2(360, 112)
const BUTTON_FONT_SIZE := 24
const TUTORIAL_FONT_SIZE := 28
const CAPTION_WIDTH := 460.0
const CAPTION_FONT_SIZE := 18
const ROW_GAP := 24

const CAPTION_TEXT := "砂時計の読み方から勝ち方まで、実際の盤面を動かしながら順に説明します。"
const DICT_CAPTION_TEXT := "守護・硝子・貫通といった語の意味と、その能力を持つ砂時計を引けます。"
const TUTORIAL_CAPTION_TEXT := "実際に1局遊びながら、出す・ターンを終える・攻撃する・反転するを順に覚えます。"


func _ready() -> void:
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.offset_top = TOP_BAND
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", ROW_SEPARATION)
	center.add_child(column)

	var first_time := not UiState.has_done_tutorial()
	column.add_child(
		_make_row(
			"1局遊んで覚える",
			TUTORIAL_CAPTION_TEXT,
			TUTORIAL_BUTTON_SIZE if first_time else BUTTON_SIZE,
			TUTORIAL_FONT_SIZE if first_time else BUTTON_FONT_SIZE,
			func() -> void: tutorial_requested.emit()
		)
	)
	column.add_child(
		_make_row(
			"遊び方を読む",
			CAPTION_TEXT,
			BUTTON_SIZE,
			BUTTON_FONT_SIZE,
			func() -> void: rules_requested.emit()
		)
	)
	column.add_child(
		_make_row(
			"キーワード辞書",
			DICT_CAPTION_TEXT,
			BUTTON_SIZE,
			BUTTON_FONT_SIZE,
			func() -> void: keyword_dict_requested.emit()
		)
	)


## 1つの入口(ボタン + その右の説明)を組む。ボタンの幅は行ごとに変わるため、
## 説明の左端を揃えるようボタン側の枠を最大幅で固定する。
func _make_row(
	label: String, caption: String, button_size: Vector2, font_size: int, on_pressed: Callable
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_GAP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(TUTORIAL_BUTTON_SIZE.x, button_size.y)
	var button := CodedButton.make(label, button_size)
	button.add_theme_font_size_override("font_size", font_size)
	button.pressed.connect(on_pressed)
	holder.add_child(button)
	row.add_child(holder)

	var text := Label.new()
	text.text = caption
	text.custom_minimum_size = Vector2(CAPTION_WIDTH, 0)
	text.add_theme_font_size_override("font_size", CAPTION_FONT_SIZE)
	text.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	return row
