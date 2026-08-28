class_name CardPileViewer
extends Control
## 墓地の中身を見るモーダル(GameDesign.md 9章)。山札の中身は見られない。
## 対局中に「何が落ちたか」を数え直せないと、残っている脅威を読めないため用意する。

const SCREEN_SIZE := Vector2(1280, 720)

const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const PANEL_SIZE := Vector2(880, 520)
const COLUMNS := 6

var _title: Label
var _grid: GridContainer
var _empty: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# **`set_anchors_preset()` は使わない**(Architecture.md 4章)。コードで生成した直後の
	# サイズ0のノードへ使うと0のまま固定され、暗幕が盤面を覆わずクリックも止められない。
	size = SCREEN_SIZE
	_build()


## 同じカードは1枚にまとめ、枚数をバッジで出す。20枚が並ぶと読み取れないため。
func open_pile(title: String, cards: Array) -> void:
	_title.text = "%s(%d枚)" % [title, cards.size()]
	for child in _grid.get_children():
		child.queue_free()
	var counts: Dictionary = {}
	var order: Array = []
	for card in cards:
		if not counts.has(card):
			counts[card] = 0
			order.append(card)
		counts[card] += 1
	order.sort_custom(
		func(a: CardData, b: CardData) -> bool:
			return a.cost < b.cost if a.cost != b.cost else a.id < b.id
	)
	for card in order:
		var view := CardView.new()
		view.mode = CardView.Mode.HAND
		view.custom_minimum_size = CardView.HAND_SIZE_PX
		view.badge = "×%d" % counts[card]
		_grid.add_child(view)
		view.show_card(card, true)
	_empty.visible = cards.is_empty()
	visible = true


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.size = SCREEN_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_SIZE
	panel.size = PANEL_SIZE
	panel.position = (Vector2(1280, 720) - PANEL_SIZE) * 0.5
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	column.add_child(_title)
	_empty = Label.new()
	_empty.text = "まだ何も落ちていません。"
	column.add_child(_empty)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)
	# VBoxContainer は子を横いっぱいに広げるため、明示的に中央へ縮める。
	var close := CodedButton.make("閉じる", Vector2(160, 48))
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func() -> void: visible = false)
	column.add_child(close)


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		visible = false
