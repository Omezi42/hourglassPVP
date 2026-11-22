class_name CraftModal
extends Control
## 砂粒でカードを1枚生成する(GameDesign.md 15章「砂粒」)。デッキ編集の錠前の札と、図鑑のカード詳細から開く。
## カードの面・所持数・砂粒の残高・要る砂粒を見せ、「生成する」と「ショップのパックへ」(デッキ編集から開いたとき)を置く。
## `ShopSetPreview` と同じ「暗幕 + `content_panel.tres` の中央パネル」の型を使う。

signal crafted(card: CardData)
signal shop_requested(set_id: String)

const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const CARD_SIZE := Vector2(177, 237)
const BODY_WIDTH := 300.0
const BUTTON_SIZE := Vector2(300, 52)
const GAP := 14
const COLUMN_GAP := 28

var _card: CardData
var _dim: ColorRect
var _center: CenterContainer
var _view: CardView
var _name: Label
var _rarity: Label
var _owned: Label
var _cost: Label
var _message: Label
var _chip: CurrencyChip
var _craft: Button
var _shop: Button
var _busy := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	PortraitModal.watch(self, _layout)
	EscClose.attach(self, close)


## 開く。`with_shop` が真なら「ショップのパックへ」も置く(デッキ編集の錠前から)。
func open(card: CardData, with_shop := false) -> void:
	_card = card
	_message.text = ""
	_view.show_card(card, true)
	_view.custom_minimum_size = CARD_SIZE
	_shop.visible = with_shop
	_refresh()
	_layout()
	visible = true


func close() -> void:
	if not _busy:
		visible = false


## 生成できるカードか(公開済みの弾のカード)。基本セット・ソロモード限定・未公開は生成しない。
static func craftable(card: CardData) -> bool:
	if card == null or card.set_id.is_empty():
		return false
	for pack_id in ShopCatalog.pack_ids():
		if ShopCatalog.pack_card_ids(PackDefinition.load_pack(pack_id)).has(card.id):
			return true
	return false


func _refresh() -> void:
	var have := AccountService.card_count(_card.id)
	var cap := CardOwnership.cap(_card)
	var cost := RarityTable.get_table().cost_of(_card.rarity)
	var dust := AccountService.sand_dust()
	_name.text = _card.display_name
	_rarity.text = RarityPaint.rarity_name(_card.rarity)
	_rarity.add_theme_color_override("font_color", RarityPaint.color(_card.rarity))
	_owned.text = "所持 %d / %d" % [have, cap]
	_chip.set_amount(dust, false)
	if have >= cap:
		_cost.text = "これ以上は持てません"
	elif dust < cost:
		_cost.text = "生成に砂粒 %d ・ あと %d 足りません" % [cost, cost - dust]
	else:
		_cost.text = "生成に砂粒 %d → 生成後の残高 %d" % [cost, dust - cost]
	_craft.text = "生成する(砂粒 %d)" % cost
	_craft.disabled = have >= cap or dust < cost or _busy


func _on_craft() -> void:
	if _busy:
		return
	_busy = true
	_craft.disabled = true
	_message.text = "生成しています…"
	var ok: bool = await NetSession.sign_in()
	var result: Dictionary
	if ok:
		var uid := NetSession.auth.uid if NetSession.auth != null else ""
		result = await PackService.craft(NetSession.client, uid, _card.id)
	else:
		result = {"ok": false, "message": "接続できないため生成できません。"}
	_busy = false
	_message.text = str(result.get("message", ""))
	_refresh()
	if bool(result.get("ok", false)):
		_chip.set_amount(AccountService.sand_dust())
		crafted.emit(_card)


func _layout() -> void:
	size = PortraitModal.screen_size()
	_dim.size = size
	PortraitModal.fit(_center)


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = UiPalette.MODAL_DIM
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(
		func(event: InputEvent) -> void:
			if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
				close()
	)
	add_child(_dim)
	_center = CenterContainer.new()
	_center.anchor_right = 1.0
	_center.anchor_bottom = 1.0
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	var panel := PanelContainer.new()
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	_center.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", COLUMN_GAP)
	panel.add_child(row)
	var holder := CenterContainer.new()
	row.add_child(holder)
	_view = CardView.new()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_view)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = BODY_WIDTH
	column.add_theme_constant_override("separation", GAP)
	row.add_child(column)
	_name = _label(column, UiPalette.T_HEAD, UiPalette.IVORY)
	_rarity = _label(column, UiPalette.T_BODY, UiPalette.IVORY)
	_owned = _label(column, UiPalette.T_BODY, UiPalette.IVORY)
	_chip = CurrencyChip.new()
	_chip.dust = true
	_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_chip)
	_cost = _label(column, UiPalette.T_SMALL, UiPalette.MUTED)
	_message = _label(column, UiPalette.T_SMALL, UiPalette.SAND_HI)
	_craft = CodedButton.make_in_group("", BUTTON_SIZE, CodedButton.PRIMARY_ACTION_GROUP)
	_craft.pressed.connect(_on_craft)
	column.add_child(_craft)
	_shop = CodedButton.make("ショップのパックへ", BUTTON_SIZE)
	_shop.pressed.connect(
		func() -> void:
			visible = false
			shop_requested.emit(_card.set_id)
	)
	column.add_child(_shop)
	var close_button := CodedButton.make("閉じる", BUTTON_SIZE)
	close_button.pressed.connect(close)
	column.add_child(close_button)


func _label(parent: Control, px: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = BODY_WIDTH
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
