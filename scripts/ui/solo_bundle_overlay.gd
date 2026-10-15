class_name SoloBundleOverlay
extends Control
## 遠征(ソロモード)の束のオーバーレイ(GameDesign.md 27章「画面」)。道を暗幕で覆い、
## 束(作戦ごとの3枚)から1つを**選ぶだけ**(まだ足さない)。右端に`SoloDeckList`で
## 足したあとの山札を出し、増える札を光らせてから「この束を足す」で確定する。
## 縦画面では束の行・足したあとの山札・ボタンを上から積み、中身ごと `PORTRAIT_ZOOM` 倍にする
## (GameDesign.md 9章「縦画面」)。

signal bundle_chosen(index: int)
signal skip_pressed

const TITLE_FONT_SIZE := 30
const SUBTITLE_FONT_SIZE := 16
const DIM_COLOR := Color(0, 0, 0, 0.72)
const TITLE_TOP := 28.0
const SUBTITLE_TOP := 70.0
const ROWS_TOP := 104.0
const ROWS_BOTTOM_MARGIN := 20.0
const ROW_GAP := 16.0
const ROW_NAME_WIDTH := 260.0
## 束が3つのとき、行の高さから縦の余白を引くとちょうど`CardView.HAND_SIZE_PX.y`(158)に
## 一致するよう選んだ値(GameDesign.md 27章「画面」で「手札と同じ大きさで欠けずに」)。
const ROW_PADDING := 15.0
const NAME_FONT_SIZE := 22
const SUMMARY_FONT_SIZE := 13
const TAG_FONT_SIZE := 13
const TAG_TEXT := "◆ 作戦"
const TAG_COLOR := Color(0.9, 0.75, 0.4)
const CARD_GAP := 16.0
## 右端の「足したあとの山札」欄(GameDesign.md 27章「画面」)。束の並びはこれを除いた
## 残りの幅で組む。
const DECK_PANEL_WIDTH := 300.0
const DECK_PANEL_MARGIN := 32.0
const DECK_PANEL_PADDING := 20.0
const DECK_LABEL_FONT_SIZE := 15
const ADD_BUTTON_SIZE := Vector2(240, 48)
const SKIP_BUTTON_SIZE := Vector2(200, 44)
const BUTTON_GAP := 12.0

## 縦画面の配置(座標は `PORTRAIT_ZOOM` で割った論理の大きさ)。束の行は名前の行の下に
## 札3枚、その右に作戦の説明を置く。
const PORTRAIT_ZOOM := 1.4
const PORTRAIT_SIDE_MARGIN := 16.0
const PORTRAIT_BOTTOM_MARGIN := 20.0
const PORTRAIT_ROW_PADDING := 12.0
const PORTRAIT_NAME_HEIGHT := 30.0
const PORTRAIT_SUMMARY_GAP := 14.0
const PORTRAIT_SUMMARY_FONT_SIZE := 17
const PORTRAIT_TAG_FONT_SIZE := 16
const PORTRAIT_DECK_HEIGHT := 190.0
const PORTRAIT_DECK_LABEL_FONT_SIZE := 17
const PORTRAIT_BUTTON_SIZE := Vector2(220, 52)

var portrait := false

var _dim: ColorRect
var _body: Control
var _title: Label
var _subtitle: Label
var _rows_box: Control
var _deck_panel_canvas: Control
var _deck_label: Label
var _deck_list: SoloDeckList
var _add_button: Button
var _skip_button: Button
var _offer: Array[Dictionary] = []
var _theme_id := ""
var _deck_ids: Array[String] = []
var _selected_index := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.color = DIM_COLOR
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	_title = _label(TITLE_FONT_SIZE, UiPalette.TEXT_OFFWHITE, true)
	_title.text = "束を1つ選んで山札に足す"
	_body.add_child(_title)
	_subtitle = _label(SUBTITLE_FONT_SIZE, UiPalette.TEXT_MUTED)
	_body.add_child(_subtitle)
	_rows_box = Control.new()
	_rows_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_body.add_child(_rows_box)

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
	_body.add_child(_deck_panel_canvas)
	_deck_label = _label(DECK_LABEL_FONT_SIZE, UiPalette.TEXT_MUTED)
	_deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_body.add_child(_deck_label)
	_deck_list = SoloDeckList.new()
	_body.add_child(_deck_list)

	_add_button = CodedButton.make_in_group(
		"この束を足す", ADD_BUTTON_SIZE, CodedButton.PRIMARY_ACTION_GROUP
	)
	_add_button.pressed.connect(_on_add_pressed)
	_body.add_child(_add_button)
	_skip_button = CodedButton.make("見送る", SKIP_BUTTON_SIZE)
	_skip_button.pressed.connect(func() -> void: skip_pressed.emit())
	_body.add_child(_skip_button)

	resized.connect(_layout)
	_layout()


## 縦横を切り替える(`CardSoloMapScreen.apply_orientation()` から呼ぶ)。選んでいる束は保つ。
func set_portrait(value: bool) -> void:
	portrait = value
	_layout()


