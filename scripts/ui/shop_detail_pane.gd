class_name ShopDetailPane
extends Control
## ショップ右の詳細(GameDesign.md 21章)。品種 / 名前 / 見本 / 説明 / 価格と購入後の残高 / 「購入する」。
## **タイルで選ぶ → ここで「購入する」の2段階を購入の確認とする**(確認のダイアログは出さない)。

signal buy_requested(kind: ShopCatalog.Kind, id: String)
signal set_preview_requested(set_id: String)

const KIND_BASELINE := 16.0
const KIND_FONT_SIZE := 14
const NAME_BASELINE := 46.0
const NAME_FONT_SIZE := 24
const PREVIEW_TOP := 64.0
const PREVIEW_HEIGHT := 196.0
const PREVIEW_FRAME_WIDTH := 1.5
const PREVIEW_PAD := 8.0
const CAPTION_GAP := 20.0
const CAPTION_FONT_SIZE := 13
const DESC_GAP := 26.0
const DESC_FONT_SIZE := 15
const DESC_MAX_LINES := 3
const BUY_HEIGHT := 56.0
const BUY_FONT_SIZE := 20
const SUB_BUTTON_HEIGHT := 46.0
const BUTTON_GAP := 10.0
const STATUS_GAP := 18.0
const STATUS_FONT_SIZE := 16

var _kind: ShopCatalog.Kind = ShopCatalog.Kind.ICON
var _id := ""
var _font: Font
var _table: AccountTablePreview
var _buy: Button
var _look: Button


func _ready() -> void:
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
	_buy.add_theme_color_override("font_color", UiPalette.OUTLINE_DARK)
	_buy.add_theme_color_override("font_hover_color", UiPalette.OUTLINE_DARK)
	_buy.pressed.connect(func() -> void: buy_requested.emit(_kind, _id))
	add_child(_buy)
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
	_look.visible = kind == ShopCatalog.Kind.CARD_SET
	_buy.visible = not owned
	_buy.disabled = AccountService.currency() < ShopCatalog.price(kind, id)
	_buy.mouse_default_cursor_shape = (
		Control.CURSOR_ARROW if _buy.disabled else Control.CURSOR_POINTING_HAND
	)
	_layout()
	queue_redraw()


## 購入が確定した瞬間、品の絵を砂金チップへ飛ばす起点(9章)。
func preview_global_rect() -> Rect2:
	return Rect2(global_position + _preview_rect().position, _preview_rect().size)


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
		UiPalette.TEXT_MUTED
	)
	draw_string(
		_font,
		Vector2(0.0, NAME_BASELINE),
		ShopCatalog.item_name(_kind, _id),
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x,
		NAME_FONT_SIZE,
		UiPalette.TEXT_OFFWHITE
	)
	var preview := _preview_rect()
	if not _table.visible:
		draw_rect(preview, UiPalette.BOARD_TABLE_FILL)
		var inner := preview.grow(-PREVIEW_PAD)
		if _kind == ShopCatalog.Kind.SKIN:
			ShopItemArt.skin_states(self, inner, _id)
		elif _kind == ShopCatalog.Kind.CARD_SET:
			ShopItemArt.card_set_grid(self, inner, _id, _font)
		draw_rect(preview, UiPalette.BRASS_DARK, false, PREVIEW_FRAME_WIDTH)
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
			UiPalette.TEXT_MUTED
		)
	draw_multiline_string(
		_font,
		Vector2(0.0, y + DESC_GAP),
		_description(),
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x,
		DESC_FONT_SIZE,
		DESC_MAX_LINES,
		UiPalette.TEXT_OFFWHITE
	)
	_draw_status()


func _caption() -> String:
	match _kind:
		ShopCatalog.Kind.ICON, ShopCatalog.Kind.PLAYMAT, ShopCatalog.Kind.EMOTE:
			return "対局ではこう見えます"
		ShopCatalog.Kind.SKIN:
			return "砂が落ちるにつれて絵が変わります"
		_:
			return ""


func _description() -> String:
	if _kind == ShopCatalog.Kind.CARD_SET:
		return CardSetLibrary.description(_id)
	return ShopCatalog.item_detail(_kind, _id)


## 価格と購入後の残高。**足りないときも赤で書かない**(GameDesign.md 21章)。
func _draw_status() -> void:
	var owned := AccountService.owns(_kind, _id)
	var cost := ShopCatalog.price(_kind, _id)
	var balance := AccountService.currency()
	var text := ""
	var color := UiPalette.TEXT_MUTED
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
		color = UiPalette.BRASS_HIGHLIGHT
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
