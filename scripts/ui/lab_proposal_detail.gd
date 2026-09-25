class_name LabProposalDetail
extends Control
## 掲示板〈ラボ〉の案の詳細パネル(GameDesign.md 29章)。全文と「この案に投票する」を出す。
## 暗幕 + `content_panel.tres` の中央パネルという既存の型。投票の通信は画面が行う。

signal vote_requested(proposal_id: String)

const SCREEN_SIZE := Vector2(1280, 720)
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const DIM_COLOR := Color(0, 0, 0, 0.65)
const PANEL_WIDTH := 760.0
const BODY_MIN_HEIGHT := 180.0
const KIND_FONT_SIZE := 15
const NAME_FONT_SIZE := 30
const BODY_FONT_SIZE := 19
const NOTE_FONT_SIZE := 15
const VOTE_SIZE := Vector2(300, 60)
const CLOSE_SIZE := Vector2(160, 60)
const RULE_COLOR := Color(0.85, 0.62, 0.22, 0.35)
const COLUMN_GAP := 14
const ROW_GAP := 12

var _proposal_id := ""
var _kind: Label
var _name: Label
var _body: Label
var _note: Label
var _vote_button: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = SCREEN_SIZE
	_build()


## `vote_label` が空なら投票ボタンを出さない(締切後・自分の投稿)。
func open(proposal: Dictionary, vote_label: String, vote_enabled: bool, note: String) -> void:
	_proposal_id = str(proposal.get("id", ""))
	_kind.text = "砂術" if str(proposal.get("card_kind", "")) == "spell" else "砂時計"
	_name.text = str(proposal.get("card_name", ""))
	_body.text = str(proposal.get("description", ""))
	_note.text = note
	_note.visible = not note.is_empty()
	_vote_button.visible = not vote_label.is_empty()
	_vote_button.text = vote_label
	_vote_button.disabled = not vote_enabled
	visible = true


## 投票の通信中は押せなくする。
func set_busy(busy: bool) -> void:
	_vote_button.disabled = busy


## 投票できなかった理由などを1行出す。
func show_note(note: String) -> void:
	_note.text = note
	_note.visible = not note.is_empty()


func close() -> void:
	visible = false


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.size = SCREEN_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	var center := CenterContainer.new()
	center.size = SCREEN_SIZE
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", load(PANEL_STYLE))
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	column.add_theme_constant_override("separation", COLUMN_GAP)
	panel.add_child(column)

	_kind = _label(KIND_FONT_SIZE, UiPalette.GLOW_AMBER)
	column.add_child(_kind)
	_name = _label(NAME_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	column.add_child(_name)

	var rule := ColorRect.new()
	rule.color = RULE_COLOR
	rule.custom_minimum_size = Vector2(PANEL_WIDTH, 1)
	column.add_child(rule)

	_body = _label(BODY_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(PANEL_WIDTH, BODY_MIN_HEIGHT)
	column.add_child(_body)

	_note = _label(NOTE_FONT_SIZE, UiPalette.TEXT_MUTED)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_note)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", ROW_GAP)
	column.add_child(row)
	_vote_button = CodedButton.make("", VOTE_SIZE)
	CodedButton.apply_styles(_vote_button, "primary_action")
	_vote_button.pressed.connect(func() -> void: vote_requested.emit(_proposal_id))
	row.add_child(_vote_button)
	var close_button := CodedButton.make("閉じる", CLOSE_SIZE)
	close_button.pressed.connect(close)
	row.add_child(close_button)


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _on_dim_input(event: InputEvent) -> void:
	if ClickArea.is_primary_release(event):
		close()
