class_name AccountCredentialDialog
extends Control
## 登録・ログインの入力ダイアログ(GameDesign.md 14章)。入力を渡すだけで、通信は画面側が行い
## `finish()` で結果を返す。

signal submitted(mode: Mode, login_id: String, password: String)

enum Mode { REGISTER, LOGIN }

const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const PANEL_WIDTH := 500.0
const PANEL_TOP := 140.0
const DIM := Color(0, 0, 0, 0.6)
const CAPTION_WIDTH := 96
const TITLE_FONT_SIZE := 22
const NOTE_FONT_SIZE := 14
const BUTTON_SIZE := Vector2(170, 48)
const WARNING_COLOR := Color(1, 0.72, 0.45, 1)
const ERROR_COLOR := Color(1, 0.55, 0.5, 1)

var mode := Mode.REGISTER
var _title: Label
var _id_input: LineEdit
var _password_input: LineEdit
var _warning: Label
var _message: Label
var _submit: Button
var _cancel: Button


func _ready() -> void:
	visible = false
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build()


## `guest_currency` はゲストのままログインするときに失う砂金。負ならゲストではない。
func open(p_mode: Mode, guest_currency: int) -> void:
	mode = p_mode
	_id_input.text = ""
	_password_input.text = ""
	_message.text = ""
	if mode == Mode.REGISTER:
		_title.text = "IDを登録する"
		_submit.text = "登録する"
		_warning.text = "メールアドレスを登録しないため、パスワードを忘れると復旧できません。いまの記録と砂金はそのまま引き継がれます。"
	else:
		_title.text = "登録済みのIDで入る"
		_submit.text = "ログイン"
		_warning.text = ""
		if guest_currency >= 0:
			_warning.text = (
				"いま遊んでいるゲストの記録と%sには、あとから戻れなくなります。残したい場合は、先に「IDを登録する」を使ってください。"
				% CurrencyRules.label_text(guest_currency)
			)
	_warning.visible = not _warning.text.is_empty()
	_set_busy(false)
	visible = true


## 通信の結果を受け取る。成功なら閉じ、失敗なら理由を出して入力を残す。
func finish(error: String) -> void:
	_set_busy(false)
	if error.is_empty():
		visible = false
	else:
		_message.text = error


func _on_submit() -> void:
	_set_busy(true)
	_message.text = "登録しています…" if mode == Mode.REGISTER else "ログインしています…"
	_message.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	submitted.emit(mode, _id_input.text, _password_input.text)


func _set_busy(value: bool) -> void:
	_submit.disabled = value
	_cancel.disabled = value
	if not value:
		_message.add_theme_color_override("font_color", ERROR_COLOR)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = DIM
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", load(PANEL_STYLE))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -PANEL_WIDTH * 0.5
	panel.offset_right = PANEL_WIDTH * 0.5
	panel.offset_top = PANEL_TOP
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)

	_id_input = _input_row(column, "ID", "英数字・記号(3〜20文字)")
	_id_input.max_length = FirebaseAuth.ID_MAX_LENGTH
	_password_input = _input_row(column, "パスワード", "6文字以上")
	_password_input.secret = true
	MobileTextInput.wire(_id_input, "ログインID")
	MobileTextInput.wire(_password_input, "パスワード")
	_password_input.text_submitted.connect(func(_text: String) -> void: _on_submit())

	_warning = _note(WARNING_COLOR)
	column.add_child(_warning)
	_message = _note(ERROR_COLOR)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_message)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	column.add_child(buttons)
	_cancel = CodedButton.make("やめる", BUTTON_SIZE)
	_cancel.pressed.connect(func() -> void: visible = false)
	buttons.add_child(_cancel)
	_submit = CodedButton.make_in_group("", BUTTON_SIZE, CodedButton.PRIMARY_ACTION_GROUP)
	_submit.pressed.connect(_on_submit)
	buttons.add_child(_submit)


func _input_row(parent: Container, caption: String, placeholder: String) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size = Vector2(CAPTION_WIDTH, 0)
	row.add_child(label)
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(input)
	return input


func _note(color: Color) -> Label:
	var label := Label.new()
	# 折り返しは幅が決まる前に立てる(Pitfalls「autowrap_mode は size より先に」)。
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", NOTE_FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	return label
