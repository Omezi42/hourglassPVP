class_name SignatureLandFx
extends Control
## 看板の演出のうち、場に出たときのもの(GameDesign.md 9章)。いまはクロノスだけ。
## 重い着地(`CardView.play_land(true)`)が落ちきった瞬間に `landed` を出し、台座の周りへ
## 歯車の輪を広げて一回転させ、噛み合ったところで止める(反転できない印)。
## 盤面の状態を持たないため、`CardMatchEffectStrike` の持ち越しには関わらない。

signal landed

const SCREEN_SIZE := Vector2(1280, 720)
const GROW := 0.1
const SPIN := 0.5
const HOLD := 0.06
const FADE := 0.16
const TURN := TAU / float(SignaturePaint.GEAR_TEETH) * 6.0
const RING_SCALE := 1.3

var _center := Vector2.ZERO
var _grow := 0.0
var _turn := 0.0
var _alpha := 0.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SCREEN_SIZE
	z_index = 24


## `pedestal` は台座の上面の中心(画面の座標)。
func play_chronos(pedestal: Vector2) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_center = pedestal
	_grow = 0.0
	_turn = 0.0
	_alpha = 0.0
	SoundBank.play(SoundBank.Sfx.SIG_CHRONOS)
	_tween = create_tween()
	_tween.tween_interval(CardUnitFx.HEAVY_LAND_DURATION)
	_tween.tween_callback(landed.emit)
	_tween.tween_callback(func() -> void: _alpha = 1.0)
	_tween.tween_method(_set_grow, 0.0, 1.0, GROW).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_turn, 0.0, TURN, SPIN).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	_tween.tween_interval(HOLD)
	_tween.tween_method(_set_alpha, 1.0, 0.0, FADE)


func _set_grow(value: float) -> void:
	_grow = value
	queue_redraw()


func _set_turn(value: float) -> void:
	_turn = value
	queue_redraw()


func _set_alpha(value: float) -> void:
	_alpha = value
	queue_redraw()


func _draw() -> void:
	if _alpha <= 0.0:
		return
	var radius := CardView.PEDESTAL_RADIUS * RING_SCALE * _grow
	if radius.x <= 0.0:
		return
	SignaturePaint.gear_ring(self, _center, radius, _turn, _alpha)
