class_name LearnMenu
extends Control
## メニューの「遊び方」から開く、ルールを読む・覚える入口のモーダル(GameDesign.md 9章)。
## 「1局遊んで覚える」(誘導対局)を先頭に、遊び方・画面の見かた・キーワード辞書を並べる。
## ホームに常に出しておくほどではないが、迷ったときにメニューから必ずたどれる場所に置く。
## 組み立てはメニュー(`SettingsPanel`)と同じ「暗幕 + 中央のパネル」。

signal tutorial_requested
signal rules_requested
signal screen_guide_requested
signal keyword_dict_requested

const PANEL_STYLE := preload("res://resources/theme/content_panel.tres")
const DIM_COLOR := Color(0, 0, 0, 0.6)
const PANEL_WIDTH := 440.0
const MARGIN := 32
const SEPARATION := 18
const TITLE_SIZE := 30
const TITLE_COLOR := Color(0.85, 0.62, 0.22)
const BUTTON_SIZE := Vector2(376, 64)
const CLOSE_SIZE := Vector2(200, 56)

var _center: CenterContainer


func _init() -> void:
	visible = false
	anchor_right = 1.0
	anchor_bottom = 1.0
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)
	_center = CenterContainer.new()
	_center.anchor_right = 1.0
	_center.anchor_bottom = 1.0
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	panel.add_theme_stylebox_override("panel", PANEL_STYLE)
	_center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", SEPARATION)
	margin.add_child(column)
	var title := Label.new()
	title.text = "ルールを覚える"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	column.add_child(title)
	_add_entry(column, "1局遊んで覚える", tutorial_requested)
	_add_entry(column, "遊び方", rules_requested)
	_add_entry(column, "画面の見かた", screen_guide_requested)
	_add_entry(column, "キーワード辞書", keyword_dict_requested)
	var close_button := CodedButton.make("とじる", CLOSE_SIZE)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	column.add_child(close_button)


func _ready() -> void:
	PortraitModal.watch(self, _fit)


## 入口を押したら閉じてから知らせる(開いた先の画面から戻ったとき、モーダルを残さない)。
func _add_entry(column: VBoxContainer, label: String, request: Signal) -> void:
	var button := CodedButton.make(label, BUTTON_SIZE)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(
		func() -> void:
			close()
			request.emit()
	)
	column.add_child(button)


func open() -> void:
	_fit()
	visible = true
	move_to_front()


func close() -> void:
	visible = false


func apply_orientation(_portrait: bool) -> void:
	_fit()


func _fit() -> void:
	PortraitModal.fit(_center)


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
