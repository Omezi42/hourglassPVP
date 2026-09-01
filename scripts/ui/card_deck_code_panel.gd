class_name CardDeckCodePanel
extends Control
## デッキコードの発行と読み込み(GameDesign.md 9章)。
## 書き出しと読み込みを1つのパネルにまとめているのは、受け渡しが
## 「相手のコードを入れる」「自分のコードを渡す」の対で起きるため。
##
## **コードは8桁の数字で、中身はサーバーへ預ける**(`DeckCodeService`)。
## **発行はボタンを押したときだけ行う**。画面を開くたびに預けると、使われない
## コードが際限なく増えるため。

signal loaded(deck: Array)

const SCREEN_SIZE := Vector2(1280, 720)
## 幅だけ決め、高さは中身に合わせる。
const PANEL_WIDTH := 760.0
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
## コードは8桁の数字しか入らないため、欄は短くてよい。
const FIELD_SIZE := Vector2(300, 48)
const BUTTON_SIZE := Vector2(180, 52)

var _own_field: LineEdit
var _input_field: LineEdit
var _message: Label
var _issue_button: Button
var _load_button: Button
var _deck: Array = []
var _busy := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# `set_anchors_preset()` は生成直後(サイズ0)のノードでは0のまま固定される。
	size = SCREEN_SIZE
	_build()


func open(deck: Array) -> void:
	_deck = deck
	_own_field.text = ""
	_input_field.text = ""
	_message.text = ""
	_set_busy(false)
	visible = true


func close() -> void:
	visible = false


## 発行はここでだけ行う。同じ構築なら `DeckCodeService` が同じ番号を返すため、
## 続けて押しても預けたものが増えることはない。
func _on_issue_pressed() -> void:
	if _busy:
		return
	if _deck.size() != MatchState.DECK_SIZE:
		_message.text = "デッキが%d枚のときだけコードを発行できます" % MatchState.DECK_SIZE
		return
	_set_busy(true)
	_message.text = "コードを発行中"
	if not await NetSession.sign_in():
		_fail("通信に失敗しました。接続を確認してください")
		return
	var code: String = await DeckCodeService.publish(NetSession.client, _deck)
	if code == "":
		_fail("コードを発行できませんでした")
		return
	_own_field.text = code
	_message.text = "このコードを渡してください"
	_set_busy(false)


func _on_copy_pressed() -> void:
	if _own_field.text == "":
		_message.text = "先にコードを発行してください"
		return
	DisplayServer.clipboard_set(_own_field.text)
	_message.text = "コピーしました"


func _on_load_pressed() -> void:
	if _busy:
		return
	if DeckCodeService.normalize(_input_field.text) == "":
		_message.text = "コードは%d桁の数字です" % DeckCodeService.CODE_LENGTH
		return
	_set_busy(true)
	_message.text = "読み込み中"
	if not await NetSession.sign_in():
		_fail("通信に失敗しました。接続を確認してください")
		return
	var deck: Array = await DeckCodeService.fetch(NetSession.client, _input_field.text)
	if deck.is_empty():
		_fail("このコードは読み込めませんでした")
		return
	_set_busy(false)
	loaded.emit(deck)
	close()


func _fail(message: String) -> void:
	_set_busy(false)
	_message.text = message


func _set_busy(busy: bool) -> void:
	_busy = busy
	_issue_button.disabled = busy
	_load_button.disabled = busy
	_input_field.editable = not busy


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
	var own_row := _make_row(_own_field, "コピー", _on_copy_pressed)
	_issue_button = CodedButton.make("コードを発行", Vector2(180, FIELD_SIZE.y))
	_issue_button.pressed.connect(_on_issue_pressed)
	own_row.add_child(_issue_button)
	column.add_child(own_row)

	column.add_child(_make_label("受け取ったコード(読み込む側)", 18))
	_input_field = _make_field(false)
	_input_field.max_length = DeckCodeService.CODE_LENGTH
	_input_field.placeholder_text = "%d桁の数字" % DeckCodeService.CODE_LENGTH
	var load_row := _make_row(_input_field, "読み込む", _on_load_pressed)
	_load_button = load_row.get_child(1)
	column.add_child(load_row)

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
