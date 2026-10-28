class_name CardDeckList
extends Control
## 編成中のデッキを**1種類1行のリスト**として描く(GameDesign.md 9章)。棚(`CardDeckShelf`)と
## 切り替えて使い、シグナルと `global_rect_for_card()` は棚と同じ形にそろえる。
##
## **同名2枚は「×2」の1行にまとめる。**棚は並べた形で見せ、リストは一目で読ませる役割のため。
## 1つの `Control` が全行を `_draw()` で描き、当たり判定を矩形の表として持つ(棚と同じ理由)。
## **1列で `ScrollContainer` の中に置く。**高さは種類数から自分で決める(`custom_minimum_size.y`)。

signal card_hovered(card: CardData)
signal hover_left
signal card_removed(card: CardData)
signal card_add_requested(card: CardData)

const PAD := 8.0
const ROW_GAP := 4.0
## 横の行の高さ。縦は `text_scale` を掛ける。
const ROW_HEIGHT := 44.0
## 行の高さに対する文字の割合。
const FONT_RATIO := 0.42
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
		_fit_height()
		queue_redraw()

var _font: Font
## 1要素 = {"card": CardData, "count": int}。並びは棚と同じコスト順。
var _entries: Array[Dictionary] = []
var _hover_index := -1
var _glow_amount := 0.0
var _glow_tween: Tween
var _was_full := false
## 押した行。**離したときに同じ行の上なら戻す**(指でのスクロールを押下にしないため)。
var _press := PressTracker.new()
var _pressed_index := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
		return
	if what == NOTIFICATION_SCROLL_BEGIN:
		_press.cancel()
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
	_fit_height()
	queue_redraw()


func _fit_height() -> void:
	var rows := _entries.size()
	custom_minimum_size.y = PAD * 2.0 + rows * _row_height() + maxf(rows - 1, 0) * ROW_GAP


func _row_height() -> float:
	return ROW_HEIGHT * text_scale


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
## 見えていない行はスクロールして見せてから返す(飛んだ先が枠の外にならないように)。
func global_rect_for_card(card: CardData) -> Rect2:
	for index in _entries.size():
		if _entries[index]["card"] == card:
			var row := _row_rect(index)
			var square := Rect2(row.position, Vector2(row.size.y, row.size.y))
			return Rect2(_global_origin_after_reveal(row) + square.position, square.size)
	return Rect2()


## スクロール位置を変えても子の位置が動くのは次の並べ直しのため、原点は親から計算する。
func _global_origin_after_reveal(row: Rect2) -> Vector2:
	var scroll := get_parent() as ScrollContainer
	if scroll == null:
		return get_global_rect().position
	var view_h: float = scroll.size.y
	var top := float(scroll.scroll_vertical)
	if row.position.y < top:
		scroll.scroll_vertical = int(row.position.y - PAD)
	elif row.end.y > top + view_h:
		scroll.scroll_vertical = int(ceilf(row.end.y + PAD - view_h))
	return scroll.get_global_rect().position - Vector2(0.0, scroll.scroll_vertical)


func _row_rect(index: int) -> Rect2:
	var h := _row_height()
	return Rect2(Vector2(PAD, PAD + index * (h + ROW_GAP)), Vector2(size.x - PAD * 2.0, h))


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
	var font_size: int = roundi(h * FONT_RATIO)
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
	var health_at := Vector2(right - r, row.get_center().y)
	if not card.is_spell:
		right -= r * 2.0 + h * 0.08
	CardStatBadge.pair(self, _font, Vector2(right - r, row.get_center().y), health_at, card, r)
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
	# 空のときは見えている範囲の中ほど(自分の高さは余白だけになっている)。
	var view := size
	var scroll := get_parent() as ScrollContainer
	if scroll != null:
		view = scroll.size
	var plate := Rect2(view * 0.5 - Vector2(plate_w, plate_h) * 0.5, Vector2(plate_w, plate_h))
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
	# **行を押して離すとその1枚が在庫へ戻る**(棚の枠と同じ)。2枚の行は1枚ずつ減る。
	match _press.feed(event, size):
		PressTracker.Result.PRESSED:
			_pressed_index = _index_at(_event_position(event))
		PressTracker.Result.CONFIRMED:
			var index := _index_at(_event_position(event))
			if index >= 0 and index == _pressed_index:
				card_removed.emit(_entries[index]["card"])
			_pressed_index = -1
		PressTracker.Result.CANCELED:
			_pressed_index = -1


func _event_position(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return (event as InputEventMouse).position
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	return Vector2(-1.0, -1.0)


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
