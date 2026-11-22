class_name ShopItemArt
extends RefCounted
## ショップの品の絵(GameDesign.md 21章)。タイル(`ShopItemTile`)と詳細(`ShopDetailPane`)が
## 同じ絵を大きさ違いで描くため、描き方をここへ集める。名前だけでは何を買うのか分からない品ほど、
## 実物に近いものをそのまま見せる。

## 砂時計の絵に対する紋章の位置(絵の左下。手札の紋章の印と同じ置き場)と大きさ。
const SEAL_ANCHOR := Vector2(0.2, 0.83)
const SEAL_RADIUS_RATIO := 0.15
const NAME_FONT_SIZE := UiPalette.T_MICRO
const NAME_HEIGHT := 18.0
const CELL_PAD := 4.0
const GRID_COLUMNS := 5
const BUBBLE_CORNER := 10.0
const BUBBLE_FONT_SIZE := UiPalette.T_BODY
## 段階公開でまだ出していない枠(GameDesign.md 21章)。公開済みの絵を影にして「?」を重ねる。
const HIDDEN_TINT := Color(UiPalette.INK_500, 0.6)
const HIDDEN_MARK_RATIO := 0.32
const HIDDEN_MARK_COLOR := Color(UiPalette.MUTED, 0.85)
const HIDDEN_NAME := "近日公開"
## パックの包み(縦横比・上下の真鍮の綴じ・題字・名札の高さの比)。
const PACK_COVER_TITLE := "砂時計アリーナ"
const PACK_COVER_ASPECT := 0.66
const PACK_COVER_GLOW := 0.22
const PACK_CRIMP_RATIO := 0.03
const PACK_TITLE_RATIO := 0.1
const PACK_PLATE_RATIO := 0.11
const PACK_TEXT_GAP := 24.0
const PACK_LINE_STEP := 24.0


## カードセットの収録カードを横一列に並べる(タイル)。未公開の枠は予定枚数ぶん「?」で埋める。
static func card_set_row(ci: CanvasItem, rect: Rect2, set_id: String, font: Font) -> void:
	var ids := CardSetLibrary.card_ids(set_id)
	var slots := CardSetLibrary.planned_count(set_id)
	if ids.is_empty():
		return
	var cell := Vector2(rect.size.x / slots, rect.size.y)
	for i in slots:
		var at := Rect2(rect.position + Vector2(cell.x * i, 0.0), cell)
		if i < ids.size():
			_hourglass(ci, at, ids[i])
		else:
			_hidden(ci, at, ids[0], font)


## カードセットの収録カードを名前つきで格子に並べる(詳細)。
static func card_set_grid(ci: CanvasItem, rect: Rect2, set_id: String, font: Font) -> void:
	var ids := CardSetLibrary.card_ids(set_id)
	var slots := CardSetLibrary.planned_count(set_id)
	if ids.is_empty():
		return
	var columns: int = mini(slots, GRID_COLUMNS)
	var rows: int = ceili(slots / float(columns))
	var cell := Vector2(rect.size.x / columns, rect.size.y / rows)
	for i in slots:
		var origin := (
			rect.position + Vector2(cell.x * (i % columns), cell.y * floori(i / float(columns)))
		)
		var art := Rect2(origin, Vector2(cell.x, cell.y - NAME_HEIGHT))
		var label := HIDDEN_NAME
		if i < ids.size():
			_hourglass(ci, art, ids[i])
			var card := CardLibrary.find_by_id(ids[i])
			label = card.display_name if card != null else ""
		else:
			_hidden(ci, art, ids[0], font)
		if font != null:
			ci.draw_string(
				font,
				origin + Vector2(0.0, cell.y - CELL_PAD),
				label,
				HORIZONTAL_ALIGNMENT_CENTER,
				cell.x,
				NAME_FONT_SIZE,
				UiPalette.IVORY if i < ids.size() else UiPalette.MUTED
			)


## まだ公開していない枠。紋章は押さない(どのカードかを示すものが無いため)。
static func _hidden(ci: CanvasItem, cell: Rect2, shape_card_id: String, font: Font) -> void:
	var card := CardLibrary.find_by_id(shape_card_id)
	if card == null:
		return
	var texture := HourglassArt.texture(card.art_key(), HourglassArt.State.UPRIGHT)
	if texture == null:
		return
	var room := cell.grow(-CELL_PAD)
	var scale: float = minf(room.size.x / texture.get_size().x, room.size.y / texture.get_size().y)
	var art_size := texture.get_size() * scale
	var at := room.position + (room.size - art_size) * 0.5
	ci.draw_texture_rect(texture, Rect2(at, art_size), false, HIDDEN_TINT)
	if font == null:
		return
	var mark_size := int(art_size.y * HIDDEN_MARK_RATIO)
	ci.draw_string(
		font,
		Vector2(at.x, at.y + art_size.y * 0.5 + mark_size * 0.36),
		"?",
		HORIZONTAL_ALIGNMENT_CENTER,
		art_size.x,
		mark_size,
		HIDDEN_MARK_COLOR
	)


## 砂時計1つを枠に収め、紋章を押す。**色だけでは見分けられない**ため紋章を必ず添える(9章)。
static func _hourglass(ci: CanvasItem, cell: Rect2, card_id: String) -> void:
	var card := CardLibrary.find_by_id(card_id)
	if card == null:
		return
	var texture := HourglassArt.texture(card.art_key(), HourglassArt.State.UPRIGHT)
	if texture == null:
		return
	var room := cell.grow(-CELL_PAD)
	var scale: float = minf(room.size.x / texture.get_size().x, room.size.y / texture.get_size().y)
	var art_size := texture.get_size() * scale
	var at := room.position + (room.size - art_size) * 0.5
	ci.draw_texture_rect(texture, Rect2(at, art_size), false)
	EmblemSeal.brass(ci, at + art_size * SEAL_ANCHOR, card.emblem, art_size.y * SEAL_RADIUS_RATIO)


