class_name ShopItemTile
extends Button
## ショップ中央のタイル1件(GameDesign.md 21章)。「品の絵 / 名前 / 価格または『✓ 所持』」。
## **押すと選ぶだけで、買わない**——買う入口は詳細(`ShopDetailPane`)の「購入する」1本に絞る。
##
## 地の面は `CodedButtonStyle`(真鍮の額縁+暗く凹んだ中央パネル)を流用する(`HomeTile` と同じ流儀)。

## 品種ごとの列数とタイルの高さ。絵の形(紋章=正方形、マット・スキン=横長、文言=1行)に合わせる。
## `stacked` は名前と価格を横に並べる幅が無いタイル(紋章)で、2行に積んで中央に寄せる。
const LAYOUT := {
	ShopCatalog.Kind.CARD_SET: {"columns": 1, "height": 150.0, "stacked": false},
	ShopCatalog.Kind.SKIN: {"columns": 2, "height": 190.0, "stacked": false},
	ShopCatalog.Kind.PLAYMAT: {"columns": 2, "height": 170.0, "stacked": false},
	ShopCatalog.Kind.EMOTE: {"columns": 2, "height": 96.0, "stacked": false},
	ShopCatalog.Kind.ICON: {"columns": 5, "height": 140.0, "stacked": true},
}
const ART_PAD := 6.0
## 絵の下に名前と価格の1行を置くぶんの高さ。
const FOOTER_HEIGHT := 38.0
const FOOTER_BASELINE_INSET := 13.0
## 2行に積むときの高さと行の間隔。
const STACKED_FOOTER_HEIGHT := 50.0
const STACKED_LINE_STEP := 19.0
const TEXT_PAD := 10.0
const NAME_FONT_SIZE := 15
const PRICE_FONT_SIZE := 15
const PRICE_WIDTH := 92.0
const PRICE_EMBLEM_SIZE := 13.0
const PRICE_EMBLEM_GAP := 4.0
const ICON_SEAL_RATIO := 0.4
const SELECT_INSET := 2.0
const SELECT_CORNER := 12.0
const SELECT_WIDTH := 3.0
## 残高が足りない品の暗さ(GameDesign.md 21章「買えないことは品を暗くすることで示す」)。
const UNAFFORDABLE_TONE := Color(0.62, 0.6, 0.58, 1.0)

var kind: ShopCatalog.Kind
var id := ""
var owned := false
var affordable := true
var selected := false:
	set(value):
		selected = value
		queue_redraw()
var _font: Font


static func columns(p_kind: ShopCatalog.Kind) -> int:
	return int(LAYOUT[p_kind]["columns"])


static func height(p_kind: ShopCatalog.Kind) -> float:
	return float(LAYOUT[p_kind]["height"])


func _init(p_kind: ShopCatalog.Kind, p_id: String) -> void:
	kind = p_kind
	id = p_id
	text = ""
	CodedButton.apply_styles(self, CodedButton.ICON_GROUP)


func _ready() -> void:
	_font = get_theme_default_font()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# 買えない品も選んで見本を見られる。**暗くするのは `modulate`**(子のマット見本ごと
	# 一括で暗くなる)、ホバーの発光だけを止める(手札のマナ不足と同じ。9章)。
	if not owned and not affordable:
		modulate = UNAFFORDABLE_TONE
		add_theme_stylebox_override("hover", get_theme_stylebox("normal"))
	if kind == ShopCatalog.Kind.PLAYMAT:
		# 模様は矩形の外まで伸びるため、切り抜きの効く子の層へ敷く(`BoardTable` と同じ理由)。
		var layer := BoardTable.MatLayer.new()
		layer.mat_id = id
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	resized.connect(_layout_layers)
	_layout_layers()


func _layout_layers() -> void:
	for child in get_children():
		if child is BoardTable.MatLayer:
			var art := _art_rect()
			child.position = art.position
			child.size = art.size


func _inner_rect() -> Rect2:
	return CodedButtonStyle.inner_rect(Rect2(Vector2.ZERO, size))


func _art_rect() -> Rect2:
	var inner := _inner_rect()
	return Rect2(
		inner.position + Vector2(ART_PAD, ART_PAD),
		Vector2(inner.size.x - ART_PAD * 2.0, inner.size.y - _footer_height() - ART_PAD)
	)


