class_name CardDeckEditorScreen
extends Control
## v5.0のデッキ編集(GameDesign.md 9章)。デッキは30枚・同名2枚まで。
##
## **左=全カードのグリッド / 右=編成中のデッキ**の2カラム。カードは毎日のアプデで
## 増え続けるため、一覧の探しやすさを最優先し、絞り込みと名前の検索を添える。
## 編成中のデッキは**コスト帯ごとの段**(`CardDeckShelf`)として見せる。

signal back_pressed
## 未所有のカードセットのカードを押し、ショップへ進むことを選んだ(GameDesign.md 21章)。
signal shop_requested(set_id: String)

const SCREEN_WIDTH := 1280.0
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const CONFIRM_SCENE := "res://scenes/confirm_modal.tscn"
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
## 戻るボタンの見た目。共通ヘッダー(`ScreenHeader`)と同じ左向きの五角形にする。
const BACK_GROUP := "back_nav"
## 縦の切り替えのうち、選んでいない側の見た目。
const TAB_GROUP := "wide_text"
const NAME_FONT := 18
const BACK_RECT := Rect2(24, 30, 92, 42)
const ACTION_SIZE := Vector2(126, 42)
const ACTION_GAP := 10.0
## `CardDetailPanel` の低背版の大きさ。ここを小さくしても最小サイズで押し返されるため揃える。
const DETAIL_SIZE := CardDetailPanel.COMPACT_SIZE
## **詳細はカーソルの近くへ出す**(GameDesign.md 9章)。置き場の規則は
## `CardDetailPanel.place_near()` が持ち、ここは収める範囲だけを決める。
const DETAIL_BOUNDS := Rect2(16, 16, SCREEN_WIDTH - 32, 688)
## カードから外れてから詳細を消すまでの猶予。隣のカードへ移る途中で点滅させないため。
const DETAIL_HIDE_DELAY := 0.15
## 一覧⇄棚の飛翔演出の尺(GameDesign.md 9章「手触り」)。
const FLIGHT_DURATION := 0.32
const COUNT_FONT := 16
const FILTER_SIZE := Vector2(130, 36)
const NAME_SIZE := Vector2(228, 36)
const PROGRESS_FONT := 20

## 縦画面(GameDesign.md 9章「縦画面」)。在庫棚と組立台を同じ木箱で切り替え、
## 中身は文字の目安(本文24px以上)を満たす大きさにする。
const PORTRAIT_BACK_RECT := Rect2(24, 22, 140, 64)
const PORTRAIT_ACTION_SIZE := Vector2(170, 72)
const PORTRAIT_ACTION_TOP := 112.0
const PORTRAIT_TAB_RECT := Rect2(24, 196, 672, 72)
const PORTRAIT_TAB_GAP := 12.0
const PORTRAIT_BOX := WorkshopBackdrop.PORTRAIT_BOX_RECT
const PORTRAIT_GRID_RECT := Rect2(
	PORTRAIT_BOX.position.x + 24,
	PORTRAIT_BOX.position.y + WorkshopBackdrop.BAND_HEIGHT + 10,
	PORTRAIT_BOX.size.x - 48,
	PORTRAIT_BOX.size.y - WorkshopBackdrop.BAND_HEIGHT - 26
)
const PORTRAIT_SIDE_RECT := Rect2(
	PORTRAIT_BOX.position.x + 18,
	PORTRAIT_BOX.position.y + 18,
	PORTRAIT_BOX.size.x - 36,
	PORTRAIT_BOX.size.y - 36
)
const PORTRAIT_GRID_COLUMNS := 3
const PORTRAIT_STOCK_ZOOM := 1.6
const PORTRAIT_SHELF_TEXT := 1.7
const PORTRAIT_BUTTON_FONT := 26
const PORTRAIT_COUNT_FONT := 24
const PORTRAIT_FILTER_SIZE := Vector2(190, 64)
const PORTRAIT_NAME_SIZE := Vector2(340, 64)
const PORTRAIT_PROGRESS_FONT := 28
const PORTRAIT_DETAIL_SCALE := 1.6

