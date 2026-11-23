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
## 13項目+小見出し2本+分類の間の空き(13 x 34 + 2 x 22 + 8 + 15 x 4 = 554px)が
## スクロールなしでコンテンツ領域(560px)へ収まる高さ。
const ITEM_SIZE := Vector2(212, 34)
const LIST_SEPARATION := 4
const LIST_HEADER_HEIGHT := 22.0
const LIST_SECTION_GAP := 8.0
## 小見出し(分類名+右へ伸びる罫線)。罫線の色はパネル枠の金。
const SECTION_RULE_THICKNESS := 1
const SECTION_RULE_ALPHA := 0.35
const SECTION_RULE_GAP := 8
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
## 詳細の中身の幅。実演と説明文が収まる値で、パネルの中央へ置く。
const ENTRY_WIDTH := 640.0
## 横の実演の幅(高さは比で決まる)。横の詳細は高さに余裕が無く、これ以上は大きくしない。
const LANDSCAPE_PREVIEW_WIDTH := 468.0

## 縦画面(GameDesign.md 9章「縦画面」)。語のボタンを分類ごとに上へ3列で並べ、その下に詳細を画面の幅で出す。
const PORTRAIT_COLUMNS := 3
const PORTRAIT_ITEM_HEIGHT := 64.0
const PORTRAIT_ITEM_GAP := 8.0
const PORTRAIT_BUTTON_FONT := 24
const PORTRAIT_SECTION_GAP := 16.0
const PORTRAIT_HEADER_HEIGHT := 28.0
const PORTRAIT_HEADER_FONT := UiPalette.T_LEAD
const PORTRAIT_HEADER_GAP := 8.0
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
var _portrait_column: VBoxContainer
var _grids: Array[GridContainer] = []
var _section_headers: Array[HBoxContainer] = []
var _section_labels: Array[Label] = []
var _section_counts: Array[int] = []
var _section_of: Array[int] = []
var _list_gap: Control
var _portrait_gaps: Array[Control] = []
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
	# 縦では語のボタンを分類ごとのグリッドへ移して3列に並べる(VBoxは向きを変えられないため)。
	_portrait_column = VBoxContainer.new()
	_portrait_column.add_theme_constant_override("separation", 0)
	_portrait_column.visible = false
	add_child(_portrait_column)

	_entries = KeywordEntries.all_entries()
	var previous_kind := -1
	for i in _entries.size():
		var entry := _entries[i]
		var kind := int(entry["kind"])
		if kind != previous_kind:
			previous_kind = kind
			_section_headers.append(_make_section_header(kind))
			_section_counts.append(0)
			var grid := GridContainer.new()
			grid.columns = PORTRAIT_COLUMNS
			grid.add_theme_constant_override("h_separation", int(PORTRAIT_ITEM_GAP))
			grid.add_theme_constant_override("v_separation", int(PORTRAIT_ITEM_GAP))
			_grids.append(grid)
		_section_counts[_section_counts.size() - 1] += 1
		_section_of.append(_section_counts.size() - 1)
		var button := CodedButton.make(_item_label(entry), ITEM_SIZE)
		button.pressed.connect(_select.bind(i))
		_buttons.append(button)
		_marks.append(_make_mark(button))
	_list_gap = _spacer(LIST_SECTION_GAP)
	for i in _section_headers.size():
		_portrait_gaps.append(_spacer(PORTRAIT_HEADER_GAP))
		_portrait_gaps.append(_spacer(PORTRAIT_SECTION_GAP))
	_arrange_list(false)

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
	var content := _header.portrait_content_rect()
	var gap_w := PORTRAIT_ITEM_GAP * (PORTRAIT_COLUMNS - 1)
	var item_w := (content.size.x - gap_w) / PORTRAIT_COLUMNS
	var item_size := Vector2(item_w, PORTRAIT_ITEM_HEIGHT) if portrait else ITEM_SIZE
	if _buttons[0].get_parent() != (_grids[0] if portrait else _column):
		_arrange_list(portrait)
	for i in _buttons.size():
		var button := _buttons[i]
		button.custom_minimum_size = item_size
		if portrait:
			button.add_theme_font_size_override("font_size", _scaled(PORTRAIT_BUTTON_FONT, factor))
		else:
			button.remove_theme_font_size_override("font_size")
		_fit_mark(_marks[i], item_size.y, portrait)
	var header_h := _scaled(int(PORTRAIT_HEADER_HEIGHT), factor)
	for i in _section_headers.size():
		_section_headers[i].custom_minimum_size.y = header_h if portrait else LIST_HEADER_HEIGHT
		_section_labels[i].add_theme_font_size_override(
			"font_size", _scaled(PORTRAIT_HEADER_FONT, factor) if portrait else UiPalette.T_BODY
		)
	_portrait_column.visible = portrait
	_scroll.visible = not portrait
	var detail := DETAIL_RECT
	if portrait:
		var list_h := 0.0
		for count in _section_counts:
			var rows := ceili(float(count) / PORTRAIT_COLUMNS)
			list_h += header_h + PORTRAIT_HEADER_GAP
			list_h += rows * PORTRAIT_ITEM_HEIGHT + (rows - 1) * PORTRAIT_ITEM_GAP
		list_h += PORTRAIT_SECTION_GAP * (_section_counts.size() - 1)
		_portrait_column.position = content.position
		_portrait_column.size = Vector2(content.size.x, list_h)
		var top := content.position.y + list_h + PORTRAIT_SECTION_GAP
		detail = Rect2(content.position.x, top, content.size.x, content.end.y - top)
	# 中身の最小幅を先に決める。パネルの最小幅が大きいうちに size を代入すると、
	# 後から中身が狭まっても広がったまま残る(Pitfalls.md)。
	# 縦送りの帯が出ても中身が帯の下へ潜らないよう、その幅を引いておく。
	var inner := detail.size.x - DETAIL_MARGIN_X * 2.0
	var bar := _detail_scroll.get_v_scroll_bar().get_combined_minimum_size().x
	_entry_view.custom_minimum_size.x = inner - bar if portrait else ENTRY_WIDTH
	_entry_view.set_layout(
		_entry_view.custom_minimum_size.x if portrait else LANDSCAPE_PREVIEW_WIDTH,
		_scaled(PORTRAIT_BODY_FONT if portrait else KeywordEntryView.BODY_FONT_SIZE, factor),
		_scaled(PORTRAIT_CAPTION_FONT if portrait else KeywordEntryView.CAPTION_FONT_SIZE, factor),
		_scaled(PORTRAIT_TITLE_FONT if portrait else KeywordEntryView.TITLE_FONT_SIZE, factor)
	)
	_panel.position = detail.position
	_panel.size = detail.size