## エモートの文言を、面(タイル・詳細)の中へ沈めた区画に収める。
static func emote_bubble(ci: CanvasItem, rect: Rect2, emote_id: String, font: Font) -> void:
	UiKit.well(ci.get_canvas_item(), rect, BUBBLE_CORNER)
	if font == null:
		return
	ci.draw_string(
		font,
		Vector2(rect.position.x, rect.get_center().y + BUBBLE_FONT_SIZE * 0.36),
		EmoteLibrary.get_emote_text(emote_id),
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		BUBBLE_FONT_SIZE,
		UiPalette.IVORY
	)


## パックの包み(封をした砂時計を収めた札。GameDesign.md 21章)。開封で返すものと同じ姿。
static func pack_cover(ci: CanvasItem, rect: Rect2, pack_id: String, font: Font) -> void:
	var rid := ci.get_canvas_item()
	var corner := UiKit.radius(rect) * 0.4
	UiKit.vgrad(
		rid,
		UiKit.rr(rect, corner),
		[[0.0, UiPalette.RARITY_EPIC.darkened(0.55)], [1.0, UiPalette.CARD_BACK_BOTTOM]]
	)
	UiKit.glow(rid, rect.get_center(), rect.size * 0.42, Color(UiPalette.SAND, PACK_COVER_GLOW))
	var crimp := rect.size.y * PACK_CRIMP_RATIO
	for top in [rect.position.y, rect.end.y - crimp]:
		UiKit.vgrad(
			rid, UiKit.rr(Rect2(rect.position.x, top, rect.size.x, crimp), 1.0), UiKit.brass_stops()
		)
	UiKit.stroke(rid, UiKit.rr(rect, corner), Color(UiPalette.GOLD, 0.6), 1.2)
	var title_h := rect.size.y * PACK_TITLE_RATIO
	var plate_h := rect.size.y * PACK_PLATE_RATIO
	var art := Rect2(
		rect.position.x,
		rect.position.y + crimp + title_h,
		rect.size.x,
		rect.size.y - crimp * 2.0 - title_h - plate_h * 1.4
	)
	PackVesselPaint.draw(rid, PackVesselPaint.fit(art.grow(-rect.size.x * 0.08)))
	if font == null:
		return
	var px := maxi(roundi(title_h * 0.55), UiPalette.T_MICRO)
	UiKit.text_in(
		rid,
		font,
		PACK_COVER_TITLE,
		Rect2(rect.position.x, rect.position.y + crimp, rect.size.x, title_h),
		px,
		UiPalette.GOLD_HI
	)
	var pack := PackDefinition.load_pack(pack_id)
	var plate := Rect2(
		rect.position.x + rect.size.x * 0.12,
		rect.end.y - crimp - plate_h * 1.2,
		rect.size.x * 0.76,
		plate_h
	)
	UiKit.tag(rid, font, plate, pack.display_name if pack != null else "", px)


## パックのタイルの中身: 左に包み、右に弾の名前・枚数・収録テーマ・レジェンドの枚数。
static func pack_summary(ci: CanvasItem, rect: Rect2, pack_id: String, font: Font) -> void:
	var pack := PackDefinition.load_pack(pack_id)
	if pack == null:
		return
	var cover_w := rect.size.y * PACK_COVER_ASPECT
	pack_cover(ci, Rect2(rect.position, Vector2(cover_w, rect.size.y)), pack_id, font)
	if font == null:
		return
	var left := rect.position.x + cover_w + PACK_TEXT_GAP
	var width := rect.end.x - left
	var y := rect.position.y + UiPalette.T_HEAD + UiPalette.S2
	ci.draw_string(
		font,
		Vector2(left, y),
		pack.display_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		width,
		UiPalette.T_HEAD,
		UiPalette.IVORY
	)
	y += UiPalette.T_BODY + UiPalette.S4
	ci.draw_string(
		font,
		Vector2(left, y),
		ShopCatalog.item_detail(ShopCatalog.Kind.PACK, pack_id),
		HORIZONTAL_ALIGNMENT_LEFT,
		width,
		UiPalette.T_BODY,
		UiPalette.MUTED
	)
	var lines: Array[Array] = []
	for set_id in pack.set_ids:
		if not CardSetLibrary.card_ids(set_id).is_empty():
			lines.append(["・" + CardSetLibrary.display_name(set_id), UiPalette.IVORY])
	var legends := legend_count(pack)
	if legends > 0:
		lines.append(["・レジェンド%d枚" % legends, UiPalette.RARITY_LEGEND])
	var column_w := width * 0.5
	y += UiPalette.S4
	for i in lines.size():
		var at := Vector2(left + column_w * (i % 2), y + PACK_LINE_STEP * (1 + floori(i / 2.0)))
		ci.draw_string(
			font,
			at,
			str(lines[i][0]),
			HORIZONTAL_ALIGNMENT_LEFT,
			column_w,
			UiPalette.T_SMALL,
			lines[i][1]
		)


## 弾の公開済みレジェンドの枚数。
static func legend_count(pack: PackDefinition) -> int:
	var count := 0
	for card_id in ShopCatalog.pack_card_ids(pack):
		var card := CardLibrary.find_by_id(card_id)
		if card != null and card.rarity == CardEnums.Rarity.LEGENDARY:
			count += 1
	return count
