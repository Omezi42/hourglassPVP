class_name HomeHourglassStand
extends Control
## ホーム中央の台座に載った砂時計(GameDesign.md 9章)。首から下の部屋へ砂が細く落ち続け、押すと上下に半回転する。
## 触って遊ぶためのもので、押しても何も起きない(対局の入口は下の「対戦する」ボタン)。
## 砂の流れは見た目だけで、上の部屋の砂は減らない。

const ART := preload("res://assets/hourglasses/master/state_falling.png")
## 絵の中の首と、下の部屋の砂山の頂(絵の高さに対する比)。流れの粒はこの間を落ちる。
const NECK_Y := 0.49
const PILE_Y := 0.69
const STREAM_X := 0.5
## 台座の背丈(この部品の高さに対する比)。上から 真鍮の天板 / 木の胴 / 木の土台 の3段で、
## 段ごとの背丈は台座に対する比、幅は砂時計の絵の幅に対する比。天板は上面を楕円で見せて奥行きを出す。
const PEDESTAL_RATIO := 0.25
## 絵の中の砂時計の足元(絵の高さに対する比)。天板の上面の中心をここへ合わせて載せる。
const FEET_Y := 0.962
## 天板の前面の厚み(台座の背丈に対する比)。残りを胴と土台で分ける。
const CAP_SHARE := 0.22
const BODY_SHARE := 0.55
const CAP_WIDTH := 1.3
const BODY_WIDTH := 1.0
const BASE_WIDTH := 1.22
const CAP_TOP_SQUASH := 0.1
const BAND_HEIGHT := 0.14
const ELLIPSE_SEGMENTS := 40
const CAP_TOP := [[0.0, Color(0.92, 0.76, 0.42)], [1.0, Color(0.66, 0.46, 0.18)]]
const BASE_WOOD := [[0.0, Color(0.48, 0.28, 0.13)], [1.0, Color(0.22, 0.11, 0.05)]]
const EDGE_LIGHT := Color(1.0, 0.92, 0.70, 0.55)
const CONTACT_SHADOW := Color(0.0, 0.0, 0.0, 0.32)
const FLOOR_SHADOW := Color(0.0, 0.0, 0.0, 0.4)
const FLOOR_SHADOW_WIDTH := 1.7
const CONTACT_WIDTH := 0.86
## 後ろの光。輪を細かく重ねて段を目立たせない。
const GLOW_RATIO := 0.62
const GLOW_RINGS := 14
const GLOW := Color(1.0, 0.84, 0.48, 0.03)
## 首から砂山まで細く見える砂の糸(粒の後ろ)。
const THREAD_WIDTH := 1.6
const THREAD_COLOR := Color(1.0, 0.80, 0.45, 0.35)

const GRAIN_COUNT := 7
## 粒が首から砂山まで落ちきる秒数。
const FALL_SECONDS := 0.55
const GRAIN_SIZE := 2.4
const GRAIN_COLOR := Color(1.0, 0.82, 0.48, 0.95)
## 粒の横の揺れ(絵の幅に対する比)。
const GRAIN_JITTER := 0.012

const FLIP_SECONDS := 0.55
const FLIP_HOP := 14.0

var _clock := 0.0
## 半回転の進み(0〜1)。回っている間は流れを止める。
var _flip := 0.0
var _flip_tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock = fmod(_clock + delta, FALL_SECONDS * float(GRAIN_COUNT))
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	_turn_over()


func _turn_over() -> void:
	if _flip_tween != null and _flip_tween.is_valid():
		return
	SoundBank.play(SoundBank.Sfx.FLIP)
	_flip_tween = create_tween()
	(
		_flip_tween
		. tween_method(_set_flip, 0.0, 1.0, FLIP_SECONDS)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_IN_OUT)
	)
	_flip_tween.finished.connect(
		func() -> void:
			_flip = 0.0
			queue_redraw()
	)


func _set_flip(value: float) -> void:
	_flip = value
	queue_redraw()


func _draw() -> void:
	var pedestal_h := size.y * PEDESTAL_RATIO
	var art_h := size.y - pedestal_h
	var art_w := art_h * float(ART.get_width()) / float(ART.get_height())
	var art := Rect2(Vector2((size.x - art_w) * 0.5, 0.0), Vector2(art_w, art_h))
	_draw_glow(art.get_center(), art_h * GLOW_RATIO)
	var feet := art_h * FEET_Y
	_draw_pedestal(Rect2(0.0, feet, size.x, size.y - feet), art_w)
	var center := art.get_center()
	var turning := _flip > 0.0
	# 枠は上下対称のため、回りきったら元の向きの絵へ戻す(砂が下へ落ちた後の姿になる)。
	var angle := PI * _flip
	var hop := sin(PI * _flip) * FLIP_HOP
	draw_set_transform(center + Vector2(0.0, -hop), angle, Vector2.ONE)
	draw_texture_rect(ART, Rect2(-art.size * 0.5, art.size), false)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if not turning:
		_draw_stream(art)


