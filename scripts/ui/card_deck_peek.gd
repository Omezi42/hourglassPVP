class_name CardDeckPeek
extends Control
## デッキ一覧の「一覧」(GameDesign.md 9章「デッキ一覧」)。暗幕の上へ、30枚を共有のデッキ表と同じ棚
## (`CardDeckShelf`、横10×縦3。縦画面は6×5)で出す。
## `CardDeckSheet` をそのまま使わないのは、書き出し用の隅の作品名とバージョンを画面に出さないため。
## 下の「閉じる」と主の操作(管理=編集する / 対局前=このデッキで対局)だけを持ち、駒は押せない。

signal primary_pressed

const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const DIM_COLOR := Color(UiPalette.INK_900, 0.62)
## 横の棚は共有のデッキ表(1208×510)と同じ縦横比。
const SHELF_SIZE := Vector2(1108, 468)
const PORTRAIT_SHELF_SIZE := Vector2(624, 730)
const PORTRAIT_COLUMNS := 6
const PORTRAIT_TEXT_SCALE := 1.7
const ROW_GAP := 12.0
const TITLE_FONT := 30
const SUB_FONT := 17
const PORTRAIT_TITLE_FONT := 36
const PORTRAIT_SUB_FONT := 24
const CLOSE_SIZE := Vector2(180, 56)
const PRIMARY_SIZE := Vector2(240, 56)
const PORTRAIT_CLOSE_SIZE := Vector2(200, 72)
const PORTRAIT_PRIMARY_SIZE := Vector2(300, 72)
const PORTRAIT_BUTTON_FONT := 26

var _panel: PanelContainer
var _title: Label
var _sub: Label
var _shelf: CardDeckShelf
var _close: Button
var _primary: Button
var _portrait := false


func _ready() -> void:
	visible = false
	anchor_right = 1.0
	anchor_bottom = 1.0
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", ROW_GAP * 1.5)
	center.add_child(column)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", load(PANEL_STYLE))
	column.add_child(_panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", ROW_GAP)
	_panel.add_child(body)
	_title = Label.new()
	body.add_child(_title)
	_sub = Label.new()
	_sub.add_theme_color_override("font_color", UiPalette.MUTED)
	body.add_child(_sub)
	_shelf = CardDeckShelf.new()
	_shelf.readonly = true
	_shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_shelf)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", ROW_GAP)
	column.add_child(buttons)
	_close = CodedButton.make("閉じる", CLOSE_SIZE)
	_close.pressed.connect(close)
	buttons.add_child(_close)
	_primary = CodedButton.make_in_group("", PRIMARY_SIZE, CodedButton.PRIMARY_ACTION_GROUP)
	_primary.pressed.connect(
		func() -> void:
			close()
			primary_pressed.emit()
	)
	buttons.add_child(_primary)
	_layout()


func open(deck_name: String, cards: Array, primary_label: String) -> void:
	_title.text = deck_name
	_sub.text = "%d枚  ・  %s" % [cards.size(), CardDeckCase.summary_of(cards)]
	_shelf.deck = cards.duplicate()
	_primary.text = primary_label
	visible = true


func close() -> void:
	visible = false


func apply_orientation(portrait: bool) -> void:
	_portrait = portrait
	if _panel != null:
		_layout()


func _layout() -> void:
	_shelf.columns = PORTRAIT_COLUMNS if _portrait else CardDeckSheet.COLUMNS
	_shelf.text_scale = PORTRAIT_TEXT_SCALE if _portrait else 1.0
	_shelf.custom_minimum_size = PORTRAIT_SHELF_SIZE if _portrait else SHELF_SIZE
	_title.add_theme_font_size_override(
		"font_size", PORTRAIT_TITLE_FONT if _portrait else TITLE_FONT
	)
	_sub.add_theme_font_size_override("font_size", PORTRAIT_SUB_FONT if _portrait else SUB_FONT)
	_close.custom_minimum_size = PORTRAIT_CLOSE_SIZE if _portrait else CLOSE_SIZE
	_primary.custom_minimum_size = PORTRAIT_PRIMARY_SIZE if _portrait else PRIMARY_SIZE
	for button in [_close, _primary]:
		if _portrait:
			button.add_theme_font_size_override("font_size", PORTRAIT_BUTTON_FONT)
		else:
			button.remove_theme_font_size_override("font_size")


## 開いている間のEscは、一覧画面から戻らずにこれを閉じる(`Main` より先に受ける)。
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
