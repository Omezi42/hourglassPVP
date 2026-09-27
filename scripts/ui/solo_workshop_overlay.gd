class_name SoloWorkshopOverlay
extends Control
## 遠征(ソロモード)の工房のオーバーレイ(GameDesign.md 27章「画面」)。左に山札の
## 種類ごとに1枚、コスト順の格子を出し、押すと右の作業台に大きく出して「抜く」
## 「複製する」(同名は2枚まで)を結果つきで選ばせる。束・行き先の詳細と同じ
## 「左で選び、右で結果を見て決める」形にそろえる。

signal card_removed(card_id: String)
signal card_duplicated(card_id: String)
signal skip_pressed

const TITLE_FONT_SIZE := 30
const SUBTITLE_FONT_SIZE := 16
const DIM_COLOR := Color(0, 0, 0, 0.74)
const TITLE_TOP := 70.0
const SUBTITLE_TOP := 118.0
const CONTENT_TOP := 150.0
const CONTENT_BOTTOM_MARGIN := 90.0
const SIDE_MARGIN := 60.0
const PANEL_GAP := 28.0
## 左(格子)と右(作業台)の幅の割合。道・状態パネルと同じ6:4(GameDesign.md 27章)。
const GRID_RATIO := 0.6

const GRID_COLUMNS := 6
const GRID_CARD_GAP := 14.0
const GRID_ROW_GAP := 20.0
const COUNT_BADGE_FONT_SIZE := 14
const COUNT_BADGE_COLOR := Color(0.95, 0.8, 0.45)
const SELECTED_RING_GAP := 6.0
const SELECTED_RING_WIDTH := 3.0

const PANEL_PADDING := 24.0
const PANEL_EMPTY_FONT_SIZE := 18
const PANEL_COUNT_FONT_SIZE := 15
const PANEL_CARD_SCALE := 1.6
const PANEL_CARD_TOP_GAP := 8.0
const PANEL_DECK_LABEL_GAP := 18.0
const ACTION_BUTTON_SIZE := Vector2(140, 48)
const ACTION_ROW_GAP := 14.0
const ACTION_RESULT_FONT_SIZE := 14
const ACTION_RESULT_GAP := 16.0

const SKIP_BUTTON_SIZE := Vector2(200, 44)
const SKIP_TOP_GAP := 16.0

var _dim: ColorRect
var _title: Label
var _subtitle: Label
var _grid_box: Control
var _panel_canvas: Control
var _panel_empty_label: Label
var _panel_deck_count_label: Label
var _panel_card: CardView
var _panel_in_deck_label: Label
var _remove_button: Button
var _remove_result_label: Label
var _duplicate_button: Button
var _duplicate_result_label: Label
var _skip_button: Button
var _deck_ids: Array[String] = []
var _selected_id := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.color = DIM_COLOR
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_title = _label(TITLE_FONT_SIZE, UiPalette.TEXT_OFFWHITE, true)
	_title.text = "工房"
	add_child(_title)
	_subtitle = _label(SUBTITLE_FONT_SIZE, UiPalette.TEXT_MUTED)
	_subtitle.text = "山札から1枚を抜くか、1枚を複製する(同名は2枚まで)"
	add_child(_subtitle)
	_grid_box = Control.new()
	_grid_box.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_grid_box)

	_panel_canvas = Control.new()
	_panel_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_canvas.draw.connect(
		func() -> void:
			SoloUiPaint.paint_panel(
				_panel_canvas.get_canvas_item(), Rect2(Vector2.ZERO, _panel_canvas.size), false
			)
	)
	add_child(_panel_canvas)

	_panel_empty_label = _label(PANEL_EMPTY_FONT_SIZE, UiPalette.TEXT_OFFWHITE, true)
	_panel_empty_label.text = "カードを1枚選ぶ"
	add_child(_panel_empty_label)
	_panel_deck_count_label = _label(PANEL_COUNT_FONT_SIZE, UiPalette.TEXT_MUTED)
	add_child(_panel_deck_count_label)

	_panel_card = CardView.new()
	_panel_card.mode = CardView.Mode.HAND
	_panel_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel_card)
	_panel_in_deck_label = _label(PANEL_COUNT_FONT_SIZE, UiPalette.TEXT_MUTED)
	add_child(_panel_in_deck_label)

	_remove_button = CodedButton.make("抜く", ACTION_BUTTON_SIZE)
	_remove_button.pressed.connect(_on_remove_pressed)
	add_child(_remove_button)
	_remove_result_label = _label(ACTION_RESULT_FONT_SIZE, UiPalette.TEXT_MUTED)
	_remove_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_remove_result_label)

	_duplicate_button = CodedButton.make_in_group(
		"複製する", ACTION_BUTTON_SIZE, CodedButton.PRIMARY_ACTION_GROUP
	)
	_duplicate_button.pressed.connect(_on_duplicate_pressed)
	add_child(_duplicate_button)
	_duplicate_result_label = _label(ACTION_RESULT_FONT_SIZE, UiPalette.TEXT_MUTED)
	_duplicate_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_duplicate_result_label)

	_skip_button = CodedButton.make("何もしない", SKIP_BUTTON_SIZE)
	_skip_button.pressed.connect(func() -> void: skip_pressed.emit())
	add_child(_skip_button)

	resized.connect(_layout)
	_layout()


