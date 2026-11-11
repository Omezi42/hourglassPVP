class_name CardDeckListScreen
extends Control
## 保存済みデッキの一覧(GameDesign.md 9章)。**管理**(編集・削除・並び替え)と、
## **対局の開始前に使うデッキを選ぶ**の2つのモードを1つの画面で兼ねる。
##
## どちらも同じ見た目のカード一覧を出すためで、選ぶ側だけ別の画面を作ると
## 片方の見た目が古くなる。件数が増えても1画面に収まるよう**横2列のグリッド**とする。
## 札(`CardDeckCase`)を押すと管理では編集・選択ではそのデッキに決まり、中身は札の「一覧」から
## `CardDeckPeek` で重ねて見る(札の砂時計だけではどのカードか分からないため)。

signal back_pressed
signal create_requested
signal edit_requested(index: int)
signal deck_picked(index: int)

enum Mode { MANAGE, PICK }

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const CONFIRM_SCENE := "res://scenes/confirm_modal.tscn"
## 空の案内を出す矩形を、パネルの縁と上の1行から内側へ寄せる幅。
const EMPTY_INSET := Vector2(40.0, 56.0)
const LIST_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 1232, ScreenHeader.CONTENT_HEIGHT)
## 札の幅は一覧の幅を2列で割る(左右24px・札の間16px)。
const GRID_GAP := 16
const CARD_SIZE := Vector2((LIST_RECT.size.x - GRID_GAP) / 2.0, 140)
const GUIDE_FONT := 20

## 縦画面(GameDesign.md 9章「縦画面」)。1列にし、札を中身ごと大きく描く。
const PORTRAIT_COLUMNS := 1
## 縦の札は左右24pxを引いた幅いっぱい。下の右に72px以上のボタンを置くぶん背を高くする。
const PORTRAIT_CARD_SIZE := Vector2(
	ScreenOrientation.PORTRAIT_SIZE.x - ScreenHeader.OUTER_MARGIN * 2.0, 236
)
const PORTRAIT_GUIDE_FONT := 24
## 削除した札が縮んで消えるまでの尺(GameDesign.md 9章)。
const DELETE_SHRINK_DURATION := 0.15

var _header: ScreenHeader
var _grid: GridContainer
## 一覧の上に出す1行(並び替え中・空のときの案内と、サイトから届いた知らせ)。
var _empty_label: Label
## 1つも無いときだけ、棚の中央へ出す印と案内。
var _empty_state: EmptyState
var _reorder_button: Button
var _intro_button: Button
## みんなのデッキ(GameDesign.md 26章)。この画面の上へ重ねて開く。
var _intro_screen: CardDeckIntroScreen
var _confirm: ConfirmModal
var _peek: CardDeckPeek
## 「一覧」で開いているデッキの添字(主の操作で編集・選択へ渡す)。
var _peek_index := -1
var _mode: Mode = Mode.MANAGE
var _reordering := false
var _pending_delete := -1
var _room: VBoxContainer
var _portrait := false


func _ready() -> void:
	_build()


## 管理として開く(デッキタブから)。
func open_manage() -> void:
	_intro_screen.visible = false
	_peek.close()
	_mode = Mode.MANAGE
	_reordering = false
	_refresh()
	_receive_from_site()


## 対局の開始前に使うデッキを選ぶ(GameDesign.md 9章)。
func open_pick() -> void:
	_intro_screen.visible = false
	_peek.close()
	_mode = Mode.PICK
	_reordering = false
	_refresh()
	_receive_from_site()


## 攻略サイトの「ゲームに追加」で届いたデッキを足し、1行で知らせる(GameDesign.md 32章)。
func _receive_from_site() -> void:
	await DeckInboxService.receive(NetSession.client, AccountSyncService.synced_uid())
	if not is_inside_tree():
		return
	var announcement := DeckInboxService.take_announcement()
	if announcement.is_empty():
		return
	_refresh()
	_empty_label.text = announcement
	_empty_label.visible = true