var _save_button: Button
var _filter: CardDeckFilter
var _filter_button: Button
var _count_label: Label
var _grid: GridContainer
var _shelf: CardDeckShelf
var _progress: Label
var _detail: CardDetailPanel
var _detail_hide_timer: Timer
var _preset_picker: CardPresetPicker
var _share_panel: CardDeckSharePanel
var _shop_confirm: ConfirmModal
## ショップへの導線を出している最中のカードセット。
var _pending_set := ""
## 一覧に並べるカード。**コスト順**で固定する(GameDesign.md 9章の既定と揃える)。
## `_card_views` の並びと1対1で対応するため、参照する側は必ずこちらを見る。
var _pool: Array[CardData] = []
var _card_views: Array[WorkshopStockItem] = []
## 編成中のデッキ。同じ CardData が最大2つ入る。
var _deck: Array = []
## 編集中のデッキが一覧の何番目か。-1 は新規作成(保存すると末尾へ追加する)。
var _index := -1
var _name_input: LineEdit
var _backdrop: WorkshopBackdrop
var _back: Button
var _actions: Array[Button] = []
var _grid_box: VBoxContainer
var _side_box: VBoxContainer
var _tab_buttons: Array[Button] = []
var _portrait := false
## 縦で在庫棚を出しているか(false なら組立台)。
var _show_stock := true
## タッチの長押しで詳細を出す(ホバーの代わり。GameDesign.md 9章「タッチでの操作」)。
var _long: LongPress
var _long_view: WorkshopStockItem


func _ready() -> void:
	_build()
	open()


func _input(event: InputEvent) -> void:
	if is_visible_in_tree():
		TouchInput.note(event)


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
	_backdrop = WorkshopBackdrop.new()
	add_child(_backdrop)
	_build_header()
	_build_tabs()
	_build_grid()
	_build_side()
	_build_detail()
	_long = LongPress.new(self)
	_long.fired.connect(_on_stock_long_press)
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
	_shop_confirm = load(CONFIRM_SCENE).instantiate()
	add_child(_shop_confirm)
	_shop_confirm.confirmed.connect(func() -> void: shop_requested.emit(_pending_set))


## 画面名は吊り看板が示す(下地が描く)ため、ここは操作だけを置く。
## 並びは共通の規約どおり**左=戻る / 右=主アクション**(GameDesign.md 9章)。
func _build_header() -> void:
	# 戻るの見た目は共通ヘッダーと揃える(GameDesign.md 9章)。この画面は本・工房の
	# 紙面へ操作を載せないためヘッダーを持たないが、**ボタンの形まで別にすると
	# 画面ごとに戻り方が違って見える**。
	_back = CodedButton.make_in_group("戻る", BACK_RECT.size, BACK_GROUP)
	_back.position = BACK_RECT.position
	_back.pressed.connect(func() -> void: back_pressed.emit())
	add_child(_back)
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
		_actions.append(button)
		if i == 0:
			_save_button = button


## 縦でだけ出す、在庫棚と組立台の切り替え。
func _build_tabs() -> void:
	for i in 2:
		var tab := CodedButton.make("", Vector2.ZERO)
		tab.visible = false
		tab.pressed.connect(_select_tab.bind(i == 0))
		add_child(tab)
		_tab_buttons.append(tab)


