class_name CardDeckList
extends Control
## 編成中のデッキを**1種類1行のリスト**として描く(GameDesign.md 9章)。棚(`CardDeckShelf`)と
## 切り替えて使い、シグナルと `global_rect_for_card()` は棚と同じ形にそろえる。
##
## **同名2枚は「×2」の1行にまとめる。**棚は並べた形で見せ、リストは一目で読ませる役割のため。
## 1つの `Control` が全行を `_draw()` で描き、当たり判定を矩形の表として持つ(棚と同じ理由)。

signal card_hovered(card: CardData)
signal hover_left
signal card_removed(card: CardData)
signal card_add_requested(card: CardData)

## 列の数。種類が最も多い(30種)ときも、スクロールなしで1面に収まるようにする。
const COLUMNS := 2
const PAD := 8.0
const COLUMN_GAP := 10.0
const ROW_GAP := 3.0
## 行の高さに対する文字の割合と、文字の大きさの上限(縦は `text_scale` を掛ける)。
const FONT_RATIO := 0.46
const FONT_MAX := 15
const BADGE_RATIO := 0.36
const ROW_TOP := Color(0.20, 0.135, 0.085)
const ROW_BOTTOM := Color(0.13, 0.085, 0.052)
const ROW_EDGE := Color(0.52, 0.42, 0.26, 0.45)
const ROW_HOVER := Color(1.0, 0.88, 0.52, 0.85)
const COUNT_COLOR := Color(1.0, 0.86, 0.52)
const EMPTY_HINT := "左の在庫棚から選ぶと、ここへ並びます"
const HINT_FONT := 16

var deck: Array = []:
	set(value):
		deck = value
		_rebuild()

var text_scale := 1.0:
	set(value):
		text_scale = value
		queue_redraw()

var _font: Font
## 1要素 = {"card": CardData, "count": int}。並びは棚と同じコスト順。
var _entries: Array[Dictionary] = []
var _hover_index := -1
var _glow_amount := 0.0
var _glow_tween: Tween
var _was_full := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
		return
	if what == NOTIFICATION_MOUSE_EXIT and _hover_index >= 0:
		_hover_index = -1
		hover_left.emit()
		queue_redraw()


func _rebuild() -> void:
	var sorted := deck.duplicate()
	sorted.sort_custom(CardLibrary.compare_by_cost)
	_entries.clear()
	for card in sorted:
		if not _entries.is_empty() and _entries[-1]["card"] == card:
			_entries[-1]["count"] = int(_entries[-1]["count"]) + 1
		else:
			_entries.append({"card": card, "count": 1})
	_hover_index = -1
	var full: bool = deck.size() == MatchState.DECK_SIZE
	if full and not _was_full:
		_start_glow()
	_was_full = full
	queue_redraw()


func _start_glow() -> void:
	_glow_amount = 1.0
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_tween = create_tween()
	_glow_tween.tween_method(_set_glow_amount, 1.0, 0.0, CardDeckShelf.GLOW_DURATION)


func _set_glow_amount(value: float) -> void:
	_glow_amount = value
	queue_redraw()


## そのカードの行の、印のあたりの正方形(グローバル座標)。飛翔演出の着地点/出発点。
func global_rect_for_card(card: CardData) -> Rect2:
	for index in _entries.size():
		if _entries[index]["card"] == card:
			var row := _row_rect(index)
			var square := Rect2(row.position, Vector2(row.size.y, row.size.y))
			return Rect2(get_global_rect().position + square.position, square.size)
	return Rect2()


## 1列に入る行の数。**最大の種類数(=デッキ枚数)から決め、行の高さを常に同じにする。**
func _rows_per_column() -> int:
	return int(ceil(float(MatchState.DECK_SIZE) / float(COLUMNS)))


func _row_rect(index: int) -> Rect2:
	var rows := _rows_per_column()
	var col_w: float = (size.x - PAD * 2.0 - COLUMN_GAP * (COLUMNS - 1)) / float(COLUMNS)
	var row_h: float = (size.y - PAD * 2.0 - ROW_GAP * (rows - 1)) / float(rows)
	var col: int = index / rows
	var row: int = index % rows
	return Rect2(
		Vector2(PAD + col * (col_w + COLUMN_GAP), PAD + row * (row_h + ROW_GAP)),
		Vector2(col_w, row_h)
	)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		UiPaint.rounded_rect_points_uniform(rect, 8.0, 6),
		rect,
		[[0.0, CardDeckShelf.BACK_TOP], [1.0, CardDeckShelf.BACK_BOTTOM]]
	)
	UiPaint.draw_inner_shadow(get_canvas_item(), rect, 8.0, 8, 7, Color(0, 0, 0), 0.7)
	for index in _entries.size():
		_draw_row(index)
	if _entries.is_empty():
		_draw_hint()
	if _glow_amount > 0.0:
		var glow := UiPalette.GLOW_AMBER
		glow.a = _glow_amount * CardDeckShelf.GLOW_ALPHA
		draw_rect(rect, glow, true)


