class_name AlmanacEntry
extends Control
## 砂時計図鑑の一覧の1件(GameDesign.md 9章)。紙の上に刷った標本の欄として描く。
##
## **`CardView` は使わない。**あちらは手札と場のための暗いカードで、紙のページへ置くと
## そこだけ別のUIから来たように浮く。ここで要るのは番号・絵・コスト・総量・名前だけ。

signal pressed(card: CardData)

const CELL_SIZE := Vector2(168, 122)
## 絵と名前を重ねないため、標本の欄は上・名札は下と決めて高さを配る。
## **絵は矩形いっぱいに描かれる**(周りの余白は絵の中に含まれない)ため、
## 名札のぶんはここで確実に空ける。34pxでは名前が砂時計の台へ乗っていた。
const NAME_BAND := 42.0
## 標本の欄の上端。丁付け(No.)の下から始める。
const ART_TOP := 15.0
const INK := Color(0.20, 0.135, 0.075)
const INK_SOFT := Color(0.40, 0.30, 0.19)
const LOCKED_INK := Color(0.46, 0.37, 0.25)
const STAMP_RED := Color(0.63, 0.13, 0.11)
const COST_TOP := Color(0.46, 0.70, 0.98)
const COST_BOTTOM := Color(0.11, 0.24, 0.52)
const TOTAL_TOP := Color(1.0, 0.84, 0.46)
const TOTAL_BOTTOM := Color(0.72, 0.44, 0.12)
const SPELL_TOP := Color(0.72, 0.80, 1.0)
const SPELL_BOTTOM := Color(0.28, 0.36, 0.68)

var card: CardData
var number := 0
var selected := false
## 未収集(GameDesign.md 9章)。**保有の仕組みが入るまでは常に false** で、
## 全件を収集済みとして扱う。枠組みだけ先に作っておく。
var locked := false

var _font: Font
var _press := PressTracker.new()


func _ready() -> void:
	custom_minimum_size = CELL_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font


func show_card(new_card: CardData, new_number: int) -> void:
	card = new_card
	number = new_number
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _press.feed(event, size) == PressTracker.Result.CONFIRMED:
		pressed.emit(card)


func _draw() -> void:
	if card == null:
		return
	if selected:
		_draw_selection()
	draw_string(
		_font, Vector2(6, 16), "No.%03d" % number, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK_SOFT
	)
	var art := _art_rect()
	if locked:
		_draw_locked(art)
	elif card.is_spell:
		_draw_spell_plate(art)
	else:
		var icon := card.icon_upright
		if icon != null:
			draw_texture_rect(icon, art, false)
		# **紋章は絵の左下へ印として押す**(GameDesign.md 9章)。全種が同じ絵の色違いで
		# ある以上、一覧で見分けているのは実際にはこの紋章のほう。
		# ここではコスト・総量と同じく**絵の外の隅**へ置く(絵の中へ入れると台に重なる)。
		EmblemSeal.brass(self, Vector2(art.position.x - 2.0, art.end.y - 10.0), card.emblem, 12.0)
	draw_string(
		_font,
		Vector2(0, size.y - 6),
		"— 未 発 見 —" if locked else card.display_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		15,
		LOCKED_INK if locked else INK
	)
	if locked:
		return
	# **コストと総量は一覧の時点で読めるようにする**(現行の一覧と同じ情報量を保つ)。
	# **採取済みの印は置かない**——未収集をシルエットで示す以上、
	# 収集済みの側にも印を打つと同じことを2度言うことになる(GameDesign.md 9章)。
	_draw_diamond(Vector2(art.position.x - 2, art.position.y + 10), card.cost, 12.0)
	_draw_total(Vector2(art.end.x + 2, art.end.y - 10), 11.0)


## 絵を置く矩形。標本の欄(上)と名札(下)を分けて、重ならないようにする。
func _art_rect() -> Rect2:
	var h: float = size.y - NAME_BAND - ART_TOP
	var w: float = h / 1.30
	return Rect2(Vector2((size.x - w) * 0.5, ART_TOP), Vector2(w, h))


## いま開いている項目。紙へ引いた朱の下線と薄い当たりで示す。
func _draw_selection() -> void:
	var rect := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		UiPaint.rounded_rect_points_uniform(rect, 6.0, 5),
		rect,
		[[0.0, Color(STAMP_RED, 0.10)], [1.0, Color(STAMP_RED, 0.03)]]
	)
	draw_line(
		Vector2(rect.position.x + 8, rect.end.y),
		Vector2(rect.end.x - 8, rect.end.y),
		Color(STAMP_RED, 0.75),
		2.0
	)


## 未収集。**輪郭だけを見せ、砂時計と砂術で形を分ける**(何が埋まるのか想像できるように)。
func _draw_locked(art: Rect2) -> void:
	if card.is_spell:
		var plate := UiPaint.rounded_rect_points_uniform(art.grow(-3), 5.0, 6)
		UiPaint.fill_gradient_polygon(
			get_canvas_item(),
			plate,
			art,
			[[0.0, Color(0.42, 0.36, 0.26, 0.45)], [1.0, Color(0.30, 0.26, 0.19, 0.45)]]
		)
		var closed := plate.duplicate()
		closed.append(plate[0])
		draw_polyline(closed, Color(0.36, 0.29, 0.19, 0.6), 2.0)
	else:
		var icon := card.icon_upright
		if icon != null:
			draw_texture_rect(icon, art, false, Color(0.42, 0.34, 0.24, 0.40))
	draw_string(
		_font,
		Vector2(art.position.x, art.get_center().y + 14),
		"?",
		HORIZONTAL_ALIGNMENT_CENTER,
		art.size.x,
		36,
		Color(0.34, 0.26, 0.16, 0.95)
	)


## 砂術の札。紙の上でも「置くカードではない」と分かるよう、藍の枠に紋章を置く。
func _draw_spell_plate(art: Rect2) -> void:
	var points := UiPaint.rounded_rect_points_uniform(art.grow(-3), 5.0, 6)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		points,
		art,
		[[0.0, Color(0.34, 0.40, 0.56)], [1.0, Color(0.18, 0.22, 0.36)]]
	)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, Color(0.20, 0.26, 0.42), 2.0)
	if card.emblem != null:
		var side: float = art.size.x * 0.66
		draw_texture_rect(
			card.emblem,
			Rect2(art.get_center() - Vector2(side, side) * 0.5, Vector2(side, side)),
			false,
			Color(0.92, 0.95, 1.0)
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
		center - Vector2(20, -5),
		str(value),
		HORIZONTAL_ALIGNMENT_CENTER,
		40,
		int(r + 2),
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
	UiPaint.draw_ring(get_canvas_item(), center, r, Color(0.10, 0.06, 0.03), 1.6, 20)
	draw_string(
		_font,
		center - Vector2(20, -5),
		"術" if card.is_spell else str(card.total_sand),
		HORIZONTAL_ALIGNMENT_CENTER,
		40,
		int(r + 1),
		Color(0.14, 0.08, 0.03)
	)
