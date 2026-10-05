class_name CardShopScreen
extends Control
## ショップ(GameDesign.md 21章、Architecture.md 10.8)。砂金を使う唯一の場所で、
## 売るのはアイコン・エモート・プレイマット・カードセット・カードスキン。共通のレイアウト規約
## (GameDesign.md 9章)に従い、`ScreenHeader` を使う。
##
## **左に品種のタブ、中央に品のタイル、右に選んだ品の詳細**。品が増えても1本のスクロールへ
## 積み上がらず、目当ての品種へ1回で行けるようにする。

signal back_pressed
## 買ったものはアカウント画面・ホームのヘッダーに効くため、購入のたびに通知する。
signal purchased

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const MARGIN := ScreenHeader.OUTER_MARGIN
const SCREEN_WIDTH := 1280.0
const COLUMN_GAP := 12.0
const RAIL_WIDTH := 196.0
const DETAIL_WIDTH := 388.0
const TAB_HEIGHT := 64.0
const TAB_GAP := 10
const GRID_SEPARATION := 12
## 中央の一覧の下に残す、購入の結果を1行で出す欄の高さ。
const MESSAGE_HEIGHT := 34.0
const MESSAGE_FONT_SIZE := 16

## タブの並び(対局への効き目が大きい順。GameDesign.md 21章)。
const KINDS: Array[Dictionary] = [
	{"kind": ShopCatalog.Kind.CARD_SET, "heading": "カードセット"},
	{"kind": ShopCatalog.Kind.SKIN, "heading": "カードスキン"},
	{"kind": ShopCatalog.Kind.PLAYMAT, "heading": "プレイマット"},
	{"kind": ShopCatalog.Kind.EMOTE, "heading": "エモート"},
	{"kind": ShopCatalog.Kind.ICON, "heading": "アイコン"},
]

var _balance: CurrencyChip
## 開いた直後は脈を出さない。買って減ったときも同じで、脈は増えたときだけ出る。
var _balance_seen := false
var _message: Label
var _rail: VBoxContainer
var _scroll: ScrollContainer
var _grid: GridContainer
var _detail: ShopDetailPane
var _preview: ShopSetPreview
var _kind: ShopCatalog.Kind = ShopCatalog.Kind.CARD_SET
var _selected_id := ""
var _tiles: Array[ShopItemTile] = []
var _busy := false


func _ready() -> void:
	_build()


## 画面を開くたびにMainが呼ぶ。残高は購入で必ず動くため、開くたびに描き直す。
## focus_set_id を渡すと、カードセットのタブでそのセットを選んで開く(デッキ編集からの導線)。
## 渡さなければ先頭のタブの先頭の品を選ぶ(詳細が空の画面を見せない)。
func open(focus_set_id := "") -> void:
	_set_message("")
	var by_kind := _ids_by_kind()
	var sets: Array = by_kind.get(ShopCatalog.Kind.CARD_SET, [])
	_selected_id = ""
	if focus_set_id != "" and sets.has(focus_set_id):
		_kind = ShopCatalog.Kind.CARD_SET
		_selected_id = focus_set_id
	else:
		for entry in KINDS:
			var ids: Array = by_kind.get(entry["kind"], [])
			if not ids.is_empty():
				_kind = entry["kind"]
				_selected_id = str(ids[0])
				break
	_refresh()
	_scroll_to_selected()


## `ShopCatalog.items()` を品種ごとに束ねる。
func _ids_by_kind() -> Dictionary:
	var by_kind: Dictionary = {}
	for item in ShopCatalog.items():
		if not by_kind.has(item["kind"]):
			by_kind[item["kind"]] = []
		by_kind[item["kind"]].append(str(item["id"]))
	return by_kind


func _refresh() -> void:
	_balance.set_amount(AccountService.currency(), _balance_seen)
	_balance_seen = true
	var by_kind := _ids_by_kind()
	_build_tabs(by_kind)
	_build_tiles(by_kind.get(_kind, []))
	_detail.visible = not _selected_id.is_empty()
	if _detail.visible:
		_detail.show_item(_kind, _selected_id)


## **売り物が0件の品種のタブは出さない**(GameDesign.md 21章)。
func _build_tabs(by_kind: Dictionary) -> void:
	for child in _rail.get_children():
		child.queue_free()
	for entry in KINDS:
		var kind: ShopCatalog.Kind = entry["kind"]
		var ids: Array = by_kind.get(kind, [])
		if ids.is_empty():
			continue
		var tab := ShopKindTab.new()
		tab.kind = kind
		tab.label_text = str(entry["heading"])
		tab.total_count = ids.size()
		for id in ids:
			if AccountService.owns(kind, str(id)):
				tab.owned_count += 1
		tab.active = kind == _kind
		tab.custom_minimum_size = Vector2(RAIL_WIDTH, TAB_HEIGHT)
		tab.pressed.connect(func() -> void: _select_kind(kind))
		_rail.add_child(tab)


func _build_tiles(ids: Array) -> void:
	for child in _grid.get_children():
		child.queue_free()
	_tiles.clear()
	var columns := ShopItemTile.columns(_kind)
	_grid.columns = columns
	var tile_width := (_grid_width() - GRID_SEPARATION * (columns - 1)) / float(columns)
	for id in ids:
		var tile := ShopItemTile.new(_kind, str(id))
		tile.owned = AccountService.owns(_kind, str(id))
		tile.affordable = AccountService.currency() >= ShopCatalog.price(_kind, str(id))
		tile.selected = str(id) == _selected_id
		tile.custom_minimum_size = Vector2(tile_width, ShopItemTile.height(_kind))
		tile.pressed.connect(func() -> void: _select_item(str(id)))
		_grid.add_child(tile)
		_tiles.append(tile)


