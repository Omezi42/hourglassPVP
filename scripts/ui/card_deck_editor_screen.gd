class_name CardDeckEditorScreen
extends Control
## v5.0のデッキ編集(GameDesign.md 9章)。デッキは30枚・同名2枚まで。
##
## **左=全カードのグリッド / 右=編成中のデッキ**の2カラム。カードは毎日のアプデで
## 増え続けるため、一覧の探しやすさを最優先し、絞り込みと名前の検索を添える。
## 編成中のデッキは**コスト帯ごとの段**(`CardDeckShelf`)として見せる。

signal back_pressed

const SCREEN_WIDTH := 1280.0
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
## 在庫棚・組立台の内側(木箱の枠と上端の帯を除いた範囲)。**外形は下地が描く**。
const GRID_RECT := Rect2(
	WorkshopBackdrop.SHELF_RECT.position.x + 24,
	WorkshopBackdrop.SHELF_RECT.position.y + WorkshopBackdrop.BAND_HEIGHT + 10,
	WorkshopBackdrop.SHELF_RECT.size.x - 48,
	WorkshopBackdrop.SHELF_RECT.size.y - WorkshopBackdrop.BAND_HEIGHT - 26
)
const SIDE_RECT := Rect2(
	WorkshopBackdrop.BENCH_RECT.position.x + 18,
	WorkshopBackdrop.BENCH_RECT.position.y + 12,
	WorkshopBackdrop.BENCH_RECT.size.x - 36,
	WorkshopBackdrop.BENCH_RECT.size.y - 26
)
const SIDE_INNER_WIDTH := SIDE_RECT.size.x
const GRID_COLUMNS := 4
const GRID_GAP := 6
## 本の外(木箱の上)へ置く操作。共通ヘッダーと同じ並び(左=戻る / 右=主アクション)。
const BACK_RECT := Rect2(24, 30, 92, 42)
const ACTION_SIZE := Vector2(126, 42)
const ACTION_GAP := 10.0
## `CardDetailPanel` の低背版の大きさ。ここを小さくしても最小サイズで押し返されるため揃える。
const DETAIL_SIZE := CardDetailPanel.COMPACT_SIZE
## **詳細は指しているものと反対のカラムへ出す**(GameDesign.md 9章)。
## 同じ側へ出すと、パネルがカーソルの下の帯を覆った瞬間にホバーが外れ、
## 出したり消したりを繰り返す。ヘッダーの主アクションや反対側の欄に重なるのは許容する。
const DETAIL_POSITION_RIGHT := Vector2(SIDE_RECT.position.x, ScreenHeader.OUTER_MARGIN)
const DETAIL_POSITION_LEFT := Vector2(GRID_RECT.position.x, ScreenHeader.CONTENT_TOP)
## カードから外れてから詳細を消すまでの猶予。隣のカードへ移る途中で点滅させないため。
const DETAIL_HIDE_DELAY := 0.15

var _save_button: Button
var _filter: CardDeckFilter
var _filter_button: Button
var _count_label: Label
var _grid: GridContainer
var _shelf: CardDeckShelf
var _progress: Label
var _shortfall: Label
var _detail: CardDetailPanel
var _detail_hide_timer: Timer
var _preset_picker: CardPresetPicker
var _share_panel: CardDeckSharePanel
## 一覧に並べるカード。**コスト順**で固定する(GameDesign.md 9章の既定と揃える)。
## `_card_views` の並びと1対1で対応するため、参照する側は必ずこちらを見る。
var _pool: Array[CardData] = []
var _card_views: Array[WorkshopStockItem] = []
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
	_hide_detail()
	_refresh()
	_apply_filter()


# --- 組み立て -----------------------------------------------------------


func _build() -> void:
	add_child(WorkshopBackdrop.new())
	_build_header()
	_build_grid()
	_build_side()
	_build_detail()
	# **モーダルは最後に足す。**`Control` は後から足した子ほど手前に描かれる。
	_filter = CardDeckFilter.new()
	_filter.changed.connect(_apply_filter)
	add_child(_filter)
	_preset_picker = CardPresetPicker.new()
	_preset_picker.picked.connect(_on_preset_picked)
	add_child(_preset_picker)
	_share_panel = CardDeckSharePanel.new()
	_share_panel.loaded.connect(_on_code_loaded)
	add_child(_share_panel)


## 画面名は吊り看板が示す(下地が描く)ため、ここは操作だけを置く。
## 並びは共通の規約どおり**左=戻る / 右=主アクション**(GameDesign.md 9章)。
func _build_header() -> void:
	var back := CodedButton.make("← 戻る", BACK_RECT.size)
	back.position = BACK_RECT.position
	back.pressed.connect(func() -> void: back_pressed.emit())
	add_child(back)
	# 右から「共有 / プリセット / 保存」の順に積む(左へ行くほど主要な操作)。
	var labels := ["保存", "プリセット", "共有"]
	var handlers: Array[Callable] = [
		_on_save_pressed,
		func() -> void: _preset_picker.open(),
		func() -> void: _share_panel.open(_deck, _name_input.text),
	]
	for i in labels.size():
		var button := CodedButton.make(labels[i], ACTION_SIZE)
		var from_right := labels.size() - i
		button.position = Vector2(
			SCREEN_WIDTH - 24.0 - from_right * (ACTION_SIZE.x + ACTION_GAP) + ACTION_GAP,
			BACK_RECT.position.y
		)
		button.pressed.connect(handlers[i])
		add_child(button)
		if i == 0:
			_save_button = button


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
	_count_label.text = ""
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
		var view := WorkshopStockItem.new()
		view.pressed.connect(_on_card_pressed)
		view.mouse_entered.connect(_on_stock_hovered.bind(view))
		view.mouse_exited.connect(_on_hover_left)
		_grid.add_child(view)
		_card_views.append(view)


