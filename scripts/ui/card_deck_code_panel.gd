class_name CardDeckCodePanel
extends Control
## デッキコードの表示と読み込み(GameDesign.md 9章)。
## 書き出しと読み込みを1つのパネルにまとめているのは、受け渡しが
## 「相手のコードを貼る」「自分のコードを渡す」の対で起きるため。

signal loaded(deck: Array)

const SCREEN_SIZE := Vector2(1280, 720)
## 幅だけ決め、高さは中身に合わせる。
const PANEL_WIDTH := 760.0
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const FIELD_SIZE := Vector2(600, 48)
const BUTTON_SIZE := Vector2(180, 52)

var _own_field: LineEdit
var _input_field: LineEdit
var _message: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# `set_anchors_preset()` は生成直後(サイズ0)のノードでは0のまま固定される。
	size = SCREEN_SIZE
	_build()


func open(deck: Array) -> void:
	_own_field.text = CardDeckCode.encode(deck)
	_input_field.text = ""
	_message.text = ""
	visible = true


func close() -> void:
	visible = false


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(_own_field.text)
	_message.text = "コピーしました"


func _on_load_pressed() -> void:
	var deck := CardDeckCode.decode(_input_field.text)
	if deck.is_empty():
		_message.text = "このコードは読み込めませんでした"
		return
	loaded.emit(deck)
	close()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.size = SCREEN_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.size = SCREEN_SIZE
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(_make_label("デッキコード", 26))

	column.add_child(_make_label("いまのデッキのコード(渡す側)", 18))
	_own_field = _make_field(true)
	column.add_child(_make_row(_own_field, "コピー", _on_copy_pressed))

	column.add_child(_make_label("受け取ったコード(読み込む側)", 18))
	_input_field = _make_field(false)
	column.add_child(_make_row(_input_field, "読み込む", _on_load_pressed))

	_message = _make_label("", 18)
	column.add_child(_message)

	var close_button := CodedButton.make("閉じる", BUTTON_SIZE)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	column.add_child(close_button)


func _make_row(field: LineEdit, label: String, handler: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(field)
	var button := CodedButton.make(label, Vector2(140, FIELD_SIZE.y))
	button.pressed.connect(handler)
	row.add_child(button)
	return row


func _make_field(read_only: bool) -> LineEdit:
	var field := LineEdit.new()
	field.custom_minimum_size = FIELD_SIZE
	field.editable = not read_only
	# 渡す側の欄も選択してコピーできるようにするため、read_only は使うが無効化はしない。
	field.select_all_on_focus = true
	return field


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	return label
