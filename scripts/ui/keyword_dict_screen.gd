class_name KeywordDictScreen
extends Control
## キーワード辞書(GameDesign.md 17章)。左に語の一覧、右に選んだ語の詳細。
## ルール画面が「順に読ませる紙芝居」なのに対し、こちらは語を1つ引きに来る場所。

signal back_pressed

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const CONTENT_HEIGHT := 720.0 - ScreenHeader.CONTENT_TOP - ScreenHeader.OUTER_MARGIN
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

var _entry_view: KeywordEntryView
var _buttons: Array[Button] = []
var _entries: Array[Dictionary] = []


func _ready() -> void:
	_build()
	# 開いた直後に詳細が空のまま置かれないよう、先頭の語を選んでおく。
	if not _entries.is_empty():
		_select(0)


func _build() -> void:
	add_child(ScreenBackdrop.new())

	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	header.set_title("キーワード辞書")
	header.back_pressed.connect(func() -> void: back_pressed.emit())

	var scroll := ScrollContainer.new()
	scroll.position = LIST_RECT.position
	scroll.size = LIST_RECT.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)

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