func _build_grid() -> void:
	var container := VBoxContainer.new()
	container.position = GRID_RECT.position
	container.size = GRID_RECT.size
	container.custom_minimum_size = GRID_RECT.size
	container.add_theme_constant_override("separation", 8)
	add_child(container)
	_grid_box = container

	# 上部ツールバー(件数表示 + 絞り込みボタン)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	container.add_child(toolbar)

	_count_label = Label.new()
	_count_label.text = ""
	_count_label.add_theme_font_size_override("font_size", COUNT_FONT)
	_count_label.add_theme_color_override("font_color", UiPalette.BRASS_HIGHLIGHT)
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toolbar.add_child(_count_label)

	_filter_button = CodedButton.make("絞り込み", FILTER_SIZE)
	# **押したボタンの位置から膨らんで開く**(GameDesign.md 9章「手触り」)。
	_filter_button.pressed.connect(func() -> void: _filter.open(_filter_button.get_global_rect()))
	toolbar.add_child(_filter_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.enable(scroll)
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
		view.gui_input.connect(_on_stock_input.bind(view))
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
	_side_box = column

	# 1. デッキ名と枚数
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	column.add_child(top_row)
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "デッキ名"
	_name_input.max_length = CardDeckSave.NAME_LIMIT
	_name_input.custom_minimum_size = NAME_SIZE
	MobileTextInput.wire(_name_input, "デッキ名")
	top_row.add_child(_name_input)
	_progress = Label.new()
	_progress.add_theme_font_size_override("font_size", PROGRESS_FONT)
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(_progress)

	# 2. 編成中のデッキ(30枠の決まった棚)。
	# **マナカーブの棒グラフは置かない**(GameDesign.md 9章)。
	# **「あと何枚」の帯も置かない**——空いている枠の数がそのまま残りを示すため。
	# **`ScrollContainer` へは入れない。**あの中では棚が「何段入るか」を知れず、
	# 枠の大きさを決められない(実際、高さ0のまま並んで画面の半分が空いた)。
	_shelf = CardDeckShelf.new()
	_shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shelf.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shelf.custom_minimum_size.x = SIDE_INNER_WIDTH
	_shelf.card_hovered.connect(_on_shelf_hovered)
	_shelf.hover_left.connect(_on_hover_left)
	_shelf.card_removed.connect(_on_band_remove)
	_shelf.card_add_requested.connect(_on_card_pressed)
	_shelf.card_long_pressed.connect(_show_detail)
	column.add_child(_shelf)


func _build_detail() -> void:
	_detail = CardDetailPanel.new()
	_detail.compact = true
	# 語のボタンと実演を持たせない(GameDesign.md 17章)。ホバーで出して外れたら消える
	# パネルの中に押しに行く先を置くと、そこへカーソルを動かした時点で消えてしまう。
	_detail.interactive = false
	_detail.size = DETAIL_SIZE
	_detail.visible = false
	# **パネルはホバーを奪わない。**カーソルの近くへ出す以上、下のカードや棚の上へ乗るため、
	# 塞ぐと「パネルに隠れたカードを指すと消える」ことになる。
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_detail)

	_detail_hide_timer = Timer.new()
	_detail_hide_timer.one_shot = true
	_detail_hide_timer.wait_time = DETAIL_HIDE_DELAY
	_detail_hide_timer.timeout.connect(_hide_detail)
	add_child(_detail_hide_timer)


# --- 向き ---------------------------------------------------------------


## 縦横が変わったときに `Main` から呼ばれる(Architecture.md 4.7節)。編成中のデッキ・名前・絞り込みは保つ。
func apply_orientation(portrait: bool) -> void:
	_portrait = portrait
	if _grid_box == null:
		return
	_backdrop.portrait = portrait
	var font := PORTRAIT_BUTTON_FONT if portrait else 0
	_place(_back, PORTRAIT_BACK_RECT if portrait else BACK_RECT, font)
	var action_size := PORTRAIT_ACTION_SIZE if portrait else ACTION_SIZE
	var right := float(ScreenOrientation.base_size().x) - ScreenHeader.OUTER_MARGIN
	for i in _actions.size():
		var from_right := _actions.size() - i
		var top := PORTRAIT_ACTION_TOP if portrait else BACK_RECT.position.y
		var x := right - from_right * (action_size.x + ACTION_GAP) + ACTION_GAP
		_place(_actions[i], Rect2(Vector2(x, top), action_size), font)
	var tab_w := (PORTRAIT_TAB_RECT.size.x - PORTRAIT_TAB_GAP) * 0.5
	for i in _tab_buttons.size():
		_tab_buttons[i].visible = portrait
		var at := PORTRAIT_TAB_RECT.position + Vector2((tab_w + PORTRAIT_TAB_GAP) * i, 0.0)
		_place(_tab_buttons[i], Rect2(at, Vector2(tab_w, PORTRAIT_TAB_RECT.size.y)), font)
	_place_box(_grid_box, PORTRAIT_GRID_RECT if portrait else GRID_RECT)
	_place_box(_side_box, PORTRAIT_SIDE_RECT if portrait else SIDE_RECT)
	_grid.columns = PORTRAIT_GRID_COLUMNS if portrait else GRID_COLUMNS
	for view in _card_views:
		view.zoom = PORTRAIT_STOCK_ZOOM if portrait else 1.0
	_shelf.text_scale = PORTRAIT_SHELF_TEXT if portrait else 1.0
	_shelf.custom_minimum_size.x = PORTRAIT_SIDE_RECT.size.x if portrait else SIDE_INNER_WIDTH
	_count_label.add_theme_font_size_override(
		"font_size", PORTRAIT_COUNT_FONT if portrait else COUNT_FONT
	)
	_place(
		_filter_button, Rect2(Vector2.ZERO, PORTRAIT_FILTER_SIZE if portrait else FILTER_SIZE), font
	)
	_name_input.custom_minimum_size = PORTRAIT_NAME_SIZE if portrait else NAME_SIZE
	_name_input.add_theme_font_size_override("font_size", font if portrait else NAME_FONT)
	_progress.add_theme_font_size_override(
		"font_size", PORTRAIT_PROGRESS_FONT if portrait else PROGRESS_FONT
	)
	_detail.scale = Vector2.ONE * (PORTRAIT_DETAIL_SCALE if portrait else 1.0)
	_hide_detail()
	_select_tab(_show_stock)


