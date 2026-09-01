class_name CardListScreen
extends Control
## 砂時計(カード)の一覧(GameDesign.md 9章)。定義されている全種類を並べ、
## 選ぶと右の詳細パネルに内容を出す。

signal back_pressed

## 並び順(GameDesign.md 9章)。既定はコスト順で、押すたびに追加順と往復する。
enum Order { COST, POOL }

const ORDER_LABELS := {Order.COST: "コスト順", Order.POOL: "追加順"}
const HEADER_SCENE := "res://scenes/screen_header.tscn"
const COLUMNS := 6
const SCROLLBAR_WIDTH := 16.0
const SCREEN_SIZE := Vector2(1280, 720)
## 一覧と詳細の間隔。左右の外周余白と同じ値にして、3つの間隔を揃える。
const COLUMN_GAP := ScreenHeader.OUTER_MARGIN
const CONTENT_HEIGHT := ScreenHeader.CONTENT_HEIGHT
const DETAIL_POSITION := Vector2(
	SCREEN_SIZE.x - ScreenHeader.OUTER_MARGIN - CardDetailPanel.PANEL_SIZE.x,
	ScreenHeader.CONTENT_TOP
)
const GRID_RECT := Rect2(
	ScreenHeader.OUTER_MARGIN,
	ScreenHeader.CONTENT_TOP,
	DETAIL_POSITION.x - COLUMN_GAP - ScreenHeader.OUTER_MARGIN,
	CONTENT_HEIGHT
)

var _detail: CardDetailPanel
var _keyword_popup: KeywordPopup
var _views: Array[CardView] = []
var _grid: GridContainer
var _selected: CardData
var _order_button: Button
var _order: Order = Order.COST


func _ready() -> void:
	_build()
	# 開いた直後に詳細が空のまま置かれないよう、先頭のカードを選んでおく。
	if not _views.is_empty():
		_select(_views[0])


func _build() -> void:
	add_child(ScreenBackdrop.new())

	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	header.set_title("砂時計一覧")
	header.back_pressed.connect(func() -> void: back_pressed.emit())
	_order_button = CodedButton.make(ORDER_LABELS[_order], Vector2(190, 56))
	_order_button.pressed.connect(_on_order_pressed)
	header.add_action(_order_button)

	var scroll := ScrollContainer.new()
	scroll.position = GRID_RECT.position
	scroll.size = GRID_RECT.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	# 6列が一覧の幅いっぱいに広がるよう、余りを列の間隔へ配る。固定の間隔だと
	# 右端に列1つ分に満たない空きが残り、一覧だけが左へ寄って見える。
	_grid.add_theme_constant_override("h_separation", _h_separation())
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)
	_fill_grid()

	_detail = CardDetailPanel.new()
	_detail.position = DETAIL_POSITION
	add_child(_detail)
	# 効果文が下端で切れないよう、詳細パネルはコンテンツ領域の高さいっぱいまで伸ばす。
	# `CardDetailPanel._ready()` が既定サイズを入れるため、add_child の後に上書きする。
	_detail.custom_minimum_size = Vector2(CardDetailPanel.PANEL_SIZE.x, GRID_RECT.size.y)
	_detail.size = _detail.custom_minimum_size

	# 語を押すとその意味を引ける(GameDesign.md 17章)。全画面へ暗幕を敷くため、
	# 詳細パネルではなく画面側が持つ。
	_keyword_popup = KeywordPopup.new()
	add_child(_keyword_popup)
	_detail.keyword_pressed.connect(func(entry: Dictionary) -> void: _keyword_popup.open(entry))


## 一覧の幅から列の間隔を割り出す。縦のスクロールバーぶんを引いておく。
static func _h_separation() -> int:
	var usable := GRID_RECT.size.x - SCROLLBAR_WIDTH - COLUMNS * CardView.HAND_SIZE_PX.x
	return int(usable / float(COLUMNS - 1))


func _select(view: CardView) -> void:
	_selected = view.card
	for other in _views:
		other.selected = other == view
		other.queue_redraw()
	_detail.show_card(view.card)


## いま選んでいる並び順でカードを並べ直す。選択中のカードは並びが変わっても保つ。
func _fill_grid() -> void:
	# **remove_child してから解放する。**queue_free() だけだとフレームの終わりまで
	# 子として残り、並べ直したカードがその後ろへ付いて並び順が1フレーム崩れる。
	for view in _views:
		_grid.remove_child(view)
		view.queue_free()
	_views.clear()
	for card in _cards_in_order():
		var view := CardView.new()
		view.mode = CardView.Mode.HAND
		view.custom_minimum_size = CardView.HAND_SIZE_PX
		# 並べて見比べる画面では守護だけ枠を太くしない(GameDesign.md 9章)。
		view.guard_frame = false
		view.show_card(card, true)
		view.selected = card == _selected
		view.pressed.connect(_select)
		_grid.add_child(view)
		_views.append(view)


func _cards_in_order() -> Array[CardData]:
	match _order:
		Order.POOL:
			return CardLibrary.sorted_by_pool_index()
		_:
			return CardLibrary.sorted_by_cost()


func _on_order_pressed() -> void:
	_order = Order.POOL if _order == Order.COST else Order.COST
	_order_button.text = ORDER_LABELS[_order]
	_fill_grid()
