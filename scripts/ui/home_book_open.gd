class_name HomeBookOpen
extends Control
## ホームから砂時計図鑑へ移る前の演出(GameDesign.md 9章)。下段の札の本が画面の中央へ寄り、
## 表紙が開いて紙が数枚めくれる。図鑑が見開きの本であることへつなげるため。押せば最後まで飛ばす。
## ホームの最前面に置き、流している間は下の札を押させない。

signal finished

const DURATION := 0.85
## 各段の始まり(全体に対する比)。寄る → 表紙 → 紙。
const GATHER_END := 0.3
const COVER_END := 0.55
const PAGE_COUNT := 3
## 紙1枚がめくれきるまでの長さと、次の紙までのずれ(全体に対する比)。
const PAGE_SPAN := 0.22
const PAGE_STAGGER := 0.08

## 開いた本の背丈(画面の高さに対する比)と、1ページの縦横比(幅 / 高さ)。
const BOOK_HEIGHT := 0.56
const PAGE_ASPECT := 0.74
## めくれている面の自由端を上下へ広げる量(背丈に対する比)。手前へ起き上がって見せるため。
const LIFT := 0.06
const PAGE_INSET := 6.0
const SCRIM := Color(0.02, 0.02, 0.04, 0.6)
const LEATHER_INSIDE := [[0.0, Color(0.30, 0.17, 0.10)], [1.0, Color(0.18, 0.09, 0.05)]]
const PAGE_SHADE := Color(0.35, 0.27, 0.16)
const EDGE := Color(0.07, 0.05, 0.03, 0.6)
const EMBLEM_RATIO := 0.3

var _from := Rect2()
var _t := 0.0
var _tween: Tween


static func make() -> HomeBookOpen:
	var fx := HomeBookOpen.new()
	fx.anchor_right = 1.0
	fx.anchor_bottom = 1.0
	fx.mouse_filter = Control.MOUSE_FILTER_STOP
	fx.visible = false
	return fx


## `from` は札の本の絵の矩形(画面座標)。終わると `finished` を出し、絵は最後の姿のまま残る
## (画面の切り替えのクロスフェードで一緒に消えるため)。消すのは `HomeScreen` が隠れたとき。
func play(from: Rect2) -> void:
	_from = Rect2(from.position - global_position, from.size)
	_t = 0.0
	visible = true
	_tween = create_tween()
	_tween.tween_method(_set_t, 0.0, 1.0, DURATION)
	_tween.finished.connect(func() -> void: finished.emit())


func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed:
		return
	accept_event()
	if _tween != null and _tween.is_valid():
		_tween.custom_step(DURATION)


func _set_t(value: float) -> void:
	_t = value
	queue_redraw()


