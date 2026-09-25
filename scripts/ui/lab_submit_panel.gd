class_name LabSubmitPanel
extends Control
## 掲示板〈ラボ〉への案の投稿フォーム(GameDesign.md 29章)。入力 → 確認 → 送信の2段。
## 投稿後は書き直せないため、送信の前に内容を読み返す段を1回挟む。
## `ShopSetPreview` と同じ「暗幕 + `content_panel.tres` の中央パネル」の型。

signal submitted

const SCREEN_SIZE := Vector2(1280, 720)
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const FIELD_NORMAL := "res://resources/theme/coded_line_edit_normal.tres"
const FIELD_FOCUS := "res://resources/theme/coded_line_edit_focus.tres"
const DIM_COLOR := Color(0, 0, 0, 0.65)
const FIELD_WIDTH := 680.0
const DESCRIPTION_HEIGHT := 150.0
const HEADING_FONT_SIZE := 24
const LABEL_FONT_SIZE := 16
const FIELD_FONT_SIZE := 18
const PREVIEW_NAME_FONT_SIZE := 26
const KIND_SIZE := Vector2(200, 48)
const MAIN_BUTTON_SIZE := Vector2(260, 56)
const SUB_BUTTON_SIZE := Vector2(160, 56)
const COLUMN_GAP := 12
const ROW_GAP := 10

var _round: Dictionary = {}
var _kind := LabProposalService.Kind.HOURGLASS
var _busy := false
var _form: VBoxContainer
var _confirm: VBoxContainer
var _name_input: LineEdit
var _name_count: Label
var _description_input: TextEdit
var _description_count: Label
var _kind_buttons: Array[Button] = []
var _form_message: Label
var _preview_kind: Label
var _preview_name: Label
var _preview_body: Label
var _confirm_message: Label
var _send_button: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = SCREEN_SIZE
	_build()


func open(round: Dictionary) -> void:
	_round = round
	_name_input.text = ""
	_description_input.text = ""
	_kind = LabProposalService.Kind.HOURGLASS
	_refresh_kind_buttons()
	_refresh_counts()
	_show_form("お題:%s" % str(round.get("title", "")), UiPalette.TEXT_MUTED)
	visible = true


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.size = SCREEN_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.size = SCREEN_SIZE
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", load(PANEL_STYLE))
	center.add_child(panel)

	var stack := VBoxContainer.new()
	panel.add_child(stack)
	_form = _column()
	stack.add_child(_form)
	_confirm = _column()
	stack.add_child(_confirm)
	_build_form()
	_build_confirm()


func _build_form() -> void:
	_form.add_child(_label("案を出す", HEADING_FONT_SIZE, UiPalette.TEXT_OFFWHITE))
	_form_message = _label("", LABEL_FONT_SIZE, UiPalette.TEXT_MUTED)
	_form_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_form_message.custom_minimum_size = Vector2(FIELD_WIDTH, 0)
	_form.add_child(_form_message)

	_name_count = _field_heading(_form, "カード名(案)")
	_name_input = LineEdit.new()
	_name_input.custom_minimum_size = Vector2(FIELD_WIDTH, 0)
	_name_input.max_length = LabModeration.NAME_MAX_LENGTH
	_name_input.text_changed.connect(func(_text: String) -> void: _refresh_counts())
	MobileTextInput.wire(_name_input, "カード名(案)")
	_form.add_child(_name_input)

	_description_count = _field_heading(_form, "モチーフ・効果の説明")
	_description_input = TextEdit.new()
	_description_input.custom_minimum_size = Vector2(FIELD_WIDTH, DESCRIPTION_HEIGHT)
	_description_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_description_input.add_theme_stylebox_override("normal", load(FIELD_NORMAL))
	_description_input.add_theme_stylebox_override("focus", load(FIELD_FOCUS))
	_description_input.add_theme_font_size_override("font_size", FIELD_FONT_SIZE)
	_description_input.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	_description_input.text_changed.connect(_refresh_counts)
	MobileTextInput.wire(_description_input, "モチーフ・効果の説明")
	_form.add_child(_description_input)

	_form.add_child(_label("砂時計 / 砂術", LABEL_FONT_SIZE, UiPalette.TEXT_MUTED))
	var kind_row := HBoxContainer.new()
	kind_row.add_theme_constant_override("separation", ROW_GAP)
	_form.add_child(kind_row)
	for kind in [LabProposalService.Kind.HOURGLASS, LabProposalService.Kind.SPELL]:
		var button := CodedButton.make(
			"砂時計" if kind == LabProposalService.Kind.HOURGLASS else "砂術", KIND_SIZE
		)
		button.toggle_mode = true
		button.pressed.connect(_on_kind_pressed.bind(kind))
		kind_row.add_child(button)
		_kind_buttons.append(button)

	var buttons := _button_row(_form)
	var next := CodedButton.make("確認へ", MAIN_BUTTON_SIZE)
	CodedButton.apply_styles(next, "primary_action")
	next.pressed.connect(_on_next_pressed)
	buttons.add_child(next)
	var close := CodedButton.make("閉じる", SUB_BUTTON_SIZE)
	close.pressed.connect(func() -> void: visible = false)
	buttons.add_child(close)


