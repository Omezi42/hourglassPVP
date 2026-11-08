class_name CardMatchSpellDrag
extends RefCounted
## 砂術をドラッグして撃つ操作(GameDesign.md 9章「砂術」)。**砂術はドラッグでしか撃てない。**
##
## 手札の上端より上へ運んだかどうかで札の姿を変える。対象を取るものは札が卓の左へ移って
## 矢印を伸ばし(`CardSpellAim`)、取らないものは指先の札が光る(`CardDragPreview.set_armed()`)。
## 撃った後の予測は対局の写しへ実際に撃って求める(`SpellForecast`)。
##
## `card_match_screen.gd` が1000行の上限に近いため、ここへ切り出している。

var _screen: CardMatchScreen
var _view: CardView
var _index := -1
var _card: CardData
## 対象を1体選ぶか。墓地から選ぶもの・選べる対象がいないものは、取らないものと同じに扱う。
var _targeted := false
var _above := false
var _done := true
## 指している対象。{"side", "slot"}。指していなければ空。
var _pointed: Dictionary = {}
var _forecast_views: Array[CardView] = []


func _init(screen: CardMatchScreen) -> void:
	_screen = screen


func active() -> bool:
	return not _done


## 手札の砂術を掴んだ。対象を取るものは掴んだ時点で対象を光らせる。
func begin(view: CardView, index: int) -> void:
	_view = view
	_index = index
	_card = _screen.state.hand[_screen.my_side][index]
	_done = false
	_above = false
	_pointed = {}
	var side := _screen._spell.target_side(_card)
	_targeted = (
		CardEffectResolver.grave_choice_effect(_card) == null
		and side >= 0
		and CardMatchEffectTarget.has_candidate(_screen.state, _card, side)
	)
	if _targeted:
		_screen.selection.await_target(index, -1)
		_screen.refresh()


## 毎フレーム。手札の上端を越えたか、何を指しているかで姿と予測を組み直す。
func tick() -> void:
	if _done:
		return
	_screen._own_bar.highlight_cost(_screen.state.play_cost(_screen.my_side, _card))
	var mouse := _screen.get_local_mouse_position()
	var layout := _screen.layout
	var above := mouse.y < layout.hand_area.position.y and mouse.x < layout.play_right
	if above != _above:
		_above = above
		_switch(mouse)
	if _targeted and _above:
		_point(_target_under(_screen.get_global_mouse_position()))


## 対象・盤面へ落とされた(`CardMatchTouch` のドロップから)。`slot` が -1 なら相手のHP帯。
func drop(side: int, slot: int) -> void:
	if _done:
		return
	if not _targeted:
		if _above:
			_release()
		return
	if not _above or not _can_target(side, slot):
		return
	var from := _screen._spell_aim.card_center()
	_finish()
	_screen._effect_strike.note_spell_origin(_screen.my_side, from)
	_screen._spell.cast_at(side, slot)


## ドラッグが終わった。落とし先の無い所で離しても、取らないものは光っていれば撃つ。
func end() -> void:
	if _done:
		return
	if not _targeted and _above:
		_release()
		return
	_finish()


func _release() -> void:
	var from := _screen.get_local_mouse_position()
	_finish()
	_screen._effect_strike.note_spell_origin(_screen.my_side, from)
	_screen._spell.release(_index)


func _finish() -> void:
	_done = true
	_screen._spell_aim.hide_card()
	_clear_forecast()
	_point({})
	_screen._own_bar.highlight_cost(0)


func _switch(mouse: Vector2) -> void:
	var preview := _view.drag_preview if is_instance_valid(_view) else null
	if _targeted:
		if preview != null:
			preview.set_hidden(_above)
		if _above:
			_screen._spell_aim.show_card(_card, mouse, _screen.layout)
		else:
			_screen._spell_aim.hide_card()
			_point({})
		return
	if preview != null:
		preview.set_armed(_above)
	if _above:
		_show_forecast({})
	else:
		_clear_forecast()


func _point(target: Dictionary) -> void:
	if target == _pointed:
		return
	if not _pointed.is_empty() and _pointed["slot"] >= 0:
		_screen.view_at(_pointed["side"], _pointed["slot"]).brace = false
	_pointed = target
	var valid := not target.is_empty()
	_screen._spell_aim.set_valid(valid)
	if not valid:
		_clear_forecast()
		return
	if target["slot"] >= 0:
		_screen.view_at(target["side"], target["slot"]).brace = true
	_show_forecast(target)


## 指先の下にある、狙える対象。無ければ空。
func _target_under(point: Vector2) -> Dictionary:
	var foe := MatchState.other_side(_screen.my_side)
	for side in [foe, _screen.my_side]:
		for slot in MatchState.BOARD_SIZE:
			var view := _screen.view_at(side, slot)
			if view.visible and view.get_global_rect().has_point(point):
				return {"side": side, "slot": slot} if _can_target(side, slot) else {}
	if _screen.foe_bar.get_global_rect().has_point(point) and _can_target(foe, -1):
		return {"side": foe, "slot": -1}
	return {}


func _can_target(side: int, slot: int) -> bool:
	if slot < 0:
		return (
			side == MatchState.other_side(_screen.my_side)
			and CardMatchEffectTarget.can_target_face(_card)
		)
	return CardMatchEffectTarget.can_target(_screen.state, _card, side, slot)


func _show_forecast(target: Dictionary) -> void:
	_clear_forecast()
	var changes := SpellForecast.compute(_screen.state, _screen.my_side, _index, target)
	for change in changes:
		var view := _screen.view_at(change["side"], change["slot"])
		view.preview_health = change["health"]
		view.preview_dead = change["dead"]
		view.queue_redraw()
		_forecast_views.append(view)


func _clear_forecast() -> void:
	for view in _forecast_views:
		view.preview_health = -1
		view.preview_dead = false
		view.queue_redraw()
	_forecast_views.clear()
