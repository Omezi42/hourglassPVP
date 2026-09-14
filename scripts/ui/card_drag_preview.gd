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

var _art: TextureRect
var _angle := 0.0
var _last_mouse := Vector2.ZERO
var _has_last := false


## `CardView._get_drag_data()` が呼ぶ。渡すのは実際に画面へ描かれるのと同じ絵と大きさ。
func setup(texture: Texture2D, art_size: Vector2) -> void:
	_art = TextureRect.new()
	_art.texture = texture
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.custom_minimum_size = art_size
	_art.size = art_size
	_art.position = -art_size * 0.5
	# 上端をつままれてぶら下がっているものとして扱う(GameDesign.md 9章)。
	_art.pivot_offset = Vector2(art_size.x * 0.5, 0.0)
	_art.modulate = Color(1, 1, 1, 0.85)
	add_child(_art)
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
	_last_mouse = mouse
	_has_last = true
