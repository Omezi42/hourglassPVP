class_name HandHoverSheen
extends Control
## ホバー中の手札の札を、カーソルのある側へ傾け、面に柔らかい光の筋を流す(GameDesign.md 9章)。
##
## 1個だけ作って画面の子に置き(画面と一緒に解放されるように)、ホバー中だけその札の子へ付け替える。**札そのものは描き直さない**(Web版では
## 描き直すたびにGLの番号を使い捨てる。Pitfalls.md)。傾きは札の `rotation` へ足し、光の筋は
## `clip_contents` の中で `TextureRect` を動かすだけにする。

## カーソルが札の端にあるときの傾き。
const TILT_MAX := deg_to_rad(4.0)
## 傾きと光の筋がカーソルへ追いつく速さ(大きいほど遅れが小さい)。
const FOLLOW_SPEED := 14.0
const SETTLE_DURATION := 0.14
## 光の筋の幅(札の幅に対する割合)・斜めの角度・濃さ・色。
const BAND_WIDTH_RATIO := 0.55
const BAND_ANGLE := deg_to_rad(18.0)
const BAND_ALPHA := 0.28
const BAND_COLOR := Color(1.0, 0.95, 0.82)
## 札の角丸から光がはみ出さないよう内側へ寄せる量。
const INSET := 3.0

var _home: Node
var _view: CardView
var _rest_rotation := 0.0
var _tilt := 0.0
var _band_x := 0.0
var _band: TextureRect


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_band = TextureRect.new()
	_band.texture = _band_texture()
	_band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_band.stretch_mode = TextureRect.STRETCH_SCALE
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.modulate = Color(BAND_COLOR, BAND_ALPHA)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_band.material = additive
	add_child(_band)
	visible = false
	set_process(false)


## 札に付けていない間の置き場。
func park_in(home: Node) -> void:
	_home = home
	home.add_child(self)


## 札へ付ける。付け替える前の札は傾きを戻す。
func attach(view: CardView) -> void:
	if view == _view:
		return
	detach()
	_view = view
	_rest_rotation = view.rotation
	_tilt = 0.0
	position = Vector2(INSET, INSET)
	size = view.size - Vector2(INSET, INSET) * 2.0
	_band.size = Vector2(size.x * BAND_WIDTH_RATIO, size.y * 2.0)
	_band.pivot_offset = _band.size * 0.5
	_band.rotation = BAND_ANGLE
	_band_x = _local_mouse_x()
	get_parent().remove_child(self)
	view.add_child(self)
	visible = true
	set_process(true)
	_place_band()


func detach() -> void:
	if _view == null:
		return
	set_process(false)
	visible = false
	get_parent().remove_child(self)
	_home.add_child(self)
	if is_instance_valid(_view):
		var settle := _view.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		settle.tween_property(_view, "rotation", _rest_rotation, SETTLE_DURATION)
	_view = null


func _process(delta: float) -> void:
	if not is_instance_valid(_view) or not _view.visible:
		detach()
		return
	var follow := clampf(FOLLOW_SPEED * delta, 0.0, 1.0)
	var mouse_x := _local_mouse_x()
	var half := size.x * 0.5
	var lean := clampf((mouse_x - half) / half, -1.0, 1.0)
	_tilt = lerpf(_tilt, lean * TILT_MAX, follow)
	_view.rotation = _rest_rotation + _tilt
	_band_x = lerpf(_band_x, mouse_x, follow)
	_place_band()


func _place_band() -> void:
	_band.position = Vector2(_band_x - _band.size.x * 0.5, (size.y - _band.size.y) * 0.5)


func _local_mouse_x() -> float:
	return _view.get_local_mouse_position().x - INSET


func _band_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.5, Color(1, 1, 1, 1))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 4
	return texture
