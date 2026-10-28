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
## 並び替え後のスライド(GameDesign.md 9章)にかける尺。
const SLIDE_DURATION := 0.16

## 並び替えのたびに一覧側(`CardListScreen`)が全件を作り直すため、インスタンス
## 自身は前の並びの位置を持てない。**カードidをキーに、直前に確定した位置を
## 並び替えをまたいで持ち越す**(`CardMatchHandLayout`と同じ「代入せずTweenで
## 滑らせる」考え方を、作り直されるノードでも成立させるための器)。
static var _last_position_by_id: Dictionary = {}

var card: CardData
var number := 0
var selected := false
## 未収集(GameDesign.md 9章)。カードセット(8章)に属し、まだ所有していないカードで
## true になる。基本セット70枚は`CardData.set_id`が空のため常にfalse。
var locked := false
## 描く倍率。縦画面で名前と数字を文字の目安まで大きくする(GameDesign.md 9章「縦画面」)。
## 中身は `CELL_SIZE` の座標のまま描き、まとめて拡大する(`WorkshopStockItem` と同じ)。
var zoom := 1.0:
	set(value):
		zoom = value
		custom_minimum_size = CELL_SIZE * zoom
		queue_redraw()

var _font: Font
var _press := PressTracker.new()
var _slide_tween: Tween


func _ready() -> void:
	custom_minimum_size = CELL_SIZE * zoom
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font


func show_card(new_card: CardData, new_number: int) -> void:
	card = new_card
	number = new_number
	queue_redraw()
	# グリッドはこのフレームの終わりに子を並べ直すため、目標の位置は
	# 並び終わってから読む(先に読むと(0,0)のままを掴む。`list_reveal_fx.gd`と同じ手順)。
	call_deferred("_settle_position")


## 並び替え前にこのカードがいた位置が分かれば、そこから今の位置へ短く滑らせる。
## 初めて置かれるとき(記録が無い)は代入するだけで、動かして見せない。
func _settle_position() -> void:
	if card == null:
		return
	var target := position
	var prev: Variant = _last_position_by_id.get(card.id)
	if prev is Vector2 and prev != target:
		if _slide_tween != null and _slide_tween.is_valid():
			_slide_tween.kill()
		position = prev
		_slide_tween = create_tween()
		_slide_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_slide_tween.tween_property(self, "position", target, SLIDE_DURATION)
	_last_position_by_id[card.id] = target


func _gui_input(event: InputEvent) -> void:
	# 未収集のカードは詳細を開かせない。「シルエットと『?』で示す」(GameDesign.md 9章)
	# 以上、押して中身を読めてしまうと未収集の意味が無くなる。
	if locked:
		return
	if _press.feed(event, size) == PressTracker.Result.CONFIRMED:
		pressed.emit(card)


func _draw() -> void:
	if card == null:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * zoom)
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
		# **紋章は絵の右上へ印として押す**(GameDesign.md 9章)。全種が同じ絵の色違いで
		# ある以上、一覧で見分けているのは実際にはこの紋章のほう。
		# ここではコストと同じく**絵の外の隅**へ置く(絵の中へ入れると台に重なる)。
		EmblemSeal.brass(self, Vector2(art.end.x + 2.0, art.position.y + 10.0), card.emblem, 12.0)
	draw_string(
		_font,
		Vector2(0, _base_size().y - 6),
		"— 未 発 見 —" if locked else card.display_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		_base_size().x,
		15,
		LOCKED_INK if locked else INK
	)
	if locked:
		return
	# **コスト・攻撃力・体力は一覧の時点で読めるようにする**(現行の一覧と同じ情報量を保つ)。
	# **採取済みの印は置かない**——未収集をシルエットで示す以上、
	# 収集済みの側にも印を打つと同じことを2度言うことになる(GameDesign.md 9章)。
	_draw_diamond(Vector2(art.position.x - 2, art.position.y + 10), card.cost, 12.0)
	var bottom := art.end.y - 10.0
	CardStatBadge.pair(
		self, _font, Vector2(art.position.x - 2, bottom), Vector2(art.end.x + 2, bottom), card, 11.0
	)


## 絵を置く矩形。標本の欄(上)と名札(下)を分けて、重ならないようにする。
func _art_rect() -> Rect2:
	var base := _base_size()
	var h: float = base.y - NAME_BAND - ART_TOP
	var w: float = h / 1.30
	return Rect2(Vector2((base.x - w) * 0.5, ART_TOP), Vector2(w, h))


## 拡大する前の大きさ(描く座標の範囲)。
func _base_size() -> Vector2:
	return size / zoom


## いま開いている項目。紙へ引いた朱の下線と薄い当たりで示す。
func _draw_selection() -> void:
	var rect := Rect2(Vector2(2, 2), _base_size() - Vector2(4, 4))
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
		ShapePaint.polyline(get_canvas_item(), closed, Color(0.36, 0.29, 0.19, 0.6), 2.0)
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
	ShapePaint.polyline(get_canvas_item(), closed, Color(0.20, 0.26, 0.42), 2.0)
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
	ShapePaint.polyline(get_canvas_item(), closed, Color(0.03, 0.06, 0.14), 2.0)
	draw_string(
		_font,
		center - Vector2(20, -5),
		str(value),
		HORIZONTAL_ALIGNMENT_CENTER,
		40,
		int(r + 2),
		Color.WHITE
	)
