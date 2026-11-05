class_name CardDeckIntroScreen
extends Control
## みんなのデッキ(GameDesign.md 26章 / Architecture.md 10.14節)。#デッキ紹介 に紹介されたデッキを
## 新しい順に並べ、1件を開くと30枚の棚とコメントの全文、「デッキに追加」を出す。
## デッキ一覧(`CardDeckListScreen`)の上へ重ねて開く。閉じると `closed` を出す。

signal closed
## 1件をデッキ一覧へ足した。一覧の側が並びを描き直すのに使う。
signal deck_added

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const EMPTY_INSET := Vector2(40.0, 56.0)
const LIST_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 1232, ScreenHeader.CONTENT_HEIGHT)
const CARD_SIZE := Vector2(596, 132)
const PORTRAIT_CARD_SIZE := Vector2(624, 172)
const EMBLEM_COUNT := 5
const EMBLEM_SIZE := Vector2(34, 34)
const PORTRAIT_EMBLEM_SIZE := Vector2(44, 44)
const NAME_FONT := 24
const META_FONT := 15
const COMMENT_FONT := 15
const GUIDE_FONT := 20
const PORTRAIT_NAME_FONT := 30
const PORTRAIT_META_FONT := 22
const PORTRAIT_COMMENT_FONT := 22
const PORTRAIT_GUIDE_FONT := 24
## 札のコメントは2行まで(超えたら「…」。GameDesign.md 26章)。
const COMMENT_LINES := 2
const PANEL_INNER_MARGIN := 48.0

## 詳細: 左に棚、右にコメントと「デッキに追加」。
const SHELF_SIZE := Vector2(720, 500)
const SIDE_WIDTH := 440.0
const DETAIL_FONT := 18
const ADD_BUTTON_SIZE := Vector2(260, 60)
## 縦の詳細は棚を上、コメントを下へ積む。
const PORTRAIT_SHELF_HEIGHT := 600.0
const PORTRAIT_DETAIL_FONT := 24
const PORTRAIT_ADD_BUTTON_SIZE := Vector2(360, 76)
const PORTRAIT_SHELF_TEXT_SCALE := 1.4
const SECONDS_PER_MINUTE := 60

var _header: ScreenHeader
var _panel: PanelContainer
var _list_view: VBoxContainer
var _guide: Label
var _grid: GridContainer
var _empty_state: EmptyState
var _detail_view: BoxContainer
var _shelf: CardDeckShelf
var _detail_meta: Label
var _detail_comment: Label
var _add_button: Button
var _add_result: Label
var _intros: Array = []
## 開いている1件。-1 なら一覧。
var _opened := -1
var _portrait := false
## 読み込みの世代。開き直したときに古い読み込みの結果を捨てる。
var _load_serial := 0
## 読み込み中・失敗のあいだ一覧の代わりに出す見出し。読めたら空。
var _status := ""
var _status_waiting := false


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build()
	visible = false


func open() -> void:
	visible = true
	_opened = -1
	_intros = []
	_set_status("読み込んでいます", true)
	_load_serial += 1
	var serial := _load_serial
	var loaded: Variant = null
	if await NetSession.sign_in():
		loaded = await DeckIntroService.fetch_recent(NetSession.client)
	if serial != _load_serial or not is_inside_tree():
		return
	if not (loaded is Array):
		_set_status("読み込めませんでした", false)
		return
	_intros = loaded
	_set_status("", false)


func _set_status(text: String, waiting: bool) -> void:
	_status = text
	_status_waiting = waiting
	_fill_list()


func apply_orientation(portrait: bool) -> void:
	_portrait = portrait
	if _panel == null:
		return
	_header.apply_orientation(portrait)
	_layout()
	if visible:
		if _opened >= 0:
			_show_detail(_opened)
		else:
			_fill_list()


