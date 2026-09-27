class_name SoloWorkshopOverlay
extends Control
## 遠征(ソロモード)の工房のオーバーレイ(GameDesign.md 27章「画面」)。山札の種類ごとに
## 1枚並べ、押すと選択して「抜く」「複製する」(同名は2枚まで)を出す。「何もしない」も置く。

signal card_removed(card_id: String)
signal card_duplicated(card_id: String)
signal skip_pressed

const TITLE_FONT_SIZE := 30
const SUBTITLE_FONT_SIZE := 16
const DIM_COLOR := Color(0, 0, 0, 0.74)
const TITLE_TOP := 70.0
const SUBTITLE_TOP := 118.0
const GRID_TOP := 150.0
const GRID_BOTTOM_MARGIN := 150.0
const GRID_SIDE_MARGIN := 90.0
const COLUMNS := 9
const CARD_GAP := 12.0
const ROW_GAP := 18.0
const COUNT_BADGE_FONT_SIZE := 14
const COUNT_BADGE_COLOR := Color(0.95, 0.8, 0.45)
const SELECTED_RING_GAP := 6.0
const SELECTED_RING_WIDTH := 3.0
const ACTION_BUTTON_SIZE := Vector2(140, 48)
const ACTION_BUTTON_GAP := 10.0
const ACTION_TOP_GAP := 16.0
const SKIP_BUTTON_SIZE := Vector2(200, 48)
const SKIP_BOTTOM_MARGIN := 40.0

var _dim: ColorRect
var _title: Label
var _subtitle: Label
var _grid_box: Control
var _actions_box: Control
var _remove_button: Button
var _duplicate_button: Button
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

	_actions_box = Control.new()
	_actions_box.visible = false
	_actions_box.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_actions_box)
	_remove_button = CodedButton.make("抜く", ACTION_BUTTON_SIZE)
	_remove_button.pressed.connect(_on_remove_pressed)
	_actions_box.add_child(_remove_button)
	_duplicate_button = CodedButton.make_in_group(
		"複製する", ACTION_BUTTON_SIZE, CodedButton.PRIMARY_ACTION_GROUP
	)
	_duplicate_button.pressed.connect(_on_duplicate_pressed)
	_actions_box.add_child(_duplicate_button)

	_skip_button = CodedButton.make("何もしない", SKIP_BUTTON_SIZE)
	_skip_button.pressed.connect(func() -> void: skip_pressed.emit())
	add_child(_skip_button)

	resized.connect(_layout)
	_layout()


func show_data(deck_ids: Array[String]) -> void:
	_deck_ids = deck_ids
	_selected_id = ""
	_rebuild_grid()
	_layout()


func _unique_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _deck_ids:
		if not ids.has(id):
			ids.append(id)
	return ids


func _rebuild_grid() -> void:
	for child in _grid_box.get_children():
		_grid_box.remove_child(child)
		child.queue_free()
	var ids := _unique_ids()
	var inner_w := _grid_box.size.x
	if inner_w <= 0.0:
		return
	var card_w: float = (inner_w - float(COLUMNS - 1) * CARD_GAP) / float(COLUMNS)
	var card_h := card_w * (CardView.HAND_SIZE_PX.y / CardView.HAND_SIZE_PX.x)
	var card_size := Vector2(card_w, card_h)
	for i in ids.size():
		var col := i % COLUMNS
		var row := i / COLUMNS
		var pos := Vector2(float(col) * (card_w + CARD_GAP), float(row) * (card_h + ROW_GAP))
		_build_card(pos, card_size, ids[i])


func _build_card(pos: Vector2, card_size: Vector2, card_id: String) -> void:
	var card := CardLibrary.find_by_id(card_id)
	if card == null:
		return
	var count := _deck_ids.count(card_id)
	var view := CardView.new()
	view.mode = CardView.Mode.HAND
	view.position = pos
	_grid_box.add_child(view)
	view.show_card(card, true)
	view.size = card_size
	if _selected_id == card_id:
		var ring := Control.new()
		ring.position = Vector2(-SELECTED_RING_GAP, -SELECTED_RING_GAP)
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
		view.add_child(ring)
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
	_rebuild_grid()
	_layout()


func _on_remove_pressed() -> void:
	if _selected_id.is_empty():
		return
	card_removed.emit(_selected_id)


func _on_duplicate_pressed() -> void:
	if _selected_id.is_empty():
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
	_grid_box.position = Vector2(GRID_SIDE_MARGIN, GRID_TOP)
	_grid_box.size = Vector2(
		size.x - GRID_SIDE_MARGIN * 2.0, size.y - GRID_TOP - GRID_BOTTOM_MARGIN
	)
	_rebuild_grid()
	_actions_box.visible = not _selected_id.is_empty()
	if _actions_box.visible:
		var index := _unique_ids().find(_selected_id)
		var inner_w := _grid_box.size.x
		var card_w: float = (inner_w - float(COLUMNS - 1) * CARD_GAP) / float(COLUMNS)
		var card_h := card_w * (CardView.HAND_SIZE_PX.y / CardView.HAND_SIZE_PX.x)
		var col := index % COLUMNS
		var row := index / COLUMNS
		var card_pos := (
			_grid_box.position
			+ Vector2(float(col) * (card_w + CARD_GAP), float(row) * (card_h + ROW_GAP))
		)
		var actions_top := card_pos.y + card_h + ACTION_TOP_GAP
		var total_w := ACTION_BUTTON_SIZE.x * 2.0 + ACTION_BUTTON_GAP
		var center_x := card_pos.x + card_w * 0.5
		var duplicate_disabled := _deck_ids.count(_selected_id) >= SoloRun.MAX_DECK_COPIES
		_remove_button.position = Vector2(center_x - total_w * 0.5, actions_top)
		_duplicate_button.position = Vector2(
			center_x - total_w * 0.5 + ACTION_BUTTON_SIZE.x + ACTION_BUTTON_GAP, actions_top
		)
		_duplicate_button.disabled = duplicate_disabled
	_skip_button.position = Vector2(
		(size.x - SKIP_BUTTON_SIZE.x) * 0.5, size.y - SKIP_BOTTOM_MARGIN
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
