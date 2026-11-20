class_name CardViewPreviewFade
extends RefCounted
## 予測の丸の畳み(GameDesign.md 9章「対局画面の手触り」)。`preview_health` が 0以上から -1 へ戻ったとき、
## 最後に描いた値を残し、不透明度と大きさを 1→0・1→`UNSELECT_SHRINK` で動かして消す。出は即時。

var value := -1
var dead := false
## 1で全開、0で消えた。`active` の間だけ丸を描く。
var amount := 1.0
var active := false

var _view: CardView
var _tween: Tween


func _init(view: CardView) -> void:
	_view = view


## `preview_health` が `old` から `new` へ変わる(代入の直前に呼ぶ)。数字の入れ替えは補間しない。
func observe(old: int, new: int) -> void:
	if new >= 0:
		if active:
			_stop()
		return
	if old < 0 or not _view.is_inside_tree() or not _view.is_visible_in_tree():
		return
	value = old
	dead = _view.preview_dead
	active = true
	amount = 1.0
	_kill()
	_tween = _view.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_amount, 1.0, 0.0, CardView.UNSELECT_DURATION)
	_tween.tween_callback(_stop)


func _set_amount(next: float) -> void:
	amount = next
	_view.queue_redraw()


func _stop() -> void:
	_kill()
	active = false
	amount = 1.0
	_view.queue_redraw()


func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
