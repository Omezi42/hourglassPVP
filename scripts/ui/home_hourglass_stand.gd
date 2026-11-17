class_name HomeHourglassStand
extends Control
## ホーム中央の台座に載った砂時計(GameDesign.md 9章)。首から下の部屋へ砂が細く落ち続け、押すと上下に半回転する。
## 触って遊ぶためのもので、押しても何も起きない(対局の入口は下の「対戦する」ボタン)。
## 砂の流れは絵のシェーダーが描く見た目だけで、上の部屋の砂は減らない。

## 砂時計はコード描画のサンド(落下中)。場の駒と同じ部品を、この台の大きさで1枚ぶん持つ
## (共有の動く絵は駒の大きさで描くため、ここへ引き伸ばすとぼやける)。
const ART_KEY := "sand"
const ART_STATE := HourglassArt.State.FALLING
## 台座は真鍮の円盤1枚(上面の楕円と側面の帯)。半径は砂時計の絵の高さに対する比で、
## 上面のつぶれと側面の厚みは半径に対する比。円盤の下に落ちる影のぶんだけ下を空ける。
const PEDESTAL_RADIUS := 0.40
const PEDESTAL_SQUASH := 0.17
const PEDESTAL_DROP := 0.16
const PEDESTAL_RESERVE := 0.19
## 砂時計の足元を円盤の上面の中心より少し上へ載せる(px)。
const FEET_LIFT := 6.0
const ELLIPSE_SEGMENTS := 40
const SIDE_STOPS := [
	[0.0, UiPalette.BRASS], [0.5, UiPalette.BRASS_DEEP], [1.0, UiPalette.BRASS_INK]
]
const TOP_STOPS := [[0.0, UiPalette.BRASS], [1.0, UiPalette.GOLD_HI]]
const TOP_DIMPLE := Color(0.2, 0.1, 0.0, 0.35)
const FLOOR_SHADOW := Color(0.0, 0.0, 0.0, 0.32)
## 後ろの光(広い砂色と、芯の明るい光)。大きさは砂時計の絵の高さに対する比。
const GLOW_WIDE := Color(1.0, 0.80, 0.45, 0.30)
const GLOW_WIDE_RADII := Vector2(1.25, 1.0)
const GLOW_CORE := Color(1.0, 0.90, 0.65, 0.22)
const GLOW_CORE_RADII := Vector2(0.6, 0.62)
const FLIP_SECONDS := 0.55
const FLIP_HOP := 14.0

var _clock := 0.0
var _stack: HourglassLive.Stack = null
## 砂時計の絵(動く絵が作れないときは焼いた止め絵)。
var _art: Texture2D = null
## 半回転の進み(0〜1)。回っている間は流れを止める。
var _flip := 0.0
var _flip_tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	_art = HourglassArt.texture(ART_KEY, ART_STATE)
	resized.connect(_rebuild_stack)
	_rebuild_stack()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _stack == null:
		return
	_clock += delta
	_stack.set_time(_clock)
	queue_redraw()


## 台の大きさに合わせて動く絵を作り直す。キャンバスの原寸より大きくはしない。
func _rebuild_stack() -> void:
	if not HourglassLive.has_shader(ART_KEY) or size.y <= 0.0:
		return
	var canvas := Vector2(HourglassLive.CANVAS)
	var height := minf(_art_height(), canvas.y)
	var pixels := Vector2i(roundi(height * canvas.x / canvas.y), roundi(height))
	if _stack != null and _stack.viewport.size == pixels:
		return
	if _stack != null:
		_stack.viewport.queue_free()
	_stack = HourglassLive.make_stack(
		ART_KEY,
		ART_STATE,
		HourglassLive.load_layer(ART_KEY, ART_STATE, HourglassLive.LAYER_BACK),
		HourglassLive.load_layer(ART_KEY, ART_STATE, HourglassLive.LAYER_FRAME),
		pixels
	)
	_stack.set_time(_clock)
	add_child(_stack.viewport)
	_art = _stack.texture


func _art_height() -> float:
	return size.y / (1.0 + PEDESTAL_RESERVE)


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
	var ci := get_canvas_item()
	if _art == null:
		return
	var art_h := _art_height()
	var art_w := art_h * float(_art.get_width()) / float(_art.get_height())
	var art := Rect2(Vector2((size.x - art_w) * 0.5, 0.0), Vector2(art_w, art_h))
	var feet := Vector2(size.x * 0.5, art_h)
	UiKit.glow(ci, feet - Vector2(0, art_h * 0.55), GLOW_WIDE_RADII * art_h, GLOW_WIDE)
	UiKit.glow(ci, feet - Vector2(0, art_h * 0.5), GLOW_CORE_RADII * art_h, GLOW_CORE)
	_draw_pedestal(feet + Vector2(0, FEET_LIFT), art_h * PEDESTAL_RADIUS)
	var center := art.get_center()
	# 枠は上下対称のため、回りきったら元の向きの絵へ戻す(砂が下へ落ちた後の姿になる)。
	var angle := PI * _flip
	var hop := sin(PI * _flip) * FLIP_HOP
	draw_set_transform(center + Vector2(0.0, -hop), angle, Vector2.ONE)
	draw_texture_rect(_art, Rect2(-art.size * 0.5, art.size), false)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## 真鍮の円盤。`top` は上面の中心。床の影 → 側面の帯 → 上面 → 砂時計の足元の窪み の順に重ねる。
func _draw_pedestal(top: Vector2, rx: float) -> void:
	var ci := get_canvas_item()
	var ry := rx * PEDESTAL_SQUASH
	var drop := rx * PEDESTAL_DROP
	UiKit.fill(
		ci,
		UiKit.ellipse(top + Vector2(0, drop + ry * 0.9), Vector2(rx * 1.15, ry * 1.2)),
		FLOOR_SHADOW
	)
	# 側面は上面の楕円の下半分を厚みぶん下へ押し出した帯(下の縁が丸いので凸の形になる)。
	var side := PackedVector2Array()
	var half := ELLIPSE_SEGMENTS / 2
	side.append(top + Vector2(rx, 0))
	for k in half + 1:
		var angle := PI * float(k) / float(half)
		side.append(top + Vector2(cos(angle) * rx, sin(angle) * ry + drop))
	side.append(top + Vector2(-rx, 0))
	UiKit.vgrad(ci, side, SIDE_STOPS)
	var face := UiKit.ellipse(top, Vector2(rx, ry), ELLIPSE_SEGMENTS)
	UiKit.vgrad(ci, face, TOP_STOPS)
	UiKit.stroke(ci, face, UiPalette.GOLD_HI, UiKit.LINE_MIN)
	UiKit.fill(ci, UiKit.ellipse(top, Vector2(rx * 0.55, ry * 0.5)), TOP_DIMPLE)
