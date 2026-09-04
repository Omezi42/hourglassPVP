class_name CardListScreen
extends Control
## 砂時計図鑑(GameDesign.md 9章)。**机に開いた見開きの本**として、左のページに一覧、
## 右のページに選んだ1枚の解説を置く。カードを並べるだけの表ではなく、
## 集めたものを綴じておく場所として作る。

signal back_pressed

## 並び順(GameDesign.md 9章)。既定はコスト順で、押すたびに追加順と往復する。
enum Order { COST, POOL }

const ORDER_LABELS := {Order.COST: "コスト順", Order.POOL: "追加順"}
const SCREEN_SIZE := Vector2(1280, 720)
const COLUMNS := 3
const SCROLLBAR_WIDTH := 14.0
## 一覧を敷く範囲(左のページの内側)。見出しと丁付けのぶんを上下へ空ける。
const INDEX_RECT := Rect2(
	AlmanacBook.LEFT_PAGE.position.x + 16,
	AlmanacBook.LEFT_PAGE.position.y + 52,
	AlmanacBook.LEFT_PAGE.size.x - 32,
	AlmanacBook.LEFT_PAGE.size.y - 84
)
## 解説を置く範囲(右のページの内側)。
const PAGE_RECT := Rect2(
	AlmanacBook.RIGHT_PAGE.position.x + 26,
	AlmanacBook.RIGHT_PAGE.position.y + 24,
	AlmanacBook.RIGHT_PAGE.size.x - 52,
	AlmanacBook.RIGHT_PAGE.size.y - 56
)
## 本の外に置く操作。**紙面へ操作を載せない**(GameDesign.md 9章)。
const BACK_RECT := Rect2(24, 28, 96, 42)
const ORDER_RECT := Rect2(SCREEN_SIZE.x - 24 - 168, 28, 168, 42)

var _page: AlmanacPage
var _keyword_popup: KeywordPopup
var _views: Array[AlmanacEntry] = []
var _grid: GridContainer
var _selected: CardData
var _order_button: Button
var _order: Order = Order.COST
var _font: Font
var _heading: Control


func _ready() -> void:
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font
	_build()
	# 開いた直後に解説が空のまま置かれないよう、先頭のカードを選んでおく。
	if not _views.is_empty():
		_select(_views[0].card)


func _build() -> void:
	add_child(AlmanacBook.new())

	var back := CodedButton.make("← 戻る", BACK_RECT.size)
	back.position = BACK_RECT.position
	back.pressed.connect(func() -> void: back_pressed.emit())
	add_child(back)
	_order_button = CodedButton.make("並び替え:%s" % ORDER_LABELS[_order], ORDER_RECT.size)
	_order_button.position = ORDER_RECT.position
	_order_button.pressed.connect(_on_order_pressed)
	add_child(_order_button)

	var heading := Control.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.size = SCREEN_SIZE
	heading.draw.connect(_draw_heading)
	add_child(heading)
	_heading = heading

	var scroll := ScrollContainer.new()
	scroll.position = INDEX_RECT.position
	scroll.size = INDEX_RECT.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", _h_separation())
	_grid.add_theme_constant_override("v_separation", 2)
	scroll.add_child(_grid)
	_fill_grid()

	_page = AlmanacPage.new()
	_page.position = PAGE_RECT.position
	_page.custom_minimum_size = PAGE_RECT.size
	_page.size = PAGE_RECT.size
	add_child(_page)

	# 語を押すとその意味を引ける(GameDesign.md 17章)。全画面へ暗幕を敷くため、
	# ページではなく画面側が持つ。
	_keyword_popup = KeywordPopup.new()
	add_child(_keyword_popup)
	_page.keyword_pressed.connect(func(entry: Dictionary) -> void: _keyword_popup.open(entry))


## 見出しと丁付けは紙へ直に刷る(枠を持つUI部品にしない)。
## **本より手前に描く独立したノードへ置く**——`Control._draw()` は自分の子より
## 背面に描かれるため、画面側で描くと本の紙に隠れて何も見えない(実際にそうなった)。
func _draw_heading() -> void:
	var page := AlmanacBook.LEFT_PAGE
	_heading.draw_string(
		_font,
		Vector2(page.position.x + 16, page.position.y + 42),
		"砂 時 計 図 鑑",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		25,
		AlmanacEntry.INK
	)
	_heading.draw_string(
		_font,
		Vector2(page.end.x - 156, page.position.y + 42),
		"収集 %d / %d" % [_views.size(), _views.size()],
		HORIZONTAL_ALIGNMENT_RIGHT,
		140,
		16,
		AlmanacEntry.INK_SOFT
	)
	_draw_rule(Vector2(page.position.x + 16, page.position.y + 52), page.size.x - 32)


## 飾り罫。両端へ菱形を置いた1本線。
func _draw_rule(at: Vector2, width: float) -> void:
	_heading.draw_line(
		at + Vector2(8, 0), at + Vector2(width - 8, 0), Color(0.45, 0.33, 0.18, 0.6), 1.4
	)
	for x in [at.x + 2.0, at.x + width - 2.0]:
		var c := Vector2(x, at.y)
		_heading.draw_colored_polygon(
			PackedVector2Array(
				[c + Vector2(0, -4), c + Vector2(4, 0), c + Vector2(0, 4), c + Vector2(-4, 0)]
			),
			Color(0.45, 0.33, 0.18, 0.8)
		)


## 一覧の幅から列の間隔を割り出す。縦のスクロールバーぶんを引いておく。
static func _h_separation() -> int:
	var usable := INDEX_RECT.size.x - SCROLLBAR_WIDTH - COLUMNS * AlmanacEntry.CELL_SIZE.x
	return maxi(int(usable / float(COLUMNS - 1)), 0)


func _select(card: CardData) -> void:
	_selected = card
	for view in _views:
		view.selected = view.card == card
		view.queue_redraw()
	_page.show_card(card)


## いま選んでいる並び順でカードを並べ直す。選択中のカードは並びが変わっても保つ。
func _fill_grid() -> void:
	# **remove_child してから解放する。**queue_free() だけだとフレームの終わりまで
	# 子として残り、並べ直したカードがその後ろへ付いて並び順が1フレーム崩れる。
	for view in _views:
		_grid.remove_child(view)
		view.queue_free()
	_views.clear()
	var cards := _cards_in_order()
	for i in cards.size():
		var view := AlmanacEntry.new()
		_grid.add_child(view)
		view.show_card(cards[i], i + 1)
		view.selected = cards[i] == _selected
		view.pressed.connect(_select)
		_views.append(view)


func _cards_in_order() -> Array[CardData]:
	match _order:
		Order.POOL:
			return CardLibrary.sorted_by_pool_index()
		_:
			return CardLibrary.sorted_by_cost()


func _on_order_pressed() -> void:
	_order = Order.POOL if _order == Order.COST else Order.COST
	_order_button.text = "並び替え:%s" % ORDER_LABELS[_order]
	_fill_grid()