## 束を出す。`win_count`は小見出しの「N戦目の勝利」、`deck_ids`はいまの山札(足す前)。
func show_data(
	offer: Array[Dictionary], win_count: int, deck_ids: Array[String], theme_id: String
) -> void:
	_offer = offer
	_theme_id = theme_id
	_deck_ids = deck_ids
	_selected_index = -1
	_subtitle.text = "%d戦目の勝利" % win_count
	_refresh_deck_panel()
	_layout()


func _refresh_deck_panel() -> void:
	var added: Array[String] = []
	if _selected_index >= 0 and _selected_index < _offer.size():
		for id in _offer[_selected_index].get("cards", []):
			added.append(str(id))
	_deck_label.text = "山札 %d枚 → %d枚" % [_deck_ids.size(), _deck_ids.size() + added.size()]
	var shown_ids := _deck_ids.duplicate()
	shown_ids.append_array(added)
	_deck_list.show_data(shown_ids, added)
	_add_button.disabled = _selected_index < 0


func _rebuild_rows() -> void:
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
		_build_row(Rect2(0, y, rows_w, row_h), _offer[i], i)


func _build_row(rect: Rect2, bundle: Dictionary, index: int) -> void:
	var is_own := str(bundle.get("theme", "")) == _theme_id
	var is_selected := index == _selected_index
	var canvas := Control.new()
	canvas.position = rect.position
	canvas.size = rect.size
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(
		func() -> void:
			SoloUiPaint.paint_panel(
				canvas.get_canvas_item(), Rect2(Vector2.ZERO, rect.size), is_selected
			)
	)
	_rows_box.add_child(canvas)

	var theme := str(bundle.get("theme", ""))
	var cards: Array = bundle.get("cards", [])
	# 横: 左に名前・説明・印、右に札。縦: 上の行に名前と印、その下の左に札・右に説明。
	var pad := PORTRAIT_ROW_PADDING if portrait else ROW_PADDING
	var name_rect := Rect2(pad, pad - 4.0, ROW_NAME_WIDTH - pad, 30.0)
	var summary_rect := Rect2(pad, pad + 30.0, ROW_NAME_WIDTH - pad, rect.size.y - pad - 44.0)
	var tag_rect := Rect2(pad, rect.size.y - pad - 18.0, 200.0, 20.0)
	var cards_rect := Rect2(
		ROW_NAME_WIDTH, pad, rect.size.x - ROW_NAME_WIDTH, rect.size.y - pad * 2.0
	)
	if portrait:
		name_rect = Rect2(pad, pad - 4.0, rect.size.x - pad * 2.0, PORTRAIT_NAME_HEIGHT)
		tag_rect = name_rect
		cards_rect = Rect2(
			pad,
			pad + PORTRAIT_NAME_HEIGHT,
			rect.size.x - pad * 2.0,
			rect.size.y - pad * 2.0 - PORTRAIT_NAME_HEIGHT
		)

	var name_label := _label(NAME_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.position = rect.position + name_rect.position
	name_label.size = name_rect.size
	name_label.text = "%sの束" % CardCpuDecks.name_of(theme)
	_rows_box.add_child(name_label)

	if is_own:
		var tag := _label(PORTRAIT_TAG_FONT_SIZE if portrait else TAG_FONT_SIZE, TAG_COLOR)
		tag.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_RIGHT if portrait else HORIZONTAL_ALIGNMENT_LEFT
		)
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.position = rect.position + tag_rect.position
		tag.size = tag_rect.size
		tag.text = TAG_TEXT
		_rows_box.add_child(tag)

	# **`CardView.size`は`HAND_SIZE_PX`のまま保つ。**縮めるには`size`ではなく`scale`を使う
	# (`size`を縮めると中身が切り取られる。Pitfalls.md)。当たり判定は`scale`に従う。
	var scale: float = clampf(cards_rect.size.y / CardView.HAND_SIZE_PX.y, 0.1, 1.0)
	var card_size := CardView.HAND_SIZE_PX * scale
	var cards_top := (
		rect.position.y + cards_rect.position.y + (cards_rect.size.y - card_size.y) * 0.5
	)
	for k in cards.size():
		var card := CardLibrary.find_by_id(str(cards[k]))
		if card == null:
			continue
		var view := CardView.new()
		view.mode = CardView.Mode.HAND
		view.position = Vector2(
			rect.position.x + cards_rect.position.x + float(k) * (card_size.x + CARD_GAP), cards_top
		)
		view.scale = Vector2(scale, scale)
		_rows_box.add_child(view)
		view.show_card(card, true)

	if portrait:
		var cards_w := (
			card_size.x * float(cards.size()) + CARD_GAP * float(maxi(cards.size() - 1, 0))
		)
		var summary_left := cards_rect.position.x + cards_w + PORTRAIT_SUMMARY_GAP
		summary_rect = Rect2(
			summary_left, cards_rect.position.y, rect.size.x - pad - summary_left, cards_rect.size.y
		)
	var summary_label := _label(
		PORTRAIT_SUMMARY_FONT_SIZE if portrait else SUMMARY_FONT_SIZE, UiPalette.TEXT_MUTED
	)
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if portrait:
		summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary_label.position = rect.position + summary_rect.position
	summary_label.size = summary_rect.size
	summary_label.text = CardCpuDecks.summary_of(theme)
	_rows_box.add_child(summary_label)

	var button := SoloUiPaint.transparent_button()
	button.position = rect.position
	button.size = rect.size
	button.pressed.connect(_on_row_pressed.bind(index))
	_rows_box.add_child(button)


