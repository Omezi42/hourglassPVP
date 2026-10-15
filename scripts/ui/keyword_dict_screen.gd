class_name KeywordDictScreen
extends Control
## キーワード辞書(GameDesign.md 17章)。左に語の一覧、右に選んだ語の詳細。
## ルール画面が「順に読ませる紙芝居」なのに対し、こちらは語を1つ引きに来る場所。

signal back_pressed

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const CONTENT_HEIGHT := ScreenHeader.CONTENT_HEIGHT
const LIST_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 236, CONTENT_HEIGHT)
const DETAIL_RECT := Rect2(284, ScreenHeader.CONTENT_TOP, 972, CONTENT_HEIGHT)
## 10項目がスクロールなしでコンテンツ領域(560px)へ収まる高さにしてある。
const ITEM_SIZE := Vector2(212, 46)
## 選択中の印。色だけだと真鍮のボタンの上では差が読み取りにくかったため、文字でも示す。
## 記号はフォント(Zen Kaku Gothic New)が持つものだけを使う(▸ は字形が無く豆腐になる)。
const SELECTED_PREFIX := "◆ "
const DETAIL_MARGIN := 22
## 詳細の中身の幅。実演(520px)と説明文が収まる値で、パネルの中央へ置く。
const ENTRY_WIDTH := 640.0

## 縦画面(GameDesign.md 9章「縦画面」)。語のボタンを上に2列で並べ、その下に詳細を画面の幅で出す。
const PORTRAIT_COLUMNS := 2
const PORTRAIT_ITEM_HEIGHT := 72.0
const PORTRAIT_ITEM_GAP := 8.0
const PORTRAIT_BUTTON_FONT := 24
const PORTRAIT_SECTION_GAP := 16.0
const PORTRAIT_BODY_FONT := 24
const PORTRAIT_CAPTION_FONT := 20
const PORTRAIT_TITLE_FONT := 36

var _entry_view: KeywordEntryView
var _buttons: Array[Button] = []
var _entries: Array[Dictionary] = []
var _header: ScreenHeader
var _scroll: ScrollContainer
var _column: VBoxContainer
var _grid: GridContainer
var _panel: PanelContainer


func _ready() -> void:
	_build()
	# 開いた直後に詳細が空のまま置かれないよう、先頭の語を選んでおく。
	if not _entries.is_empty():
		_select(0)


func _build() -> void:
	var backdrop := ScreenBackdrop.new()
	backdrop.room = ScreenBackdrop.Room.LIBRARY
	add_child(backdrop)

	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	_header = header
	header.set_title("キーワード辞書")
	header.back_pressed.connect(func() -> void: back_pressed.emit())

	var scroll := ScrollContainer.new()
	scroll.position = LIST_RECT.position
	scroll.size = LIST_RECT.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.enable(scroll)
	add_child(scroll)
	_scroll = scroll
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	_column = column
	# 縦では語のボタンをこのグリッドへ移して2列に並べる(VBoxは向きを変えられないため)。
	_grid = GridContainer.new()
	_grid.columns = PORTRAIT_COLUMNS
	_grid.add_theme_constant_override("h_separation", int(PORTRAIT_ITEM_GAP))
	_grid.add_theme_constant_override("v_separation", int(PORTRAIT_ITEM_GAP))
	_grid.visible = false
	add_child(_grid)

	_entries = KeywordEntries.all_entries()
	for i in _entries.size():
		var entry := _entries[i]
		var button := CodedButton.make(_item_label(entry, false), ITEM_SIZE)
		button.pressed.connect(_select.bind(i))
		column.add_child(button)
		_buttons.append(button)

	var panel := PanelContainer.new()
	panel.position = DETAIL_RECT.position
	panel.size = DETAIL_RECT.size
	panel.custom_minimum_size = DETAIL_RECT.size
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	_panel = panel

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, DETAIL_MARGIN)
	panel.add_child(margin)

	# 詳細の中身(語・説明・実演・砂時計)は実演の幅で決まるため、パネルより狭い。
	# 左へ寄せると右半分がまるごと空いて見えるので、パネルの中央へ置く。
	var center := HBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(center)

	_entry_view = KeywordEntryView.new()
	_entry_view.custom_minimum_size = Vector2(ENTRY_WIDTH, 0)
	_entry_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_entry_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(_entry_view)


## 縦横が変わったときに `Main` から呼ばれる(Architecture.md 4.7節)。選んでいる語は保つ。
func apply_orientation(portrait: bool) -> void:
	if _header == null:
		return
	_header.apply_orientation(portrait)
	var holder: Container = _grid if portrait else _column
	var content := _header.portrait_content_rect()
	var item_w := (content.size.x - PORTRAIT_ITEM_GAP) / PORTRAIT_COLUMNS
	for button in _buttons:
		button.get_parent().remove_child(button)
		holder.add_child(button)
		button.custom_minimum_size = (
			Vector2(item_w, PORTRAIT_ITEM_HEIGHT) if portrait else ITEM_SIZE
		)
		if portrait:
			button.add_theme_font_size_override("font_size", PORTRAIT_BUTTON_FONT)
		else:
			button.remove_theme_font_size_override("font_size")
	_grid.visible = portrait
	_scroll.visible = not portrait
	var detail := DETAIL_RECT
	if portrait:
		var rows := ceili(float(_buttons.size()) / PORTRAIT_COLUMNS)
		var list_h := rows * PORTRAIT_ITEM_HEIGHT + (rows - 1) * PORTRAIT_ITEM_GAP
		_grid.position = content.position
		_grid.size = Vector2(content.size.x, list_h)
		var top := content.position.y + list_h + PORTRAIT_SECTION_GAP
		detail = Rect2(content.position.x, top, content.size.x, content.end.y - top)
	_panel.position = detail.position
	_panel.custom_minimum_size = detail.size
	_panel.size = detail.size
	var inner := detail.size.x - DETAIL_MARGIN * 2.0
	_entry_view.custom_minimum_size.x = inner if portrait else ENTRY_WIDTH
	_entry_view.set_layout(
		KeywordEntryView.PREVIEW_WIDTH,
		PORTRAIT_BODY_FONT if portrait else KeywordEntryView.BODY_FONT_SIZE,
		PORTRAIT_CAPTION_FONT if portrait else KeywordEntryView.CAPTION_FONT_SIZE,
		PORTRAIT_TITLE_FONT if portrait else KeywordEntryView.TITLE_FONT_SIZE
	)


func _select(index: int) -> void:
	for i in _buttons.size():
		var selected: bool = i == index
		_buttons[i].text = _item_label(_entries[i], selected)
		_buttons[i].add_theme_color_override(
			"font_color", UiPalette.GLOW_AMBER if selected else UiPalette.TEXT_OFFWHITE
		)
	_entry_view.show_entry(_entries[index])


static func _item_label(entry: Dictionary, selected: bool) -> String:
	var prefix: String = SELECTED_PREFIX if selected else ""
	return "%s%s(%s)" % [prefix, KeywordEntries.title(entry), KeywordEntries.category(entry)]
