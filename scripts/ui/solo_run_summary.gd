class_name SoloRunSummary
extends Control
## 遠征(ソロモード)の記録(GameDesign.md 27章「画面」)。遠征が終わったあと、
## 次に遠征の画面を開いたとき1度だけ出す。押せない道(`SoloRouteView.show_record()`)と
## 最後の山札を並べ、「出発へ」で閉じる。

signal departure_pressed

const SCREEN_SIZE := Vector2(1280, 720)
const DIM_COLOR := Color(0, 0, 0, 0.82)
const CONTENT_TOP := 96.0
const CONTENT_MARGIN := 64.0
const ROUTE_RATIO := 0.62
const PANEL_GAP := 32.0
const TITLE_FONT_SIZE := 34
const NAME_FONT_SIZE := 18
const STATS_FONT_SIZE := 16
const NOTE_FONT_SIZE := 15
const DECK_LABEL_FONT_SIZE := 15
const DECK_PANEL_PADDING := 20.0
const BUTTON_SIZE := Vector2(200, 52)
const HEADER_GAP := 74.0
const NAME_GAP := 34.0
const STATS_GAP := 26.0
const NOTE_GAP := 30.0
const ROUTE_TOP_GAP := 20.0
const ROUTE_BOTTOM_MARGIN := 110.0

var _dim: ColorRect
var _title: Label
var _name_label: Label
var _stats_label: Label
var _note_label: Label
var _route: SoloRouteView
var _deck_panel_canvas: Control
var _deck_label: Label
var _deck_list: SoloDeckList
var _button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = SCREEN_SIZE
	visible = false
	_dim = ColorRect.new()
	_dim.color = DIM_COLOR
	_dim.size = SCREEN_SIZE
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_title = _label(TITLE_FONT_SIZE, UiPalette.TEXT_OFFWHITE, true)
	add_child(_title)
	_name_label = _label(NAME_FONT_SIZE, UiPalette.BRASS_HIGHLIGHT)
	add_child(_name_label)
	_stats_label = _label(STATS_FONT_SIZE, UiPalette.TEXT_MUTED)
	add_child(_stats_label)
	_note_label = _label(NOTE_FONT_SIZE, UiPalette.TEXT_MUTED)
	_note_label.visible = false
	add_child(_note_label)
	_route = SoloRouteView.new()
	add_child(_route)
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
	_button = CodedButton.make_in_group("出発へ", BUTTON_SIZE, CodedButton.PRIMARY_ACTION_GROUP)
	_button.pressed.connect(
		func() -> void:
			visible = false
			departure_pressed.emit()
	)
	add_child(_button)
	resized.connect(_layout)
	_layout()


## `SoloProgress.take_finished()`の中身をそのまま渡す。
func open(finished: Dictionary) -> void:
	var run := SoloRun.from_dict(finished.get("run", {}))
	var reason := str(finished.get("reason", ""))
	_title.text = "踏破" if run.cleared else "遠征の終わり"
	_name_label.text = (
		"作戦「%s」 ・ %d勝 / %d段" % [CardCpuDecks.name_of(run.theme_id), run.wins, SoloRun.FLOOR_COUNT]
	)
	_stats_label.text = "残りHP %d ・ 持っている恩恵: %s" % [run.hp, _boon_names(run.boons)]
	var lost_floor := -1 if run.cleared else run.floor
	_route.show_record(run.route, run.chosen, lost_floor)
	_deck_label.text = "最後の山札 %d枚" % run.deck_ids.size()
	_deck_list.show_data(run.deck_ids)
	_note_label.visible = reason == "abandoned_mid_battle"
	if _note_label.visible:
		_note_label.text = "対局の途中で抜けたため、遠征は終わりました"
	visible = true
	_layout()


func _boon_names(boons: Array[String]) -> String:
	if boons.is_empty():
		return "なし"
	var names: Array[String] = []
	for id in boons:
		var boon := SoloBoonLibrary.find_by_id(id)
		if boon != null:
			names.append(boon.display_name)
	return "、".join(names)


func _layout() -> void:
	if _dim == null:
		return
	_dim.size = size
	var content_w := size.x - CONTENT_MARGIN * 2.0
	var top := CONTENT_TOP
	_title.position = Vector2(CONTENT_MARGIN, top)
	_title.size = Vector2(content_w, 40.0)
	top += HEADER_GAP
	_name_label.position = Vector2(CONTENT_MARGIN, top)
	_name_label.size = Vector2(content_w, 24.0)
	top += NAME_GAP
	_stats_label.position = Vector2(CONTENT_MARGIN, top)
	_stats_label.size = Vector2(content_w, 22.0)
	top += STATS_GAP
	if _note_label.visible:
		_note_label.position = Vector2(CONTENT_MARGIN, top)
		_note_label.size = Vector2(content_w, 20.0)
		top += NOTE_GAP
	top += ROUTE_TOP_GAP
	var route_w := content_w * ROUTE_RATIO - PANEL_GAP * 0.5
	var deck_w := content_w * (1.0 - ROUTE_RATIO) - PANEL_GAP * 0.5
	var area_h := size.y - ROUTE_BOTTOM_MARGIN - top
	_route.position = Vector2(CONTENT_MARGIN, top)
	_route.size = Vector2(route_w, area_h)
	var deck_rect := Rect2(CONTENT_MARGIN + route_w + PANEL_GAP, top, deck_w, area_h)
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
	_button.position = Vector2((size.x - BUTTON_SIZE.x) * 0.5, size.y - ROUTE_BOTTOM_MARGIN * 0.55)


func _label(font_size: int, color: Color, display := false) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.visible = true
	if display:
		label.add_theme_font_override("font", UiFonts.display_font(label.get_theme_default_font()))
	return label
