class_name CardDeckEditorScreen
extends Control
## v5.0のデッキ編集(GameDesign.md 9章)。デッキは30枚・同名2枚まで。
##
## **左=全カードのグリッド / 右=編成中のデッキ**の2カラム。カードは毎日のアプデで
## 増え続けるため、一覧の探しやすさを最優先し、絞り込みと名前の検索を添える。
## 編成中は「カードの絵を右端へ薄く敷いた帯」(`CardDeckBand`)を縦に並べる。

signal back_pressed

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const GRID_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 816, 584)
const SIDE_RECT := Rect2(856, ScreenHeader.CONTENT_TOP, 400, 584)
const SIDE_INNER_WIDTH := 372.0
const GRID_COLUMNS := 6
const GRID_GAP := 12
const CURVE_HEIGHT := 140.0
## `CardDetailPanel` の低背版の大きさ。ここを小さくしても最小サイズで押し返されるため揃える。
const DETAIL_SIZE := CardDetailPanel.COMPACT_SIZE
## **詳細は指しているカードの隣ではなく、画面の右上へ固定して出す**(GameDesign.md 9章)。
## カーソルの近くへ出すと、次に見たいカードの上にパネルが被って選びづらい。
## ヘッダーの主アクションや編成中の欄の上端に重なるのは許容する。
const DETAIL_POSITION := Vector2(SIDE_RECT.position.x, ScreenHeader.OUTER_MARGIN)

var _header: ScreenHeader
var _filter: CardDeckFilter
var _filter_button: Button
var _count_label: Label
var _grid: GridContainer
var _bands: VBoxContainer
var _progress: Label
var _curve: CardManaCurve
var _detail: CardDetailPanel
var _keyword_popup: KeywordPopup
var _preset_picker: CardPresetPicker
var _code_panel: CardDeckCodePanel
## 一覧に並べるカード。**コスト順**で固定する(GameDesign.md 9章の既定と揃える)。
## `_card_views` の並びと1対1で対応するため、参照する側は必ずこちらを見る。
var _pool: Array[CardData] = []
var _card_views: Array[CardView] = []
var _band_pool: Array[CardDeckBand] = []
## 編成中のデッキ。同じ CardData が最大2つ入る。
var _deck: Array = []
## 編集中のデッキが一覧の何番目か。-1 は新規作成(保存すると末尾へ追加する)。
var _index := -1
var _name_input: LineEdit


func _ready() -> void:
	_build()
	open()


## 保存済みのデッキを1つ読み込んで開く。index が範囲外なら新規作成として開く。
func open(index: int = -1) -> void:
	var decks := CardDeckSave.list_decks()
	if index >= 0 and index < decks.size():
		_index = index
		_deck = (decks[index]["cards"] as Array).duplicate()
		_name_input.text = str(decks[index]["name"])
	else:
		_index = -1
		_deck = []
		_name_input.text = CardDeckSave.next_default_name()
	_header.set_title("デッキ編集" if _index >= 0 else "新しいデッキ")
	_hide_detail()
	_refresh()
	_apply_filter()


# --- 組み立て -----------------------------------------------------------


func _build() -> void:
	add_child(ScreenBackdrop.new())
	_build_header()
	_build_grid()
	_build_side()
	_build_detail()
	# **モーダルは最後に足す。**`Control` は後から足した子ほど手前に描かれる。
	_filter = CardDeckFilter.new()
	_filter.changed.connect(_apply_filter)
	add_child(_filter)
	_keyword_popup = KeywordPopup.new()
	add_child(_keyword_popup)
	_preset_picker = CardPresetPicker.new()
	_preset_picker.picked.connect(_on_preset_picked)
	add_child(_preset_picker)
	_code_panel = CardDeckCodePanel.new()
	_code_panel.loaded.connect(_on_code_loaded)
	add_child(_code_panel)


