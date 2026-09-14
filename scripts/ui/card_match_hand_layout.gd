class_name CardMatchHandLayout
extends RefCounted
## 手札の並べ方(GameDesign.md 9章「対局画面の手触り」)。
##
## `card_match_screen.gd` が1000行の上限に近いため、`_refresh_hand()` にあった位置計算を
## ここへ移した。**位置は代入ではなく Tween で滑らせる**(ドローで入った札に他の札が
## 場所を空ける動きを見せる)。直前まで非表示だった札(新しく配られた札)だけは
## 出所の無い移動に見えないよう即座に置く。
##
## ホバー中の札の両隣を外へ避け、相手の手番の間は手札全体を沈めて暗くする
## (GameDesign.md 9章)。

const SLIDE_DURATION := 0.15
## カーソルを乗せた札の両隣を避ける量。
const AVOID_PX := 12.0
const AVOID_DURATION := 0.12
## 相手の手番の間、手札全体を沈める量。`CardView.SUMMONED_SINK` と同じ語彙。
const TURN_SINK := CardView.SUMMONED_SINK
const ACTIVE_MODULATE := Color(1, 1, 1, 1)
const INACTIVE_MODULATE := Color(0.82, 0.82, 0.85, 1.0)

var _screen: CardMatchScreen
## 直近の `apply()` が決めた、避け・沈みを含まない素の位置。
var _base_positions: Dictionary = {}
## 直前の `apply()` でその枠が表示されていたか(index基準)。
var _was_visible: Array[bool] = []
var _tweens: Dictionary = {}
## いま避けている札 → その札にかけているオフセット(x)。
var _avoid_offsets: Dictionary = {}
var _hovered_index := -1


func _init(screen: CardMatchScreen) -> void:
	_screen = screen


## 手札の位置・沈み・暗さをまとめて更新する。避けている札があれば、その分だけ
## 素の位置からずらして置く(でなければ `apply()` のたびに避けが解けてしまう)。
func apply(hand: Array, my_turn: bool) -> void:
	var views := _screen._hand_views
	if _was_visible.size() != views.size():
		_was_visible.resize(views.size())
		_was_visible.fill(false)
	var count := mini(hand.size(), views.size())
	if _hovered_index >= count:
		_hovered_index = -1
		_avoid_offsets.clear()
	var area := CardMatchScreen.HAND_AREA
	var step := CardView.HAND_SIZE_PX.x + CardMatchScreen.HAND_GAP
	if count > 1:
		step = minf(step, (area.size.x - CardView.HAND_SIZE_PX.x) / float(count - 1))
	var width := CardView.HAND_SIZE_PX.x + maxf(count - 1, 0) * step
	var start := area.position.x + (area.size.x - width) * 0.5
	var top := CardMatchScreen.HAND_TOP + (0.0 if my_turn else TURN_SINK)
	var tint := ACTIVE_MODULATE if my_turn else INACTIVE_MODULATE
	for i in views.size():
		var view := views[i]
		if i >= count:
			view.visible = false
			_was_visible[i] = false
			_avoid_offsets.erase(view)
			continue
		var base := Vector2(start + i * step, top)
		_base_positions[view] = base
		var target: Vector2 = base + Vector2(_avoid_offsets.get(view, 0.0), 0.0)
		view.visible = true
		view.size = CardView.HAND_SIZE_PX
		view.modulate = tint
		if _was_visible[i]:
			_slide(view, target)
		else:
			view.position = target
		_was_visible[i] = true


## カーソルを乗せた札の両隣を外へ避ける(GameDesign.md 9章)。
func on_hovered(view: CardView) -> void:
	var views := _screen._hand_views
	var index := views.find(view)
	if index < 0 or index == _hovered_index:
		return
	_hovered_index = index
	_restore_avoided()
	if index > 0:
		_avoid(views[index - 1], -AVOID_PX)
	if index + 1 < views.size() and views[index + 1].visible:
		_avoid(views[index + 1], AVOID_PX)


func on_left() -> void:
	_hovered_index = -1
	_restore_avoided()


## 前の対局の位置を持ち越さない(GameDesign.md 9章)。次の `apply()` は全札を即座に置く。
func reset() -> void:
	for tween in _tweens.values():
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()
	_base_positions.clear()
	_avoid_offsets.clear()
	_hovered_index = -1
	_was_visible.fill(false)


func _avoid(view: CardView, offset_x: float) -> void:
	_avoid_offsets[view] = offset_x
	var base: Vector2 = _base_positions.get(view, view.position)
	_slide(view, base + Vector2(offset_x, 0.0), AVOID_DURATION)


func _restore_avoided() -> void:
	for view in _avoid_offsets.keys():
		if is_instance_valid(view):
			_slide(view, _base_positions.get(view, view.position), AVOID_DURATION)
	_avoid_offsets.clear()


func _slide(view: CardView, target: Vector2, duration: float = SLIDE_DURATION) -> void:
	var tween: Tween = _tweens.get(view)
	if tween != null and tween.is_valid():
		tween.kill()
	tween = view.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "position", target, duration)
	_tweens[view] = tween
