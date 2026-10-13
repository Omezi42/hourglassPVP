class_name SignatureStrikeFx
extends Control
## 看板の演出のうち、効果が対象へ届くもの(GameDesign.md 9章)。`EmblemStrikeFx` の代わりに
## `CardMatchEffectStrike` が呼び、同じ `impact` / `finished` を出す。結果の見せ方(砂の飛散・
## 破壊・砂の移動)は進行役がそのまま出すため、ここは「届くまで」だけを描く。
##
## 波紋・砂の帯のように対象へ順に届くものは、届いた対象ごとに `hit(index)` を出す。
## `impact` は最後の対象へ届いた瞬間に1度だけ出す。

signal hit(index: int)
signal impact
signal finished

const SCREEN_SIZE := Vector2(1280, 720)
const FADE := 0.22

## クロックタワー:鐘が現れて振れ、波紋が広がる。鐘が鳴る位置は効果音と揃える。
const BELL_DURATION := 0.32
const BELL_SWING := 0.32
const BELL_LIFT := 64.0
const RIPPLE_DURATION := 0.45
## 波紋が最後の対象を越えてから消えるまでの余り。
const RIPPLE_MARGIN := 24.0

## 砂塵嵐:卓の端から端へ帯が吹き抜ける。
const BAND_DURATION := 0.62
const BAND_HALF_HEIGHT := 56.0
const BAND_OVERRUN := 60.0

## 時間停止:色が抜け、砂粒が昇り、色が戻る。
const STASIS_DRAIN := 0.26
const STASIS_HOLD := 0.48
const STASIS_WASH := Color(0.70, 0.74, 0.82, 0.55)
const STASIS_BOX := Vector2(112.0, 128.0)
const STASIS_CORNER := 22.0

## 時の裁き:天秤が現れ、攻撃力の側へ傾ききって砕く。
const VERDICT_APPEAR := 0.24
const VERDICT_TIP := 0.4
const VERDICT_TILT := 0.42
const VERDICT_LIFT := 40.0
const VERDICT_DROP := 12.0

const SOUNDS := {
	CardEnums.SignatureFx.CLOCKTOWER: SoundBank.Sfx.SIG_CLOCKTOWER,
	CardEnums.SignatureFx.TEMPEST: SoundBank.Sfx.SIG_TEMPEST,
	CardEnums.SignatureFx.STASIS: SoundBank.Sfx.SIG_STASIS,
	CardEnums.SignatureFx.VERDICT: SoundBank.Sfx.SIG_VERDICT,
}

var _kind: int = CardEnums.SignatureFx.NONE
var _from := Vector2.ZERO
var _targets: Array[Vector2] = []
var _reached: Array[bool] = []
## 前置き(鐘・天秤が現れる / 色が抜ける)の進み。
var _intro := 0.0
## 本体(波紋・帯・傾き・砂粒)の進み。
var _main := 0.0
var _alpha := 0.0
var _impacted := false
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SCREEN_SIZE
	z_index = 24


static func handles(kind: int) -> bool:
	return SOUNDS.has(kind)


func play(kind: int, from: Vector2, targets: Array[Vector2]) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_kind = kind
	_from = from
	_targets = targets
	_reached.clear()
	_reached.resize(targets.size())
	_reached.fill(false)
	_intro = 0.0
	_main = 0.0
	_alpha = 1.0
	_impacted = false
	SoundBank.play(SOUNDS[kind])
	_tween = create_tween()
	match kind:
		CardEnums.SignatureFx.CLOCKTOWER:
			_tween.tween_method(_set_intro, 0.0, 1.0, BELL_DURATION)
			_tween.tween_method(_set_main, 0.0, 1.0, RIPPLE_DURATION)
		CardEnums.SignatureFx.TEMPEST:
			_tween.tween_method(_set_main, 0.0, 1.0, BAND_DURATION).set_trans(Tween.TRANS_SINE)
		CardEnums.SignatureFx.STASIS:
			_tween.tween_method(_set_intro, 0.0, 1.0, STASIS_DRAIN)
			_tween.tween_callback(_on_impact)
			_tween.tween_method(_set_main, 0.0, 1.0, STASIS_HOLD)
		CardEnums.SignatureFx.VERDICT:
			_tween.tween_method(_set_intro, 0.0, 1.0, VERDICT_APPEAR).set_ease(Tween.EASE_OUT)
			(
				_tween
				. tween_method(_set_main, 0.0, 1.0, VERDICT_TIP)
				. set_trans(Tween.TRANS_BACK)
				. set_ease(Tween.EASE_OUT)
			)
	_tween.tween_callback(_on_impact)
	_tween.tween_method(_set_alpha, 1.0, 0.0, FADE)
	_tween.tween_callback(_on_finished)