func _draw() -> void:
	var gather := _ease(clampf(_t / GATHER_END, 0.0, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(SCRIM, SCRIM.a * gather))
	var h := size.y * BOOK_HEIGHT
	var page := Vector2(h * PAGE_ASPECT, h)
	var spine_final := size * 0.5 - Vector2(0.0, h * 0.5)
	# 閉じた本(表紙)は右ページの位置にある。札の絵の矩形からそこへ寄せる。
	var closed_final := Rect2(spine_final, page)
	var closed := Rect2(
		_from.position.lerp(closed_final.position, gather), _from.size.lerp(page, gather)
	)
	var scale := closed.size.y / h
	var spine := closed.position
	var cover_t := _ease(clampf((_t - GATHER_END) / (COVER_END - GATHER_END), 0.0, 1.0))
	if cover_t <= 0.0:
		_draw_cover_face(_face(spine, page * scale, 0.0), true)
		return
	_draw_leaf(Rect2(spine, page), LEATHER_INSIDE)
	_draw_leaf(_inset(Rect2(spine, page)), HomeProps.PAGE)
	var flipped := 0
	for k in PAGE_COUNT:
		var start := COVER_END + PAGE_STAGGER * float(k)
		var turn := _ease(clampf((_t - start) / PAGE_SPAN, 0.0, 1.0))
		if turn >= 1.0:
			flipped += 1
	# 左側: 開いた表紙の裏と、めくり終えた紙。
	if cover_t >= 1.0:
		_draw_leaf(Rect2(spine - Vector2(page.x, 0.0), page), LEATHER_INSIDE)
		if flipped > 0:
			_draw_leaf(_inset(Rect2(spine - Vector2(page.x, 0.0), page)), HomeProps.PAGE)
	for k in PAGE_COUNT:
		var start := COVER_END + PAGE_STAGGER * float(k)
		var turn := _ease(clampf((_t - start) / PAGE_SPAN, 0.0, 1.0))
		if turn > 0.0 and turn < 1.0:
			_draw_turning_page(spine, page, turn)
	if cover_t < 1.0:
		var face := _face(spine, page, cover_t)
		_draw_cover_face(face, cover_t < 0.5)
	ShapePaint.colored_polygon(
		get_canvas_item(),
		PackedVector2Array(
			[
				spine - Vector2(1.5, 0.0),
				spine + Vector2(1.5, 0.0),
				spine + Vector2(1.5, page.y),
				spine - Vector2(1.5, page.y)
			]
		),
		EDGE
	)


## 背を軸に `turn`(0〜1)だけ回った面の4隅。0 で右に伏せ、1 で左に伏せる。
func _face(spine: Vector2, page: Vector2, turn: float) -> PackedVector2Array:
	var angle := PI * turn
	var reach := cos(angle) * page.x
	var lift := sin(angle) * page.y * LIFT
	return PackedVector2Array(
		[
			spine,
			spine + Vector2(reach, -lift),
			spine + Vector2(reach, page.y + lift),
			spine + Vector2(0.0, page.y)
		]
	)


func _draw_turning_page(spine: Vector2, page: Vector2, turn: float) -> void:
	var face := _face(spine, page, turn)
	var shade := absf(cos(PI * turn))
	var stops := [
		[0.0, HomeProps.PAGE[0][1].lerp(PAGE_SHADE, 1.0 - shade)],
		[1.0, HomeProps.PAGE[1][1].lerp(PAGE_SHADE, 1.0 - shade)],
	]
	UiPaint.fill_gradient_polygon(get_canvas_item(), face, _bounds(face), stops)
	ShapePaint.polyline(get_canvas_item(), RankMedal.closed(face), EDGE, 1.0, true)


## 表紙(`outside` なら表、そうでなければ裏)。
func _draw_cover_face(face: PackedVector2Array, outside: bool) -> void:
	var stops: Array = HomeProps.LEATHER if outside else LEATHER_INSIDE
	UiPaint.fill_gradient_polygon(get_canvas_item(), face, _bounds(face), stops)
	ShapePaint.polyline(get_canvas_item(), RankMedal.closed(face), EDGE, 1.5, true)
	if not outside:
		return
	var center := (face[0] + face[1] + face[2] + face[3]) * 0.25
	var side := absf(face[1].x - face[0].x)
	if side < 1.0:
		return
	var radius := minf(side, face[3].y - face[0].y) * EMBLEM_RATIO * 0.5
	ShapePaint.circle(get_canvas_item(), center, radius, HomeProps.BRASS[1][1])
	UiPaint.draw_emblem(get_canvas_item(), UiPaint.Emblem.HOURGLASS, center, radius * 1.3)


func _draw_leaf(rect: Rect2, stops: Array) -> void:
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		PackedVector2Array(
			[
				rect.position,
				Vector2(rect.end.x, rect.position.y),
				rect.end,
				Vector2(rect.position.x, rect.end.y)
			]
		),
		rect,
		stops
	)


func _inset(rect: Rect2) -> Rect2:
	return rect.grow(-PAGE_INSET)


static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


static func _bounds(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r