func _build_header() -> void:
	_header = load(HEADER_SCENE).instantiate()
	add_child(_header)
	_header.set_title("デッキ編集")
	_header.back_pressed.connect(func() -> void: back_pressed.emit())
	# **3つのボタンは画面タイトルへ寄りすぎないよう詰めてある。**以前は合計524pxあり、
	# 中央のタイトル(「新しいデッキ」)と数pxしか離れていなかった。
	var save_button := CodedButton.make("保存", Vector2(132, 56))
	save_button.pressed.connect(_on_save_pressed)
	_header.add_action(save_button)
	# 20枚を自分で組まずに遊べる状態を用意する(GameDesign.md 18章)。
	var preset_button := CodedButton.make("プリセット", Vector2(152, 56))
	preset_button.pressed.connect(func() -> void: _preset_picker.open())
	_header.add_action(preset_button)
	# デッキコード(GameDesign.md 9章)。ルームマッチで友達と遊べるのに構築を
	# 渡す手段が無いのは片手落ちであるため。
	var code_button := CodedButton.make("コード", Vector2(120, 56))
	code_button.pressed.connect(func() -> void: _code_panel.open(_deck))
	_header.add_action(code_button)


func _build_grid() -> void:
	var container := VBoxContainer.new()
	container.position = GRID_RECT.position
	container.size = GRID_RECT.size
	container.custom_minimum_size = GRID_RECT.size
	container.add_theme_constant_override("separation", 8)
	add_child(container)

	# 上部ツールバー(件数表示 + 絞り込みボタン)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	container.add_child(toolbar)

	_count_label = Label.new()
	_count_label.text = "カード一覧"
	_count_label.add_theme_font_size_override("font_size", 16)
	_count_label.add_theme_color_override("font_color", UiPalette.BRASS_HIGHLIGHT)
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toolbar.add_child(_count_label)

	_filter_button = CodedButton.make("絞り込み", Vector2(130, 36))
	_filter_button.pressed.connect(func() -> void: _filter.open())
	toolbar.add_child(_filter_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	container.add_child(scroll)

	_pool = CardLibrary.sorted_by_cost()
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", GRID_GAP)
	_grid.add_theme_constant_override("v_separation", GRID_GAP)
	scroll.add_child(_grid)

	for card in _pool:
		var view := CardView.new()
		view.mode = CardView.Mode.HAND
		view.custom_minimum_size = CardView.HAND_SIZE_PX
		# 並べて見比べる画面では守護だけ枠を太くしない(GameDesign.md 9章)。
		view.guard_frame = false
		view.pressed.connect(_on_card_pressed)
		_grid.add_child(view)
		_card_views.append(view)


func _build_side() -> void:
	var panel := PanelContainer.new()
	panel.position = SIDE_RECT.position
	panel.size = SIDE_RECT.size
	panel.custom_minimum_size = SIDE_RECT.size
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	# 1. デッキ名と枚数
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	column.add_child(top_row)
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "デッキ名"
	_name_input.max_length = CardDeckSave.NAME_LIMIT
	_name_input.custom_minimum_size = Vector2(228, 36)
	top_row.add_child(_name_input)
	_progress = Label.new()
	_progress.add_theme_font_size_override("font_size", 20)
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(_progress)

	# 2. 編成中カード一覧
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_bands = VBoxContainer.new()
	_bands.add_theme_constant_override("separation", 4)
	_bands.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_bands)

	# 3. マナカーブ(下部配置・高さ140px)
	_curve = CardManaCurve.new()
	_curve.custom_minimum_size = Vector2(SIDE_INNER_WIDTH, CURVE_HEIGHT)
	column.add_child(_curve)


func _build_detail() -> void:
	_detail = CardDetailPanel.new()
	_detail.compact = true
	_detail.size = DETAIL_SIZE
	_detail.position = DETAIL_POSITION
	_detail.visible = false
	_detail.keyword_pressed.connect(func(entry: Dictionary) -> void: _keyword_popup.open(entry))
	_detail.gui_input.connect(_on_detail_gui_input)
	add_child(_detail)


# --- 表示 ---------------------------------------------------------------


func _refresh() -> void:
	_progress.text = "%d / %d 枚" % [_deck.size(), MatchState.DECK_SIZE]
	_refresh_bands()
	_curve.show_deck(_deck)
	var full: bool = _deck.size() >= MatchState.DECK_SIZE
	for i in _card_views.size():
		var card: CardData = _pool[i]
		var copies := _count_of(card)
		var view := _card_views[i]
		view.badge = "%d/%d" % [copies, CardDeckSave.COPY_LIMIT]
		view.show_card(card, not full and copies < CardDeckSave.COPY_LIMIT)