func _draw_row(index: int) -> void:
	var row := _row_rect(index)
	var card: CardData = _entries[index]["card"]
	var count: int = _entries[index]["count"]
	var points := UiPaint.rounded_rect_points_uniform(row, 5.0, 4)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(), points, row, [[0.0, ROW_TOP], [1.0, ROW_BOTTOM]]
	)
	var closed := points.duplicate()
	closed.append(points[0])
	var hovered := index == _hover_index
	ShapePaint.polyline(
		get_canvas_item(), closed, ROW_HOVER if hovered else ROW_EDGE, 2.0 if hovered else 1.2
	)

	var h := row.size.y
	var r: float = h * BADGE_RATIO
	var font_size: int = roundi(minf(h * FONT_RATIO, FONT_MAX * text_scale))
	var baseline: float = row.get_center().y + font_size * 0.36
	var x := row.position.x + h * 0.12
	_draw_diamond(Vector2(x + r, row.get_center().y), card.cost, r)
	x += r * 2.0 + h * 0.14
	EmblemSeal.brass(self, Vector2(x + r, row.get_center().y), card.emblem, r * 0.9)
	x += r * 2.0 + h * 0.18

	var count_text := "×%d" % count
	var count_w: float = (
		_font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	)
	var right := row.end.x - h * 0.16
	draw_string(
		_font,
		Vector2(right - count_w, baseline),
		count_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		COUNT_COLOR if count > 1 else CardDeckShelf.NAME_COLOR
	)
	right -= count_w + h * 0.16
	_draw_total(Vector2(right - r, row.get_center().y), card, r)
	right -= r * 2.0 + h * 0.16

	# 名前が入らないときは文字を詰める(省略すると同じ頭の名前が見分けられない)。
	var name_room := right - x
	var name_size := font_size
	while (
		name_size > 8
		and (
			_font.get_string_size(card.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
			> name_room
		)
	):
		name_size -= 1
	draw_string(
		_font,
		Vector2(x, row.get_center().y + name_size * 0.36),
		card.display_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		name_size,
		CardDeckShelf.NAME_COLOR
	)


func _draw_diamond(center: Vector2, value: int, r: float) -> void:
	var points := PackedVector2Array(
		[
			center + Vector2(0, -r),
			center + Vector2(r, 0),
			center + Vector2(0, r),
			center + Vector2(-r, 0)
		]
	)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		points,
		Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0),
		[[0.0, CardDeckShelf.COST_TOP], [1.0, CardDeckShelf.COST_BOTTOM]]
	)
	var closed := points.duplicate()
	closed.append(points[0])
	ShapePaint.polyline(get_canvas_item(), closed, Color(0.03, 0.06, 0.14), 1.6)
	_draw_centered(center, str(value), int(r + 2), Color.WHITE)


## 総量。砂術は総量を持たないため「術」と出す(棚と同じ)。
func _draw_total(center: Vector2, card: CardData, r: float) -> void:
	var top: Color = CardDeckShelf.SPELL_TOP if card.is_spell else CardDeckShelf.TOTAL_TOP
	var bottom: Color = CardDeckShelf.SPELL_BOTTOM if card.is_spell else CardDeckShelf.TOTAL_BOTTOM
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		UiPaint.circle_points(center, r, 20),
		Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0),
		[[0.0, top], [1.0, bottom]]
	)
	UiPaint.draw_ring(get_canvas_item(), center, r, Color(0.10, 0.06, 0.03), 1.6, 20)
	_draw_centered(
		center, "術" if card.is_spell else str(card.total_sand), int(r + 1), Color(0.14, 0.08, 0.03)
	)


func _draw_centered(center: Vector2, text: String, font_size: int, color: Color) -> void:
	var width: float = font_size * 3.0
	draw_string(
		_font,
		Vector2(center.x - width * 0.5, center.y + font_size * 0.36),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		width,
		font_size,
		color
	)


## デッキが空のときだけ、中ほどへ木札を置く(棚と同じ形)。
func _draw_hint() -> void:
	var font_size: int = roundi(HINT_FONT * text_scale)
	var plate_w: float = minf(size.x - PAD * 4.0, font_size * 26.0)
	var plate_h: float = font_size * 2.8
	var plate := Rect2(size * 0.5 - Vector2(plate_w, plate_h) * 0.5, Vector2(plate_w, plate_h))
	var points := UiPaint.rounded_rect_points_uniform(plate, 8.0, 6)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		points,
		plate,
		[[0.0, Color(0.26, 0.175, 0.10)], [1.0, Color(0.13, 0.085, 0.05)]]
	)
	var closed := points.duplicate()
	closed.append(points[0])
	ShapePaint.polyline(get_canvas_item(), closed, Color(0.58, 0.46, 0.30), 1.8)
	draw_string(
		_font,
		Vector2(plate.position.x, plate.get_center().y + font_size * 0.36),
		EMPTY_HINT,
		HORIZONTAL_ALIGNMENT_CENTER,
		plate.size.x,
		font_size,
		Color(0.90, 0.82, 0.66)
	)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover((event as InputEventMouseMotion).position)
		return
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return
	# **行を押すとその1枚が在庫へ戻る**(棚の枠と同じ)。2枚の行は1枚ずつ減る。
	var index := _index_at(press.position)
	if index >= 0:
		card_removed.emit(_entries[index]["card"])


func _update_hover(at: Vector2) -> void:
	var index := _index_at(at)
	if index == _hover_index:
		return
	_hover_index = index
	if index < 0:
		hover_left.emit()
	else:
		card_hovered.emit(_entries[index]["card"])
	queue_redraw()


func _index_at(at: Vector2) -> int:
	for index in _entries.size():
		if _row_rect(index).has_point(at):
			return index
	return -1


## 在庫棚(`WorkshopStockItem`)からのドラッグを受ける(棚と同じ)。
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has("stock_card")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	card_add_requested.emit((data as Dictionary)["stock_card"])