## 語のボタンと小見出しを向きに合わせて並べ直す。付け替えは先に `remove_child()` する
## (`ListRevealFx` が位置を掴むため。Pitfalls.md)。
func _arrange_list(portrait: bool) -> void:
	var movers: Array[Node] = [_list_gap]
	movers.append_array(_section_headers)
	movers.append_array(_grids)
	movers.append_array(_portrait_gaps)
	movers.append_array(_buttons)
	for node in movers:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
	for i in _section_headers.size():
		if portrait:
			if i > 0:
				_portrait_column.add_child(_portrait_gaps[i * 2 + 1])
			_portrait_column.add_child(_section_headers[i])
			_portrait_column.add_child(_portrait_gaps[i * 2])
			_portrait_column.add_child(_grids[i])
		else:
			if i > 0:
				_column.add_child(_list_gap)
			_column.add_child(_section_headers[i])
		for j in _buttons.size():
			if _section_of[j] == i:
				(_grids[i] if portrait else _column).add_child(_buttons[j])


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
	return KeywordEntries.title(entry)


static func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


## 一覧の小見出し。分類名の右へ細い罫線を引く。押せない。
func _make_section_header(kind: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SECTION_RULE_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = str(KeywordEntries.CATEGORY_NAMES.get(kind, ""))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", UiPalette.T_BODY)
	label.add_theme_color_override("font_color", UiPalette.MUTED)
	row.add_child(label)
	var rule := ColorRect.new()
	rule.color = Color(UiPalette.GOLD, SECTION_RULE_ALPHA)
	rule.custom_minimum_size = Vector2(0, SECTION_RULE_THICKNESS)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rule)
	_section_labels.append(label)
	return row