func _build() -> void:
	var backdrop := ScreenBackdrop.new()
	backdrop.room = ScreenBackdrop.Room.HALL
	add_child(backdrop)

	_header = load(HEADER_SCENE).instantiate()
	add_child(_header)
	_header.back_pressed.connect(func() -> void: back_pressed.emit())
	_reorder_button = CodedButton.make("並び替え", Vector2(220, 56))
	_reorder_button.pressed.connect(_on_reorder_pressed)
	_header.add_action(_reorder_button)
	_intro_button = CodedButton.make("みんなのデッキ", Vector2(220, 56))
	_intro_button.pressed.connect(func() -> void: _intro_screen.open())
	_header.add_action(_intro_button)

	# 札は囲うパネルを持たず、部屋へ直接並べる。
	_room = VBoxContainer.new()
	_room.position = LIST_RECT.position
	_room.size = LIST_RECT.size
	add_child(_room)
	var column := _room
	_empty_label = Label.new()
	_empty_label.add_theme_font_size_override("font_size", GUIDE_FONT)
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_empty_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.enable(scroll)
	column.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", GRID_GAP)
	_grid.add_theme_constant_override("v_separation", GRID_GAP)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	# 1つも保存していないときは、案内の1行だけだと広いパネルが空のまま残り、
	# 画面が壊れているようにも見える。棚の位置へ印と1行を中央で出す。
	_empty_state = EmptyState.new()
	_empty_state.position = LIST_RECT.position + EMPTY_INSET
	_empty_state.size = LIST_RECT.size - EMPTY_INSET * 2.0
	_empty_state.visible = false
	add_child(_empty_state)

	# モーダルは最後に足す(後から足した子ほど手前に描かれるため)。
	_peek = CardDeckPeek.new()
	add_child(_peek)
	_peek.primary_pressed.connect(_on_peek_primary)

	_confirm = load(CONFIRM_SCENE).instantiate()
	add_child(_confirm)
	_confirm.confirmed.connect(_on_delete_confirmed)
	_confirm.cancelled.connect(func() -> void: _pending_delete = -1)

	_intro_screen = CardDeckIntroScreen.new()
	add_child(_intro_screen)
	_intro_screen.closed.connect(_refresh)


## 縦横が変わったときに `Main` から呼ばれる(Architecture.md 4.7節)。モードと並び替え中かどうかは保つ。
func apply_orientation(portrait: bool) -> void:
	_portrait = portrait
	if _room == null:
		return
	_header.apply_orientation(portrait)
	_intro_screen.apply_orientation(portrait)
	_peek.apply_orientation(portrait)
	_layout()
	if is_visible_in_tree():
		_refresh()


func _layout() -> void:
	var rect := LIST_RECT
	if _portrait:
		var top := _header.portrait_content_top()
		rect = Rect2(
			ScreenHeader.OUTER_MARGIN,
			top,
			ScreenOrientation.PORTRAIT_SIZE.x - ScreenHeader.OUTER_MARGIN * 2.0,
			ScreenHeader.PORTRAIT_CONTENT_BOTTOM - top
		)
	_room.position = rect.position
	_room.custom_minimum_size = rect.size
	_room.size = rect.size
	_empty_state.position = rect.position + EMPTY_INSET
	_empty_state.size = rect.size - EMPTY_INSET * 2.0
	_empty_label.add_theme_font_size_override(
		"font_size", PORTRAIT_GUIDE_FONT if _portrait else GUIDE_FONT
	)
	# 折り返す行には幅を与える(幅が決まる前の1文字ずつの高さが残るため。Pitfalls.md)。
	_empty_label.custom_minimum_size.x = rect.size.x if _portrait else 0.0
	_grid.columns = PORTRAIT_COLUMNS if _portrait else 2


# --- 表示 ---------------------------------------------------------------