func _build_confirm() -> void:
	_confirm.add_child(_label("この内容で投稿します", HEADING_FONT_SIZE, UiPalette.TEXT_OFFWHITE))
	_preview_kind = _label("", LABEL_FONT_SIZE, UiPalette.GLOW_AMBER)
	_confirm.add_child(_preview_kind)
	_preview_name = _label("", PREVIEW_NAME_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	_confirm.add_child(_preview_name)
	_preview_body = _label("", FIELD_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	_preview_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_body.custom_minimum_size = Vector2(FIELD_WIDTH, DESCRIPTION_HEIGHT)
	_confirm.add_child(_preview_body)
	_confirm_message = _label("", LABEL_FONT_SIZE, UiPalette.TEXT_MUTED)
	_confirm_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_message.custom_minimum_size = Vector2(FIELD_WIDTH, 0)
	_confirm.add_child(_confirm_message)

	var buttons := _button_row(_confirm)
	_send_button = CodedButton.make("投稿する", MAIN_BUTTON_SIZE)
	CodedButton.apply_styles(_send_button, "primary_action")
	_send_button.pressed.connect(_on_send_pressed)
	buttons.add_child(_send_button)
	var back := CodedButton.make("書き直す", SUB_BUTTON_SIZE)
	back.pressed.connect(func() -> void: _show_form(_form_message.text, UiPalette.TEXT_MUTED))
	buttons.add_child(back)


func _column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(FIELD_WIDTH, 0)
	column.add_theme_constant_override("separation", COLUMN_GAP)
	return column


## 見出しと、右寄せの残り文字数の行。残り文字数のLabelを返す。
func _field_heading(parent: Control, text: String) -> Label:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var heading := _label(text, LABEL_FONT_SIZE, UiPalette.TEXT_MUTED)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	var count := _label("", LABEL_FONT_SIZE, UiPalette.TEXT_MUTED)
	row.add_child(count)
	return count


func _button_row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", ROW_GAP)
	parent.add_child(row)
	return row


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _show_form(message: String, color: Color) -> void:
	_form.visible = true
	_confirm.visible = false
	_form_message.text = message
	_form_message.add_theme_color_override("font_color", color)


func _refresh_counts() -> void:
	_set_count(_name_count, _name_input.text, LabModeration.NAME_MAX_LENGTH)
	_set_count(_description_count, _description_input.text, LabModeration.DESCRIPTION_MAX_LENGTH)


func _set_count(label: Label, text: String, limit: int) -> void:
	var left := limit - text.strip_edges().length()
	label.text = "残り%d字" % left
	label.add_theme_color_override(
		"font_color", UiPalette.WARNING_RED if left < 0 else UiPalette.TEXT_MUTED
	)


func _on_kind_pressed(kind: LabProposalService.Kind) -> void:
	_kind = kind
	_refresh_kind_buttons()


## 選択中のチップは凹んだ見た目に加えて文字色も琥珀へ変える(`CardDeckFilter` と同じ)。
func _refresh_kind_buttons() -> void:
	for i in _kind_buttons.size():
		var selected := i == int(_kind)
		_kind_buttons[i].button_pressed = selected
		for slot in ["font_color", "font_pressed_color", "font_hover_pressed_color"]:
			if selected:
				_kind_buttons[i].add_theme_color_override(slot, UiPalette.GLOW_AMBER)
			else:
				_kind_buttons[i].remove_theme_color_override(slot)


func _on_next_pressed() -> void:
	var reason := LabModeration.quick_check(_name_input.text, _description_input.text)
	if not reason.is_empty():
		_show_form(reason, UiPalette.WARNING_RED)
		return
	_preview_kind.text = "砂術" if _kind == LabProposalService.Kind.SPELL else "砂時計"
	_preview_name.text = _name_input.text.strip_edges()
	_preview_body.text = _description_input.text.strip_edges()
	_confirm_message.text = "投稿後は書き直せません。この回に出せる案は1人1件です。"
	_confirm_message.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	_form.visible = false
	_confirm.visible = true


func _on_send_pressed() -> void:
	if _busy:
		return
	_busy = true
	_send_button.disabled = true
	_confirm_message.text = "投稿しています…"
	var uid := NetSession.auth.uid if NetSession.auth != null else ""
	var result: Dictionary = await LabProposalService.submit(
		NetSession.client, uid, _round, _name_input.text, _description_input.text, _kind
	)
	_busy = false
	_send_button.disabled = false
	if bool(result.get("ok", false)):
		visible = false
		submitted.emit()
		return
	_confirm_message.text = str(result.get("message", ""))
	_confirm_message.add_theme_color_override("font_color", UiPalette.WARNING_RED)
