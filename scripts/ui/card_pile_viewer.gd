class_name CardPileViewer
extends Control
## 墓地の中身を見るモーダル(GameDesign.md 9章)。山札の中身は見られない。
## 対局中に「何が落ちたか」を数え直せないと、残っている脅威を読めないため用意する。
##
## 墓地から1体を選ぶ効果(6章「墓地を読む効果」)では、同じ形で選べる砂時計だけを
## 1枚ずつ並べて押させる(`open_choice()`)。

const PANEL_STYLE := "res://resources/theme/content_panel.tres"
## パネルは幅だけ決め、高さは中身(何行並ぶか)に合わせて伸ばす。固定にすると
## 数枚しか無いときに中身が上へ寄り、下半分がまるごと空いて見える。
const PANEL_WIDTH := 880.0
## 一覧が伸びる上限。これを超えたらスクロールする。
const MAX_ROWS := 3
const COLUMNS := 6
const ROW_GAP := 10.0
const TITLE_FONT_SIZE := 24
const EMPTY_FONT_SIZE := 18
const CLOSE_FONT_SIZE := 20
const CLOSE_SIZE := Vector2(160, 48)
## パネルの枠の内側の余白(`content_panel.tres` の左右)。
const PANEL_PAD := 24.0
## 縦は列を減らし、札と文字を大きくする(GameDesign.md 9章「縦画面」)。
const PORTRAIT_COLUMNS := 4
const PORTRAIT_MAX_ROWS := 4

var _title: Label
var _grid: GridContainer
var _scroll: ScrollContainer
var _empty: Label
var _close: Button
## 選ぶモードのときの受け手。押した墓地の位置を渡す。見るだけのときは空。
var _on_pick := Callable()
var _on_cancel := Callable()
var _dim: ColorRect
var _center: CenterContainer
var _panel: PanelContainer
var _columns := COLUMNS
var _max_rows := MAX_ROWS
var _card_size := CardView.HAND_SIZE_PX


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# **`set_anchors_preset()` は使わない**(Architecture.md 4章)。コードで生成した直後の
	# サイズ0のノードへ使うと0のまま固定され、暗幕が盤面を覆わずクリックも止められない。
	_build()


## 向きに合わせる(`CardMatchArrange`)。中身は開くたびに作るため、次に開いたときから効く。
func apply_layout(layout: CardMatchLayout) -> void:
	size = layout.screen_size
	_dim.size = layout.screen_size
	_center.size = layout.screen_size
	var zoom := layout.text_scale
	_columns = PORTRAIT_COLUMNS if layout.portrait else COLUMNS
	_max_rows = PORTRAIT_MAX_ROWS if layout.portrait else MAX_ROWS
	_card_size = CardView.HAND_SIZE_PX * (layout.hand_scale if layout.portrait else 1.0)
	_grid.columns = _columns
	var width := _card_size.x * _columns + ROW_GAP * (_columns - 1) + PANEL_PAD * 2.0
	_panel.custom_minimum_size = Vector2(width if layout.portrait else PANEL_WIDTH, 0)
	_title.add_theme_font_size_override("font_size", roundi(TITLE_FONT_SIZE * zoom))
	_empty.add_theme_font_size_override("font_size", roundi(EMPTY_FONT_SIZE * zoom))
	_close.add_theme_font_size_override("font_size", roundi(CLOSE_FONT_SIZE * zoom))
	_close.custom_minimum_size = CLOSE_SIZE * zoom
	_close.size = CLOSE_SIZE * zoom


## 同じカードは1枚にまとめ、枚数をバッジで出す。30枚が並ぶと読み取れないため。
func open_pile(
	title: String, cards: Array, skin_viewer: CardSkins.Viewer = CardSkins.Viewer.SELF
) -> void:
	_on_pick = Callable()
	_on_cancel = Callable()
	_close.text = "閉じる"
	_title.text = "%s(%d枚)" % [title, cards.size()]
	_clear_grid()
	var counts: Dictionary = {}
	var order: Array = []
	for card in cards:
		if not counts.has(card):
			counts[card] = 0
			order.append(card)
		counts[card] += 1
	order.sort_custom(CardLibrary.compare_by_cost)
	for card in order:
		var view := CardView.new()
		view.mode = CardView.Mode.HAND
		view.custom_minimum_size = _card_size
		view.badge = "×%d" % counts[card]
		view.skin_viewer = skin_viewer
		_grid.add_child(view)
		view.show_card(card, true)
	_show(cards.is_empty(), order.size())


## 墓地から1体を選ばせる。`indices` は選べるものの墓地での位置で、同じカードでも
## 1枚ずつ並べる(どの1枚を選んだかを位置で返すため)。やめると `on_cancel` を呼ぶ。
func open_choice(
	title: String, pile: Array, indices: Array[int], on_pick: Callable, on_cancel: Callable
) -> void:
	_on_pick = on_pick
	_on_cancel = on_cancel
	_close.text = "やめる"
	_title.text = title
	_clear_grid()
	for index in indices:
		var view := CardView.new()
		view.mode = CardView.Mode.HAND
		view.custom_minimum_size = _card_size
		_grid.add_child(view)
		view.show_card(pile[index], true)
		view.pressed.connect(func(_view: CardView) -> void: _pick(index))
	_show(indices.is_empty(), indices.size())


func _clear_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()


func _show(empty: bool, count: int) -> void:
	_empty.visible = empty
	_scroll.visible = not empty
	var rows: int = ceili(float(count) / float(_columns))
	var row_height: float = _card_size.y + ROW_GAP
	_scroll.custom_minimum_size = Vector2(0, mini(maxi(rows, 1), _max_rows) * row_height)
	visible = true


func _pick(index: int) -> void:
	var on_pick := _on_pick
	_on_pick = Callable()
	_on_cancel = Callable()
	visible = false
	on_pick.call(index)


func _dismiss() -> void:
	var on_cancel := _on_cancel
	_on_pick = Callable()
	_on_cancel = Callable()
	visible = false
	if on_cancel.is_valid():
		on_cancel.call()


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.65)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)

	# 中身の高さで伸び縮みさせつつ画面の中央に置くため、CenterContainer へ入れる。
	_center = CenterContainer.new()
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
	column.add_theme_constant_override("separation", 12)
	_panel.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	column.add_child(_title)
	_empty = Label.new()
	_empty.text = "まだ何も落ちていません。"
	column.add_child(_empty)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.enable(_scroll)
	column.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", int(ROW_GAP))
	_grid.add_theme_constant_override("v_separation", int(ROW_GAP))
	_scroll.add_child(_grid)
	# VBoxContainer は子を横いっぱいに広げるため、明示的に中央へ縮める。
	_close = CodedButton.make("閉じる", CLOSE_SIZE)
	_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close.pressed.connect(_dismiss)
	column.add_child(_close)


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_dismiss()
