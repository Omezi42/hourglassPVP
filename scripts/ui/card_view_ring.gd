class_name CardViewRing
extends RefCounted
## 台座の輪の出入り(GameDesign.md 9章「対局画面の手触り」)。選ぶと一回り大きく薄い輪が締まって出て、
## 取り消すと縮んで消え、狙えない守護の輪は2回明滅する。値は `CardView` が持ち、`CardViewPaint.pedestal_ring()` が読む。

## 選んだ輪の出: 半径の倍率と不透明度の始まり、尺。
const SELECT_START_SCALE := 1.15
const SELECT_START_ALPHA := 0.35
const SELECT_DURATION := 0.12
## 守護の輪の明滅(出せない札の足りないピップと同じ尺・回数)。
const GUARD_BLINK_LOW := 0.3
const GUARD_BLINK_STEP := 0.16
const GUARD_BLINKS := 2

var _view: CardView
var _select_tween: Tween
var _unselect_tween: Tween
var _blink_tween: Tween
var _was_selected := false
var _pending := false


func _init(view: CardView) -> void:
	_view = view


## `selected` が代入された。`refresh()` は毎回 false へ外して付け直すため、フレームの終わりに1度だけ見る。
func request() -> void:
	if _pending:
		return
	_pending = true
	_evaluate.call_deferred()


func _evaluate() -> void:
	_pending = false
	var now := _view.selected
	var rising := now and not _was_selected
	_was_selected = now
	if rising and _view.mode == CardView.Mode.BOARD and _view.is_inside_tree():
		play_select()


func play_select() -> void:
	_kill(_select_tween)
	_view.select_amount = 0.0
	_select_tween = _view.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_select_tween.tween_method(_set_select, 0.0, 1.0, SELECT_DURATION)


func play_unselect() -> void:
	_kill(_unselect_tween)
	_view.unselect_amount = 1.0
	_unselect_tween = _view.create_tween().set_ease(Tween.EASE_OUT)
	_unselect_tween.tween_method(_set_unselect, 1.0, 0.0, CardView.UNSELECT_DURATION)


## 狙えない相手を押した。守護の駒の輪を明滅させる。
func blink_guard() -> void:
	_kill(_blink_tween)
	_blink_tween = _view.create_tween()
	for i in GUARD_BLINKS:
		_blink_tween.tween_method(_set_blink, 1.0, GUARD_BLINK_LOW, GUARD_BLINK_STEP)
		_blink_tween.tween_method(_set_blink, GUARD_BLINK_LOW, 1.0, GUARD_BLINK_STEP)


func _set_select(value: float) -> void:
	_view.select_amount = value
	_view.queue_redraw()


func _set_unselect(value: float) -> void:
	_view.unselect_amount = value
	_view.queue_redraw()


func _set_blink(value: float) -> void:
	_view.guard_blink = value
	_view.queue_redraw()


static func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
