class_name SoloOfferOverlay
extends Control
## 遠征(ソロモード)の候補オーバーレイ(GameDesign.md 27章「画面」)。道を暗幕で覆い、
## 候補から1枚選んで山札に足す(見送ってもよい)。右端に`SoloDeckList`でいまの山札を
## 出し、何を足すか山札の中身を見て決められるようにする。

signal card_chosen(card_id: String)
signal skip_pressed

const TITLE_FONT_SIZE := 30
const SUBTITLE_FONT_SIZE := 16
const DIM_COLOR := Color(0, 0, 0, 0.72)
const CARD_SCALE_MAX := 1.55
const CARD_GAP := 36.0
const TOP_OFFSET := 176.0
const TITLE_TOP := 70.0
const SUBTITLE_TOP := 118.0
const SKIP_GAP := 36.0
const SKIP_SIZE := Vector2(200, 52)
const TAG_SIZE := Vector2(72, 26)
const TAG_FONT_SIZE := 13
const TAG_TEXT := "作戦"
## 右端の「いまの山札」欄(GameDesign.md 27章「画面」)。カードの列はこれを除いた
## 残りの幅で中央寄せする。
const DECK_PANEL_WIDTH := 280.0
const DECK_PANEL_MARGIN := 32.0
const DECK_PANEL_PADDING := 20.0
const DECK_LABEL_FONT_SIZE := 15

var _dim: ColorRect
var _title: Label
var _subtitle: Label
var _cards_box: Control
var _skip_button: Button
var _deck_panel_canvas: Control
var _deck_label: Label
var _deck_list: SoloDeckList
var _cards_width := 0.0
var _offer: Array[String] = []
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
	_cards_box = Control.new()
	_cards_box.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_cards_box)
	_skip_button = CodedButton.make("見送る", SKIP_SIZE)
	_skip_button.pressed.connect(func() -> void: skip_pressed.emit())
	add_child(_skip_button)

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

	resized.connect(_layout)
	_layout()


## 候補を出す。`theme_id`のCPUデッキの15種に含まれる1枚には肩に「作戦」の札を付ける
## (GameDesign.md 27章「山札を育てる」)。右端の「いまの山札」を見て、何を足すか決められる
## ようにする(GameDesign.md 27章「画面」)。
func show_data(
	offer: Array[String], win_count: int, deck_ids: Array[String], theme_id: String
) -> void:
	_title.text = "山札に1枚足す"
	_subtitle.text = "%d戦目の勝利 ・ 山札 %d枚" % [win_count, deck_ids.size()]
	_deck_label.text = "いまの山札 %d枚" % deck_ids.size()
	_deck_list.show_data(deck_ids)
	_offer = offer
	_theme_id = theme_id
	_layout()


func _rebuild_cards() -> void:
	for child in _cards_box.get_children():
		_cards_box.remove_child(child)
		child.queue_free()
	var theme_ids := CardCpuDecks.card_ids_of(_theme_id)
	var card_size := _card_size(_offer.size())
	var total_w := card_size.x * float(_offer.size()) + CARD_GAP * float(maxi(_offer.size() - 1, 0))
	var left := (_cards_width - total_w) * 0.5
	for i in _offer.size():
		var card_id: String = _offer[i]
		var card := CardLibrary.find_by_id(card_id)
		if card == null:
			continue
		var view := CardView.new()
		view.mode = CardView.Mode.HAND
		view.position = Vector2(left + float(i) * (card_size.x + CARD_GAP), TOP_OFFSET)
		view.size = card_size
		_cards_box.add_child(view)
		view.show_card(card, true)
		view.size = card_size
		view.pressed.connect(func(_v: CardView) -> void: card_chosen.emit(card_id))
		if theme_ids.has(card_id):
			_add_operation_tag(view, card_size)


## カードの列は残りの幅(山札欄を除いた分)で中央寄せする。4枚の候補(関門)でも
## はみ出さないよう、倍率を幅から決める(GameDesign.md 27章「画面」)。
func _card_size(count: int) -> Vector2:
	var base := CardView.HAND_SIZE_PX
	var available := _cards_width - CARD_GAP * float(maxi(count - 1, 0))
	var scale := (
		CARD_SCALE_MAX if count <= 0 else minf(CARD_SCALE_MAX, available / (base.x * float(count)))
	)
	return base * scale


func _add_operation_tag(view: CardView, card_size: Vector2) -> void:
	var tag := Control.new()
	tag.position = Vector2(card_size.x - TAG_SIZE.x + 8.0, -10.0)
	tag.size = TAG_SIZE
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.draw.connect(
		func() -> void:
			var ci := tag.get_canvas_item()
			var rect := Rect2(Vector2.ZERO, TAG_SIZE)
			var points := UiPaint.rounded_rect_points_uniform(rect, 6.0, 8)
			UiPaint.fill_gradient_polygon(
				ci, points, rect, [[0.0, UiPalette.BRASS_HIGHLIGHT], [1.0, UiPalette.BRASS_MID]]
			)
			UiPaint.draw_bevel(
				ci, points, UiPalette.BRASS_RIM_LIGHT, UiPalette.OUTLINE_DARK, 1.5, false
			)
			var font := tag.get_theme_default_font()
			if font == null:
				return
			var w := font.get_string_size(TAG_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT_SIZE).x
			tag.draw_string(
				font,
				Vector2((TAG_SIZE.x - w) * 0.5, TAG_SIZE.y * 0.68),
				TAG_TEXT,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				TAG_FONT_SIZE,
				Color(0.2, 0.13, 0.07, 1.0)
			)
	)
	view.add_child(tag)


func _layout() -> void:
	if _dim == null:
		return
	_dim.size = size
	_cards_width = size.x - DECK_PANEL_WIDTH - DECK_PANEL_MARGIN
	_title.position = Vector2(0, TITLE_TOP)
	_title.size = Vector2(_cards_width, 44.0)
	_subtitle.position = Vector2(0, SUBTITLE_TOP)
	_subtitle.size = Vector2(_cards_width, 26.0)
	_rebuild_cards()
	var card_size := _card_size(_offer.size())
	_skip_button.position = Vector2(
		(_cards_width - SKIP_SIZE.x) * 0.5, TOP_OFFSET + card_size.y + SKIP_GAP
	)
	var deck_rect := Rect2(
		size.x - DECK_PANEL_WIDTH,
		TOP_OFFSET,
		DECK_PANEL_WIDTH,
		size.y - TOP_OFFSET - TOP_OFFSET * 0.3
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


func _label(font_size: int, color: Color, display := false) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if display:
		label.add_theme_font_override("font", UiFonts.display_font(label.get_theme_default_font()))
	return label
