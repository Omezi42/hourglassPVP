class_name ShopDetailPane
extends Control
## ショップ右の詳細(GameDesign.md 21章)。品種 / 名前 / 見本 / 説明 / 価格と購入後の残高 / 「購入する」。
## **タイルで選ぶ → ここで「購入する」の2段階を購入の確認とする**(確認のダイアログは出さない)。

signal buy_requested(kind: ShopCatalog.Kind, id: String)
signal set_preview_requested(set_id: String)
## パックを開ける(`count` は1か10、`free` は今日の無料パック)。
signal pack_requested(pack_id: String, count: int, free: bool)

const KIND_BASELINE := 16.0
const KIND_FONT_SIZE := UiPalette.T_SMALL
const NAME_BASELINE := 46.0
const NAME_FONT_SIZE := UiPalette.T_HEAD
const PREVIEW_TOP := 64.0
const PREVIEW_HEIGHT := 196.0
const PREVIEW_PAD := 8.0
const CAPTION_GAP := 20.0
const CAPTION_FONT_SIZE := UiPalette.T_SMALL
const DESC_GAP := 26.0
const DESC_FONT_SIZE := UiPalette.T_BODY
const DESC_MAX_LINES := 3
const BUY_HEIGHT := 56.0
const BUY_FONT_SIZE := UiPalette.T_LEAD
const SUB_BUTTON_HEIGHT := 46.0
const BUTTON_GAP := 10.0
const STATUS_GAP := 18.0
const STATUS_FONT_SIZE := UiPalette.T_BODY
## パックの「1パック」「10パック」の2つ並びのボタンの高さ。
const PACK_BUTTON_HEIGHT := 50.0
const PACK_INFO_TOP := 64.0

var _kind: ShopCatalog.Kind = ShopCatalog.Kind.ICON
var _id := ""
var _font: Font
var _table: AccountTablePreview
var _buy: Button
var _look: Button
var _buy_one: Button
var _buy_bulk: Button
var _free: Button


func _ready() -> void:
	set_process(false)
	_font = get_theme_default_font()
	_table = AccountTablePreview.new()
	add_child(_table)
	_look = CodedButton.make("収録カードを見る", Vector2(0, SUB_BUTTON_HEIGHT))
	_look.pressed.connect(func() -> void: set_preview_requested.emit(_id))
	add_child(_look)
	_buy = CodedButton.make_in_group(
		"購入する", Vector2(0, BUY_HEIGHT), CodedButton.PRIMARY_ACTION_GROUP
	)
	_buy.add_theme_font_size_override("font_size", BUY_FONT_SIZE)
	_buy.pressed.connect(func() -> void: buy_requested.emit(_kind, _id))
	add_child(_buy)
	_buy_one = CodedButton.make("", Vector2(0, PACK_BUTTON_HEIGHT))
	_buy_one.pressed.connect(func() -> void: pack_requested.emit(_id, 1, false))
	add_child(_buy_one)
	_buy_bulk = CodedButton.make("", Vector2(0, PACK_BUTTON_HEIGHT))
	_buy_bulk.pressed.connect(
		func() -> void: pack_requested.emit(_id, PackService.BULK_COUNT, false)
	)
	add_child(_buy_bulk)
	_free = CodedButton.make_in_group(
		"今日の無料パックを開ける", Vector2(0, BUY_HEIGHT), CodedButton.PRIMARY_ACTION_GROUP
	)
	_free.add_theme_font_size_override("font_size", BUY_FONT_SIZE)
	_free.pressed.connect(func() -> void: pack_requested.emit(_id, 1, true))
	add_child(_free)
	resized.connect(_layout)
	_layout()