func _refresh() -> void:
	var decks := CardDeckSave.list_decks()
	var picking: bool = _mode == Mode.PICK
	_header.set_title("使うデッキを選ぶ" if picking else "デッキ")
	_reorder_button.visible = not picking and decks.size() > 1
	_intro_button.visible = not picking
	_reorder_button.text = "並び替えを終える" if _reordering else "並び替え"
	_empty_label.text = _guide_text(decks.size(), picking)
	_empty_label.visible = not _empty_label.text.is_empty()
	# 縦では主アクションの行の有無で一覧の上端が変わる。
	if _portrait:
		_layout()
	# 管理では新規作成の枠が残るため、空の案内は選ぶときだけ出す。
	if decks.is_empty() and picking:
		_empty_state.show_message("まだデッキがありません", "このままでもプリセットの「基本」で対局へ入れます")
	else:
		_empty_state.hide_message()
	# 同じフレームで2度組み直しても(向きの切り替え)古い札が並びに残らないよう、すぐ外す。
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var last_used := CardDeckSave.selected_index() if picking else -1
	for i in decks.size():
		_grid.add_child(_make_card(i, decks[i], decks.size(), i == last_used))
	if not picking and not _reordering:
		_grid.add_child(_make_new_slot())
	ListRevealFx.stagger(_grid.get_children())


## 上の1行。**常時は出さない**(件数は並びを見れば分かる)。並び替え中と、空のときの次の一手だけ。
func _guide_text(count: int, picking: bool) -> String:
	if picking:
		return ""
	if count == 0:
		return "「新しいデッキを作る」から%d枚のデッキを作れます" % MatchState.DECK_SIZE
	if _reordering:
		return "↑ ↓ で並び順を入れ替えます"
	return ""


func _make_card(index: int, deck: Dictionary, total: int, last_used: bool) -> CardDeckCase:
	var card := CardDeckCase.new()
	card.portrait = _portrait
	card.custom_minimum_size = PORTRAIT_CARD_SIZE if _portrait else CARD_SIZE
	card.deck_name = str(deck.get("name", CardDeckSave.DEFAULT_NAME))
	card.cards = deck.get("cards", [])
	card.last_used = last_used
	card.set_actions(_mode == Mode.MANAGE, _reordering, index > 0, index < total - 1)
	card.area_pressed.connect(_on_card_pressed.bind(index))
	card.list_pressed.connect(_on_list_pressed.bind(index))
	card.delete_pressed.connect(_on_delete_pressed.bind(index))
	card.move_pressed.connect(func(offset: int) -> void: _on_move_pressed(index, offset))
	return card


func _make_new_slot() -> CardDeckCase:
	var slot := CardDeckCase.new()
	slot.portrait = _portrait
	slot.new_slot = true
	slot.custom_minimum_size = PORTRAIT_CARD_SIZE if _portrait else CARD_SIZE
	slot.area_pressed.connect(func() -> void: create_requested.emit())
	return slot


# --- 操作 ---------------------------------------------------------------


## 札そのもの: 管理では編集、選ぶときはそのデッキに決める。並び替え中は ↑ ↓ だけを押させる。
func _on_card_pressed(index: int) -> void:
	if _reordering:
		return
	_act_on(index)


func _act_on(index: int) -> void:
	if _mode == Mode.PICK:
		deck_picked.emit(index)
	else:
		edit_requested.emit(index)


func _on_list_pressed(index: int) -> void:
	var decks := CardDeckSave.list_decks()
	if index < 0 or index >= decks.size():
		return
	_peek_index = index
	_peek.open(
		str(decks[index]["name"]),
		decks[index]["cards"],
		"このデッキで対局" if _mode == Mode.PICK else "編集する"
	)


func _on_peek_primary() -> void:
	if _peek_index >= 0:
		_act_on(_peek_index)


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
	var index := _pending_delete
	_pending_delete = -1
	if index < 0:
		return
	var card: Control = (
		_grid.get_child(index) as Control if index < _grid.get_child_count() else null
	)
	if card == null:
		CardDeckSave.remove_deck(index)
		_refresh()
		return
	# 消える前に縮めて見せる(GameDesign.md 9章「削除した札は縮んで消え、残りが詰まる」)。
	# 実際の配列操作は演出の完了を待たずに行わず、Tween終了後にまとめて行う。
	card.pivot_offset = card.size * 0.5
	var tween := card.create_tween()
	tween.tween_property(card, "scale", Vector2.ZERO, DELETE_SHRINK_DURATION)
	tween.tween_callback(
		func() -> void:
			CardDeckSave.remove_deck(index)
			_refresh()
	)
