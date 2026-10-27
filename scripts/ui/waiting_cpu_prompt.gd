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
## 縦(GameDesign.md 9章「縦画面」)。`PortraitModal` の論理幅で組み、2つのボタンは上下に積む。
const PORTRAIT_BUTTON_SIZE := Vector2(320, 56)
const BODY_INSET := 48.0

var _dim: ColorRect
var _center: CenterContainer
var _panel: PanelContainer
var _body: Label
var _buttons: BoxContainer


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
	var width := PortraitModal.WIDTH if portrait else PANEL_WIDTH
	_panel.custom_minimum_size.x = width
	_body.custom_minimum_size.x = width - BODY_INSET
	_buttons.vertical = portrait
	for button in _buttons.get_children():
		(button as Control).custom_minimum_size = PORTRAIT_BUTTON_SIZE if portrait else BUTTON_SIZE
	PortraitModal.fit(_center)


func close() -> void:
	visible = false


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, DIM_ALPHA)
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
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	_center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)

	var title := Label.new()
	title.text = "対戦相手が見つかりました"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	column.add_child(title)

	var body := Label.new()
	_body = body
	# 折り返しは幅より先に立てる(Pitfalls.md)。
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = PANEL_WIDTH - BODY_INSET
	body.text = "ほかのプレイヤーがマッチングを待っています。\nマッチングすると、いまのCPU戦は記録に残さず終わります。"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	body.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	column.add_child(body)

	var row := BoxContainer.new()
	_buttons = row
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	var keep := CodedButton.make("このままCPUと続ける", BUTTON_SIZE)
	keep.pressed.connect(func() -> void: continue_pressed.emit())
	row.add_child(keep)
	var go := CodedButton.make_in_group("マッチングする", BUTTON_SIZE, CodedButton.PRIMARY_ACTION_GROUP)
	go.pressed.connect(func() -> void: match_pressed.emit())
	row.add_child(go)
