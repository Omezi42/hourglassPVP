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
## 縦(GameDesign.md 9章「縦画面」)。パネルは `PortraitModal` の論理幅で組み、中身ごと拡大する。
const PORTRAIT_ROW_BUTTON_SIZE := Vector2(152, 72)
const PORTRAIT_PANEL_INNER := PortraitModal.WIDTH - 48.0
const ROW_SEPARATION := 20
const PORTRAIT_ROW_SEPARATION := 16
const PORTRAIT_SUMMARY_WIDTH := (
	PORTRAIT_PANEL_INNER - PORTRAIT_ROW_BUTTON_SIZE.x - PORTRAIT_ROW_SEPARATION
)
const CLOSE_SIZE := Vector2(180, 56)
const PORTRAIT_CLOSE_SIZE := Vector2(180, 72)

var _dim: ColorRect
var _center: CenterContainer
var _panel: PanelContainer
var _row_buttons: Array[Button] = []
var _rows: Array[HBoxContainer] = []
var _close_button: Button
var _summaries: Array[Label] = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# `set_anchors_preset()` は生成直後(サイズ0)のノードでは0のまま固定される。
	size = SCREEN_SIZE
	_build()
	PortraitModal.watch(self, _layout)
	EscClose.attach(self, close)


func open() -> void:
	_layout()
	ModalMotion.show(self, _center)


func _layout() -> void:
	var portrait := ScreenOrientation.is_portrait()
	size = PortraitModal.screen_size()
	_dim.size = size
	_panel.custom_minimum_size.x = PortraitModal.WIDTH if portrait else PANEL_WIDTH
	for button in _row_buttons:
		button.custom_minimum_size = PORTRAIT_ROW_BUTTON_SIZE if portrait else ROW_BUTTON_SIZE
	for row in _rows:
		row.add_theme_constant_override(
			"separation", PORTRAIT_ROW_SEPARATION if portrait else ROW_SEPARATION
		)
	_close_button.custom_minimum_size = PORTRAIT_CLOSE_SIZE if portrait else CLOSE_SIZE
	for summary in _summaries:
		summary.custom_minimum_size.x = PORTRAIT_SUMMARY_WIDTH if portrait else SUMMARY_WIDTH
	PortraitModal.fit(_center)


func close() -> void:
	ModalMotion.hide(self, _center)


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = UiPalette.MODAL_DIM
	_dim.size = SCREEN_SIZE
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	# 大きさは代入せず画面へ張る(代入は中身の最小幅で広がったまま戻らない。Pitfalls.md)。
	_center = CenterContainer.new()
	_center.anchor_right = 1.0
	_center.anchor_bottom = 1.0
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)

	var panel := PanelContainer.new()
	_panel = panel
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	_center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)

	var title := Label.new()
	title.text = "プリセットデッキを読み込む"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UiPalette.T_HEAD)
	column.add_child(title)

	for preset in CardPresetDecks.PRESETS:
		column.add_child(_make_row(preset))

	_close_button = CodedButton.make("閉じる", CLOSE_SIZE)
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_button.pressed.connect(close)
	column.add_child(_close_button)


func _make_row(preset: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_SEPARATION)
	_rows.append(row)

	var button := CodedButton.make(preset["name"], ROW_BUTTON_SIZE)
	var preset_id: String = preset["id"]
	button.pressed.connect(
		func() -> void:
			picked.emit(preset_id)
			close()
	)
	row.add_child(button)
	_row_buttons.append(button)

	var summary := Label.new()
	summary.text = preset["summary"]
	summary.custom_minimum_size = Vector2(SUMMARY_WIDTH, 0)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary.add_theme_color_override("font_color", UiPalette.IVORY)
	row.add_child(summary)
	_summaries.append(summary)
	return row
