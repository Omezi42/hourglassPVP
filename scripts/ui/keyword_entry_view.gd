class_name KeywordEntryView
extends VBoxContainer
## キーワード辞書の1語ぶんの表示(GameDesign.md 17章)。
## 語 / 説明 / 実演 / その語を持つ砂時計 の4つを縦に積む。
##
## **辞書画面の右カラムと、詳細パネルから開くポップの両方がこれを使う。**
## 同じ語を2箇所で別々に組み立てると、片方だけ内容が古くなるため。

const SPACING := 12
const TITLE_FONT_SIZE := 28
const BODY_FONT_SIZE := 16
const CAPTION_FONT_SIZE := 15
const PREVIEW_HEIGHT := 186.0
## 実演の幅。横いっぱいに伸ばすと駒が広い枠の中央へ小さく浮いて読みにくい。
const PREVIEW_WIDTH := 520.0
const CARD_SIZE := Vector2(96, 128)
const EMPTY_TEXT := "まだこの能力を持つ砂時計はありません。"

var _title: Label
var _category: Label
var _body: Label
var _preview: CardEffectPreview
var _cards_caption: Label
var _cards_row: HBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", SPACING)
	_build()


func show_entry(entry: Dictionary) -> void:
	_title.text = KeywordEntries.title(entry)
	_category.text = KeywordEntries.category(entry)
	_body.text = KeywordEntries.description(entry)

	var demo := KeywordEntries.demo(entry)
	_preview.visible = demo >= 0
	if demo >= 0:
		_preview.show_demo(demo)
	else:
		_preview.clear()

	var cards := KeywordEntries.cards_with(entry)
	_cards_caption.text = (EMPTY_TEXT if cards.is_empty() else "この能力を持つ砂時計(%d種)" % cards.size())
	for child in _cards_row.get_children():
		child.queue_free()
	for card in cards:
		var view := CardView.new()
		view.mode = CardView.Mode.HAND
		view.show_card(card, true)
		view.custom_minimum_size = CARD_SIZE
		# 辞書の中でカードを選ぶ導線は持たないため、押しても何も起きない。
		_cards_row.add_child(view)


func _build() -> void:
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	add_child(title_row)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(_title)

	_category = Label.new()
	_category.add_theme_font_size_override("font_size", CAPTION_FONT_SIZE)
	_category.add_theme_color_override("font_color", UiPalette.GLOW_AMBER)
	_category.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(_category)

	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	_body.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	add_child(_body)

	_preview = CardEffectPreview.new()
	_preview.custom_minimum_size = Vector2(PREVIEW_WIDTH, PREVIEW_HEIGHT)
	_preview.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(_preview)

	_cards_caption = Label.new()
	_cards_caption.add_theme_font_size_override("font_size", CAPTION_FONT_SIZE)
	_cards_caption.add_theme_color_override("font_color", UiPalette.GLOW_AMBER)
	add_child(_cards_caption)

	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, CARD_SIZE.y + 12.0)
	add_child(scroll)
	_cards_row = HBoxContainer.new()
	_cards_row.add_theme_constant_override("separation", 10)
	scroll.add_child(_cards_row)