func _apply_filter() -> void:
	var visible_count := 0
	for i in _card_views.size():
		var matched := _filter.matches(_pool[i])
		_card_views[i].visible = matched
		if matched:
			visible_count += 1
	var active := _filter.active_filter_count()
	if active > 0:
		_filter_button.text = "絞り込み (%d)" % active
		_filter_button.add_theme_color_override("font_color", UiPalette.GLOW_AMBER)
		_filter_button.add_theme_color_override("font_hover_color", UiPalette.GLOW_AMBER)
		_count_label.text = "カード一覧 (%d / %d 種)" % [visible_count, _pool.size()]
	else:
		_filter_button.text = "絞り込み"
		_filter_button.remove_theme_color_override("font_color")
		_filter_button.remove_theme_color_override("font_hover_color")
		_count_label.text = "カード一覧 (%d 種)" % _pool.size()


## 帯は使い回す。1枚足すたびに全て作り直すと、押した瞬間にカーソルの下のノードが
## 消えてホバーが途切れるため。
func _refresh_bands() -> void:
	var distinct := _distinct_sorted()
	while _band_pool.size() < distinct.size():
		var band := CardDeckBand.new()
		band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		band.add_pressed.connect(_on_band_add)
		band.remove_pressed.connect(_on_band_remove)
		band.pressed.connect(_on_band_pressed)
		_bands.add_child(band)
		_band_pool.append(band)
	for i in _band_pool.size():
		var band := _band_pool[i]
		band.visible = i < distinct.size()
		if band.visible:
			var card: CardData = distinct[i]
			var can_add: bool = (
				_deck.size() < MatchState.DECK_SIZE and _count_of(card) < CardDeckSave.COPY_LIMIT
			)
			band.show_card(card, _count_of(card), can_add)


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


func _count_of(card: CardData) -> int:
	var found := 0
	for entry in _deck:
		if entry == card:
			found += 1
	return found


# --- 詳細(クリック時のみ表示) ------------------------------------------


## 出す場所は常に画面の右上で、指しているカードの位置では動かさない
## (カーソルの近くへ出すと隣のカードが隠れて選びづらいため)。
func _show_detail(card: CardData) -> void:
	if card == null:
		return
	_detail.show_card(card)
	_detail.position = DETAIL_POSITION
	_detail.visible = true


func _hide_detail() -> void:
	_detail.visible = false


func _on_detail_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
			_hide_detail()
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if _detail == null or not _detail.visible:
		return
	if (_keyword_popup != null and _keyword_popup.visible) \
			or (_filter != null and _filter.visible) \
			or (_preset_picker != null and _preset_picker.visible) \
			or (_code_panel != null and _code_panel.visible):
		return
	if event.is_action_pressed("ui_cancel"):
		_hide_detail()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed:
			if click.button_index == MOUSE_BUTTON_RIGHT:
				_hide_detail()
				get_viewport().set_input_as_handled()
			elif click.button_index == MOUSE_BUTTON_LEFT:
				if not _detail.get_global_rect().has_point(click.position):
					_hide_detail()


# --- 操作 ---------------------------------------------------------------


func _on_card_pressed(view: CardView) -> void:
	_show_detail(view.card)
	_add_card(view.card)


func _on_band_pressed(card: CardData) -> void:
	_show_detail(card)


func _on_band_add(card: CardData) -> void:
	_add_card(card)


func _add_card(card: CardData) -> void:
	if _deck.size() >= MatchState.DECK_SIZE:
		return
	if _count_of(card) >= CardDeckSave.COPY_LIMIT:
		return
	_deck.append(card)
	_refresh()


func _on_band_remove(card: CardData) -> void:
	var index := _deck.find(card)
	if index >= 0:
		_deck.remove_at(index)
		_refresh()


func _on_code_loaded(deck: Array) -> void:
	_deck = deck
	_refresh()


func _on_preset_picked(preset_id: String) -> void:
	_deck = CardPresetDecks.deck_of(preset_id)
	_refresh()


## 30枚ちょうどのときだけ保存する。枚数が足りないデッキで対局へ入れないようにするため。
func _on_save_pressed() -> void:
	if _deck.size() != MatchState.DECK_SIZE:
		_progress.text = (
			"%d / %d 枚(%d枚ちょうどに)" % [_deck.size(), MatchState.DECK_SIZE, MatchState.DECK_SIZE]
		)
		return
	if _index >= 0:
		CardDeckSave.update_deck(_index, _name_input.text, _deck)
	else:
		# 作ったばかりのデッキは、そのまま対局へ持って行けるよう選択の初期値にする。
		CardDeckSave.set_selected_index(CardDeckSave.add_deck(_name_input.text, _deck))
	back_pressed.emit()