func _stacked() -> bool:
	return bool(LAYOUT[kind]["stacked"])


func _footer_height() -> float:
	return STACKED_FOOTER_HEIGHT if _stacked() else FOOTER_HEIGHT


func _draw() -> void:
	if _font == null:
		return
	var art := _art_rect()
	match kind:
		ShopCatalog.Kind.ICON:
			EmblemSeal.brass(
				self,
				art.get_center(),
				UserProfileLibrary.get_icon_texture(id),
				art.size.y * ICON_SEAL_RATIO
			)
		ShopCatalog.Kind.EMOTE:
			ShopItemArt.emote_bubble(self, art, id, _font)
		ShopCatalog.Kind.SKIN:
			ShopItemArt.skin_states(self, art, id)
		ShopCatalog.Kind.CARD_SET:
			ShopItemArt.card_set_row(self, art, id, _font)
	_draw_footer()
	if selected:
		var ring := Rect2(Vector2.ONE * SELECT_INSET, size - Vector2.ONE * SELECT_INSET * 2.0)
		var points := UiPaint.rounded_rect_points_uniform(ring, SELECT_CORNER, 5)
		points.append(points[0])
		draw_polyline(points, UiPalette.GLOW_AMBER, SELECT_WIDTH, true)


## ホバー中は面が琥珀に明るくなるため、文字を暗い色へ替えて読めるようにする
## (残高が足りない品はホバーで光らないので替えない)。
func _lit() -> bool:
	return is_hovered() and (owned or affordable)


func _draw_footer() -> void:
	var inner := _inner_rect()
	var lit := _lit()
	var baseline := inner.end.y - FOOTER_BASELINE_INSET
	var name := ShopCatalog.item_name(kind, id)
	if kind == ShopCatalog.Kind.CARD_SET:
		name += "(%s)" % CardSetLibrary.count_text(id)
	var name_color := UiPalette.OUTLINE_DARK if lit else UiPalette.TEXT_OFFWHITE
	var text_left := inner.position.x + TEXT_PAD
	var text_width := inner.size.x - TEXT_PAD * 2.0
	if _stacked():
		draw_string(
			_font,
			Vector2(text_left, baseline - STACKED_LINE_STEP),
			name,
			HORIZONTAL_ALIGNMENT_CENTER,
			text_width,
			NAME_FONT_SIZE,
			name_color
		)
	else:
		draw_string(
			_font,
			Vector2(text_left, baseline),
			name,
			HORIZONTAL_ALIGNMENT_LEFT,
			text_width - PRICE_WIDTH,
			NAME_FONT_SIZE,
			name_color
		)
	_draw_price(baseline, lit)


## 価格(所持済みなら「✓ 所持」)。積むタイルは中央へ、並べるタイルは右端へ寄せる。
func _draw_price(baseline: float, lit: bool) -> void:
	var inner := _inner_rect()
	var label := "✓ 所持" if owned else CurrencyRules.amount_text(ShopCatalog.price(kind, id))
	var label_width := (
		_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, PRICE_FONT_SIZE).x
	)
	var price_right := inner.end.x - TEXT_PAD
	if _stacked():
		var block_width := label_width
		if not owned:
			block_width += PRICE_EMBLEM_SIZE + PRICE_EMBLEM_GAP
		price_right = inner.get_center().x + block_width * 0.5
	if owned:
		draw_string(
			_font,
			Vector2(price_right - label_width, baseline),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			PRICE_FONT_SIZE,
			UiPalette.BRASS_PRESSED_DARK if lit else UiPalette.TEXT_MUTED
		)
		return
	# 価格は赤で書かない(GameDesign.md 21章)。単位は残高チップと同じ砂時計の印で示す。
	draw_string(
		_font,
		Vector2(price_right - label_width, baseline),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		PRICE_FONT_SIZE,
		UiPalette.BRASS_PRESSED_DARK if lit else UiPalette.BRASS_HIGHLIGHT
	)
	var emblem_center := Vector2(
		price_right - label_width - PRICE_EMBLEM_GAP - PRICE_EMBLEM_SIZE * 0.5,
		baseline - PRICE_FONT_SIZE * 0.36
	)
	UiPaint.draw_emblem(
		get_canvas_item(), UiPaint.Emblem.HOURGLASS, emblem_center, PRICE_EMBLEM_SIZE
	)