func _build() -> void:
	var backdrop := ScreenBackdrop.new()
	backdrop.room = ScreenBackdrop.Room.HALL
	add_child(backdrop)

	_header = load(HEADER_SCENE).instantiate()
	add_child(_header)
	_header.back_pressed.connect(_on_back)

	_panel = PanelContainer.new()
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var stack := Control.new()
	_panel.add_child(stack)

	_list_view = VBoxContainer.new()
	_list_view.anchor_right = 1.0
	_list_view.anchor_bottom = 1.0
	stack.add_child(_list_view)
	_guide = Label.new()
	_guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list_view.add_child(_guide)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.enable(scroll)
	_list_view.add_child(scroll)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	_detail_view = BoxContainer.new()
	_detail_view.anchor_right = 1.0
	_detail_view.anchor_bottom = 1.0
	_detail_view.add_theme_constant_override("separation", 24)
	stack.add_child(_detail_view)
	_shelf = CardDeckShelf.new()
	_shelf.readonly = true
	_detail_view.add_child(_shelf)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 16)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_view.add_child(side)
	_detail_meta = Label.new()
	_detail_meta.add_theme_color_override("font_color", UiPalette.BRASS_HIGHLIGHT)
	side.add_child(_detail_meta)
	_detail_comment = Label.new()
	_detail_comment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_detail_comment)
	_add_button = CodedButton.make("デッキに追加", ADD_BUTTON_SIZE)
	_add_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_add_button.pressed.connect(_on_add_pressed)
	side.add_child(_add_button)
	_add_result = Label.new()
	_add_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_add_result)

	_empty_state = EmptyState.new()
	_empty_state.visible = false
	add_child(_empty_state)
	_layout()


func _layout() -> void:
	var rect := LIST_RECT
	if _portrait:
		var top := _header.portrait_content_top()
		rect = Rect2(
			ScreenHeader.OUTER_MARGIN,
			top,
			ScreenOrientation.PORTRAIT_SIZE.x - ScreenHeader.OUTER_MARGIN * 2.0,
			ScreenHeader.PORTRAIT_CONTENT_BOTTOM - top
		)
	_panel.position = rect.position
	_panel.custom_minimum_size = rect.size
	_panel.size = rect.size
	_empty_state.position = rect.position + EMPTY_INSET
	_empty_state.size = rect.size - EMPTY_INSET * 2.0
	_guide.add_theme_font_size_override(
		"font_size", PORTRAIT_GUIDE_FONT if _portrait else GUIDE_FONT
	)
	# 折り返す行には幅を与える(幅が決まる前の1文字ずつの高さが残るため。Pitfalls.md)。
	_guide.custom_minimum_size.x = rect.size.x - PANEL_INNER_MARGIN
	_grid.columns = 1 if _portrait else 2

	_detail_view.vertical = _portrait
	var inner_width := rect.size.x - PANEL_INNER_MARGIN
	_shelf.custom_minimum_size = (
		Vector2(inner_width, PORTRAIT_SHELF_HEIGHT) if _portrait else SHELF_SIZE
	)
	_shelf.text_scale = PORTRAIT_SHELF_TEXT_SCALE if _portrait else 1.0
	var side_width := inner_width if _portrait else SIDE_WIDTH
	var detail_font := PORTRAIT_DETAIL_FONT if _portrait else DETAIL_FONT
	for label: Label in [_detail_meta, _detail_comment, _add_result]:
		label.add_theme_font_size_override("font_size", detail_font)
		label.custom_minimum_size.x = side_width
	_add_button.custom_minimum_size = PORTRAIT_ADD_BUTTON_SIZE if _portrait else ADD_BUTTON_SIZE


# --- 一覧 ---------------------------------------------------------------


func _show_list() -> void:
	_opened = -1
	_header.set_title("みんなのデッキ")
	_list_view.visible = true
	_detail_view.visible = false
	_guide.text = ""
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()