func show_data(deck_ids: Array[String]) -> void:
	_deck_ids = deck_ids
	_selected_id = ""
	_layout()


## 山札の種類をコスト順に並べ直した、重複の無い一覧。
func _unique_ids() -> Array[String]:
	var counts := {}
	for id in _deck_ids:
		counts[id] = true
	var cards: Array[CardData] = []
	for id in counts:
		var card := CardLibrary.find_by_id(str(id))
		if card != null:
			cards.append(card)
	cards.sort_custom(func(a: CardData, b: CardData) -> bool: return a.cost < b.cost)
	var ids: Array[String] = []
	for card in cards:
		ids.append(card.id)
	return ids


func _grid_rect() -> Rect2:
	var grid_w := (size.x - SIDE_MARGIN * 2.0 - PANEL_GAP) * GRID_RATIO
	return Rect2(SIDE_MARGIN, CONTENT_TOP, grid_w, size.y - CONTENT_TOP - CONTENT_BOTTOM_MARGIN)


func _panel_rect() -> Rect2:
	var grid_rect := _grid_rect()
	var panel_x := grid_rect.end.x + PANEL_GAP
	return Rect2(panel_x, CONTENT_TOP, size.x - SIDE_MARGIN - panel_x, grid_rect.size.y)


## 格子1マスの大きさ。**`CardView.size`は`HAND_SIZE_PX`のまま保ち、`scale`で縮める**
## (`size`を縮めると中身が切り取られる。Pitfalls.md)。当たり判定は`scale`に従う。
func _grid_cell(inner_w: float) -> Dictionary:
	var card_w: float = (inner_w - float(GRID_COLUMNS - 1) * GRID_CARD_GAP) / float(GRID_COLUMNS)
	var scale: float = clampf(card_w / CardView.HAND_SIZE_PX.x, 0.1, 1.0)
	var card_size := CardView.HAND_SIZE_PX * scale
	return {"scale": scale, "size": card_size}


func _rebuild_grid() -> void:
	for child in _grid_box.get_children():
		_grid_box.remove_child(child)
		child.queue_free()
	var ids := _unique_ids()
	var inner_w := _grid_box.size.x
	if inner_w <= 0.0:
		return
	var cell: Dictionary = _grid_cell(inner_w)
	var card_size: Vector2 = cell["size"]
	var scale: float = cell["scale"]
	for i in ids.size():
		var col := i % GRID_COLUMNS
		var row := i / GRID_COLUMNS
		var pos := Vector2(
			float(col) * (card_size.x + GRID_CARD_GAP), float(row) * (card_size.y + GRID_ROW_GAP)
		)
		_build_card(pos, card_size, scale, ids[i])


func _build_card(pos: Vector2, card_size: Vector2, scale: float, card_id: String) -> void:
	var card := CardLibrary.find_by_id(card_id)
	if card == null:
		return
	var view := CardView.new()
	view.mode = CardView.Mode.HAND
	view.position = pos
	view.scale = Vector2(scale, scale)
	_grid_box.add_child(view)
	view.show_card(card, true)
	if _selected_id == card_id:
		var ring := Control.new()
		ring.position = pos - Vector2.ONE * SELECTED_RING_GAP
		ring.size = card_size + Vector2.ONE * SELECTED_RING_GAP * 2.0
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.draw.connect(
			func() -> void:
				UiPaint.draw_bevel(
					ring.get_canvas_item(),
					UiPaint.rounded_rect_points_uniform(Rect2(Vector2.ZERO, ring.size), 8.0, 8),
					UiPalette.BRASS_HIGHLIGHT,
					UiPalette.BRASS_HIGHLIGHT,
					SELECTED_RING_WIDTH,
					false
				)
		)
		_grid_box.add_child(ring)
	var count := _deck_ids.count(card_id)
	if count >= 2:
		var badge := _label(COUNT_BADGE_FONT_SIZE, COUNT_BADGE_COLOR)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.position = pos + Vector2(0, card_size.y - 4.0)
		badge.size = Vector2(card_size.x - 6.0, 20.0)
		badge.text = "×%d" % count
		_grid_box.add_child(badge)
	var button := SoloUiPaint.transparent_button()
	button.position = pos
	button.size = card_size
	button.pressed.connect(_on_card_pressed.bind(card_id))
	_grid_box.add_child(button)


func _on_card_pressed(card_id: String) -> void:
	_selected_id = "" if _selected_id == card_id else card_id
	_layout()


func _on_remove_pressed() -> void:
	if _selected_id.is_empty():
		return
	card_removed.emit(_selected_id)


