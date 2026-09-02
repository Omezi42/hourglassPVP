class_name CardShopScreen
extends Control
## ショップ(GameDesign.md 21章、Architecture.md 10.8)。砂金を使う唯一の場所で、
## 売るのはアイコンとエモートだけ。共通のレイアウト規約(GameDesign.md 9章)に従い、
## `ScreenHeader` を使う。

signal back_pressed
## 買ったものはアカウント画面・ホームのヘッダーに効くため、購入のたびに通知する。
signal purchased

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const CONFIRM_SCENE := "res://scenes/confirm_modal.tscn"
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const LIST_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 1232, ScreenHeader.CONTENT_HEIGHT - 46)
## 品は横2列のグリッド(GameDesign.md 9章)。縦1列にすると1画面に数件しか入らない。
const COLUMNS := 2
const CARD_SIZE := Vector2(580, 88)
const MESSAGE_TOP := ScreenHeader.CONTENT_TOP + ScreenHeader.CONTENT_HEIGHT - 34

var _grid: GridContainer
var _balance: Label
var _message: Label
var _confirm: ConfirmModal
var _busy := false
## 確認中の品。押した時点で控え、確定したときに買う。
var _pending: Dictionary = {}


func _ready() -> void:
	_build()


## 画面を開くたびにMainが呼ぶ。残高は購入で必ず動くため、開くたびに描き直す。
func open() -> void:
	_set_message("")
	_refresh()


func _refresh() -> void:
	_balance.text = "%s %d" % [CurrencyRules.CURRENCY_NAME, AccountService.currency()]
	for child in _grid.get_children():
		child.queue_free()
	for item in ShopCatalog.items():
		var kind: ShopCatalog.Kind = item["kind"]
		var id: String = str(item["id"])
		var card := ShopItemCard.new(kind, id)
		card.owned = AccountService.owns(kind, id)
		card.affordable = AccountService.currency() >= ShopCatalog.price(kind)
		card.pressed.connect(func() -> void: _on_item_pressed(kind, id))
		_grid.add_child(card)


func _on_item_pressed(kind: ShopCatalog.Kind, id: String) -> void:
	if _busy or AccountService.owns(kind, id):
		return
	var cost := ShopCatalog.price(kind)
	if AccountService.currency() < cost:
		_set_message(
			"%sが足りません(あと%d)。" % [CurrencyRules.CURRENCY_NAME, cost - AccountService.currency()]
		)
		return
	_pending = {"kind": kind, "id": id}
	_confirm.open_confirm(
		"購入の確認",
		(
			"%s「%s」を %d %s で購入します。"
			% [
				ShopCatalog.kind_name(kind),
				ShopCatalog.item_name(kind, id),
				cost,
				CurrencyRules.CURRENCY_NAME
			]
		),
		"購入する"
	)


func _on_confirmed() -> void:
	if _busy or _pending.is_empty():
		return
	_busy = true
	_set_message("購入しています…")
	var ok: bool = await NetSession.sign_in()
	var result: Dictionary
	if ok:
		var uid := NetSession.auth.uid if NetSession.auth != null else ""
		result = await AccountService.purchase(
			NetSession.client, uid, _pending["kind"], str(_pending["id"])
		)
	else:
		result = {"ok": false, "message": "接続できないため購入できません。"}
	_busy = false
	_pending = {}
	_set_message(str(result.get("message", "")))
	_refresh()
	if bool(result.get("ok", false)):
		purchased.emit()


func _set_message(text: String) -> void:
	_message.text = text


