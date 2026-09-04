class_name WorkshopStockItem
extends Control
## 時計工房の在庫棚の1件(GameDesign.md 9章)。棚に立てた砂時計として描く。
##
## **`CardView` は使わない。**あちらは手札と場のための暗いカードで、
## 木の棚へ並べるとそこだけ別のUIから来たように浮く(図鑑の `AlmanacEntry` と同じ理由)。

signal pressed(card: CardData)

const CELL_SIZE := Vector2(122, 168)
## 名前と棚板に使う下側の取り分。
const NAME_BAND := 44.0
const NAME_COLOR := Color(0.88, 0.82, 0.70)
const NAME_DIM := Color(0.62, 0.58, 0.52)
const COST_TOP := Color(0.46, 0.70, 0.98)
const COST_BOTTOM := Color(0.11, 0.24, 0.52)
const TOTAL_TOP := Color(1.0, 0.84, 0.46)
const TOTAL_BOTTOM := Color(0.72, 0.44, 0.12)
const SPELL_TOP := Color(0.72, 0.80, 1.0)
const SPELL_BOTTOM := Color(0.28, 0.36, 0.68)

var card: CardData
## デッキへ入れている枚数。上限に達していたら暗くして「2/2」を出す。
var count := 0
var limit := 2
## 一覧から足せるか。**枚数とは別に持つ**——デッキが30枚に達したときは、
## まだ2枚未満のものも足せない(枚数の表示は実数のままにする)。
var enabled := true

var _font: Font
var _press := PressTracker.new()


func _ready() -> void:
	custom_minimum_size = CELL_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font


func show_card(new_card: CardData, new_count: int, new_limit: int, can_add := true) -> void:
	card = new_card
	count = new_count
	limit = new_limit
	enabled = can_add
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _press.feed(event, size) == PressTracker.Result.CONFIRMED:
		pressed.emit(card)


func _draw() -> void:
	if card == null:
		return
	var maxed: bool = count >= limit
	var tint := Color.WHITE if enabled else Color(0.45, 0.42, 0.40)
	var art := _art_rect()
	# 棚板へ落ちる影。駒が板の上に立って見えるようにする。
	UiPaint.fill_ellipse(
		get_canvas_item(),
		Vector2(size.x * 0.5, art.end.y + 2.0),
		Vector2(art.size.x * 0.42, 6.0),
		Color(0, 0, 0, 0.45),
		24
	)
	if card.is_spell:
		_draw_spell_plate(art, tint)
	else:
		var icon := card.icon_upright
		if icon != null:
			draw_texture_rect(icon, art, false, tint)
		# **紋章は絵の左下へ印として押す**(GameDesign.md 9章)。色相だけでは
		# 見分けられないため、カードを並べる画面には必ず添える。
		EmblemSeal.brass(self, Vector2(art.position.x + 12.0, art.end.y - 12.0), card.emblem, 14.0)
	draw_string(
		_font,
		Vector2(0, size.y - 8.0),
		card.display_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		14,
		NAME_COLOR if enabled else NAME_DIM
	)
	_draw_diamond(Vector2(16, 18), card.cost, 14.0)
	_draw_total(Vector2(size.x - 16, 18), 13.0)
	if maxed:
		_draw_maxed()


## 2枚入れ終えた印。**上端の中央へ置く**——コストとの総量のあいだが唯一空いている
## 場所で、絵の下端は紋章の印と名前が使っている(以前ここへ出して重なった)。
func _draw_maxed() -> void:
	var rect := Rect2(size.x * 0.5 - 25.0, 5.0, 50.0, 24.0)
	var points := UiPaint.rounded_rect_points_uniform(rect, 6.0, 5)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		points,
		rect,
		[[0.0, Color(0.30, 0.22, 0.15)], [1.0, Color(0.13, 0.09, 0.06)]]
	)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, Color(0.72, 0.58, 0.36), 1.6)
	draw_string(
		_font,
		Vector2(rect.position.x, rect.get_center().y + 6.0),
		"%d / %d" % [count, limit],
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		15,
		Color(1.0, 0.86, 0.5)
	)


## 絵を置く矩形。棚板の上へ立てるため、下端を名前の帯の手前で止める。
func _art_rect() -> Rect2:
	var h: float = size.y - NAME_BAND
	var w: float = h / 1.30
	return Rect2(Vector2((size.x - w) * 0.5, 4.0), Vector2(w, h))


## 砂術の札。**砂時計の絵を持たない**ため、紋章を中央へ大きく置く(GameDesign.md 9章)。
func _draw_spell_plate(p_rect: Rect2, tint: Color) -> void:
	var rect := Rect2(p_rect.position + p_rect.size * 0.07, p_rect.size * 0.86)
	var points := UiPaint.rounded_rect_points_uniform(rect, 5.0, 6)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		points,
		rect,
		[[0.0, Color(0.20, 0.26, 0.40)], [1.0, Color(0.08, 0.11, 0.20)]]
	)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, CardView.SPELL_BORDER, 2.2)
	if card.emblem != null:
		var side: float = rect.size.x * 0.62
		draw_texture_rect(
			card.emblem,
			Rect2(rect.get_center() - Vector2(side, side) * 0.5, Vector2(side, side)),
			false,
			Color(0.82, 0.90, 1.0) * tint
		)


func _draw_diamond(center: Vector2, value: int, r: float) -> void:
	var points := PackedVector2Array(
		[
			center + Vector2(0, -r),
			center + Vector2(r, 0),
			center + Vector2(0, r),
			center + Vector2(-r, 0),
		]
	)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		points,
		Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0),
		[[0.0, COST_TOP], [1.0, COST_BOTTOM]]
	)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, Color(0.03, 0.06, 0.14), 2.0)
	draw_string(
		_font,
		center - Vector2(20, -6),
		str(value),
		HORIZONTAL_ALIGNMENT_CENTER,
		40,
		int(r + 3),
		Color.WHITE
	)


## 総量。**砂術は総量を持たないため「術」と出す**(空欄にすると総量0と見分けが付かない)。
func _draw_total(center: Vector2, r: float) -> void:
	var top: Color = SPELL_TOP if card.is_spell else TOTAL_TOP
	var bottom: Color = SPELL_BOTTOM if card.is_spell else TOTAL_BOTTOM
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		UiPaint.circle_points(center, r, 20),
		Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0),
		[[0.0, top], [1.0, bottom]]
	)
	UiPaint.draw_ring(get_canvas_item(), center, r, Color(0.10, 0.06, 0.03), 1.8, 20)
	draw_string(
		_font,
		center - Vector2(20, -5),
		"術" if card.is_spell else str(card.total_sand),
		HORIZONTAL_ALIGNMENT_CENTER,
		40,
		int(r + 2),
		Color(0.14, 0.08, 0.03)
	)
