class_name CardPresetPicker
extends Control
## プリセットデッキを選ぶモーダル(GameDesign.md 18章)。
## 名前だけでは何のデッキか分からないため、狙いの一文を必ず添えて並べる。

signal picked(preset_id: String)

const SCREEN_SIZE := Vector2(1280, 720)
## 幅だけ決め、高さは中身に合わせる。固定にすると下半分が空いて見える。
const PANEL_WIDTH := 720.0
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const ROW_BUTTON_SIZE := Vector2(200, 64)
const SUMMARY_WIDTH := 420.0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# `set_anchors_preset()` は生成直後(サイズ0)のノードでは0のまま固定される。
	size = SCREEN_SIZE
	_build()


func open() -> void:
	visible = true


func close() -> void:
	visible = false


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
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)

	var title := Label.new()
	title.text = "プリセットデッキを読み込む"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)

	for preset in CardPresetDecks.PRESETS:
		column.add_child(_make_row(preset))

	var close_button := CodedButton.make("閉じる", Vector2(180, 56))
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	column.add_child(close_button)


func _make_row(preset: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)

	var button := CodedButton.make(preset["name"], ROW_BUTTON_SIZE)
	var preset_id: String = preset["id"]
	button.pressed.connect(
		func() -> void:
			picked.emit(preset_id)
			close()
	)
	row.add_child(button)

	var summary := Label.new()
	summary.text = preset["summary"]
	summary.custom_minimum_size = Vector2(SUMMARY_WIDTH, 0)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	row.add_child(summary)
	return row
