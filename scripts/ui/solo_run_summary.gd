class_name SoloRunSummary
extends Control
## 遠征(ソロモード)の記録(GameDesign.md 27章「画面」)。遠征が終わったあと、
## 次に遠征の画面を開いたとき1度だけ出す。押せない道(`SoloRouteView.show_record()`)と
## 最後の山札を並べ、「出発へ」で閉じる。縦画面では道(`SoloRouteView.vertical`)と山札を
## 上下に積み、文字とボタンを縦の大きさにする(GameDesign.md 9章「縦画面」)。道を描き直す
## 大きさが要るため、他の重ね画面と違って中身ごとは拡大しない。

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

## 縦画面の配置(720x1280 の座標)。
const PORTRAIT_CONTENT_TOP := 56.0
const PORTRAIT_MARGIN := 24.0
const PORTRAIT_TEXT_FONT_SIZE := 24
const PORTRAIT_NOTE_FONT_SIZE := 22
const PORTRAIT_HEADER_GAP := 64.0
const PORTRAIT_NAME_GAP := 40.0
const PORTRAIT_STATS_HEIGHT := 64.0
const PORTRAIT_STATS_GAP := 72.0
const PORTRAIT_NOTE_GAP := 38.0
const PORTRAIT_ROUTE_HEIGHT := 660.0
const PORTRAIT_PANEL_GAP := 16.0
const PORTRAIT_DECK_LABEL_HEIGHT := 32.0
const PORTRAIT_DECK_LIST_ZOOM := 1.4
const PORTRAIT_BUTTON_SIZE := Vector2(280, 72)
const PORTRAIT_BOTTOM_MARGIN := 32.0

var portrait := false

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
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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


## 縦横を切り替える(`CardSoloMapScreen.apply_orientation()` から呼ぶ)。中身は保つ。
func set_portrait(value: bool) -> void:
	portrait = value
	_route.vertical = value
	_layout()


## `SoloProgress.take_finished()`の中身をそのまま渡す。
func open(finished: Dictionary) -> void:
	var run := SoloRun.from_dict(finished.get("run", {}))
	var reason := str(finished.get("reason", ""))
	_title.text = "踏破" if run.cleared else "遠征の終わり"
	var depth_part := " ・ 深さ%d" % run.depth if run.depth > 0 else ""
	_name_label.text = (
		"作戦「%s」%s ・ %d勝 / %d段"
		% [CardCpuDecks.name_of(run.theme_id), depth_part, run.wins, SoloRun.FLOOR_COUNT]
	)
	_stats_label.text = "残りHP %d ・ 持っている恩恵: %s" % [run.hp, _boon_names(run.boons)]
	var lost_floor := -1 if run.cleared else run.floor
	_route.show_record(
		run.route, run.chosen, lost_floor, run.expert_from_floor(), run.spring_amount()
	)
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
	if portrait:
		_layout_portrait()
	else:
		_layout_landscape()
	# 道は大きさが変わっても自分では置き直さないため、ここで駒を置き直す。
	_route.relayout()


func _layout_landscape() -> void:
	_apply_font_sizes()
	_deck_list.scale = Vector2.ONE
	_set_button_size(BUTTON_SIZE)
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
	_place_deck_panel(Rect2(CONTENT_MARGIN + route_w + PANEL_GAP, top, deck_w, area_h), 22.0)
	_button.position = Vector2((size.x - BUTTON_SIZE.x) * 0.5, size.y - ROUTE_BOTTOM_MARGIN * 0.55)


## 縦: 見出し / 作戦と勝ち数 / HPと恩恵 / 道 / 最後の山札 / 「出発へ」の順に上から積む。
func _layout_portrait() -> void:
	_apply_font_sizes()
	_deck_list.scale = Vector2.ONE * PORTRAIT_DECK_LIST_ZOOM
	_set_button_size(PORTRAIT_BUTTON_SIZE)
	var content_w := size.x - PORTRAIT_MARGIN * 2.0
	var top := PORTRAIT_CONTENT_TOP
	_title.position = Vector2(PORTRAIT_MARGIN, top)
	_title.size = Vector2(content_w, 48.0)
	top += PORTRAIT_HEADER_GAP
	_name_label.position = Vector2(PORTRAIT_MARGIN, top)
	_name_label.size = Vector2(content_w, 32.0)
	top += PORTRAIT_NAME_GAP
	_stats_label.position = Vector2(PORTRAIT_MARGIN, top)
	_stats_label.size = Vector2(content_w, PORTRAIT_STATS_HEIGHT)
	top += PORTRAIT_STATS_GAP
	if _note_label.visible:
		_note_label.position = Vector2(PORTRAIT_MARGIN, top)
		_note_label.size = Vector2(content_w, 30.0)
		top += PORTRAIT_NOTE_GAP
	_route.position = Vector2(PORTRAIT_MARGIN, top)
	_route.size = Vector2(content_w, PORTRAIT_ROUTE_HEIGHT)
	var button_top := size.y - PORTRAIT_BOTTOM_MARGIN - PORTRAIT_BUTTON_SIZE.y
	var deck_top := top + PORTRAIT_ROUTE_HEIGHT + PORTRAIT_PANEL_GAP
	_place_deck_panel(
		Rect2(PORTRAIT_MARGIN, deck_top, content_w, button_top - PORTRAIT_PANEL_GAP - deck_top),
		PORTRAIT_DECK_LABEL_HEIGHT
	)
	_button.position = Vector2((size.x - PORTRAIT_BUTTON_SIZE.x) * 0.5, button_top)


## 山札の欄。一覧は `_deck_list.scale` を掛けたあとの見た目の大きさで欄へ収める。
func _place_deck_panel(deck_rect: Rect2, label_height: float) -> void:
	_deck_panel_canvas.position = deck_rect.position
	_deck_panel_canvas.size = deck_rect.size
	_deck_label.position = deck_rect.position + Vector2(DECK_PANEL_PADDING, DECK_PANEL_PADDING)
	_deck_label.size = Vector2(deck_rect.size.x - DECK_PANEL_PADDING * 2.0, label_height)
	var deck_list_top := deck_rect.position.y + DECK_PANEL_PADDING + label_height + 8.0
	_deck_list.position = Vector2(deck_rect.position.x + DECK_PANEL_PADDING, deck_list_top)
	_deck_list.size = (
		Vector2(
			deck_rect.size.x - DECK_PANEL_PADDING * 2.0,
			deck_rect.end.y - DECK_PANEL_PADDING - deck_list_top
		)
		/ _deck_list.scale.x
	)


func _apply_font_sizes() -> void:
	var pairs := [
		[_name_label, NAME_FONT_SIZE, PORTRAIT_TEXT_FONT_SIZE],
		[_stats_label, STATS_FONT_SIZE, PORTRAIT_TEXT_FONT_SIZE],
		[_note_label, NOTE_FONT_SIZE, PORTRAIT_NOTE_FONT_SIZE],
		[_deck_label, DECK_LABEL_FONT_SIZE, PORTRAIT_TEXT_FONT_SIZE],
	]
	for pair in pairs:
		var label: Label = pair[0]
		label.add_theme_font_size_override("font_size", pair[2] if portrait else pair[1])


func _set_button_size(button_size: Vector2) -> void:
	_button.custom_minimum_size = button_size
	_button.size = button_size


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
