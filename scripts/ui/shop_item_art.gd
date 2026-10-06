class_name ShopItemArt
extends RefCounted
## ショップの品の絵(GameDesign.md 21章)。タイル(`ShopItemTile`)と詳細(`ShopDetailPane`)が
## 同じ絵を大きさ違いで描くため、描き方をここへ集める。名前だけでは何を買うのか分からない品ほど、
## 実物に近いものをそのまま見せる。

## 砂時計の絵に対する紋章の位置(絵の左下。手札の封蝋と同じ置き場)と大きさ。
const SEAL_ANCHOR := Vector2(0.2, 0.83)
const SEAL_RADIUS_RATIO := 0.15
const NAME_FONT_SIZE := 11
const NAME_HEIGHT := 18.0
const CELL_PAD := 4.0
const GRID_COLUMNS := 5
const BUBBLE_CORNER := 10.0
const BUBBLE_FONT_SIZE := 16
const BUBBLE_TOP := Color(0.16, 0.13, 0.1, 0.95)
const BUBBLE_BOTTOM := Color(0.08, 0.06, 0.05, 0.95)
const BUBBLE_OUTLINE_WIDTH := 1.2
## 段階公開でまだ出していない枠(GameDesign.md 21章)。公開済みの絵を影にして「?」を重ねる。
const HIDDEN_TINT := Color(0.55, 0.47, 0.36, 0.30)
const HIDDEN_MARK_RATIO := 0.32
const HIDDEN_MARK_COLOR := Color(0.78, 0.68, 0.52, 0.85)
const HIDDEN_NAME := "近日公開"


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
				UiPalette.TEXT_OFFWHITE if i < ids.size() else UiPalette.TEXT_MUTED
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


## カードスキンの3状態の絵を横に並べる(GameDesign.md 31章)。見た目が品そのもののため、
## 所有・ON/OFFに関わらずスキンの絵を直に読む(`CardSkins` は通さない)。
static func skin_states(ci: CanvasItem, rect: Rect2, skin_id: String) -> void:
	var count := SkinLibrary.STATE_FILES.size()
	var cell := Vector2(rect.size.x / float(count), rect.size.y)
	for state in count:
		var texture := SkinLibrary.texture(skin_id, state)
		if texture == null:
			continue
		var scale: float = minf(cell.x / texture.get_size().x, cell.y / texture.get_size().y)
		var art := texture.get_size() * scale
		var at := rect.position + Vector2(cell.x * state + (cell.x - art.x) * 0.5, cell.y - art.y)
		ci.draw_texture_rect(texture, Rect2(at, art), false)


## エモートの文言を、対局中の吹き出し(`EmoteBubble`)と同じ質感の真鍮枠に収める。
static func emote_bubble(ci: CanvasItem, rect: Rect2, emote_id: String, font: Font) -> void:
	var rid := ci.get_canvas_item()
	var points := UiPaint.rounded_rect_points_uniform(rect, BUBBLE_CORNER, 5)
	UiPaint.fill_gradient_polygon(rid, points, rect, [[0.0, BUBBLE_TOP], [1.0, BUBBLE_BOTTOM]])
	var outline := points.duplicate()
	outline.append(points[0])
	ci.draw_polyline(outline, UiPalette.BRASS_LIGHT, BUBBLE_OUTLINE_WIDTH, true)
	if font == null:
		return
	ci.draw_string(
		font,
		Vector2(rect.position.x, rect.get_center().y + BUBBLE_FONT_SIZE * 0.36),
		EmoteLibrary.get_emote_text(emote_id),
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		BUBBLE_FONT_SIZE,
		UiPalette.TEXT_OFFWHITE
	)