## 縦で在庫棚と組立台を切り替える。横では両方を出す。
func _select_tab(stock: bool) -> void:
	_show_stock = stock
	_grid_box.visible = stock or not _portrait
	_side_box.visible = not stock or not _portrait
	_backdrop.show_shelf = stock
	for i in _tab_buttons.size():
		var active: bool = (i == 0) == stock
		CodedButton.apply_styles(
			_tab_buttons[i], CodedButton.PRIMARY_ACTION_GROUP if active else TAB_GROUP
		)
	_refresh_tab_labels()


func _refresh_tab_labels() -> void:
	if _tab_buttons.is_empty():
		return
	_tab_buttons[0].text = "在庫棚"
	_tab_buttons[1].text = "デッキ %d / %d 枚" % [_deck.size(), MatchState.DECK_SIZE]


## ボタンを置き直す。`font` が0なら文字の大きさは作ったとき(テーマ)のまま。
func _place(button: Control, rect: Rect2, font: int) -> void:
	button.custom_minimum_size = rect.size
	button.size = rect.size
	if rect.position != Vector2.ZERO:
		button.position = rect.position
	if font > 0:
		button.add_theme_font_size_override("font_size", font)
	else:
		button.remove_theme_font_size_override("font_size")


func _place_box(box: Control, rect: Rect2) -> void:
	box.position = rect.position
	box.custom_minimum_size = rect.size
	box.size = rect.size


# --- 表示 ---------------------------------------------------------------


func _refresh() -> void:
	_progress.text = "%d / %d 枚" % [_deck.size(), MatchState.DECK_SIZE]
	_shelf.deck = _deck.duplicate()
	var full: bool = _deck.size() >= MatchState.DECK_SIZE
	for i in _card_views.size():
		var card: CardData = _pool[i]
		# **枚数は実数を出し、暗転だけを「入れられるか」で決める。**30枚に達した
		# だけで全部が「2/2」になると、どれを2枚積んだのか読めなくなる。
		var copies := _count_of(card)
		var owned := AccountService.owns_card_set(card.set_id)
		var can_add: bool = not full and copies < CardDeckSave.COPY_LIMIT and owned
		_card_views[i].show_card(card, copies, CardDeckSave.COPY_LIMIT, can_add, not owned)
	_save_button.disabled = not full
	_refresh_tab_labels()


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


## **カーソルの近くへ出す**(GameDesign.md 9章)。押す先を持たないパネルになった以上、
## 画面の反対の端まで視線を往復させる理由が無い。
func _show_detail(card: CardData) -> void:
	if card == null:
		return
	if _detail_hide_timer != null:
		_detail_hide_timer.stop()
	_detail.show_card(card)
	if _portrait:
		# 縦は指で隠れないよう画面の中央へ固定して出す(対局画面の長押しと同じ)。
		var screen := Vector2(ScreenOrientation.base_size())
		_detail.position = (screen - _detail.size * _detail.scale) * 0.5
	else:
		_detail.position = CardDetailPanel.place_near(
			get_local_mouse_position(), _detail.size, DETAIL_BOUNDS
		)
	_detail.visible = true


func _hide_detail() -> void:
	if _detail_hide_timer != null:
		_detail_hide_timer.stop()
	_detail.visible = false