func _build() -> void:
	add_child(ScreenBackdrop.new())
	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	header.set_title("ショップ")
	header.back_pressed.connect(func() -> void: back_pressed.emit())
	# 残高はここでの購入で必ず動くため、ヘッダーの主アクションの位置へ常時出す
	# (GameDesign.md 21章)。押すものではないのでボタンにはしない。
	_balance = Label.new()
	_balance.add_theme_font_size_override("font_size", 22)
	_balance.add_theme_color_override("font_color", UiPalette.BRASS_HIGHLIGHT)
	_balance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_action(_balance)

	var panel := PanelContainer.new()
	panel.position = LIST_RECT.position
	panel.custom_minimum_size = LIST_RECT.size
	panel.size = LIST_RECT.size
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	_message = Label.new()
	_message.position = Vector2(24, MESSAGE_TOP)
	_message.size = Vector2(1232, 28)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 16)
	_message.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	add_child(_message)

	_confirm = load(CONFIRM_SCENE).instantiate()
	add_child(_confirm)
	_confirm.confirmed.connect(_on_confirmed)
	_confirm.cancelled.connect(func() -> void: _pending = {})


## 品1件。アイコンはその絵を、エモートは実際に出る文言をそのまま出す
## (GameDesign.md 21章)。買えない品は暗くして押しても何も起こさない。
class ShopItemCard:
	extends Button
	var kind: ShopCatalog.Kind
	var id: String
	var owned := false
	var affordable := true
	var _font: Font

	func _init(p_kind: ShopCatalog.Kind, p_id: String) -> void:
		kind = p_kind
		id = p_id
		custom_minimum_size = CARD_SIZE
		flat = true

	func _ready() -> void:
		_font = get_theme_default_font()
		if _font == null:
			_font = ThemeDB.fallback_font
		mouse_default_cursor_shape = (
			Control.CURSOR_ARROW if _dimmed() else Control.CURSOR_POINTING_HAND
		)

	func _dimmed() -> bool:
		return owned or not affordable

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var points := UiPaint.rounded_rect_points_uniform(rect, 6.0, 5)
		var top := Color(0.16, 0.13, 0.11, 0.92)
		var bottom := Color(0.09, 0.07, 0.06, 0.92)
		if _dimmed():
			top = Color(0.11, 0.10, 0.09, 0.85)
			bottom = Color(0.07, 0.06, 0.06, 0.85)
		UiPaint.fill_gradient_polygon(get_canvas_item(), points, rect, [[0.0, top], [1.0, bottom]])
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(
			outline, UiPalette.BRASS_DARK if _dimmed() else UiPalette.BRASS_MID, 1.4, true
		)
		if _font == null:
			return
		_draw_thumb()
		var text_color := UiPalette.TEXT_MUTED if _dimmed() else UiPalette.TEXT_OFFWHITE
		draw_string(
			_font,
			Vector2(96, 38),
			ShopCatalog.item_name(kind, id),
			HORIZONTAL_ALIGNMENT_LEFT,
			320,
			20,
			text_color
		)
		draw_string(
			_font,
			Vector2(96, 64),
			ShopCatalog.item_detail(kind, id),
			HORIZONTAL_ALIGNMENT_LEFT,
			320,
			14,
			UiPalette.TEXT_MUTED
		)
		_draw_price()

	## アイコンは紋章そのもの、エモートは吹き出しに見立てた枠を出す。
	func _draw_thumb() -> void:
		var center := Vector2(52, 44)
		draw_circle(center, 26.0, Color(0.12, 0.1, 0.08, 0.9))
		draw_arc(center, 26.0, 0.0, TAU, 28, UiPalette.BRASS_MID, 1.2)
		if kind == ShopCatalog.Kind.ICON:
			var tex := UserProfileLibrary.get_icon_texture(id)
			if tex != null:
				draw_texture_rect(tex, Rect2(center - Vector2(18, 18), Vector2(36, 36)), false)
			return
		draw_string(
			_font,
			center + Vector2(-9, 7),
			"◆",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			20,
			UiPalette.BRASS_HIGHLIGHT
		)

	func _draw_price() -> void:
		var label := (
			"所有済み" if owned else "%d %s" % [ShopCatalog.price(kind), CurrencyRules.CURRENCY_NAME]
		)
		var color := UiPalette.TEXT_MUTED
		if not owned:
			color = UiPalette.BRASS_HIGHLIGHT if affordable else Color(1, 0.55, 0.5, 1)
		draw_string(
			_font, Vector2(size.x - 176, 52), label, HORIZONTAL_ALIGNMENT_RIGHT, 160, 18, color
		)
