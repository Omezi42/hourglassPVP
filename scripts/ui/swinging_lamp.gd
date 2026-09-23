class_name SwingingLamp
extends Control
## 対局画面の吊りランプ(GameDesign.md 9章「対局画面の再構築」)。`MatchBackdrop` の子。
## 鎖の上端を支点に、ポインタが触れると押された向きへ小さく揺れ、減衰して止まる。
## 揺れは `rotation` だけで表すため、揺れている間も描き直さない。
## 上に重なる情報帯がイベントを受けるため、触れた判定は毎フレームのポインタ位置で取る。

const LAMP_X := 640.0
const LAMP_SIZE := Vector2(26.0, 30.0)
const LAMP_LINK_COUNT := 7
const LAMP_LINK_RADIUS := 3.0
const LAMP_CONE_SPAN := 220.0
const LANTERN_GAP := 6.0

## 触れた判定の範囲(ランタンと鎖の周りへ足す余白)。
const HIT_MARGIN := 6.0
## 振り子。固有の周期はおよそ1.3秒、3秒ほどで収まる。
const STIFFNESS := 24.0
const DAMPING := 1.4
## 押し。ポインタの横速度(px/s)を角速度(rad/s)へ換算する。遅く触れても最小の押しは入る。
const PUSH_GAIN := 0.0006
const PUSH_MIN := 0.12
const PUSH_MAX := 0.45
const CLICK_PUSH := 0.3
const MAX_ANGLE := 0.14
const REST_EPSILON := 0.0005

var _velocity := 0.0
var _hovered := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0
	pivot_offset = Vector2(LAMP_X, 0.0)


func _process(delta: float) -> void:
	var hovered := _hit_rect().has_point(get_local_mouse_position())
	if hovered and not _hovered:
		_push(Input.get_last_mouse_velocity().x)
	_hovered = hovered
	if is_zero_approx(rotation) and is_zero_approx(_velocity):
		return
	_velocity += (-STIFFNESS * rotation - DAMPING * _velocity) * delta
	rotation = clampf(rotation + _velocity * delta, -MAX_ANGLE, MAX_ANGLE)
	if absf(rotation) < REST_EPSILON and absf(_velocity) < REST_EPSILON:
		rotation = 0.0
		_velocity = 0.0


func _input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var at := get_local_mouse_position()
	if _hit_rect().has_point(at):
		_velocity += CLICK_PUSH * (1.0 if at.x < LAMP_X else -1.0)


## 右へ払えば下端が右へ振れる(Godotの正の回転は時計回り=下端が左へ動く)。
func _push(pointer_speed_x: float) -> void:
	var direction := -signf(pointer_speed_x) if pointer_speed_x != 0.0 else 1.0
	var amount := clampf(absf(pointer_speed_x) * PUSH_GAIN, PUSH_MIN, PUSH_MAX)
	_velocity += direction * amount


func _bottom_y() -> float:
	return CardMatchScreen.TABLE_RECT.position.y - LANTERN_GAP


func _hit_rect() -> Rect2:
	var half_width := LAMP_SIZE.x * 0.5 + HIT_MARGIN
	return Rect2(LAMP_X - half_width, 0.0, half_width * 2.0, _bottom_y() + HIT_MARGIN)


func _draw() -> void:
	var ci := get_canvas_item()
	var bottom_y := _bottom_y()
	var lantern_top_y: float = bottom_y - LAMP_SIZE.y
	draw_line(
		Vector2(LAMP_X, 0.0), Vector2(LAMP_X, lantern_top_y), Color(0.10, 0.07, 0.05, 0.9), 2.0
	)
	for i in LAMP_LINK_COUNT:
		var t: float = float(i) / float(LAMP_LINK_COUNT - 1)
		var y: float = lerpf(0.0, lantern_top_y, t)
		UiPaint.draw_ring(
			ci, Vector2(LAMP_X, y), LAMP_LINK_RADIUS, Color(0.42, 0.33, 0.20, 0.85), 1.4, 10
		)
	_draw_lantern(ci, Vector2(LAMP_X, bottom_y))
	RoomPaint.lamp(
		self, Vector2(LAMP_X, bottom_y), CardMatchScreen.TABLE_RECT.get_center().y, LAMP_CONE_SPAN
	)


## ランタン本体(角丸矩形 + 上の笠 + 中の暖色の光)。
func _draw_lantern(ci: RID, bottom_center: Vector2) -> void:
	var rect := Rect2(bottom_center - Vector2(LAMP_SIZE.x * 0.5, LAMP_SIZE.y), LAMP_SIZE)
	var cap := Rect2(rect.position.x - 4.0, rect.position.y - 6.0, rect.size.x + 8.0, 8.0)
	UiPaint.fill_gradient_polygon(
		ci,
		UiPaint.rounded_rect_points_uniform(cap, 2.0, 4),
		cap,
		[[0.0, UiPalette.BRASS_LIGHT], [1.0, UiPalette.BRASS_DARK]]
	)
	var points := UiPaint.rounded_rect_points_uniform(rect, 4.0, 6)
	UiPaint.fill_gradient_polygon(
		ci, points, rect, [[0.0, UiPalette.BRASS_MID], [1.0, UiPalette.BRASS_DARK]]
	)
	UiPaint.draw_bevel(ci, points, UiPalette.BRASS_HIGHLIGHT, UiPalette.OUTLINE_DARK, 1.2, false)
	var inner := rect.grow(-4.0)
	UiPaint.fill_gradient_polygon(
		ci,
		UiPaint.rounded_rect_points_uniform(inner, 2.0, 4),
		inner,
		[[0.0, RoomPaint.LAMP_WARM], [1.0, RoomPaint.LAMP_WARM.darkened(0.2)]]
	)
