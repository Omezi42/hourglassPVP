class_name SoloBundleOverlay
extends Control
## 遠征(ソロモード)の束のオーバーレイ(GameDesign.md 27章「画面」)。道を暗幕で覆い、
## 束(作戦ごとの3枚)から1つ選んで山札に足す(見送ってもよい)。右端に`SoloDeckList`で
## いまの山札を出し、何を足すか山札の中身を見て決められるようにする。

signal bundle_chosen(index: int)
signal skip_pressed

const TITLE_FONT_SIZE := 30
const SUBTITLE_FONT_SIZE := 16
const DIM_COLOR := Color(0, 0, 0, 0.72)
const TITLE_TOP := 70.0
const SUBTITLE_TOP := 118.0
const ROWS_TOP := 160.0
const ROWS_BOTTOM_MARGIN := 96.0
const ROW_GAP := 16.0
const ROW_NAME_WIDTH := 300.0
const ROW_PADDING := 24.0
const NAME_FONT_SIZE := 22
const SUMMARY_FONT_SIZE := 13
const TAG_TEXT := "◆ 作戦"
const TAG_COLOR := Color(0.9, 0.75, 0.4)
const CARD_GAP := 18.0
const CARD_SCALE_MAX := 1.0
const SKIP_SIZE := Vector2(200, 48)
## 右端の「いまの山札」欄(GameDesign.md 27章「画面」)。束の並びはこれを除いた
## 残りの幅で組む。
const DECK_PANEL_WIDTH := 280.0
const DECK_PANEL_MARGIN := 32.0
const DECK_PANEL_PADDING := 20.0
const DECK_LABEL_FONT_SIZE := 15

var _dim: ColorRect
var _title: Label
var _subtitle: Label
var _rows_box: Control
var _deck_panel_canvas: Control
var _deck_label: Label
var _deck_list: SoloDeckList
var _skip_button: Button
var _offer: Array[Dictionary] = []
var _theme_id := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.color = DIM_COLOR
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_title = _label(TITLE_FONT_SIZE, UiPalette.TEXT_OFFWHITE, true)
	add_child(_title)
	_subtitle = _label(SUBTITLE_FONT_SIZE, UiPalette.TEXT_MUTED)
	add_child(_subtitle)
	_rows_box = Control.new()
	_rows_box.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_rows_box)

	_deck_panel_canvas = Control.new()
	_deck_panel_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deck_panel_canvas.draw.connect(
		func() -> void:
			SoloUiPaint.paint_panel(
				_deck_panel_canvas.get_canvas_item(),
				Rect2(Vector2.ZERO, _deck_panel_canvas.size),
				false
			)
	)
	add_child(_deck_panel_canvas)
	_deck_label = _label(DECK_LABEL_FONT_SIZE, UiPalette.TEXT_MUTED)
	_deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_deck_label)
	_deck_list = SoloDeckList.new()
	add_child(_deck_list)

	_skip_button = CodedButton.make("見送る", SKIP_SIZE)
	_skip_button.pressed.connect(func() -> void: skip_pressed.emit())
	add_child(_skip_button)

	resized.connect(_layout)
	_layout()


## 束を出す。`win_count`は小見出しの「N戦目の勝利」、`deck_ids`は右端の「いまの山札」。
func show_data(
	offer: Array[Dictionary], win_count: int, deck_ids: Array[String], theme_id: String
) -> void:
	_offer = offer
	_theme_id = theme_id
	_title.text = "束を1つ選んで山札に足す"
	_subtitle.text = (
		"%d戦目の勝利 ・ 山札 %d枚 → %d枚"
		% [win_count, deck_ids.size(), deck_ids.size() + SoloRun.BUNDLE_CARDS]
	)
	_deck_label.text = "いまの山札 %d枚" % deck_ids.size()
	_deck_list.show_data(deck_ids)
	_layout()


func _rebuild_rows(theme_id: String) -> void:
	for child in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()
	if _offer.is_empty():
		return
	var rows_w := _rows_box.size.x
	var rows_h := _rows_box.size.y
	var count := _offer.size()
	var row_h := (rows_h - ROW_GAP * float(maxi(count - 1, 0))) / float(count)
	for i in count:
		var y := float(i) * (row_h + ROW_GAP)
		_build_row(Rect2(0, y, rows_w, row_h), _offer[i], theme_id, i)


