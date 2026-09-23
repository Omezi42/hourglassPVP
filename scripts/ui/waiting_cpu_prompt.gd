class_name WaitingCpuPrompt
extends Control
## 待っている間のCPU戦の最中に、他の人が待機に入ったことを知らせるモーダル
## (GameDesign.md 11章)。「マッチングする / このままCPUと続ける」を選ばせる。

signal match_pressed
signal continue_pressed

const SCREEN_SIZE := Vector2(1280, 720)
const PANEL_WIDTH := 560.0
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const BUTTON_SIZE := Vector2(240, 64)
const TITLE_FONT_SIZE := 28
const BODY_FONT_SIZE := 18
const DIM_ALPHA := 0.6


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
	dim.color = Color(0, 0, 0, DIM_ALPHA)
	dim.size = SCREEN_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.size = SCREEN_SIZE
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)

	var title := Label.new()
	title.text = "対戦相手が見つかりました"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	column.add_child(title)

	var body := Label.new()
	body.text = "ほかのプレイヤーがマッチングを待っています。\nマッチングすると、いまのCPU戦は記録に残さず終わります。"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	body.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	column.add_child(body)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	var keep := CodedButton.make("このままCPUと続ける", BUTTON_SIZE)
	keep.pressed.connect(func() -> void: continue_pressed.emit())
	row.add_child(keep)
	var go := CodedButton.make_in_group("マッチングする", BUTTON_SIZE, CodedButton.PRIMARY_ACTION_GROUP)
	go.pressed.connect(func() -> void: match_pressed.emit())
	row.add_child(go)
