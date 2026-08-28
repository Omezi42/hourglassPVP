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
const LIST_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 620, 356)
## 右カラムは上が詳細(実演つき)、下が低背のマナカーブ(GameDesign.md 9章)。
const DETAIL_RECT := Rect2(668, ScreenHeader.CONTENT_TOP, 588, 262)
const CURVE_RECT := Rect2(668, ScreenHeader.CONTENT_TOP + 274, 588, 92)
## 全カードの横スクロールは画面の一番下に置く。外周余白(24px)を割らないよう、
## 下端から逆算した位置に固定する。
const CARDS_TOP := 720.0 - ScreenHeader.OUTER_MARGIN - (CardView.HAND_SIZE_PX.y + 16.0)

var _header: ScreenHeader
var _entries: VBoxContainer
var _progress: Label
var _curve: CardManaCurve
var _detail: CardDetailPanel
var _keyword_popup: KeywordPopup
var _preset_picker: CardPresetPicker
var _code_panel: CardDeckCodePanel
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
	add_child(ScreenBackdrop.new())

	_header = load(HEADER_SCENE).instantiate()
	add_child(_header)
	_header.set_title("デッキ編集")
	_header.back_pressed.connect(func() -> void: back_pressed.emit())
	var save_button := CodedButton.make("保存", Vector2(160, 56))
	save_button.pressed.connect(_on_save_pressed)
	_header.add_action(save_button)
	# 20枚を自分で組まずに遊べる状態を用意する(GameDesign.md 18章)。
	# 読み込んだ後は普通に編集でき、保存すれば自分のデッキになる。
	var preset_button := CodedButton.make("プリセット", Vector2(190, 56))
	preset_button.pressed.connect(func() -> void: _preset_picker.open())
	_header.add_action(preset_button)
	# デッキコード(GameDesign.md 9章)。ルームマッチで友達と遊べるのに構築を
	# 渡す手段が無いのは片手落ちであるため。
	var code_button := CodedButton.make("コード", Vector2(150, 56))
	code_button.pressed.connect(func() -> void: _code_panel.open(_deck))
	_header.add_action(code_button)

	_build_list()
	_detail = CardDetailPanel.new()
	_detail.compact = true
	add_child(_detail)
	_detail.position = DETAIL_RECT.position
	_detail.custom_minimum_size = DETAIL_RECT.size
	_detail.size = DETAIL_RECT.size
	# 語を押すとその意味を引ける(GameDesign.md 17章)。全画面へ暗幕を敷くため、
	# 詳細パネルではなく画面側が持つ。
	_keyword_popup = KeywordPopup.new()
	add_child(_keyword_popup)
	_detail.keyword_pressed.connect(func(entry: Dictionary) -> void: _keyword_popup.open(entry))
	_curve = CardManaCurve.new()
	_curve.compact = true
	_curve.position = CURVE_RECT.position
	_curve.size = CURVE_RECT.size
	add_child(_curve)
	_preset_picker = CardPresetPicker.new()
	_preset_picker.picked.connect(_on_preset_picked)
	add_child(_preset_picker)
	_code_panel = CardDeckCodePanel.new()
	_code_panel.loaded.connect(_on_code_loaded)
	add_child(_code_panel)
	_build_card_row()
	var cards := CardLibrary.all_cards()
	if not cards.is_empty():
		_detail.show_card(cards[0])


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
		# 詳細はホバーで切り替える。クリックは編成へ1枚加える操作に残す(GameDesign.md 9章)。
		view.hovered.connect(func(hovered: CardView) -> void: _detail.show_card(hovered.card))
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
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.mouse_entered.connect(func() -> void: _detail.show_card(card))
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
	# 効果文はカードによって長さが大きく違う。伸ばすと右隣の枚数へ食い込むため、
	# 幅を固定して溢れた分は省略記号で切る。**単に切ると文が枚数へ触れて見え、
	# 続きがあることも分からない**。
	note.custom_minimum_size = Vector2(240, 0)
	note.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	note.clip_text = true
	note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
func _on_code_loaded(deck: Array) -> void:
	_deck = deck
	_refresh()


func _on_preset_picked(preset_id: String) -> void:
	_deck = CardPresetDecks.deck_of(preset_id)
	_refresh()


func _on_save_pressed() -> void:
	if _deck.size() != MatchState.DECK_SIZE:
		_progress.text = "%d / %d 枚(20枚ちょうどにしてください)" % [_deck.size(), MatchState.DECK_SIZE]
		return
	CardDeckSave.save_deck(_deck)
	back_pressed.emit()
