class_name KeywordEntryView
extends VBoxContainer
## キーワード辞書の1語ぶんの表示(GameDesign.md 17章)。
## 語 / 説明 / 実演 / その語を持つ砂時計 の4つを縦に積む。
##
## **辞書画面の右カラムと、詳細パネルから開くポップの両方がこれを使う。**
## 同じ語を2箇所で別々に組み立てると、片方だけ内容が古くなるため。

## 組ごとの間隔は、この既定(語の題 → 説明 / 件数の見出し → 札の行)へ余白を足して決める。
const SPACING := 8
const TITLE_GAP := 12
## 実演の上下に足す余白。説明 → 実演は SPACING + 4 = 12、実演 → 件数の見出しは SPACING + 8 = 16。
const PREVIEW_PAD_TOP := 4
const PREVIEW_PAD_BOTTOM := 8
## 札の行の下の、横スクロールの帯のぶんの余白。
const CARDS_SCROLL_PAD := 8.0
const TITLE_FONT_SIZE := UiPalette.T_HEAD
const BODY_FONT_SIZE := UiPalette.T_BODY
const CAPTION_FONT_SIZE := UiPalette.T_BODY
const PREVIEW_HEIGHT := 186.0
## 実演の幅。横いっぱいに伸ばすと駒が広い枠の中央へ小さく浮いて読みにくい。
const PREVIEW_WIDTH := 520.0
## 手札のカードは**基準の大きさのまま並べる**。小さくすると名前とキーワードの行が
## コストと総量のバッジへ寄って読めなくなる(実際に「攻撃不可 守護」が総量へ潜っていた)。
## 幅が足りないぶんは、この列がもともと持っている横スクロールで受ける。
const CARD_SIZE := CardView.HAND_SIZE_PX
const EMPTY_TEXT := "まだこの能力を持つ砂時計はありません。"

var _title: Label
var _category: Label
var _body: Label
var _preview: CardEffectPreview
var _preview_box: MarginContainer
var _cards_caption: Label
var _cards_row: HBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", SPACING)
	_build()


## 実演の幅と文字の大きさを決め直す。縦のポップは細く組んで中身ごと拡大し(`KeywordPopup`)、
## 縦の辞書は画面の幅のまま文字を大きくする(`KeywordDictScreen`)。
func set_layout(
	preview_width: float,
	body_font: int,
	caption_font := CAPTION_FONT_SIZE,
	title_font := TITLE_FONT_SIZE
) -> void:
	_preview.custom_minimum_size.x = preview_width
	_body.add_theme_font_size_override("font_size", body_font)
	_title.add_theme_font_size_override("font_size", title_font)
	for label in [_category, _cards_caption]:
		label.add_theme_font_size_override("font_size", caption_font)


## `reveal` が真のときは、札の行を左から順に出す(辞書画面で語を選んだとき)。
func show_entry(entry: Dictionary, reveal := false) -> void:
	_title.text = KeywordEntries.title(entry)
	_category.text = KeywordEntries.category(entry)
	_body.text = KeywordEntries.description(entry)

	var demo := KeywordEntries.demo(entry)
	_preview_box.visible = not demo.is_empty()
	if demo.is_empty():
		_preview.clear()
	else:
		_preview.show_card(demo["card"], int(demo["kind"]))

	var cards := KeywordEntries.cards_with(entry)
	_cards_caption.text = (EMPTY_TEXT if cards.is_empty() else "この能力を持つ砂時計(%d種)" % cards.size())
	for child in _cards_row.get_children():
		_cards_row.remove_child(child)
		child.queue_free()
	for card in cards:
		var view := CardView.new()
		view.skin_viewer = CardSkins.Viewer.NONE
		view.mode = CardView.Mode.HAND
		view.show_card(card, true)
		view.custom_minimum_size = CARD_SIZE
		# 辞書の中でカードを選ぶ導線は持たないため、押しても何も起きない。
		_cards_row.add_child(view)
	if reveal:
		ListRevealFx.stagger(_cards_row.get_children())


func _build() -> void:
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", TITLE_GAP)
	add_child(title_row)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title.add_theme_color_override("font_color", UiPalette.IVORY)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(_title)

	_category = Label.new()
	_category.add_theme_font_size_override("font_size", CAPTION_FONT_SIZE)
	_category.add_theme_color_override("font_color", UiPalette.GOLD)
	_category.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(_category)

	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	_body.add_theme_color_override("font_color", UiPalette.IVORY)
	add_child(_body)

	_preview_box = MarginContainer.new()
	_preview_box.add_theme_constant_override("margin_top", PREVIEW_PAD_TOP)
	_preview_box.add_theme_constant_override("margin_bottom", PREVIEW_PAD_BOTTOM)
	add_child(_preview_box)
	_preview = CardEffectPreview.new()
	_preview.custom_minimum_size = Vector2(PREVIEW_WIDTH, PREVIEW_HEIGHT)
	_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_preview_box.add_child(_preview)

	_cards_caption = Label.new()
	_cards_caption.add_theme_font_size_override("font_size", CAPTION_FONT_SIZE)
	_cards_caption.add_theme_color_override("font_color", UiPalette.GOLD)
	add_child(_cards_caption)

	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, CARD_SIZE.y + CARDS_SCROLL_PAD)
	TouchScroll.enable(scroll)
	add_child(scroll)
	_cards_row = HBoxContainer.new()
	_cards_row.add_theme_constant_override("separation", 10)
	scroll.add_child(_cards_row)