func _set_intro(value: float) -> void:
	_intro = value
	queue_redraw()


func _set_main(value: float) -> void:
	_main = value
	_emit_reached()
	queue_redraw()


func _set_alpha(value: float) -> void:
	_alpha = value
	queue_redraw()


## 波紋・帯が対象を越えたら、その対象の結果を先に出してもらう。
func _emit_reached() -> void:
	for i in range(_targets.size()):
		if not _reached[i] and _has_reached(_targets[i]):
			_reached[i] = true
			hit.emit(i)


func _has_reached(target: Vector2) -> bool:
	match _kind:
		CardEnums.SignatureFx.CLOCKTOWER:
			return _ripple_radius() >= _bell_pivot().distance_to(target)
		CardEnums.SignatureFx.TEMPEST:
			return _band_front() >= target.x
	return false


func _on_impact() -> void:
	if _impacted:
		return
	_impacted = true
	for i in range(_targets.size()):
		if not _reached[i]:
			_reached[i] = true
			hit.emit(i)
	impact.emit()


func _on_finished() -> void:
	_kind = CardEnums.SignatureFx.NONE
	_targets.clear()
	queue_redraw()
	finished.emit()


func _draw() -> void:
	match _kind:
		CardEnums.SignatureFx.CLOCKTOWER:
			_draw_clocktower()
		CardEnums.SignatureFx.TEMPEST:
			SignaturePaint.sand_band(self, _band_rect(), _band_front(), _alpha)
		CardEnums.SignatureFx.STASIS:
			_draw_stasis()
		CardEnums.SignatureFx.VERDICT:
			_draw_verdict()


func _bell_pivot() -> Vector2:
	return _from - Vector2(0.0, BELL_LIFT)


func _ripple_radius() -> float:
	var reach := 0.0
	for target in _targets:
		reach = maxf(reach, _bell_pivot().distance_to(target))
	return (reach + RIPPLE_MARGIN) * _main


func _draw_clocktower() -> void:
	var pivot := _bell_pivot()
	# 鐘は現れながら大きく1度振れ、波紋の間は余韻で小さく揺れ続ける。
	var swing := sin(_intro * PI * 1.5) * BELL_SWING * (1.0 - 0.6 * _main)
	SignaturePaint.bell(self, pivot, swing, minf(_intro * 3.0, 1.0) * _alpha)
	if _intro >= 1.0:
		SignaturePaint.ripple(
			self, pivot + Vector2(0.0, SignaturePaint.BELL_HEIGHT), _ripple_radius(), _alpha
		)


func _band_rect() -> Rect2:
	var table := CardMatchScreen.TABLE_RECT
	var y := 0.0
	for target in _targets:
		y += target.y
	y /= maxf(float(_targets.size()), 1.0)
	return Rect2(
		table.position.x - BAND_OVERRUN,
		y - BAND_HALF_HEIGHT,
		table.size.x + BAND_OVERRUN * 2.0,
		BAND_HALF_HEIGHT * 2.0
	)


func _band_front() -> float:
	var rect := _band_rect()
	return lerpf(rect.position.x, rect.end.x, _main)


func _draw_stasis() -> void:
	var wash := _intro * _alpha
	for target in _targets:
		var box := Rect2(target - STASIS_BOX * 0.5, STASIS_BOX)
		draw_colored_polygon(
			UiPaint.rounded_rect_points_uniform(box, STASIS_CORNER, 6),
			Color(STASIS_WASH, STASIS_WASH.a * wash)
		)
		SignaturePaint.rising_grains(self, target, _main, wash)


func _draw_verdict() -> void:
	if _targets.is_empty():
		return
	var base := _targets[0] - Vector2(0.0, VERDICT_LIFT + VERDICT_DROP * (1.0 - _intro))
	SignaturePaint.balance(self, base, VERDICT_TILT * _main, _intro * _alpha)