func _fill_list() -> void:
	_show_list()
	if not _status.is_empty():
		_empty_state.show_message(_status, "", _status_waiting)
		return
	if _intros.is_empty():
		_empty_state.show_message("まだ紹介されたデッキがありません")
		return
	_empty_state.hide_message()
	_guide.text = "Discordの #デッキ紹介 に紹介されたデッキ"
	for i in _intros.size():
		_grid.add_child(_make_card(i, _intros[i]))
	ListRevealFx.stagger(_grid.get_children())


func _make_card(index: int, intro: Dictionary) -> Control:
	var area := ClickArea.new()
	area.custom_minimum_size = PORTRAIT_CARD_SIZE if _portrait else CARD_SIZE
	area.area_pressed.connect(func() -> void: _show_detail(index))
	var panel := PanelContainer.new()
	panel.name = "VisualRoot"
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	area.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_column)
	text_column.add_child(
		_label(String(intro["name"]), PORTRAIT_NAME_FONT if _portrait else NAME_FONT)
	)
	var meta := _label(_meta_text(intro), PORTRAIT_META_FONT if _portrait else META_FONT)
	meta.add_theme_color_override("font_color", UiPalette.BRASS_HIGHLIGHT)
	text_column.add_child(meta)
	var comment_text := String(intro["comment"])
	if not comment_text.is_empty():
		var comment := Label.new()
		comment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		comment.max_lines_visible = COMMENT_LINES
		comment.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		comment.add_theme_font_size_override(
			"font_size", PORTRAIT_COMMENT_FONT if _portrait else COMMENT_FONT
		)
		comment.text = comment_text
		comment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_column.add_child(comment)
	row.add_child(_make_emblems(intro["cards"]))
	return area


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## 使っているカードのうちコストの高い5種(デッキ一覧の札と同じ選び方)。
func _make_emblems(cards: Array) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var distinct: Array = []
	for card in cards:
		if not distinct.has(card):
			distinct.append(card)
	distinct.sort_custom(func(a: CardData, b: CardData) -> bool: return a.cost > b.cost)
	for card: CardData in distinct.slice(0, EMBLEM_COUNT):
		var icon := TextureRect.new()
		icon.texture = card.emblem if card.emblem != null else card.icon_upright
		icon.custom_minimum_size = PORTRAIT_EMBLEM_SIZE if _portrait else EMBLEM_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = UiPalette.BRASS_HIGHLIGHT
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
	return box


## 「紹介した人 ・ 紹介した日」。日付は端末の時差で直す。
func _meta_text(intro: Dictionary) -> String:
	var bias_seconds := int(Time.get_time_zone_from_system().get("bias", 0)) * SECONDS_PER_MINUTE
	var date := Time.get_date_dict_from_unix_time(int(intro["created_at"]) + bias_seconds)
	return (
		"%s ・ %d/%d/%d" % [String(intro["author_name"]), date["year"], date["month"], date["day"]]
	)


# --- 詳細 ---------------------------------------------------------------


func _show_detail(index: int) -> void:
	if index < 0 or index >= _intros.size():
		return
	_opened = index
	var intro: Dictionary = _intros[index]
	_header.set_title(String(intro["name"]))
	_list_view.visible = false
	_empty_state.hide_message()
	_detail_view.visible = true
	_shelf.deck = intro["cards"]
	_detail_meta.text = _meta_text(intro)
	_detail_comment.text = String(intro["comment"])
	_detail_comment.visible = not _detail_comment.text.is_empty()
	_add_button.disabled = false
	_add_result.text = ""


func _on_add_pressed() -> void:
	if _opened < 0:
		return
	var intro: Dictionary = _intros[_opened]
	CardDeckSave.add_deck(String(intro["name"]), intro["cards"])
	_add_button.disabled = true
	_add_result.text = "「%s」を追加しました" % intro["name"]
	deck_added.emit()


func _on_back() -> void:
	if _opened >= 0:
		_fill_list()
		return
	_load_serial += 1
	visible = false
	closed.emit()
