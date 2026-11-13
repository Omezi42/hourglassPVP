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
## 13項目(13 x 39 + 12 x 4 = 555px)がスクロールなしでコンテンツ領域(560px)へ収まる高さ。
const ITEM_SIZE := Vector2(212, 39)
const LIST_SEPARATION := 4
## 選択中の印。色だけだと真鍮のボタンの上では差が読み取りにくかったため、形でも示す。
## 記号はフォント(Zen Kaku Gothic New)が持つものだけを使う(▸ は字形が無く豆腐になる)。
const SELECTED_MARK := "◆"
const MARK_FONT := 12
const MARK_LEFT := 10.0
const PORTRAIT_MARK_FONT := 16
const PORTRAIT_MARK_LEFT := 20.0
## 印が入るときに、左からこれだけ滑り込む。
const MARK_SLIDE := 6.0
## 詳細パネルの余白。パネルの面が持つ内側の余白は外し、ここだけで決める。
const DETAIL_MARGIN_X := 24
const DETAIL_MARGIN_Y := 16
## 詳細の中身の幅。実演(520px)と説明文が収まる値で、パネルの中央へ置く。
const ENTRY_WIDTH := 640.0

## 縦画面(GameDesign.md 9章「縦画面」)。語のボタンを上に2列で並べ、その下に詳細を画面の幅で出す。
const PORTRAIT_COLUMNS := 2
const PORTRAIT_ITEM_HEIGHT := 72.0
const PORTRAIT_ITEM_GAP := 8.0
const PORTRAIT_BUTTON_FONT := 24
const PORTRAIT_SECTION_GAP := 16.0
const PORTRAIT_BODY_FONT := 24
const PORTRAIT_CAPTION_FONT := UiPalette.T_LEAD
const PORTRAIT_TITLE_FONT := UiPalette.T_TITLE

var _entry_view: KeywordEntryView
var _buttons: Array[Button] = []
var _marks: Array[Label] = []
var _entries: Array[Dictionary] = []
var _header: ScreenHeader
var _scroll: ScrollContainer
var _column: VBoxContainer
var _grid: GridContainer
var _panel: PanelContainer
var _detail_scroll: ScrollContainer
var _selected := -1
var _portrait := false
var _mark_tween: Tween
var _entry_tween: Tween


func _ready() -> void:
	_build()
	# 開いた直後に詳細が空のまま置かれないよう、先頭の語を選んでおく。
	if not _entries.is_empty():
		_select(0, false)


## 出すたびに文字の大きさの設定を読み直し、語のボタンを順に出す。
func _notification(what: int) -> void:
	if what != NOTIFICATION_VISIBILITY_CHANGED or _buttons.is_empty() or not is_visible_in_tree():
		return
	apply_orientation(_portrait)
	ListRevealFx.stagger(_buttons)


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
	column.add_theme_constant_override("separation", LIST_SEPARATION)
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
		var button := CodedButton.make(_item_label(entry), ITEM_SIZE)
		button.pressed.connect(_select.bind(i))
		column.add_child(button)
		_buttons.append(button)
		_marks.append(_make_mark(button))

	var panel := PanelContainer.new()
	panel.position = DETAIL_RECT.position
	panel.size = DETAIL_RECT.size
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		style = style.duplicate()
		for side in ["left", "right", "top", "bottom"]:
			style.set("content_margin_" + side, 0.0)
		panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	_panel = panel

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", DETAIL_MARGIN_X)
	margin.add_theme_constant_override("margin_right", DETAIL_MARGIN_X)
	margin.add_theme_constant_override("margin_top", DETAIL_MARGIN_Y)
	margin.add_theme_constant_override("margin_bottom", DETAIL_MARGIN_Y)
	panel.add_child(margin)

	# 中身が高さを超えたぶんはパネルの中で縦に送る(パネルを押し広げない)。
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.enable(_detail_scroll)
	margin.add_child(_detail_scroll)

	# 詳細の中身(語・説明・実演・砂時計)は実演の幅で決まるため、パネルより狭い。
	# 左へ寄せると右半分がまるごと空いて見えるので、パネルの中央へ置く。
	var center := HBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.add_child(center)

	_entry_view = KeywordEntryView.new()
	_entry_view.custom_minimum_size = Vector2(ENTRY_WIDTH, 0)
	_entry_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_entry_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(_entry_view)


