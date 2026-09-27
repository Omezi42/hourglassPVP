class_name SoloOfferOverlay
extends Control
## 遠征(ソロモード)の候補オーバーレイ(GameDesign.md 27章「画面」)。道を暗幕で覆い、
## 候補から1枚選んで山札に足す(見送ってもよい)。見た目は承認済みのモック
## (`tools/tmp_mock_solo.gd`)のとおり。

signal card_chosen(card_id: String)
signal skip_pressed

const TITLE_FONT_SIZE := 30
const SUBTITLE_FONT_SIZE := 16
const DIM_COLOR := Color(0, 0, 0, 0.72)
const CARD_SCALE := 1.55
const CARD_GAP := 36.0
const TOP_OFFSET := 176.0
const TITLE_TOP := 70.0
const SUBTITLE_TOP := 118.0
const SKIP_GAP := 36.0
const SKIP_SIZE := Vector2(200, 52)
const TAG_SIZE := Vector2(72, 26)
const TAG_FONT_SIZE := 13
const TAG_TEXT := "作戦"

var _dim: ColorRect
var _title: Label
var _subtitle: Label
var _cards_box: Control
var _skip_button: Button


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
	resized.connect(_layout)
	_layout()


## 候補を出す。`theme_id`のCPUデッキの15種に含まれる1枚には肩に「作戦」の札を付ける
## (GameDesign.md 27章「山札を育てる」)。
func show_data(offer: Array[String], win_count: int, deck_size: int, theme_id: String) -> void:
	_title.text = "山札に1枚足す"
	_subtitle.text = "%d戦目の勝利 ・ 山札 %d枚" % [win_count, deck_size]
	for child in _cards_box.get_children():
		_cards_box.remove_child(child)
		child.queue_free()
	var theme_ids := CardCpuDecks.card_ids_of(theme_id)
	var card_size := CardView.HAND_SIZE_PX * CARD_SCALE
	var total_w := card_size.x * float(offer.size()) + CARD_GAP * float(maxi(offer.size() - 1, 0))
	var left := (size.x - total_w) * 0.5
	for i in offer.size():
		var card_id: String = offer[i]
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
			_add_operation_tag(view)
	_layout()


func _add_operation_tag(view: CardView) -> void:
	var tag := Control.new()
	var card_size := CardView.HAND_SIZE_PX * CARD_SCALE
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
	_title.position = Vector2(0, TITLE_TOP)
	_title.size = Vector2(size.x, 44.0)
	_subtitle.position = Vector2(0, SUBTITLE_TOP)
	_subtitle.size = Vector2(size.x, 26.0)
	var card_size := CardView.HAND_SIZE_PX * CARD_SCALE
	_skip_button.position = Vector2(
		(size.x - SKIP_SIZE.x) * 0.5, TOP_OFFSET + card_size.y + SKIP_GAP
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