func _build_row(rect: Rect2, bundle: Dictionary, theme_id: String, index: int) -> void:
	var is_own := str(bundle.get("theme", "")) == theme_id
	var canvas := Control.new()
	canvas.position = rect.position
	canvas.size = rect.size
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(
		func() -> void:
			SoloUiPaint.paint_panel(
				canvas.get_canvas_item(), Rect2(Vector2.ZERO, rect.size), is_own
			)
	)
	_rows_box.add_child(canvas)

	var name_label := _label(NAME_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.position = rect.position + Vector2(ROW_PADDING, ROW_PADDING - 4.0)
	name_label.size = Vector2(ROW_NAME_WIDTH - ROW_PADDING, 30.0)
	name_label.text = "%sの束" % CardCpuDecks.name_of(str(bundle.get("theme", "")))
	_rows_box.add_child(name_label)

	var summary_label := _label(SUMMARY_FONT_SIZE, UiPalette.TEXT_MUTED)
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.position = rect.position + Vector2(ROW_PADDING, ROW_PADDING + 30.0)
	summary_label.size = Vector2(ROW_NAME_WIDTH - ROW_PADDING, rect.size.y - ROW_PADDING - 44.0)
	summary_label.text = CardCpuDecks.summary_of(str(bundle.get("theme", "")))
	_rows_box.add_child(summary_label)

	if is_own:
		var tag := _label(13, TAG_COLOR)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		tag.position = rect.position + Vector2(ROW_PADDING, rect.size.y - ROW_PADDING - 18.0)
		tag.size = Vector2(200.0, 20.0)
		tag.text = TAG_TEXT
		_rows_box.add_child(tag)

	var cards: Array = bundle.get("cards", [])
	var card_h: float = minf(
		rect.size.y - ROW_PADDING * 2.0, CardView.HAND_SIZE_PX.y * CARD_SCALE_MAX
	)
	var scale: float = card_h / CardView.HAND_SIZE_PX.y
	var card_size := CardView.HAND_SIZE_PX * scale
	var cards_left := rect.position.x + ROW_NAME_WIDTH
	var cards_top := rect.position.y + (rect.size.y - card_size.y) * 0.5
	for k in cards.size():
		var view := CardView.new()
		view.mode = CardView.Mode.HAND
		view.position = Vector2(cards_left + float(k) * (card_size.x + CARD_GAP), cards_top)
		_rows_box.add_child(view)
		var card := CardLibrary.find_by_id(str(cards[k]))
		if card == null:
			continue
		view.show_card(card, true)
		view.size = card_size

	var button := SoloUiPaint.transparent_button()
	button.position = rect.position
	button.size = rect.size
	button.pressed.connect(func() -> void: bundle_chosen.emit(index))
	_rows_box.add_child(button)


func _layout() -> void:
	if _dim == null:
		return
	_dim.size = size
	var rows_w := size.x - DECK_PANEL_WIDTH - DECK_PANEL_MARGIN
	_title.position = Vector2(0, TITLE_TOP)
	_title.size = Vector2(rows_w, 44.0)
	_subtitle.position = Vector2(0, SUBTITLE_TOP)
	_subtitle.size = Vector2(rows_w, 26.0)
	_rows_box.position = Vector2(0, ROWS_TOP)
	_rows_box.size = Vector2(rows_w, size.y - ROWS_TOP - ROWS_BOTTOM_MARGIN)
	_rebuild_rows(_theme_id)
	var deck_rect := Rect2(
		size.x - DECK_PANEL_WIDTH, ROWS_TOP, DECK_PANEL_WIDTH, size.y - ROWS_TOP - ROWS_TOP * 0.3
	)
	_deck_panel_canvas.position = deck_rect.position
	_deck_panel_canvas.size = deck_rect.size
	_deck_label.position = deck_rect.position + Vector2(DECK_PANEL_PADDING, DECK_PANEL_PADDING)
	_deck_label.size = Vector2(deck_rect.size.x - DECK_PANEL_PADDING * 2.0, 22.0)
	var deck_list_top := deck_rect.position.y + DECK_PANEL_PADDING + 30.0
	_deck_list.position = Vector2(deck_rect.position.x + DECK_PANEL_PADDING, deck_list_top)
	_deck_list.size = Vector2(
		deck_rect.size.x - DECK_PANEL_PADDING * 2.0,
		deck_rect.end.y - DECK_PANEL_PADDING - deck_list_top
	)
	_skip_button.position = Vector2(
		deck_rect.position.x + (deck_rect.size.x - SKIP_SIZE.x) * 0.5, deck_rect.end.y + 12.0
	)


func _label(font_size: int, color: Color, display := false) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if display:
		label.add_theme_font_override("font", UiFonts.display_font(label.get_theme_default_font()))
	return label