## 品を選び直したとき、または残高・所有が変わったときに呼ぶ。`bump` は選んだ瞬間の合図(9章)。
func show_item(kind: ShopCatalog.Kind, id: String, bump := false) -> void:
	_kind = kind
	_id = id
	var uses_table := (
		kind in [ShopCatalog.Kind.ICON, ShopCatalog.Kind.PLAYMAT, ShopCatalog.Kind.EMOTE]
	)
	_table.visible = uses_table
	if uses_table:
		_table.show_profile(
			AccountService.display_name_or_default(),
			id if kind == ShopCatalog.Kind.ICON else AccountService.icon_id(),
			AccountService.title_id(),
			id if kind == ShopCatalog.Kind.PLAYMAT else AccountService.playmat_id()
		)
		if kind == ShopCatalog.Kind.EMOTE:
			_table.show_emote(EmoteLibrary.get_emote_text(id))
		if bump:
			_table.bump()
	var owned := AccountService.owns(kind, id)
	var pack := kind == ShopCatalog.Kind.PACK
	_look.visible = kind == ShopCatalog.Kind.CARD_SET or pack
	_buy.visible = not owned and not pack
	_set_enabled(_buy, AccountService.currency() >= ShopCatalog.price(kind, id))
	_buy_one.visible = pack
	_buy_bulk.visible = pack
	_free.visible = pack and AccountService.free_pack_available()
	if pack:
		var price := ShopCatalog.price(kind, id)
		_buy_one.text = "1パック  %s" % CurrencyRules.amount_text(price)
		_buy_bulk.text = (
			"%dパック  %s"
			% [PackService.BULK_COUNT, CurrencyRules.amount_text(price * PackService.BULK_COUNT)]
		)
		_set_enabled(_buy_one, AccountService.currency() >= price)
		_set_enabled(_buy_bulk, AccountService.currency() >= price * PackService.BULK_COUNT)
	_layout()
	queue_redraw()


func _set_enabled(button: Button, enabled: bool) -> void:
	button.disabled = not enabled
	button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	)


## 購入が確定した瞬間、品の絵を砂金チップへ飛ばす起点(9章)。
## 縦ではパネルごと拡大して置くため、拡大を通した矩形を返す。
func preview_global_rect() -> Rect2:
	return get_global_transform() * _preview_rect()


func _preview_rect() -> Rect2:
	return Rect2(0.0, PREVIEW_TOP, size.x, PREVIEW_HEIGHT)


func _layout() -> void:
	if _buy == null:
		return
	var preview := _preview_rect()
	_table.position = preview.position
	_table.size = preview.size
	_buy.position = Vector2(0.0, size.y - BUY_HEIGHT)
	_buy.size = Vector2(size.x, BUY_HEIGHT)
	_look.size = Vector2(size.x, SUB_BUTTON_HEIGHT)
	_look.position = Vector2(0.0, _bottom_top() - SUB_BUTTON_HEIGHT - BUTTON_GAP)
	if _kind != ShopCatalog.Kind.PACK:
		return
	var bottom := size.y
	if _free.visible:
		_free.position = Vector2(0.0, size.y - BUY_HEIGHT)
		_free.size = Vector2(size.x, BUY_HEIGHT)
		bottom -= BUY_HEIGHT + BUTTON_GAP
	var half := (size.x - BUTTON_GAP) * 0.5
	for i in 2:
		var button := _buy_one if i == 0 else _buy_bulk
		button.position = Vector2((half + BUTTON_GAP) * i, bottom - PACK_BUTTON_HEIGHT)
		button.size = Vector2(half, PACK_BUTTON_HEIGHT)
	_look.position = Vector2(
		0.0, _pack_buttons_top() - STATUS_GAP * 2.0 - SUB_BUTTON_HEIGHT - BUTTON_GAP
	)


func _pack_buttons_top() -> float:
	return _buy_one.position.y


## 購入ボタン(所持済みなら同じ場所の案内文)の上端。
func _bottom_top() -> float:
	return size.y - BUY_HEIGHT