## 一覧の内側の幅(パネルの余白とスクロールバーのぶんを除く)。
func _grid_width() -> float:
	var style: StyleBox = load(PANEL_STYLE)
	var bar := _scroll.get_v_scroll_bar().get_combined_minimum_size().x
	return _grid_rect().size.x - style.get_minimum_size().x - bar


func _select_kind(kind: ShopCatalog.Kind) -> void:
	if kind == _kind or _busy:
		return
	_kind = kind
	var ids: Array = _ids_by_kind().get(kind, [])
	_selected_id = str(ids[0]) if not ids.is_empty() else ""
	_set_message("")
	_refresh()
	_scroll.scroll_vertical = 0
	if _detail.visible:
		_detail.show_item(_kind, _selected_id, true)


func _select_item(id: String) -> void:
	if id == _selected_id:
		return
	_selected_id = id
	_set_message("")
	for tile in _tiles:
		tile.selected = tile.id == id
	_detail.show_item(_kind, id, true)


## 並べ直した直後はまだ大きさが決まっていないため、1フレーム待ってから寄せる。
func _scroll_to_selected() -> void:
	_scroll.scroll_vertical = 0
	await get_tree().process_frame
	for tile in _tiles:
		if is_instance_valid(tile) and tile.selected:
			_scroll.ensure_control_visible(tile)
			return


## 詳細の「購入する」。**選ぶ → 押す、の2段階を確認とし、ダイアログは出さない**(GameDesign.md 21章)。
func _on_buy_requested(kind: ShopCatalog.Kind, id: String) -> void:
	if _busy or AccountService.owns(kind, id):
		return
	if AccountService.currency() < ShopCatalog.price(kind, id):
		return
	_busy = true
	_set_message("購入しています…")
	var flight_from := _selected_tile_rect()
	var ok: bool = await NetSession.sign_in()
	var result: Dictionary
	if ok:
		var uid := NetSession.auth.uid if NetSession.auth != null else ""
		result = await AccountService.purchase(NetSession.client, uid, kind, id)
	else:
		result = {"ok": false, "message": "接続できないため購入できません。"}
	_busy = false
	var bought := bool(result.get("ok", false))
	# 品の絵が砂金チップへ向けて飛んでから残高を更新する(GameDesign.md 9章)。
	# 残高が減る理由を数字の変化だけでなく絵でも見せるための順序。
	if bought:
		await CardFlightFx.fly(self, flight_from, _balance.get_global_rect())
	_set_message(str(result.get("message", "")))
	_refresh()
	if bought:
		purchased.emit()


func _selected_tile_rect() -> Rect2:
	for tile in _tiles:
		if tile.selected:
			return tile.get_global_rect()
	return _detail.preview_global_rect()


func _set_message(text: String) -> void:
	_message.text = text


func _rail_rect() -> Rect2:
	return Rect2(MARGIN, ScreenHeader.CONTENT_TOP, RAIL_WIDTH, ScreenHeader.CONTENT_HEIGHT)


func _detail_rect() -> Rect2:
	return Rect2(
		SCREEN_WIDTH - MARGIN - DETAIL_WIDTH,
		ScreenHeader.CONTENT_TOP,
		DETAIL_WIDTH,
		ScreenHeader.CONTENT_HEIGHT
	)


func _grid_rect() -> Rect2:
	var left := _rail_rect().end.x + COLUMN_GAP
	var right := _detail_rect().position.x - COLUMN_GAP
	return Rect2(
		left, ScreenHeader.CONTENT_TOP, right - left, ScreenHeader.CONTENT_HEIGHT - MESSAGE_HEIGHT
	)


func _build() -> void:
	var backdrop := ScreenBackdrop.new()
	backdrop.room = ScreenBackdrop.Room.SHOP
	add_child(backdrop)
	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	header.set_title("ショップ")
	header.back_pressed.connect(func() -> void: back_pressed.emit())
	# 残高はここでの購入で必ず動くため、ヘッダーの主アクションの位置へ常時出す
	# (GameDesign.md 21章)。押すものではないのでボタンにはしない。
	_balance = CurrencyChip.new()
	_balance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_action(_balance)

	_rail = VBoxContainer.new()
	_rail.position = _rail_rect().position
	_rail.size = _rail_rect().size
	_rail.add_theme_constant_override("separation", TAB_GAP)
	add_child(_rail)

	var grid_panel := _panel(_grid_rect())
	add_child(grid_panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.enable(_scroll)
	grid_panel.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", GRID_SEPARATION)
	_grid.add_theme_constant_override("v_separation", GRID_SEPARATION)
	_scroll.add_child(_grid)

	_message = Label.new()
	_message.position = Vector2(_grid_rect().position.x, _grid_rect().end.y)
	_message.size = Vector2(_grid_rect().size.x, MESSAGE_HEIGHT)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", MESSAGE_FONT_SIZE)
	_message.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	add_child(_message)

	var detail_panel := _panel(_detail_rect())
	add_child(detail_panel)
	_detail = ShopDetailPane.new()
	_detail.buy_requested.connect(_on_buy_requested)
	_detail.set_preview_requested.connect(func(set_id: String) -> void: _preview.open_set(set_id))
	detail_panel.add_child(_detail)

	_preview = ShopSetPreview.new()
	add_child(_preview)


func _panel(rect: Rect2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.custom_minimum_size = rect.size
	panel.size = rect.size
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	return panel
