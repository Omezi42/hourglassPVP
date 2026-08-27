class_name CardListScreen
extends Control
## 砂時計(カード)の一覧(GameDesign.md 9章)。定義されている全種類を並べ、
## 選ぶと右の詳細パネルに内容を出す。

signal back_pressed

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const COLUMNS := 6
const GRID_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 800, 540)
const DETAIL_POSITION := Vector2(852, ScreenHeader.CONTENT_TOP)

var _detail: CardDetailPanel
var _views: Array[CardView] = []


func _ready() -> void:
	_build()
	# 開いた直後に詳細が空のまま置かれないよう、先頭のカードを選んでおく。
	if not _views.is_empty():
		_select(_views[0])


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color(0.07, 0.06, 0.08, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	header.set_title("砂時計一覧")
	header.back_pressed.connect(func() -> void: back_pressed.emit())

	var scroll := ScrollContainer.new()
	scroll.position = GRID_RECT.position
	scroll.size = GRID_RECT.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	for card in CardLibrary.all_cards():
		var view := CardView.new()
		view.mode = CardView.Mode.HAND
		view.custom_minimum_size = CardView.HAND_SIZE_PX
		view.show_card(card, true)
		view.pressed.connect(_select)
		grid.add_child(view)
		_views.append(view)

	_detail = CardDetailPanel.new()
	_detail.position = DETAIL_POSITION
	add_child(_detail)


func _select(view: CardView) -> void:
	for other in _views:
		other.selected = other == view
		other.queue_redraw()
	_detail.show_card(view.card)
