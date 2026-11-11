class_name CardDragPreview
extends Control
## 手札をドラッグ中に指へ付いてくる絵(GameDesign.md 9章「対局画面の手触り」)。
##
## 攻撃の演出で駒を「上端をつままれてぶら下がっている」ものとして扱うのと同じ物理を、
## 手札を掴んだときにも当てる。動かす方向と逆へわずかに遅れて傾き、止まれば元へ戻る。
##
## **絵の大きさは呼び出し側が決めたものをそのまま使う**(Architecture.md 4.0節
## 「ドラッグ中のプレビューも同じ大きさで作る」)。掴んだ瞬間に絵が膨らんで見えることを避けるため。

const MAX_ANGLE := 0.25
## 横に1px動くごとに足す角度。
const TILT_PER_PIXEL := 0.018
## 目標の角度へ近づく速さ(大きいほどすぐ追いつく=遅れが小さい)。
const FOLLOW_SPEED := 10.0
## 掴んだ瞬間にわずかに膨らんでから収まる(GameDesign.md 9章)。
const GRAB_POP_SCALE := 1.12
const GRAB_POP_DURATION := 0.22
## 卓に落とす影(持ち上げた高さぶん右下へずらす)。
const SHADOW_OFFSET := Vector2(10.0, 16.0)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.38)

## 砂術を手札の上端より上へ運んだ(離せば撃つ)とき、札が琥珀色に光って少し縮む(GameDesign.md 9章)。
const ARMED_SCALE := 0.85
const ARMED_GLOW_SCALE := 1.7
const ARMED_GLOW_ALPHA := 0.75
## 光の脈打ち(1秒あたりの回数・振れ幅)。
const ARMED_PULSE_RATE := 2.2
const ARMED_PULSE_DEPTH := 0.3
const STATE_DURATION := 0.12
## 光っている間の紋章の色(運ぶ絵そのものを琥珀色に染める。後ろの光だけでは縁しか見えないため)。
const ARMED_COLOR := Color(1.0, 0.82, 0.48, 1.0)
## 手札まで戻した(離せばやめる)ときの暗さ。
const DIM_COLOR := Color(0.55, 0.55, 0.6, 0.8)

var _art: TextureRect
var _shadow: TextureRect
var _glow: TextureRect
var _tint := Color(1, 1, 1, 0.85)
var _armed := false
var _pulse := 0.0
var _angle := 0.0
var _last_mouse := Vector2.ZERO
var _has_last := false


## `CardView._get_drag_data()` が呼ぶ。渡すのは実際に画面へ描かれるのと同じ絵と大きさ。
## `tint` は絵の色(砂術の紋章は札と同じ色で塗る)。
func setup(texture: Texture2D, art_size: Vector2, tint := Color(1, 1, 1, 0.85)) -> void:
	_tint = tint
	_art = TextureRect.new()
	_art.texture = texture
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.custom_minimum_size = art_size
	_art.size = art_size
	_art.position = -art_size * 0.5
	# 上端をつままれてぶら下がっているものとして扱う(GameDesign.md 9章)。
	_art.pivot_offset = Vector2(art_size.x * 0.5, 0.0)
	_art.modulate = tint
	_shadow = _art.duplicate() as TextureRect
	_shadow.modulate = SHADOW_COLOR
	_shadow.position += SHADOW_OFFSET
	_glow = _art.duplicate() as TextureRect
	_glow.pivot_offset = art_size * 0.5
	_glow.scale = Vector2.ONE * ARMED_GLOW_SCALE
	_glow.modulate = Color(UiPalette.SAND, 0.0)
	add_child(_shadow)
	add_child(_glow)
	add_child(_art)
	_art.scale = Vector2.ONE * GRAB_POP_SCALE
	var pop := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_art, "scale", Vector2.ONE, GRAB_POP_DURATION)
	set_process(true)


func _process(delta: float) -> void:
	if _art == null:
		return
	var mouse := get_global_mouse_position()
	if _has_last:
		var dx := mouse.x - _last_mouse.x
		# 動かす方向と逆へ傾く(GameDesign.md 9章)。
		var target := clampf(-dx * TILT_PER_PIXEL, -MAX_ANGLE, MAX_ANGLE)
		_angle = lerpf(_angle, target, clampf(FOLLOW_SPEED * delta, 0.0, 1.0))
		_art.rotation = _angle
		_shadow.rotation = _angle
	_last_mouse = mouse
	_has_last = true
	if _armed:
		_pulse += delta * ARMED_PULSE_RATE * TAU
		var depth := 1.0 - ARMED_PULSE_DEPTH * (0.5 + 0.5 * sin(_pulse))
		_glow.modulate.a = ARMED_GLOW_ALPHA * depth


## 離せば撃つ状態(GameDesign.md 9章)。一度光らせた後に `false` が来たら、手札まで戻して
## 離せばやめる状態として暗くする(掴んだ直後の手札の上では暗くしない)。
func set_armed(armed: bool) -> void:
	if _art == null or _armed == armed:
		return
	_armed = armed
	var tween := create_tween().set_parallel()
	tween.tween_property(
		self, "scale", Vector2.ONE * (ARMED_SCALE if armed else 1.0), STATE_DURATION
	)
	tween.tween_property(_art, "modulate", ARMED_COLOR if armed else DIM_COLOR, STATE_DURATION)
	if not armed:
		tween.tween_property(_glow, "modulate:a", 0.0, STATE_DURATION)


## 対象を取る砂術を構えた間は、指先には札を出さず矢印だけを伸ばす(札は卓の左へ移る)。
func set_hidden(hidden: bool) -> void:
	modulate.a = 0.0 if hidden else 1.0