## 首から砂山へ落ちる粒。
func _draw_stream(art: Rect2) -> void:
	var neck := art.position.y + art.size.y * NECK_Y
	var pile := art.position.y + art.size.y * PILE_Y
	var x := art.position.x + art.size.x * STREAM_X
	draw_line(Vector2(x, neck), Vector2(x, pile), THREAD_COLOR, THREAD_WIDTH, true)
	for k in GRAIN_COUNT:
		var t := fmod(_clock / FALL_SECONDS + float(k) / float(GRAIN_COUNT), 1.0)
		var y := lerpf(neck, pile, t * t)
		var wobble := sin((_clock + float(k)) * 23.0) * art.size.x * GRAIN_JITTER * t
		draw_rect(
			Rect2(
				Vector2(x + wobble, y) - Vector2.ONE * GRAIN_SIZE * 0.5, Vector2.ONE * GRAIN_SIZE
			),
			Color(GRAIN_COLOR, GRAIN_COLOR.a * (1.0 - t * 0.4))
		)


func _draw_glow(center: Vector2, radius: float) -> void:
	for k in GLOW_RINGS:
		var shrink := 1.0 - float(k) / float(GLOW_RINGS + 1)
		ShapePaint.circle(get_canvas_item(), center, radius * shrink, GLOW)


## `rect` の上端が天板の上面の中心(砂時計の足元)。床の影 → 土台 → 胴(真鍮の帯) → 天板の前面 → 天板の上面 → 砂時計の足元の影 の順に重ねる。
func _draw_pedestal(rect: Rect2, art_w: float) -> void:
	var ci := get_canvas_item()
	var cx := rect.get_center().x
	var h := rect.size.y
	var top_ry := art_w * CAP_WIDTH * 0.5 * CAP_TOP_SQUASH
	var cap_h := h * CAP_SHARE + top_ry * 2.0
	var cap_top := rect.position.y - top_ry
	var cap := Rect2(cx - art_w * CAP_WIDTH * 0.5, cap_top, art_w * CAP_WIDTH, cap_h)
	var below := rect.end.y - (cap.end.y - top_ry)
	var body := Rect2(
		cx - art_w * BODY_WIDTH * 0.5, cap.end.y - top_ry, art_w * BODY_WIDTH, below * BODY_SHARE
	)
	var base := Rect2(
		cx - art_w * BASE_WIDTH * 0.5, body.end.y, art_w * BASE_WIDTH, rect.end.y - body.end.y
	)
	var floor_r := Vector2(art_w * FLOOR_SHADOW_WIDTH * 0.5, top_ry * 1.2)
	ShapePaint.colored_polygon(ci, _ellipse(Vector2(cx, base.end.y), floor_r), FLOOR_SHADOW)
	_slab(ci, base, BASE_WOOD)
	_slab(ci, body, HomeProps.WOOD)
	var band := Rect2(
		body.position.x,
		body.get_center().y - body.size.y * BAND_HEIGHT * 0.5,
		body.size.x,
		body.size.y * BAND_HEIGHT
	)
	UiPaint.fill_gradient_polygon(ci, _box(band), band, HomeProps.BRASS_DARK)
	draw_line(base.position, Vector2(base.end.x, base.position.y), EDGE_LIGHT, 1.0)
	# 天板の前面(下半分の楕円と側面)と上面。
	var top_c := Vector2(cx, cap.position.y + top_ry)
	var front := PackedVector2Array()
	var half := cap.size.x * 0.5
	front.append(Vector2(cap.position.x, top_c.y))
	for k in ELLIPSE_SEGMENTS / 2 + 1:
		var t := PI * float(k) / float(ELLIPSE_SEGMENTS / 2)
		front.append(Vector2(cx - cos(t) * half, cap.end.y - top_ry + sin(t) * top_ry))
	front.append(Vector2(cap.end.x, top_c.y))
	UiPaint.fill_gradient_polygon(ci, front, cap, HomeProps.BRASS)
	var top := _ellipse(top_c, Vector2(half, top_ry))
	UiPaint.fill_gradient_polygon(
		ci, top, Rect2(cap.position, Vector2(cap.size.x, top_ry * 2.0)), CAP_TOP
	)
	ShapePaint.polyline(ci, RankMedal.closed(top), EDGE_LIGHT, 1.2, true)
	ShapePaint.colored_polygon(
		ci, _ellipse(top_c, Vector2(art_w * CONTACT_WIDTH * 0.5, top_ry * 0.6)), CONTACT_SHADOW
	)


func _slab(ci: RID, rect: Rect2, stops: Array) -> void:
	UiPaint.fill_gradient_polygon(ci, _box(rect), rect, stops)
	ShapePaint.polyline(ci, RankMedal.closed(_box(rect)), HomeProps.INK, 1.2, true)


static func _box(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]
	)


static func _ellipse(center: Vector2, radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in ELLIPSE_SEGMENTS:
		var t := TAU * float(k) / float(ELLIPSE_SEGMENTS)
		points.append(center + Vector2(cos(t) * radii.x, sin(t) * radii.y))
	return points
