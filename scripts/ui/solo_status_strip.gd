class_name SoloStatusStrip
extends Control
## 縦の遠征の地図の最下段に置く状態の帯(GameDesign.md 9章「縦のその他の画面」)。
## 作戦名・深さ / HPのバーと勝った数 / 持っている恩恵の3行と「山札 N枚 ▸」を出す。
## 山札の一覧と「遠征をやめる」は呼び出し側が下から引き出す板(`SoloStatusPanel`)に出す。

signal deck_pressed

const PADDING := 16.0
const LINE_GAP := 8.0
const THEME_FONT_SIZE := 24
const BOONS_FONT_SIZE := 20
const WINS_FONT_SIZE := 22
const HP_FONT_SIZE := 20
const THEME_HEIGHT := 32.0
const HP_BAR_HEIGHT := 34.0
const BOONS_HEIGHT := 28.0
const WINS_WIDTH := 72.0
const BUTTON_SIZE := Vector2(200, 72)
const BUTTON_FONT_SIZE := 24
const BUTTON_GAP := 16.0
const HEIGHT := PADDING * 2.0 + THEME_HEIGHT + HP_BAR_HEIGHT + BOONS_HEIGHT + LINE_GAP * 2.0

var _panel_canvas: Control
var _theme_label: Label
var _hp_canvas: Control
var _wins_label: Label
var _boons_label: Label
var _deck_button: Button
var _hp := 0
var _max_hp := MatchState.INITIAL_HP


func _ready() -> void:
	_panel_canvas = Control.new()
	_panel_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_canvas.draw.connect(
		func() -> void:
			SoloUiPaint.paint_panel(
				_panel_canvas.get_canvas_item(), Rect2(Vector2.ZERO, size), false
			)
	)
	add_child(_panel_canvas)
	_theme_label = _make_label(THEME_FONT_SIZE, UiPalette.BRASS_HIGHLIGHT)
	add_child(_theme_label)
	_hp_canvas = Control.new()
	_hp_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_canvas.draw.connect(_draw_hp_bar)
	add_child(_hp_canvas)
	_wins_label = _make_label(WINS_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	_wins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_wins_label)
	_boons_label = _make_label(BOONS_FONT_SIZE, UiPalette.TEXT_MUTED)
	# 恩恵が多いと1行に収まらない。全部は山札の板(状態のパネル)で読める。
	_boons_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_boons_label)
	_deck_button = CodedButton.make("", BUTTON_SIZE)
	_deck_button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	_deck_button.pressed.connect(func() -> void: deck_pressed.emit())
	add_child(_deck_button)
	resized.connect(_layout)
	_layout()


func show_data(
	theme_id: String,
	hp: int,
	max_hp: int,
	wins: int,
	deck_size: int,
	boons: Array[String],
	depth: int
) -> void:
	var depth_part := " ・ 深さ%d" % depth if depth > 0 else ""
	_theme_label.text = "作戦「%s」%s" % [CardCpuDecks.name_of(theme_id), depth_part]
	_hp = hp
	_max_hp = max_hp
	_hp_canvas.queue_redraw()
	_wins_label.text = "%d勝" % wins
	_boons_label.text = "恩恵: %s" % SoloStatusPanel.boon_names(boons)
	_deck_button.text = "山札 %d枚 ▸" % deck_size


func _draw_hp_bar() -> void:
	SoloStatusPanel.paint_hp_bar(_hp_canvas, _hp, _max_hp, HP_FONT_SIZE)


func _layout() -> void:
	if _panel_canvas == null:
		return
	_panel_canvas.size = size
	var text_w := size.x - PADDING * 2.0 - BUTTON_SIZE.x - BUTTON_GAP
	var top := PADDING
	_theme_label.position = Vector2(PADDING, top)
	_theme_label.size = Vector2(text_w, THEME_HEIGHT)
	top += THEME_HEIGHT + LINE_GAP
	_hp_canvas.position = Vector2(PADDING, top)
	_hp_canvas.size = Vector2(text_w - WINS_WIDTH - LINE_GAP, HP_BAR_HEIGHT)
	_wins_label.position = Vector2(PADDING + text_w - WINS_WIDTH, top)
	_wins_label.size = Vector2(WINS_WIDTH, HP_BAR_HEIGHT)
	top += HP_BAR_HEIGHT + LINE_GAP
	_boons_label.position = Vector2(PADDING, top)
	_boons_label.size = Vector2(text_w, BOONS_HEIGHT)
	_deck_button.position = Vector2(
		size.x - PADDING - BUTTON_SIZE.x, (size.y - BUTTON_SIZE.y) * 0.5
	)


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