## 縦横が変わったときに `Main` から呼ばれる(Architecture.md 4.7節)。選んでいる語は保つ。
## 文字の大きさの設定(`TextSize`)もここで読む。
func apply_orientation(portrait: bool) -> void:
	_portrait = portrait
	if _header == null:
		return
	_header.apply_orientation(portrait)
	var factor := TextSize.factor()
	var holder: Container = _grid if portrait else _column
	var content := _header.portrait_content_rect()
	var item_w := (content.size.x - PORTRAIT_ITEM_GAP) / PORTRAIT_COLUMNS
	var item_size := Vector2(item_w, PORTRAIT_ITEM_HEIGHT) if portrait else ITEM_SIZE
	for i in _buttons.size():
		var button := _buttons[i]
		if button.get_parent() != holder:
			button.get_parent().remove_child(button)
			holder.add_child(button)
		button.custom_minimum_size = item_size
		if portrait:
			button.add_theme_font_size_override("font_size", _scaled(PORTRAIT_BUTTON_FONT, factor))
		else:
			button.remove_theme_font_size_override("font_size")
		_fit_mark(_marks[i], item_size.y, portrait)
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
	# 中身の最小幅を先に決める。パネルの最小幅が大きいうちに size を代入すると、
	# 後から中身が狭まっても広がったまま残る(Pitfalls.md)。
	# 縦送りの帯が出ても中身が帯の下へ潜らないよう、その幅を引いておく。
	var inner := detail.size.x - DETAIL_MARGIN_X * 2.0
	var bar := _detail_scroll.get_v_scroll_bar().get_combined_minimum_size().x
	_entry_view.custom_minimum_size.x = inner - bar if portrait else ENTRY_WIDTH
	_entry_view.set_layout(
		KeywordEntryView.PREVIEW_WIDTH,
		_scaled(PORTRAIT_BODY_FONT if portrait else KeywordEntryView.BODY_FONT_SIZE, factor),
		_scaled(PORTRAIT_CAPTION_FONT if portrait else KeywordEntryView.CAPTION_FONT_SIZE, factor),
		_scaled(PORTRAIT_TITLE_FONT if portrait else KeywordEntryView.TITLE_FONT_SIZE, factor)
	)
	_panel.position = detail.position
	_panel.size = detail.size


func _select(index: int, animate := true) -> void:
	if index == _selected:
		return
	var previous := _selected
	_selected = index
	for i in _buttons.size():
		_buttons[i].add_theme_color_override(
			"font_color", UiPalette.SAND_HI if i == index else UiPalette.IVORY
		)
	if previous >= 0:
		_marks[previous].visible = false
	_show_mark(_marks[index], animate)
	_entry_view.show_entry(_entries[index], animate)
	_detail_scroll.scroll_vertical = 0
	if animate:
		_fade_in_entry()


func _fade_in_entry() -> void:
	if _entry_tween != null and _entry_tween.is_valid():
		_entry_tween.kill()
	_entry_view.modulate.a = 0.0
	_entry_tween = create_tween()
	_entry_tween.tween_property(_entry_view, "modulate:a", 1.0, UiPalette.DUR_HOVER).set_ease(
		Tween.EASE_OUT
	)


func _show_mark(mark: Label, animate: bool) -> void:
	if _mark_tween != null and _mark_tween.is_valid():
		_mark_tween.kill()
	var base_x := PORTRAIT_MARK_LEFT if _portrait else MARK_LEFT
	mark.visible = true
	mark.modulate.a = 1.0
	mark.position.x = base_x
	if not animate:
		return
	mark.modulate.a = 0.0
	mark.position.x = base_x - MARK_SLIDE
	_mark_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT)
	_mark_tween.tween_property(mark, "modulate:a", 1.0, UiPalette.DUR_HOVER)
	_mark_tween.tween_property(mark, "position:x", base_x, UiPalette.DUR_HOVER)


## 選んでいる語の印。文字列へ混ぜると語の位置がずれるため、ボタンの子として固定の位置へ置く。
static func _make_mark(button: Button) -> Label:
	var mark := Label.new()
	mark.text = SELECTED_MARK
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_theme_color_override("font_color", UiPalette.SAND_HI)
	mark.visible = false
	button.add_child(mark)
	return mark


static func _fit_mark(mark: Label, height: float, portrait: bool) -> void:
	var font := PORTRAIT_MARK_FONT if portrait else MARK_FONT
	mark.add_theme_font_size_override("font_size", font)
	mark.position = Vector2(PORTRAIT_MARK_LEFT if portrait else MARK_LEFT, 0.0)
	mark.size = Vector2(font * 2.0, height)


static func _scaled(base: int, factor: float) -> int:
	return floori(base * factor)


static func _item_label(entry: Dictionary) -> String:
	return "%s(%s)" % [KeywordEntries.title(entry), KeywordEntries.category(entry)]