func _on_duplicate_pressed() -> void:
	if _selected_id.is_empty():
		return
	if _deck_ids.count(_selected_id) >= SoloRun.MAX_DECK_COPIES:
		return
	card_duplicated.emit(_selected_id)


func _layout() -> void:
	if _dim == null:
		return
	_dim.size = size
	_title.position = Vector2(0, TITLE_TOP)
	_title.size = Vector2(size.x, 44.0)
	_subtitle.position = Vector2(0, SUBTITLE_TOP)
	_subtitle.size = Vector2(size.x, 26.0)

	var grid_rect := _grid_rect()
	_grid_box.position = grid_rect.position
	_grid_box.size = grid_rect.size
	_rebuild_grid()

	var panel_rect := _panel_rect()
	_panel_canvas.position = panel_rect.position
	_panel_canvas.size = panel_rect.size
	_layout_panel(panel_rect)

	_skip_button.position = Vector2(
		panel_rect.position.x + (panel_rect.size.x - SKIP_BUTTON_SIZE.x) * 0.5,
		panel_rect.end.y + SKIP_TOP_GAP
	)


func _layout_panel(panel_rect: Rect2) -> void:
	var has_selection := not _selected_id.is_empty()
	_panel_empty_label.visible = not has_selection
	_panel_deck_count_label.visible = not has_selection
	_panel_card.visible = has_selection
	_panel_in_deck_label.visible = has_selection
	_remove_button.visible = has_selection
	_remove_result_label.visible = has_selection
	_duplicate_button.visible = has_selection
	_duplicate_result_label.visible = has_selection

	if not has_selection:
		_panel_empty_label.position = Vector2(
			panel_rect.position.x + PANEL_PADDING, panel_rect.position.y + PANEL_PADDING
		)
		_panel_empty_label.size = Vector2(panel_rect.size.x - PANEL_PADDING * 2.0, 28.0)
		_panel_deck_count_label.text = "山札 %d枚" % _deck_ids.size()
		_panel_deck_count_label.position = _panel_empty_label.position + Vector2(0, 34.0)
		_panel_deck_count_label.size = Vector2(panel_rect.size.x - PANEL_PADDING * 2.0, 22.0)
		return

	var card := CardLibrary.find_by_id(_selected_id)
	if card == null:
		return
	var card_size := CardView.HAND_SIZE_PX * PANEL_CARD_SCALE
	var card_top := panel_rect.position.y + PANEL_PADDING + PANEL_CARD_TOP_GAP
	_panel_card.position = Vector2(
		panel_rect.position.x + (panel_rect.size.x - card_size.x) * 0.5, card_top
	)
	_panel_card.scale = Vector2.ONE * PANEL_CARD_SCALE
	_panel_card.show_card(card, true)

	var count := _deck_ids.count(_selected_id)
	var in_deck_top := card_top + card_size.y + PANEL_DECK_LABEL_GAP
	_panel_in_deck_label.text = "山札に %d枚" % count
	_panel_in_deck_label.position = Vector2(panel_rect.position.x + PANEL_PADDING, in_deck_top)
	_panel_in_deck_label.size = Vector2(panel_rect.size.x - PANEL_PADDING * 2.0, 22.0)
	_panel_in_deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var actions_top := in_deck_top + 30.0
	var remove_top := actions_top
	_remove_button.position = Vector2(panel_rect.position.x + PANEL_PADDING, remove_top)
	_remove_result_label.text = "山札 %d → %d枚" % [_deck_ids.size(), _deck_ids.size() - 1]
	_remove_result_label.position = Vector2(
		_remove_button.position.x + ACTION_BUTTON_SIZE.x + ACTION_RESULT_GAP,
		remove_top + (ACTION_BUTTON_SIZE.y - 18.0) * 0.5
	)
	_remove_result_label.size = Vector2(
		panel_rect.size.x - PANEL_PADDING * 2.0 - ACTION_BUTTON_SIZE.x - ACTION_RESULT_GAP, 20.0
	)

	var duplicate_top := remove_top + ACTION_BUTTON_SIZE.y + ACTION_ROW_GAP
	var duplicate_disabled := count >= SoloRun.MAX_DECK_COPIES
	_duplicate_button.disabled = duplicate_disabled
	_duplicate_button.position = Vector2(panel_rect.position.x + PANEL_PADDING, duplicate_top)
	_duplicate_result_label.text = (
		"同名は2枚まで"
		if duplicate_disabled
		else "山札 %d → %d枚" % [_deck_ids.size(), _deck_ids.size() + 1]
	)
	_duplicate_result_label.position = Vector2(
		_duplicate_button.position.x + ACTION_BUTTON_SIZE.x + ACTION_RESULT_GAP,
		duplicate_top + (ACTION_BUTTON_SIZE.y - 18.0) * 0.5
	)
	_duplicate_result_label.size = _remove_result_label.size


func _label(font_size: int, color: Color, display := false) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if display:
		label.add_theme_font_override("font", UiFonts.display_font(label.get_theme_default_font()))
	return label
