class_name CardSpellReveal
extends Control
## 相手が撃った砂術を、卓の中央へ札のまま大きく出して読ませる(GameDesign.md 9章「紋章の出どころ」)。
## 紋章が飛ぶだけでは、相手が何を撃ったのか読めないため。リプレイ・観戦では両者の砂術に出す。
## 札が縮んで消えたところから紋章が飛ぶ(`CardMatchEffectStrike` が `finished` を待つ)。

signal finished

const REVEAL_SCALE := 1.8
const POP_DURATION := 0.16
## 札を読ませる間(GameDesign.md 9章「約0.8秒」)。
const HOLD_DURATION := 0.8
const VANISH_DURATION := 0.14
## 現れる瞬間の縮尺(最終の大きさに対する比)。
const POP_FROM := 0.6

var _card_view: CardView
var _tween: Tween
var _busy := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_view = CardView.new()
	_card_view.mode = CardView.Mode.HAND
	_card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_view.size = CardView.HAND_SIZE_PX
	_card_view.pivot_offset = CardView.HAND_SIZE_PX * 0.5
	_card_view.visible = false
	add_child(_card_view)


func busy() -> bool:
	return _busy


## `center` は札の中心(親のlocal座標)。`scale_factor` は縦画面の手札の倍率。
func play(card: CardData, center: Vector2, scale_factor: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_busy = true
	_card_view.card = card
	_card_view.position = center - CardView.HAND_SIZE_PX * 0.5
	_card_view.visible = true
	_card_view.modulate = Color(1, 1, 1, 0)
	var full := Vector2.ONE * REVEAL_SCALE * scale_factor
	_card_view.scale = full * POP_FROM
	_card_view.queue_redraw()
	_tween = create_tween()
	_tween.set_parallel()
	_tween.tween_property(_card_view, "modulate:a", 1.0, POP_DURATION)
	(
		_tween
		. tween_property(_card_view, "scale", full, POP_DURATION)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	_tween.chain().tween_interval(HOLD_DURATION)
	_tween.chain().tween_property(_card_view, "scale", full * POP_FROM, VANISH_DURATION)
	_tween.parallel().tween_property(_card_view, "modulate:a", 0.0, VANISH_DURATION)
	_tween.chain().tween_callback(_done)


## 対局をまたいで残さない・早送りで飛ばす。
func stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_card_view.visible = false
	if _busy:
		_done()


func _done() -> void:
	_card_view.visible = false
	_busy = false
	finished.emit()
