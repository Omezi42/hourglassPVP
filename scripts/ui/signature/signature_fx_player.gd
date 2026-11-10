class_name SignatureFxPlayer
extends Control
## カードの演出(`SignatureMove`)を再生するオーバーレイ(GameDesign.md 9章)。
## 効果の演出は `CardMatchEffectStrike` が、登場の演出は `CardMatchEffects` が持つ。
## 紋章(`EmblemStrikeFx`)と同じく盤面より手前へ重ね、同じ `impact` / `finished` を出す。
## 対象へ順に届く演出は、届いた対象ごとに `hit(index)` を出す。

signal hit(index: int)
signal impact
signal finished

const SCREEN_SIZE := Vector2(1280, 720)
## 同じ対局で同じカードの同じ演出が2回目以降に出るときの尺の割合(GameDesign.md 9章)。
const SHORT_RATE := 0.6

var _move: SignatureMove
var _t := 0.0
var _reached: Array[bool] = []
var _impacted := false
var _tween: Tween
## 短縮版で着弾の瞬間に鳴らす音。-1 なら鳴らさない。
var _impact_sfx := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SCREEN_SIZE
	z_index = 24


## 尺の割合。短縮版は `CardView.play_land()` にも同じ割合を渡して着地を揃える。
static func rate(short: bool) -> float:
	return SHORT_RATE if short else 1.0


func is_playing() -> bool:
	return _move != null


## 短縮版は専用の音を鳴らさず、着弾の瞬間に `short_sfx`(登場なら置く音)だけを鳴らす
## (GameDesign.md 9章。専用の音は通常の尺の打点で作られていて、速めた絵とずれるため)。
func play(move: SignatureMove, short := false, short_sfx := -1) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_move = move
	_t = 0.0
	_impacted = false
	_reached.clear()
	_reached.resize(move.targets.size())
	_reached.fill(false)
	var screen := get_parent() as CardMatchScreen
	var audible := screen == null or not screen.silent
	_impact_sfx = short_sfx if short and audible else -1
	if not short and move.sound() >= 0 and audible:
		SoundBank.play(move.sound())
	_tween = create_tween()
	_tween.tween_method(_set_t, 0.0, move.duration(), move.duration() * rate(short))
	_tween.tween_callback(_on_finished)


func _set_t(t: float) -> void:
	_t = t
	for i in range(_reached.size()):
		if not _reached[i] and _move.reaches(i, t):
			_reached[i] = true
			hit.emit(i)
	if t >= _move.impact_at():
		_on_impact()
	queue_redraw()


func _on_impact() -> void:
	if _impacted:
		return
	_impacted = true
	for i in range(_reached.size()):
		if not _reached[i]:
			_reached[i] = true
			hit.emit(i)
	if _impact_sfx >= 0:
		SoundBank.play(_impact_sfx)
	impact.emit()


func _on_finished() -> void:
	_on_impact()
	_move = null
	queue_redraw()
	finished.emit()


func _draw() -> void:
	if _move != null:
		_move.draw(self, _t)
