class_name CardDeckEditorScreen
extends Control
## v5.0のデッキ編集(GameDesign.md 9章)。デッキは20枚・同名2枚まで。
##
## 編成中の欄は**カードの絵ではなく「カード名 × 枚数」の縦リスト**にする(20枚を絵で
## 並べると画面に入らないため)。**コスト別の枚数はグラフとして常時表示する**。
## 20枚のデッキではコストの配分が構築の中心であり、数えなくても分かる状態にする。

signal back_pressed

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const LIST_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 620, 320)
const CURVE_RECT := Rect2(668, ScreenHeader.CONTENT_TOP, 588, 320)
const CARDS_TOP := ScreenHeader.CONTENT_TOP + 344.0

var _header: ScreenHeader
var _entries: VBoxContainer
var _progress: Label
var _curve: CardManaCurve
var _card_row: HBoxContainer
var _card_views: Array[CardView] = []
## 編成中のデッキ。同じ CardData が最大2つ入る。
var _deck: Array = []


func _ready() -> void:
	_build()
	open()


## 保存済みのデッキを読み込んで開く。
func open() -> void:
	_deck = CardDeckSave.load_deck()
	_refresh()


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color(0.07, 0.06, 0.08, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_header = load(HEADER_SCENE).instantiate()
	add_child(_header)
	_header.set_title("デッキ編集")
	_header.back_pressed.connect(func() -> void: back_pressed.emit())
	var save_button := CodedButton.make("保存", Vector2(160, 56))
	save_button.pressed.connect(_on_save_pressed)
	_header.add_action(save_button)

	_build_list()
	_curve = CardManaCurve.new()
	_curve.position = CURVE_RECT.position
	_curve.size = CURVE_RECT.size
	add_child(_curve)
	_build_card_row()


func _build_list() -> void:
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
	_progress = Label.new()
	_progress.add_theme_font_size_override("font_size", 22)
	column.add_child(_progress)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_entries = VBoxContainer.new()
	_entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_entries)


func _build_card_row() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, CARDS_TOP)
	scroll.size = Vector2(1232, CardView.HAND_SIZE_PX.y + 16)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_card_row = HBoxContainer.new()
	_card_row.add_theme_constant_override("separation", 10)
	scroll.add_child(_card_row)
	for card in CardLibrary.all_cards():
		var view := CardView.new()
		view.mode = CardView.Mode.HAND
		view.custom_minimum_size = CardView.HAND_SIZE_PX
		view.pressed.connect(_on_card_pressed)
		_card_row.add_child(view)
		_card_views.append(view)


# --- 表示 ---------------------------------------------------------------


func _refresh() -> void:
	_progress.text = "%d / %d 枚" % [_deck.size(), MatchState.DECK_SIZE]
	_refresh_entries()
	_curve.show_deck(_deck)
	var full: bool = _deck.size() >= MatchState.DECK_SIZE
	for i in _card_views.size():
		var card: CardData = CardLibrary.all_cards()[i]
		var copies := _count_of(card)
		var view := _card_views[i]
		view.badge = "%d/%d" % [copies, CardDeckSave.COPY_LIMIT]
		view.show_card(card, not full and copies < CardDeckSave.COPY_LIMIT)


func _refresh_entries() -> void:
	for child in _entries.get_children():
		child.queue_free()
	for card in _distinct_sorted():
		_entries.add_child(_make_entry(card))


## 編成中のカードをコスト順に並べた重複なしの一覧。
func _distinct_sorted() -> Array:
	var seen: Array = []
	for card in _deck:
		if not seen.has(card):
			seen.append(card)
	seen.sort_custom(
		func(a: CardData, b: CardData) -> bool:
			return a.cost < b.cost if a.cost != b.cost else a.id < b.id
	)
	return seen


func _make_entry(card: CardData) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cost := Label.new()
	cost.text = str(card.cost)
	cost.custom_minimum_size = Vector2(36, 0)
	cost.add_theme_color_override("font_color", CardView.MANA_BLUE)
	row.add_child(cost)
	var name_label := Label.new()
	name_label.text = card.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var note := Label.new()
	note.text = card.describe()
	note.custom_minimum_size = Vector2(280, 0)
	note.add_theme_color_override("font_color", UiPalette.BRASS_HIGHLIGHT)
	note.add_theme_font_size_override("font_size", 15)
	row.add_child(note)
	var count := Label.new()
	count.text = "×%d" % _count_of(card)
	count.custom_minimum_size = Vector2(48, 0)
	row.add_child(count)
	var remove := CodedButton.make_icon("−", Vector2(44, 34))
	remove.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	remove.pressed.connect(_on_remove_pressed.bind(card))
	row.add_child(remove)
	return row


func _count_of(card: CardData) -> int:
	var found := 0
	for entry in _deck:
		if entry == card:
			found += 1
	return found


# --- 操作 ---------------------------------------------------------------


func _on_card_pressed(view: CardView) -> void:
	if _deck.size() >= MatchState.DECK_SIZE:
		return
	if _count_of(view.card) >= CardDeckSave.COPY_LIMIT:
		return
	_deck.append(view.card)
	_refresh()


func _on_remove_pressed(card: CardData) -> void:
	var index := _deck.find(card)
	if index >= 0:
		_deck.remove_at(index)
		_refresh()


## 20枚ちょうどのときだけ保存する。枚数が足りないデッキで対局へ入れないようにするため。
func _on_save_pressed() -> void:
	if _deck.size() != MatchState.DECK_SIZE:
		_progress.text = "%d / %d 枚(20枚ちょうどにしてください)" % [_deck.size(), MatchState.DECK_SIZE]
		return
	CardDeckSave.save_deck(_deck)
	back_pressed.emit()