func _on_row_pressed(index: int) -> void:
	_selected_index = -1 if _selected_index == index else index
	_rebuild_rows()
	_refresh_deck_panel()


func _on_add_pressed() -> void:
	if _selected_index < 0:
		return
	bundle_chosen.emit(_selected_index)


func _layout() -> void:
	if _dim == null:
		return
	_dim.size = size
	var zoom := PORTRAIT_ZOOM if portrait else 1.0
	_body.scale = Vector2.ONE * zoom
	_body.size = size / zoom
	var area := _body.size
	if portrait:
		_layout_portrait(area)
		return
	_set_button_size(_add_button, ADD_BUTTON_SIZE)
	_set_button_size(_skip_button, SKIP_BUTTON_SIZE)
	_deck_label.add_theme_font_size_override("font_size", DECK_LABEL_FONT_SIZE)
	var rows_w := area.x - DECK_PANEL_WIDTH - DECK_PANEL_MARGIN
	_title.position = Vector2(0, TITLE_TOP)
	_title.size = Vector2(rows_w, 40.0)
	_subtitle.position = Vector2(0, SUBTITLE_TOP)
	_subtitle.size = Vector2(rows_w, 24.0)
	_rows_box.position = Vector2(0, ROWS_TOP)
	_rows_box.size = Vector2(rows_w, area.y - ROWS_TOP - ROWS_BOTTOM_MARGIN)
	_rebuild_rows()

	var buttons_h := ADD_BUTTON_SIZE.y + BUTTON_GAP + SKIP_BUTTON_SIZE.y
	var deck_rect := Rect2(
		area.x - DECK_PANEL_WIDTH,
		ROWS_TOP,
		DECK_PANEL_WIDTH,
		area.y - ROWS_TOP - ROWS_BOTTOM_MARGIN - buttons_h - BUTTON_GAP
	)
	_place_deck_panel(deck_rect)
	_add_button.position = Vector2(
		deck_rect.position.x + (deck_rect.size.x - ADD_BUTTON_SIZE.x) * 0.5,
		deck_rect.end.y + BUTTON_GAP
	)
	_skip_button.position = Vector2(
		deck_rect.position.x + (deck_rect.size.x - SKIP_BUTTON_SIZE.x) * 0.5,
		_add_button.position.y + ADD_BUTTON_SIZE.y + BUTTON_GAP
	)


## 縦: 見出し / 束の行 / 足したあとの山札 / 「見送る」「この束を足す」の順に上から積む。
func _layout_portrait(area: Vector2) -> void:
	_set_button_size(_add_button, PORTRAIT_BUTTON_SIZE)
	_set_button_size(_skip_button, PORTRAIT_BUTTON_SIZE)
	_deck_label.add_theme_font_size_override("font_size", PORTRAIT_DECK_LABEL_FONT_SIZE)
	var content_w := area.x - PORTRAIT_SIDE_MARGIN * 2.0
	_title.position = Vector2(0, TITLE_TOP)
	_title.size = Vector2(area.x, 40.0)
	_subtitle.position = Vector2(0, SUBTITLE_TOP)
	_subtitle.size = Vector2(area.x, 24.0)

	var buttons_top := area.y - PORTRAIT_BOTTOM_MARGIN - PORTRAIT_BUTTON_SIZE.y
	var deck_rect := Rect2(
		PORTRAIT_SIDE_MARGIN,
		buttons_top - BUTTON_GAP - PORTRAIT_DECK_HEIGHT,
		content_w,
		PORTRAIT_DECK_HEIGHT
	)
	_rows_box.position = Vector2(PORTRAIT_SIDE_MARGIN, ROWS_TOP)
	_rows_box.size = Vector2(content_w, deck_rect.position.y - BUTTON_GAP - ROWS_TOP)
	_rebuild_rows()
	_place_deck_panel(deck_rect)
	var buttons_w := PORTRAIT_BUTTON_SIZE.x * 2.0 + BUTTON_GAP
	var buttons_left := (area.x - buttons_w) * 0.5
	_skip_button.position = Vector2(buttons_left, buttons_top)
	_add_button.position = Vector2(buttons_left + PORTRAIT_BUTTON_SIZE.x + BUTTON_GAP, buttons_top)


func _place_deck_panel(deck_rect: Rect2) -> void:
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


func _set_button_size(button: Button, button_size: Vector2) -> void:
	button.custom_minimum_size = button_size
	button.size = button_size


func _label(font_size: int, color: Color, display := false) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if display:
		label.add_theme_font_override("font", UiFonts.display_font(label.get_theme_default_font()))
	return label
