class_name CardDeckListScreen
extends Control
## 保存済みデッキの一覧(GameDesign.md 9章)。**管理**(編集・削除・並び替え)と、
## **対局の開始前に使うデッキを選ぶ**の2つのモードを1つの画面で兼ねる。
##
## どちらも同じ見た目のカード一覧を出すためで、選ぶ側だけ別の画面を作ると
## 片方の見た目が古くなる。件数が増えても1画面に収まるよう**横2列のグリッド**とする。

signal back_pressed
signal create_requested
signal edit_requested(index: int)
signal deck_picked(index: int)

enum Mode { MANAGE, PICK }

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const CONFIRM_SCENE := "res://scenes/confirm_modal.tscn"
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const LIST_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 1232, ScreenHeader.CONTENT_HEIGHT)
const CARD_SIZE := Vector2(596, 112)
## 代表として並べる紋章の数。30枚をそのまま並べるとカードに収まらない(GameDesign.md 9章)。
const EMBLEM_COUNT := 5
const EMBLEM_SIZE := Vector2(34, 34)

var _header: ScreenHeader
var _grid: GridContainer
var _empty_label: Label
var _create_button: Button
var _reorder_button: Button
var _confirm: ConfirmModal
var _mode: Mode = Mode.MANAGE
var _reordering := false
var _pending_delete := -1


func _ready() -> void:
	_build()


## 管理として開く(デッキタブから)。
func open_manage() -> void:
	_mode = Mode.MANAGE
	_reordering = false
	_refresh()


## 対局の開始前に使うデッキを選ぶ(GameDesign.md 9章)。
func open_pick() -> void:
	_mode = Mode.PICK
	_reordering = false
	_refresh()


func _build() -> void:
	add_child(ScreenBackdrop.new())

	_header = load(HEADER_SCENE).instantiate()
	add_child(_header)
	_header.back_pressed.connect(func() -> void: back_pressed.emit())
	_create_button = CodedButton.make("新規デッキ作成", Vector2(220, 56))
	_create_button.pressed.connect(func() -> void: create_requested.emit())
	_header.add_action(_create_button)
	_reorder_button = CodedButton.make("デッキ入れ替え", Vector2(220, 56))
	_reorder_button.pressed.connect(_on_reorder_pressed)
	_header.add_action(_reorder_button)

	var panel := PanelContainer.new()
	panel.position = LIST_RECT.position
	panel.size = LIST_RECT.size
	panel.custom_minimum_size = LIST_RECT.size
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var column := VBoxContainer.new()
	panel.add_child(column)
	_empty_label = Label.new()
	_empty_label.add_theme_font_size_override("font_size", 20)
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_empty_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	# モーダルは最後に足す(後から足した子ほど手前に描かれるため)。
	_confirm = load(CONFIRM_SCENE).instantiate()
	add_child(_confirm)
	_confirm.confirmed.connect(_on_delete_confirmed)
	_confirm.cancelled.connect(func() -> void: _pending_delete = -1)


# --- 表示 ---------------------------------------------------------------


func _refresh() -> void:
	var decks := CardDeckSave.list_decks()
	var picking: bool = _mode == Mode.PICK
	_header.set_title("使うデッキを選ぶ" if picking else "デッキ")
	_create_button.visible = not picking
	_reorder_button.visible = not picking and decks.size() > 1
	_reorder_button.text = "並び替えを終える" if _reordering else "デッキ入れ替え"
	_empty_label.text = _guide_text(decks.size(), picking)
	for child in _grid.get_children():
		child.queue_free()
	for i in decks.size():
		_grid.add_child(_make_card(i, decks[i], decks.size()))


func _guide_text(count: int, picking: bool) -> String:
	if count == 0:
		if picking:
			return "保存したデッキがありません。プリセットの「基本」で対局へ入れます"
		return "保存したデッキがありません。「新規デッキ作成」から%d枚のデッキを作ってください" % MatchState.DECK_SIZE
	if picking:
		return "対局で使うデッキを選んでください"
	if _reordering:
		return "↑ ↓ で並び順を入れ替えます"
	return "%d 個のデッキ" % count


