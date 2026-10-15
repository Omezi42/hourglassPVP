class_name CardCpuDifficultyPicker
extends Control
## CPU戦の思考レベルを選ぶモーダル(GameDesign.md 13章「CPU戦の思考レベル」)。
## デッキ選択の直後にだけ挟む。選んだ値は `CardCpuDifficultySave` へ永続化し、
## 次回の初期選択として引き継ぐ。

signal picked

const SCREEN_SIZE := Vector2(1280, 720)
const PANEL_WIDTH := 640.0
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const ROW_BUTTON_SIZE := Vector2(160, 64)
const SUMMARY_WIDTH := 380.0
## 縦(GameDesign.md 9章「縦画面」)。パネルは `PortraitModal` の論理幅で組み、中身ごと拡大する。
const PORTRAIT_ROW_BUTTON_SIZE := Vector2(120, 56)
const PORTRAIT_SUMMARY_WIDTH := 292.0

const ROWS := [
	{
		"value": CardCpuStrategy.Difficulty.BEGINNER,
		"name": "初級",
		"summary": "出せる手を出し、攻撃はランダム。反転・反転権は使わない",
	},
	{
		"value": CardCpuStrategy.Difficulty.NORMAL,
		"name": "中級",
		"summary": "生涯ダメージを物差しに、攻撃してから反転する定石どおりに指す",
	},
	{
		"value": CardCpuStrategy.Difficulty.EXPERT,
		"name": "上級",
		"summary": "中級に加え、返り討ちや無駄なマナを避ける判断を上乗せする",
	},
]

var _dim: ColorRect
var _center: CenterContainer
var _panel: PanelContainer
var _row_buttons: Array[Button] = []
var _summaries: Array[Label] = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# `set_anchors_preset()` は生成直後(サイズ0)のノードでは0のまま固定される。
	size = SCREEN_SIZE
	_build()
	PortraitModal.watch(self, _layout)


func open() -> void:
	_layout()
	visible = true


func _layout() -> void:
	var portrait := ScreenOrientation.is_portrait()
	size = PortraitModal.screen_size()
	_dim.size = size
	_center.size = size
	_panel.custom_minimum_size.x = PortraitModal.WIDTH if portrait else PANEL_WIDTH
	for button in _row_buttons:
		button.custom_minimum_size = PORTRAIT_ROW_BUTTON_SIZE if portrait else ROW_BUTTON_SIZE
	for summary in _summaries:
		summary.custom_minimum_size.x = PORTRAIT_SUMMARY_WIDTH if portrait else SUMMARY_WIDTH
	PortraitModal.fit(_center)


func close() -> void:
	visible = false


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.72)
	_dim.size = SCREEN_SIZE
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_center = CenterContainer.new()
	_center.size = SCREEN_SIZE
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		_panel.add_theme_stylebox_override("panel", style)
	_center.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	_panel.add_child(column)

	var title := Label.new()
	title.text = "CPUの思考レベルを選ぶ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)

	var current := CardCpuDifficultySave.get_difficulty()
	for row in ROWS:
		column.add_child(_make_row(row, current))


func _make_row(row: Dictionary, current: CardCpuStrategy.Difficulty) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 20)

	var value: CardCpuStrategy.Difficulty = row["value"]
	var button := CodedButton.make(row["name"], ROW_BUTTON_SIZE)
	# **いまの設定でも必ず押せる**。無効化すると「対局のたびに選び直せる」(GameDesign.md
	# 13章)はずのボタンが、既定値と同じ回だけ押せなくなる(実際にこれで報告を受けた)。
	button.pressed.connect(
		func() -> void:
			CardCpuDifficultySave.set_difficulty(value)
			picked.emit()
			close()
	)
	box.add_child(button)
	_row_buttons.append(button)

	var summary := Label.new()
	summary.text = row["summary"] + ("(いまの設定)" if value == current else "")
	summary.custom_minimum_size = Vector2(SUMMARY_WIDTH, 0)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	box.add_child(summary)
	_summaries.append(summary)
	return box
