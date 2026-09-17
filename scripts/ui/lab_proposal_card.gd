class_name LabProposalCard
extends PanelContainer
## 掲示板〈ラボ〉一覧の1件(GameDesign.md 29章)。カード名・種別・説明の冒頭・得票数を
## 表示し、「Good」ボタンで投票する。過去ログでは採用/不採用の印を添える。

signal voted(proposal_id: String)

const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const CARD_SIZE := Vector2(600, 120)
const DESCRIPTION_MAX_CHARS := 60

var proposal_id := ""
var _good_label: Label
var _good_button: Button
var _result_label: Label
var _good_count := 0


func _init() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		add_theme_stylebox_override("panel", style)


## `fields` は `lab_proposals/{id}` の内容(Firestoreから読んだそのままの形)。
## **`can_vote` が false のとき、ボタンは押せるがラベルは「Good」のまま**にする
## (未登録アカウントは投票済みではないため「投票済み」と表示すると嘘になる)。
func setup(id: String, fields: Dictionary, already_voted: bool, can_vote: bool = true) -> void:
	proposal_id = id
	for child in get_children():
		child.queue_free()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	row.add_child(column)

	var kind_text := "砂術" if str(fields.get("card_kind", "")) == "spell" else "砂時計"
	var title := Label.new()
	title.text = "%s(%s)" % [str(fields.get("card_name", "")), kind_text]
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	column.add_child(title)

	var description := Label.new()
	var full_text := str(fields.get("description", ""))
	description.text = (
		full_text
		if full_text.length() <= DESCRIPTION_MAX_CHARS
		else full_text.substr(0, DESCRIPTION_MAX_CHARS) + "…"
	)
	description.add_theme_font_size_override("font_size", 16)
	description.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD
	column.add_child(description)

	if str(fields.get("source", "")) == "tournament":
		var tournament_label := Label.new()
		tournament_label.text = "大会優勝作"
		tournament_label.add_theme_font_size_override("font_size", 14)
		tournament_label.add_theme_color_override("font_color", UiPalette.GLOW_AMBER)
		column.add_child(tournament_label)

	var result := str(fields.get("result", ""))
	if not result.is_empty():
		_result_label = Label.new()
		_result_label.text = "採用" if result == "adopted" else "不採用"
		_result_label.add_theme_font_size_override("font_size", 14)
		_result_label.add_theme_color_override(
			"font_color", UiPalette.GLOW_AMBER if result == "adopted" else UiPalette.TEXT_MUTED
		)
		column.add_child(_result_label)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(side)

	_good_count = int(fields.get("good_count", 0))
	_good_label = Label.new()
	_good_label.text = "Good %d" % _good_count
	_good_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_good_label.add_theme_font_size_override("font_size", 16)
	_good_label.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	side.add_child(_good_label)

	_good_button = CodedButton.make("投票済み" if already_voted else "Good", Vector2(100, 40))
	_good_button.disabled = already_voted or not can_vote
	if not can_vote and not already_voted:
		_good_button.tooltip_text = "投票には登録済みアカウントが必要です"
	_good_button.pressed.connect(func() -> void: voted.emit(proposal_id))
	side.add_child(_good_button)


func good_count() -> int:
	return _good_count


## 投票が通ったあと、得票数の見た目だけをその場で更新する。
func mark_voted(new_count: int) -> void:
	_good_count = new_count
	if _good_label != null:
		_good_label.text = "Good %d" % new_count
	if _good_button != null:
		_good_button.disabled = true
		_good_button.text = "投票済み"