func _make_card(index: int, deck: Dictionary, total: int) -> Control:
	var area := ClickArea.new()
	area.custom_minimum_size = CARD_SIZE
	if _mode == Mode.PICK:
		area.area_pressed.connect(func() -> void: deck_picked.emit(index))
	else:
		# 管理では編集・削除のボタンだけを押させる。カード全体を押せるようにすると
		# 「押したら何が起きるのか」が2通りになる。
		area.mouse_default_cursor_shape = Control.CURSOR_ARROW
		area.mouse_filter = Control.MOUSE_FILTER_PASS

	var panel := PanelContainer.new()
	panel.name = "VisualRoot"
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	area.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_column)
	var name_label := Label.new()
	name_label.text = str(deck.get("name", CardDeckSave.DEFAULT_NAME))
	name_label.add_theme_font_size_override("font_size", 26)
	text_column.add_child(name_label)
	var summary := Label.new()
	summary.text = _summary_of(deck.get("cards", []))
	summary.add_theme_font_size_override("font_size", 15)
	summary.add_theme_color_override("font_color", UiPalette.BRASS_HIGHLIGHT)
	text_column.add_child(summary)

	row.add_child(_make_emblems(deck.get("cards", [])))
	if _mode == Mode.MANAGE:
		row.add_child(_make_actions(index, total))
	return area


## 代表的な砂時計の紋章。**コストの高い順**に選ぶ(そのデッキの主役が並ぶため)。
func _make_emblems(cards: Array) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var distinct: Array = []
	for card in cards:
		if not distinct.has(card):
			distinct.append(card)
	distinct.sort_custom(func(a: CardData, b: CardData) -> bool: return a.cost > b.cost)
	for card in distinct.slice(0, EMBLEM_COUNT):
		var icon := TextureRect.new()
		icon.texture = card.emblem if card.emblem != null else card.icon_upright
		icon.custom_minimum_size = EMBLEM_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = UiPalette.BRASS_HIGHLIGHT
		icon.tooltip_text = card.display_name
		box.add_child(icon)
	return box


func _make_actions(index: int, total: int) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _reordering:
		var up := CodedButton.make_icon("↑", Vector2(48, 44))
		up.disabled = index == 0
		up.pressed.connect(_on_move_pressed.bind(index, -1))
		box.add_child(up)
		var down := CodedButton.make_icon("↓", Vector2(48, 44))
		down.disabled = index >= total - 1
		down.pressed.connect(_on_move_pressed.bind(index, 1))
		box.add_child(down)
		return box
	var edit := CodedButton.make("編集", Vector2(96, 44))
	edit.pressed.connect(func() -> void: edit_requested.emit(index))
	box.add_child(edit)
	var remove := CodedButton.make("削除", Vector2(96, 44))
	remove.pressed.connect(_on_delete_pressed.bind(index))
	box.add_child(remove)
	return box


## デッキの中身を1行で示す。枚数とコストの重心が分かれば、どの構築かを思い出せる。
func _summary_of(cards: Array) -> String:
	if cards.is_empty():
		return ""
	var total := 0
	for card in cards:
		total += card.cost
	return "%d枚 ・ 平均コスト %.1f" % [cards.size(), float(total) / float(cards.size())]


# --- 操作 ---------------------------------------------------------------


func _on_reorder_pressed() -> void:
	_reordering = not _reordering
	_refresh()


func _on_move_pressed(index: int, offset: int) -> void:
	CardDeckSave.move_deck(index, offset)
	_refresh()


func _on_delete_pressed(index: int) -> void:
	var decks := CardDeckSave.list_decks()
	if index < 0 or index >= decks.size():
		return
	_pending_delete = index
	_confirm.open_confirm(
		"デッキの削除", "「%s」を削除します。元に戻せません" % decks[index]["name"], "削除する", "やめる", true
	)


func _on_delete_confirmed() -> void:
	if _pending_delete >= 0:
		CardDeckSave.remove_deck(_pending_delete)
	_pending_delete = -1
	_refresh()