## 組立台の木の面は下地(`WorkshopBackdrop`)が描く。ここは中身だけを積む。
func _build_side() -> void:
	var column := VBoxContainer.new()
	column.position = SIDE_RECT.position
	column.size = SIDE_RECT.size
	column.custom_minimum_size = SIDE_RECT.size
	column.add_theme_constant_override("separation", 8)
	add_child(column)

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

	# 2. 編成中のデッキ(コスト帯ごとの棚)。
	# **マナカーブの棒グラフは置かない**——段の長さがそのままマナカーブになるため
	# (GameDesign.md 9章)。
	# **`ScrollContainer` へは入れない。**あの中では棚が「1画面に何段入るか」を
	# 知れず、段の高さを決められない(実際、高さ0のまま下限で並んで画面の半分が
	# 空いた)。棚が自前でスクロールを持つ。
	_shelf = CardDeckShelf.new()
	_shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shelf.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shelf.custom_minimum_size.x = SIDE_INNER_WIDTH
	_shelf.card_hovered.connect(_on_shelf_hovered)
	_shelf.hover_left.connect(_on_hover_left)
	_shelf.card_added.connect(_on_band_add)
	_shelf.card_removed.connect(_on_band_remove)
	column.add_child(_shelf)

	# 3. 30枚に満たない間だけ出す帯(GameDesign.md 9章)。
	_shortfall = Label.new()
	_shortfall.add_theme_font_size_override("font_size", 15)
	_shortfall.add_theme_color_override("font_color", Color(1.0, 0.82, 0.46))
	_shortfall.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_shortfall.custom_minimum_size.y = 24
	column.add_child(_shortfall)


func _build_detail() -> void:
	_detail = CardDetailPanel.new()
	_detail.compact = true
	# 語のボタンと実演を持たせない(GameDesign.md 17章)。ホバーで出して外れたら消える
	# パネルの中に押しに行く先を置くと、そこへカーソルを動かした時点で消えてしまう。
	_detail.interactive = false
	_detail.size = DETAIL_SIZE
	_detail.position = DETAIL_POSITION_RIGHT
	_detail.visible = false
	# **パネルはホバーを奪わない。**反対のカラムへ出す以上、下のカードや帯の上へ乗るため、
	# 塞ぐと「パネルに隠れたカードを指すと消える」ことになる。
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_detail)

	_detail_hide_timer = Timer.new()
	_detail_hide_timer.one_shot = true
	_detail_hide_timer.wait_time = DETAIL_HIDE_DELAY
	_detail_hide_timer.timeout.connect(_hide_detail)
	add_child(_detail_hide_timer)


# --- 表示 ---------------------------------------------------------------


func _refresh() -> void:
	_progress.text = "%d / %d 枚" % [_deck.size(), MatchState.DECK_SIZE]
	_shelf.deck = _deck.duplicate()
	# **足りているときは帯ごと畳む。**空の行を残すと、そのぶん棚の段が低くなる。
	var missing: int = MatchState.DECK_SIZE - _deck.size()
	_shortfall.visible = missing > 0
	_shortfall.text = "あと %d 枚" % missing
	var full: bool = _deck.size() >= MatchState.DECK_SIZE
	for i in _card_views.size():
		var card: CardData = _pool[i]
		# **枚数は実数を出し、暗転だけを「入れられるか」で決める。**30枚に達した
		# だけで全部が「2/2」になると、どれを2枚積んだのか読めなくなる。
		var copies := _count_of(card)
		var can_add: bool = not full and copies < CardDeckSave.COPY_LIMIT
		_card_views[i].show_card(card, copies, CardDeckSave.COPY_LIMIT, can_add)
	_save_button.disabled = not full


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
		_count_label.text = "%d / %d 種" % [visible_count, _pool.size()]
	else:
		_filter_button.text = "絞り込み"
		_filter_button.remove_theme_color_override("font_color")
		_filter_button.remove_theme_color_override("font_hover_color")
		_count_label.text = "%d 種" % _pool.size()


func _count_of(card: CardData) -> int:
	var found := 0
	for entry in _deck:
		if entry == card:
			found += 1
	return found


# --- 詳細(ホバー中だけ表示) --------------------------------------------


## 指しているものと反対のカラムへ出す(GameDesign.md 9章)。
func _show_detail(card: CardData, to_right: bool) -> void:
	if card == null:
		return
	if _detail_hide_timer != null:
		_detail_hide_timer.stop()
	_detail.show_card(card)
	_detail.position = DETAIL_POSITION_RIGHT if to_right else DETAIL_POSITION_LEFT
	_detail.visible = true


func _hide_detail() -> void:
	if _detail_hide_timer != null:
		_detail_hide_timer.stop()
	_detail.visible = false


## カードから外れた。隣へ移る途中の点滅を避けるため、すぐには消さず猶予を置く。
func _on_hover_left() -> void:
	if _detail_hide_timer != null and _detail.visible:
		_detail_hide_timer.start()


func _on_stock_hovered(view: WorkshopStockItem) -> void:
	_show_detail(view.card, true)


## 棚の1本を指した。詳細は**反対のカラム**(左=一覧の上)へ出す(GameDesign.md 9章)。
func _on_shelf_hovered(card: CardData) -> void:
	_show_detail(card, false)


# --- 操作 ---------------------------------------------------------------


func _on_card_pressed(card: CardData) -> void:
	_add_card(card)


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
