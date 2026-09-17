class_name LabSubmitPanel
extends Control
## 掲示板〈ラボ〉への新規カード案の投稿フォーム(GameDesign.md 29章)。
## `ShopSetPreview` と同じ「暗幕 + `content_panel.tres` の中央パネル + 閉じる」の型。

signal submitted

const SCREEN_SIZE := Vector2(1280, 720)
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const FIELD_WIDTH := 640.0
const COST := LabProposalService.SUBMIT_COST

var _name_input: LineEdit
var _description_input: LineEdit
var _kind_buttons: Array[Button] = []
var _kind := LabProposalService.Kind.HOURGLASS
var _message: Label
var _submit_button: Button
var _busy := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = SCREEN_SIZE
	_build()


func open() -> void:
	_name_input.text = ""
	_description_input.text = ""
	_kind = LabProposalService.Kind.HOURGLASS
	_refresh_kind_buttons()
	_message.text = "投稿には%d%sを消費します。" % [COST, CurrencyRules.CURRENCY_NAME]
	_message.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	visible = true


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.size = SCREEN_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.size = SCREEN_SIZE
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.custom_minimum_size = Vector2(FIELD_WIDTH + 60.0, 0)
	panel.add_child(column)

	var heading := Label.new()
	heading.text = "新規カード案を投稿する"
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	column.add_child(heading)

	column.add_child(_field_label("カード名(案)"))
	_name_input = LineEdit.new()
	_name_input.custom_minimum_size = Vector2(FIELD_WIDTH, 0)
	_name_input.max_length = LabModeration.NAME_MAX_LENGTH
	MobileTextInput.wire(_name_input, "カード名(案)")
	column.add_child(_name_input)

	column.add_child(_field_label("モチーフ・効果の説明"))
	_description_input = LineEdit.new()
	_description_input.custom_minimum_size = Vector2(FIELD_WIDTH, 0)
	_description_input.max_length = LabModeration.DESCRIPTION_MAX_LENGTH
	MobileTextInput.wire(_description_input, "モチーフ・効果の説明")
	column.add_child(_description_input)

	column.add_child(_field_label("砂時計 / 砂術"))
	var kind_row := HBoxContainer.new()
	kind_row.add_theme_constant_override("separation", 10)
	column.add_child(kind_row)
	var hourglass_button := CodedButton.make("砂時計", Vector2(200, 48))
	hourglass_button.pressed.connect(_on_kind_pressed.bind(LabProposalService.Kind.HOURGLASS))
	kind_row.add_child(hourglass_button)
	var spell_button := CodedButton.make("砂術", Vector2(200, 48))
	spell_button.pressed.connect(_on_kind_pressed.bind(LabProposalService.Kind.SPELL))
	kind_row.add_child(spell_button)
	_kind_buttons = [hourglass_button, spell_button]

	_message = Label.new()
	_message.custom_minimum_size = Vector2(FIELD_WIDTH, 0)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD
	column.add_child(_message)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(button_row)
	_submit_button = CodedButton.make(
		"%d %sで投稿する" % [COST, CurrencyRules.CURRENCY_NAME], Vector2(280, 56)
	)
	CodedButton.apply_styles(_submit_button, "primary_action")
	_submit_button.pressed.connect(_on_submit_pressed)
	button_row.add_child(_submit_button)
	var close := CodedButton.make("閉じる", Vector2(160, 56))
	close.pressed.connect(func() -> void: visible = false)
	button_row.add_child(close)

	_refresh_kind_buttons()


func _field_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	return label


func _on_kind_pressed(kind: LabProposalService.Kind) -> void:
	_kind = kind
	_refresh_kind_buttons()


func _refresh_kind_buttons() -> void:
	for i in _kind_buttons.size():
		var is_selected := i == int(_kind)
		CodedButton.apply_styles(_kind_buttons[i], "primary_action" if is_selected else "wide_text")


func _on_submit_pressed() -> void:
	if _busy:
		return
	_busy = true
	_submit_button.disabled = true
	_message.text = "投稿しています…"
	_message.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	var uid := NetSession.auth.uid if NetSession.auth != null else ""
	var result: Dictionary = await LabProposalService.submit(
		NetSession.client, uid, _name_input.text, _description_input.text, _kind
	)
	_busy = false
	_submit_button.disabled = false
	var ok := bool(result.get("ok", false))
	_message.text = str(result.get("message", ""))
	_message.add_theme_color_override(
		"font_color", UiPalette.GLOW_AMBER if ok else UiPalette.WARNING_RED
	)
	if ok:
		submitted.emit()
