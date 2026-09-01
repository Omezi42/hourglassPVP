class_name CardDeckEditorScreen
extends Control
## v5.0のデッキ編集(GameDesign.md 9章)。デッキは20枚・同名2枚まで。
##
## **左=全カードのグリッド / 右=編成中のデッキ**の2カラム。カードは毎日のアプデで
## 増え続けるため、一覧の探しやすさを最優先し、絞り込みと名前の検索を添える。
## 編成中は「カードの絵を右端へ薄く敷いた帯」(`CardDeckBand`)を縦に並べる。

signal back_pressed

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
## **絞り込みの列は詳細パネルの左端まで広げる**。一覧の幅(816px)だけに収めていたときは
## コスト7種とキーワード4種のチップで埋まり、右端の「名前で探す」がはみ出して押せなかった。
## 右上の詳細(`DETAIL_POSITION`)の下へ潜らせないため、ここより右へは伸ばさない。
const FILTER_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 832, 34)
const GRID_RECT := Rect2(24, ScreenHeader.CONTENT_TOP + 46, 816, 514)
const SIDE_RECT := Rect2(856, ScreenHeader.CONTENT_TOP + 46, 400, 514)
const SIDE_INNER_WIDTH := 372.0
const GRID_COLUMNS := 6
const GRID_GAP := 12
const CURVE_HEIGHT := 76.0
## `CardDetailPanel` の低背版の大きさ。ここを小さくしても最小サイズで押し返されるため揃える。
const DETAIL_SIZE := CardDetailPanel.COMPACT_SIZE
## 詳細はホバー中だけ浮かせる。カードとパネルの間をカーソルが通るため、
## 外れてから消すまでに短い猶予を置く(対局画面の詳細と同じ流儀)。
const DETAIL_HIDE_DELAY := 0.12
## **詳細は指しているカードの隣ではなく、画面の右上へ固定して出す**(GameDesign.md 9章)。
## カーソルの近くへ出すと、次に見たいカードの上にパネルが被って選びづらい。
## ヘッダーの主アクションや編成中の欄の上端に重なるのは許容する。
const DETAIL_POSITION := Vector2(SIDE_RECT.position.x, ScreenHeader.OUTER_MARGIN)

var _header: ScreenHeader
var _filter: CardDeckFilter
var _grid: GridContainer
var _bands: VBoxContainer
var _progress: Label
var _curve: CardManaCurve
var _detail: CardDetailPanel
var _detail_timer: Timer
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


# --- 組み立て -----------------------------------------------------------


func _build() -> void:
	add_child(ScreenBackdrop.new())
	_build_header()
	_filter = CardDeckFilter.new()
	_filter.position = FILTER_RECT.position
	_filter.size = FILTER_RECT.size
	_filter.changed.connect(_apply_filter)
	add_child(_filter)
	_build_grid()
	_build_side()
	_build_detail()
	# **モーダルは最後に足す。**`Control` は後から足した子ほど手前に描かれる。
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
	var scroll := ScrollContainer.new()
	scroll.position = GRID_RECT.position
	scroll.size = GRID_RECT.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
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
		view.hovered.connect(_on_card_hovered)
		view.mouse_exited.connect(_hide_detail_soon)
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
	# デッキは何個でも保存できるため、どれなのかを見分ける名前が要る(GameDesign.md 9章)。
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

	_curve = CardManaCurve.new()
	_curve.compact = true
	_curve.custom_minimum_size = Vector2(SIDE_INNER_WIDTH, CURVE_HEIGHT)
	column.add_child(_curve)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_bands = VBoxContainer.new()
	_bands.add_theme_constant_override("separation", 3)
	_bands.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_bands)


func _build_detail() -> void:
	_detail = CardDetailPanel.new()
	_detail.compact = true
	_detail.size = DETAIL_SIZE
	_detail.position = DETAIL_POSITION
	_detail.visible = false
	_detail.keyword_pressed.connect(func(entry: Dictionary) -> void: _keyword_popup.open(entry))
	_detail.mouse_entered.connect(func() -> void: _detail_timer.stop())
	_detail.mouse_exited.connect(_hide_detail_soon)
	add_child(_detail)
	_detail_timer = Timer.new()
	_detail_timer.one_shot = true
	_detail_timer.wait_time = DETAIL_HIDE_DELAY
	_detail_timer.timeout.connect(_hide_detail)
	add_child(_detail_timer)


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
	for i in _card_views.size():
		_card_views[i].visible = _filter.matches(_pool[i])


## 帯は使い回す。1枚足すたびに全て作り直すと、押した瞬間にカーソルの下のノードが
## 消えてホバーが途切れるため。
func _refresh_bands() -> void:
	var distinct := _distinct_sorted()
	while _band_pool.size() < distinct.size():
		var band := CardDeckBand.new()
		band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		band.add_pressed.connect(_on_band_add)
		band.remove_pressed.connect(_on_band_remove)
		band.hovered.connect(_on_band_hovered)
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


# --- 詳細(ホバー中だけ浮かせる) -----------------------------------------


## 出す場所は常に画面の右上で、指しているカードの位置では動かさない
## (カーソルの近くへ出すと隣のカードが隠れて選びづらいため)。
func _show_detail(card: CardData) -> void:
	if card == null:
		return
	_detail_timer.stop()
	_detail.show_card(card)
	_detail.position = DETAIL_POSITION
	_detail.visible = true


func _hide_detail_soon() -> void:
	_detail_timer.start()


func _hide_detail() -> void:
	_detail.visible = false


# --- 操作 ---------------------------------------------------------------


func _on_card_hovered(view: CardView) -> void:
	_show_detail(view.card)


func _on_band_hovered(card: CardData) -> void:
	_show_detail(card)


func _on_card_pressed(view: CardView) -> void:
	_add_card(view.card)


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


## 20枚ちょうどのときだけ保存する。枚数が足りないデッキで対局へ入れないようにするため。
func _on_save_pressed() -> void:
	if _deck.size() != MatchState.DECK_SIZE:
		_progress.text = "%d / %d 枚(20枚ちょうどに)" % [_deck.size(), MatchState.DECK_SIZE]
		return
	if _index >= 0:
		CardDeckSave.update_deck(_index, _name_input.text, _deck)
	else:
		# 作ったばかりのデッキは、そのまま対局へ持って行けるよう選択の初期値にする。
		CardDeckSave.set_selected_index(CardDeckSave.add_deck(_name_input.text, _deck))
	back_pressed.emit()
