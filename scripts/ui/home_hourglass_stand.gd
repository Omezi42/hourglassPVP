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
## 台座の背丈(この部品の高さに対する比)。天板と土台の2段。
const PEDESTAL_RATIO := 0.17
const PEDESTAL_TOP_SHARE := 0.36
const PEDESTAL_TOP_WIDTH := 1.5
const PEDESTAL_BASE_WIDTH := 1.25
const PEDESTAL_TOP_RADIUS := 6.0
const PEDESTAL_BASE_RADIUS := 4.0
const PEDESTAL_LIP := Color(1.0, 0.92, 0.70, 0.55)
const GLOW_RATIO := 0.62

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
	HomeProps.glow(self, art.get_center(), art_h * GLOW_RATIO)
	_draw_pedestal(Rect2(0.0, art_h, size.x, pedestal_h), art_w)
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


func _draw_pedestal(rect: Rect2, art_w: float) -> void:
	var ci := get_canvas_item()
	var top_h := rect.size.y * PEDESTAL_TOP_SHARE
	var cx := rect.get_center().x
	var top := Rect2(
		cx - art_w * PEDESTAL_TOP_WIDTH * 0.5,
		rect.position.y - top_h * 0.4,
		art_w * PEDESTAL_TOP_WIDTH,
		top_h
	)
	var base_w := art_w * PEDESTAL_BASE_WIDTH
	var base := Rect2(cx - base_w * 0.5, top.end.y, base_w, rect.end.y - top.end.y)
	ShapePaint.colored_polygon(
		ci,
		UiPaint.rounded_rect_points_uniform(
			Rect2(base.position + HomeProps.SHADOW_OFFSET, base.size), PEDESTAL_BASE_RADIUS, 4
		),
		HomeProps.SHADOW
	)
	UiPaint.fill_gradient_polygon(
		ci, UiPaint.rounded_rect_points_uniform(base, PEDESTAL_BASE_RADIUS, 4), base, HomeProps.WOOD
	)
	UiPaint.fill_gradient_polygon(
		ci, UiPaint.rounded_rect_points_uniform(top, PEDESTAL_TOP_RADIUS, 4), top, HomeProps.BRASS
	)
	draw_line(
		top.position + Vector2(PEDESTAL_TOP_RADIUS, 1.5),
		Vector2(top.end.x - PEDESTAL_TOP_RADIUS, top.position.y + 1.5),
		PEDESTAL_LIP,
		1.5
	)
