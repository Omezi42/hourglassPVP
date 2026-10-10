class_name WelcomeDaysPanel
extends Control
## はじめの7日の受取(GameDesign.md 23章)。ホームへ重ねる「暗幕+中央パネル」のモーダル
## (`DailyMissionPanel` と同じ作り)。`HomeScreen.offer_welcome_days()` が開く。
## セットの日は、持っていないカードセットをショップと同じタイルで並べ、1つ選んで受け取る。

signal closed
## 受け取った瞬間、押したボタンの位置と獲得額を運ぶ(ヘッダーの砂金へ飛ばす演出は `HomeScreen` が持つ)。
signal reward_claimed(from_rect: Rect2, amount: int)

const SCREEN_SIZE := Vector2(1280, 720)
const PANEL_SIZE := Vector2(560, 350)
const SET_PANEL_SIZE := Vector2(900, 660)
const CONTENT_INSET := 60.0
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const CLAIM_SIZE := Vector2(240, 56)
const LOOK_SIZE := Vector2(220, 56)
const SET_COLUMNS := 2
const SET_GAP := 12
## タイル2段ぶん。セットが増えたら中でスクロールする。
const SET_ROWS_VISIBLE := 2
const FAILED_TEXT := "通信に失敗しました。次にホームを開いたときに受け取れます"
const NOTE_TEXT := "来た日の数で進みます。続けて来なくても大丈夫です"
const SET_NOTE_TEXT := "選んだセットは、受け取ったらすぐデッキ編成に使えます"

var _panel: PanelContainer
var _pips: WelcomeDayPips
var _reward_label: Label
var _sets_scroll: ScrollContainer
var _sets_grid: GridContainer
var _note: Label
var _look_button: Button
var _claim_button: Button
var _preview: ShopSetPreview
var _day := 0
var _chosen_set := ""
var _busy := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = SCREEN_SIZE
	_build()


func open() -> void:
	open_day(WelcomeDays.claimed_days() + 1)


## `day` は今日受け取る日(1〜7)。
func open_day(day: int) -> void:
	_day = day
	_chosen_set = ""
	_pips.claimed = day - 1
	_pips.queue_redraw()
	_reward_label.text = "%d日目 ・ %s" % [day, WelcomeDays.reward_text(day)]
	var picking := WelcomeDays.offers_set(day)
	_sets_scroll.visible = picking
	_look_button.visible = picking
	_note.text = SET_NOTE_TEXT if picking else NOTE_TEXT
	if picking:
		_fill_sets()
	_resize_panel(SET_PANEL_SIZE if picking else PANEL_SIZE)
	_claim_button.text = "受け取る"
	_busy = false
	_refresh_buttons()
	visible = true


func _fill_sets() -> void:
	for child in _sets_grid.get_children():
		child.queue_free()
	var tile_width := (
		(SET_PANEL_SIZE.x - CONTENT_INSET - SET_GAP * (SET_COLUMNS - 1)) / float(SET_COLUMNS)
	)
	for set_id in WelcomeDays.set_choices():
		var tile := ShopItemTile.new(ShopCatalog.Kind.CARD_SET, set_id)
		tile.custom_minimum_size = Vector2(
			tile_width, ShopItemTile.height(ShopCatalog.Kind.CARD_SET)
		)
		tile.pressed.connect(_choose.bind(set_id))
		_sets_grid.add_child(tile)


func _choose(set_id: String) -> void:
	_chosen_set = set_id
	for tile in _sets_grid.get_children():
		tile.selected = tile.id == set_id
	_refresh_buttons()


func _refresh_buttons() -> void:
	var waiting := WelcomeDays.offers_set(_day) and _chosen_set.is_empty()
	_claim_button.disabled = waiting
	_look_button.disabled = _chosen_set.is_empty()


func _resize_panel(panel_size: Vector2) -> void:
	_panel.size = panel_size
	_panel.position = (SCREEN_SIZE - panel_size) * 0.5


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = SCREEN_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = PanelContainer.new()
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(box)

	var title := Label.new()
	title.text = "はじめの7日"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	_pips = WelcomeDayPips.new()
	_pips.custom_minimum_size = Vector2(PANEL_SIZE.x - CONTENT_INSET, WelcomeDayPips.HEIGHT)
	_pips.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_pips)

	_reward_label = Label.new()
	_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_label.add_theme_font_size_override("font_size", 22)
	_reward_label.add_theme_color_override("font_color", UiPalette.BRASS_HIGHLIGHT)
	box.add_child(_reward_label)

	_sets_scroll = ScrollContainer.new()
	_sets_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sets_scroll.custom_minimum_size = Vector2(
		SET_PANEL_SIZE.x - CONTENT_INSET,
		(
			ShopItemTile.height(ShopCatalog.Kind.CARD_SET) * SET_ROWS_VISIBLE
			+ SET_GAP * (SET_ROWS_VISIBLE - 1)
		)
	)
	_sets_scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_sets_scroll)
	_sets_grid = GridContainer.new()
	_sets_grid.columns = SET_COLUMNS
	_sets_grid.add_theme_constant_override("h_separation", SET_GAP)
	_sets_grid.add_theme_constant_override("v_separation", SET_GAP)
	_sets_scroll.add_child(_sets_grid)

	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size.x = PANEL_SIZE.x - CONTENT_INSET
	_note.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_note.add_theme_font_size_override("font_size", 15)
	_note.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	box.add_child(_note)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	_look_button = CodedButton.make("収録カードを見る", LOOK_SIZE)
	_look_button.pressed.connect(func() -> void: _preview.open_set(_chosen_set))
	buttons.add_child(_look_button)
	_claim_button = CodedButton.make_in_group("受け取る", CLAIM_SIZE, CodedButton.PRIMARY_ACTION_GROUP)
	_claim_button.pressed.connect(_on_claim_pressed)
	buttons.add_child(_claim_button)

	_preview = ShopSetPreview.new()
	add_child(_preview)


## 受け取れなかったとき(通信の失敗)は、文言を出してボタンを「閉じる」に替える。
func _on_claim_pressed() -> void:
	if _busy:
		return
	if _claim_button.text != "受け取る":
		_close()
		return
	_busy = true
	_claim_button.disabled = true
	var uid := NetSession.auth.uid if NetSession.auth != null else ""
	var before := int(AccountService.profile_value("currency", 0))
	var day: int = await WelcomeDays.claim(NetSession.client, uid, _chosen_set)
	_busy = false
	_claim_button.disabled = false
	if day <= 0:
		_note.text = FAILED_TEXT
		_claim_button.text = "閉じる"
		return
	_pips.claimed = day
	_pips.queue_redraw()
	# 選んだセットを既に持っていた日は砂金になるため、実際に増えた額で見る。
	var gold := int(AccountService.profile_value("currency", 0)) - before
	if gold > 0:
		reward_claimed.emit(_claim_button.get_global_rect(), gold)
	_close()


func _close() -> void:
	visible = false
	closed.emit()