func _draw() -> void:
	if _font == null or _id.is_empty():
		return
	draw_string(
		_font,
		Vector2(0.0, KIND_BASELINE),
		ShopCatalog.kind_name(_kind),
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x,
		KIND_FONT_SIZE,
		UiPalette.GOLD
	)
	draw_string(
		_font,
		Vector2(0.0, NAME_BASELINE),
		ShopCatalog.item_name(_kind, _id),
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x,
		NAME_FONT_SIZE,
		UiPalette.IVORY
	)
	if _kind == ShopCatalog.Kind.PACK:
		ShopPackInfo.draw(self, _font, PACK_INFO_TOP, size.x, _id)
		_draw_pack_status()
		return
	var preview := _preview_rect()
	if not _table.visible:
		UiKit.well(get_canvas_item(), preview)
		var inner := preview.grow(-PREVIEW_PAD)
		if _kind == ShopCatalog.Kind.CARD_SET:
			ShopItemArt.card_set_grid(self, inner, _id, _font)
	var y := preview.end.y + CAPTION_GAP
	var caption := _caption()
	if not caption.is_empty():
		draw_string(
			_font,
			Vector2(0.0, y),
			caption,
			HORIZONTAL_ALIGNMENT_LEFT,
			size.x,
			CAPTION_FONT_SIZE,
			UiPalette.MUTED
		)
	draw_multiline_string(
		_font,
		Vector2(0.0, y + DESC_GAP),
		_description(),
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x,
		DESC_FONT_SIZE,
		DESC_MAX_LINES,
		UiPalette.IVORY
	)
	_draw_status()


func _caption() -> String:
	match _kind:
		ShopCatalog.Kind.ICON, ShopCatalog.Kind.PLAYMAT, ShopCatalog.Kind.EMOTE:
			return "対局ではこう見えます"
		_:
			return ""


func _description() -> String:
	if _kind == ShopCatalog.Kind.CARD_SET:
		var hidden := CardSetLibrary.hidden_count(_id)
		if hidden > 0:
			return "%s\n毎日1枚ずつ公開・あと %d 枚" % [CardSetLibrary.description(_id), hidden]
		return CardSetLibrary.description(_id)
	return ShopCatalog.item_detail(_kind, _id)


## 価格と購入後の残高。**足りないときも赤で書かない**(GameDesign.md 21章)。
func _draw_status() -> void:
	var owned := AccountService.owns(_kind, _id)
	var cost := ShopCatalog.price(_kind, _id)
	var balance := AccountService.currency()
	var text := ""
	var color := UiPalette.MUTED
	var y := _bottom_top() - STATUS_GAP
	if owned:
		text = ("デッキ編成で使えます" if _kind == ShopCatalog.Kind.CARD_SET else "アカウント画面で設定できます")
		y = _bottom_top() + BUY_HEIGHT * 0.5
	elif balance < cost:
		text = (
			"%s ・ あと %s 足りません"
			% [CurrencyRules.label_text(cost), CurrencyRules.amount_text(cost - balance)]
		)
	else:
		text = (
			"%s → 購入後の残高 %s"
			% [CurrencyRules.label_text(cost), CurrencyRules.amount_text(balance - cost)]
		)
		color = UiPalette.SAND_HI
	if _look.visible and not owned:
		y -= SUB_BUTTON_HEIGHT + BUTTON_GAP
	draw_string(
		_font,
		Vector2(0.0, y),
		text,
		HORIZONTAL_ALIGNMENT_CENTER if owned else HORIZONTAL_ALIGNMENT_LEFT,
		size.x,
		STATUS_FONT_SIZE,
		color
	)


## パックの購入後の残高(「砂金 1240 → 1パックで 1140」)。足りなければ「あと n 足りません」。
func _draw_pack_status() -> void:
	var cost := ShopCatalog.price(_kind, _id)
	var balance := AccountService.currency()
	var text := (
		"%s → 1パックで %s"
		% [CurrencyRules.label_text(balance), CurrencyRules.amount_text(balance - cost)]
	)
	if balance < cost:
		text = (
			"%s ・ あと %s 足りません"
			% [CurrencyRules.label_text(cost), CurrencyRules.amount_text(cost - balance)]
		)
	draw_string(
		_font,
		Vector2(0.0, _pack_buttons_top() - STATUS_GAP),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x,
		UiPalette.T_SMALL,
		UiPalette.MUTED
	)
