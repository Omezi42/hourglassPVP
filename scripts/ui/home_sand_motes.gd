class_name HomeSandMotes
extends Control
## ホームの背景で舞い降りる金色の砂粒(GameDesign.md 9章)。札の背面に敷き、押下は通す。
## 粒は画面の下端を抜けると上端へ戻る。位置は画面の大きさに対する比で持ち、向きが変わっても散らばりを保つ。

const COUNT := 42
const MIN_SIZE := 1.4
const MAX_SIZE := 3.2
const MIN_ALPHA := 0.12
const MAX_ALPHA := 0.5
## 1秒に落ちる量(画面の高さに対する比)。大きい粒ほど手前にあるものとして速く落とす。
const MIN_FALL := 0.018
const MAX_FALL := 0.05
## 横の揺れ(画面の幅に対する比)と、その周期の速さ。
const SWAY := 0.006
const SWAY_SPEED := 0.7
const COLOR := Color(1.0, 0.84, 0.50)
## 明滅の深さと速さ。
const TWINKLE_DEPTH := 0.25
const TWINKLE_SPEED := 2.0
## 乱数の種を固定し、開くたびに同じ散らばりから始める(撮影の比較のため)。
const SEED := 20261105

var _motes: Array[Vector4] = []
var _clock := 0.0


static func make() -> HomeSandMotes:
	var motes := HomeSandMotes.new()
	motes.anchor_right = 1.0
	motes.anchor_bottom = 1.0
	motes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return motes


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for k in COUNT:
		# x, y = 画面に対する位置 / z = 大きさの比(0〜1)/ w = 揺れの位相
		_motes.append(Vector4(rng.randf(), rng.randf(), rng.randf(), rng.randf() * TAU))


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	for k in _motes.size():
		var mote := _motes[k]
		mote.y += lerpf(MIN_FALL, MAX_FALL, mote.z) * delta
		if mote.y > 1.0:
			mote.y -= 1.0
		_motes[k] = mote
	queue_redraw()


func _draw() -> void:
	for mote in _motes:
		var side := lerpf(MIN_SIZE, MAX_SIZE, mote.z)
		var sway := sin(_clock * SWAY_SPEED + mote.w) * SWAY * size.x
		var at := Vector2(mote.x * size.x + sway, mote.y * size.y)
		var twinkle := 1.0 - TWINKLE_DEPTH + TWINKLE_DEPTH * sin(_clock * TWINKLE_SPEED + mote.w)
		draw_rect(
			Rect2(at - Vector2.ONE * side * 0.5, Vector2.ONE * side),
			Color(COLOR, lerpf(MIN_ALPHA, MAX_ALPHA, mote.z) * twinkle)
		)