## カードから外れた。隣へ移る途中の点滅を避けるため、すぐには消さず猶予を置く。
func _on_hover_left() -> void:
	if _detail_hide_timer != null and _detail.visible:
		_detail_hide_timer.start()


## タッチから作られたホバーでは出さない(指を離しても消えないため)。代わりに長押しで出す。
func _on_stock_hovered(view: WorkshopStockItem) -> void:
	if not TouchInput.active:
		_show_detail(view.card)


func _on_shelf_hovered(card: CardData) -> void:
	if not TouchInput.active:
		_show_detail(card)


func _on_stock_input(event: InputEvent, view: WorkshopStockItem) -> void:
	if not TouchInput.active:
		return
	if ClickArea.is_primary_click(event):
		_long_view = view
		_long.begin(view.get_global_mouse_position())
	elif event is InputEventMouseMotion:
		_long.move(view.get_global_mouse_position())
	elif ClickArea.is_primary_release(event) and _long.end():
		_hide_detail()


## 長押しが成立した。**離しても足さない**(押した扱いを打ち切る)。
func _on_stock_long_press() -> void:
	if _long_view == null or not is_instance_valid(_long_view):
		return
	_long_view.cancel_press()
	_show_detail(_long_view.card)


# --- 操作 ---------------------------------------------------------------


func _on_card_pressed(card: CardData) -> void:
	if not AccountService.owns_card_set(card.set_id):
		_offer_shop(card.set_id)
		return
	_add_card(card)


## ショップから戻ったとき。購入していれば、そのセットのカードをここで足せるようにする。
## 編成中のデッキは開き直さずそのまま残す。
func refresh_ownership() -> void:
	_refresh()


func _offer_shop(set_id: String) -> void:
	_pending_set = set_id
	_hide_detail()
	_shop_confirm.open_confirm(
		"まだ持っていないカード",
		"カードセット「%s」のカードです。ショップで購入するとデッキに入れられます。" % CardSetLibrary.display_name(set_id),
		"ショップへ",
		"閉じる"
	)


func _add_card(card: CardData) -> void:
	if _deck.size() >= MatchState.DECK_SIZE:
		return
	if _count_of(card) >= CardDeckSave.COPY_LIMIT:
		return
	# 未所有のカードセット(GameDesign.md 8章)に属するカードは追加できない。
	# 一覧側は暗く表示して押させない想定だが、ここでも弾いておく。
	if not AccountService.owns_card_set(card.set_id):
		return
	# **飛翔の出発点は配列操作の前に控える**(押された一覧のカードの位置)。
	var from_rect := _view_rect(card)
	_deck.append(card)
	_refresh()
	# 縦で組立台を出していないときは、切り替えの「デッキ」へ飛ばす。
	var to_rect := _shelf.global_rect_for_card(card)
	if not _side_box.visible:
		to_rect = _tab_buttons[1].get_global_rect()
	_fly_card(card, from_rect, to_rect)


func _on_band_remove(card: CardData) -> void:
	var index := _deck.find(card)
	if index < 0:
		return
	# **飛翔の出発点(棚の枠)は配列操作の前に控える**(取り除くと枠から消えるため)。
	var from_rect := _shelf.global_rect_for_card(card)
	_deck.remove_at(index)
	_refresh()
	var to_rect := _view_rect(card)
	if not _grid_box.visible:
		to_rect = _tab_buttons[0].get_global_rect()
	_fly_card(card, from_rect, to_rect)


## 一覧⇄棚の飛び(GameDesign.md 9章)。**演出の完了を待たず**、配列操作は既に済んだ
## 後に見た目だけを追いかけさせる。矩形のどちらかが取れなかった場合は何も飛ばさない。
func _fly_card(card: CardData, from_rect: Rect2, to_rect: Rect2) -> void:
	if from_rect.size == Vector2.ZERO or to_rect.size == Vector2.ZERO:
		return
	var texture: Texture2D = card.emblem if card.is_spell else card.icon_upright
	CardFlightFx.fly(self, from_rect, to_rect, FLIGHT_DURATION, texture)


## 一覧側でそのカードが表示されている矩形(グローバル座標)。見つからなければ `Rect2()`。
func _view_rect(card: CardData) -> Rect2:
	var index := _pool.find(card)
	if index < 0:
		return Rect2()
	return _card_views[index].get_global_rect()


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
