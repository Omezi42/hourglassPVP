class_name CardViewPose
extends RefCounted
## 場の駒の拡縮(GameDesign.md 9章「対局画面の手触り」)。自分の駒は乗せると台座から立ち上がり、
## 押すと沈み、選ぶと構えたまま。身構え(狙われる相手)は縮む。倍率は `target_factor()` が1つに決め、
## 1本の tween で動かす。支点は台座の中心(駒が台座から離れず、上へ伸びる)。
##
## 駒の `scale` は置き場所の縮尺 `base_scale` にこの倍率を掛けた値。手札は `CardView._zoom()` が持つ。
## 攻撃の演出は絵の描画だけを動かし `scale` を触らないため、演出中は倍率を動かさず、終わってから合わせる。

const PIVOT_MIN_GAP := 0.02
const PIVOT_LIMIT := 1000.0

var _view: CardView
var _tween: Tween
var _factor := 1.0
var _goal := 1.0
var _pending := false


func _init(view: CardView) -> void:
	_view = view


## 倍率を決める値が変わった。同じフレームの中で変わり続ける値(`refresh()` が選択を一度外して付け直す)
## に振り回されないよう、フレームの終わりに1度だけ評価する。
func request() -> void:
	if _pending:
		return
	_pending = true
	_apply.call_deferred()


## 掴んだ瞬間にわずかに膨らんでから収まる。
func pop() -> void:
	if _view.mode != CardView.Mode.BOARD:
		return
	_start(CardView.BOARD_GRAB_POP_SCALE, _target_factor(), true)


## 置き場所の縮尺が変わった。倍率はそのまま、掛け合わせた `scale` と支点だけ合わせる。
func resync() -> void:
	if not is_equal_approx(_factor, 1.0):
		_set_factor(_factor)


func factor() -> float:
	return _factor


func _apply() -> void:
	_pending = false
	if not _view.is_inside_tree():
		return
	if _view.mode != CardView.Mode.BOARD or _view.striking:
		return
	var goal := _target_factor()
	if is_equal_approx(goal, _goal):
		return
	_start(_factor, goal, goal > _factor)


## 上が勝つ。押している > 身構え > 選択・ホバー・攻撃ドラッグの元。
func _target_factor() -> float:
	var view := _view
	if view.card == null:
		return 1.0
	if view.operable and view.pressed_down:
		return CardView.BOARD_PRESS_SCALE
	if view.brace:
		return CardView.BRACE_SCALE
	if view.drag_source:
		return CardView.BOARD_READY_SCALE
	if view.operable and (view.selected or view._hovering):
		return CardView.BOARD_READY_SCALE
	return 1.0


func _start(from: float, to: float, rise: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_goal = to
	_set_factor(from)
	_tween = _view.create_tween()
	if rise:
		_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_method(_set_factor, from, to, CardView.BOARD_RISE_DURATION)
	else:
		_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_method(_set_factor, from, to, CardView.BOARD_SINK_DURATION)


func _set_factor(factor: float) -> void:
	_factor = factor
	var total := _view.base_scale * factor
	_view.scale = Vector2.ONE * total
	_view.pivot_offset = _pivot(factor, total)


## 置き場所の配置は駒の中心を軸にした縮尺を前提にしている。倍率を台座の中心を軸に掛けた結果と
## 同じ見た目になるよう、その合計の縮尺に対応する支点を逆算する(倍率1のときは中心のまま)。
func _pivot(factor: float, total: float) -> Vector2:
	var center := _view.size * 0.5
	var pedestal := Vector2(_view.size.x * 0.5, CardView.PEDESTAL_CENTER_Y)
	var shift := (1.0 - factor) * _view.base_scale * (pedestal - center)
	if shift == Vector2.ZERO:
		return center
	var gap := 1.0 - total
	if absf(gap) < PIVOT_MIN_GAP:
		gap = PIVOT_MIN_GAP if gap >= 0.0 else -PIVOT_MIN_GAP
	var offset := (shift / gap).limit_length(PIVOT_LIMIT)
	return center + offset
