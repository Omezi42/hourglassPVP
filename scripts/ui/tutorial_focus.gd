class_name TutorialFocus
extends RefCounted
## 誘導対局で光らせる場所の矩形(GameDesign.md 18章)。いま触るもの(輪郭)と、
## いま話題にしている数字(色違いの光)を、台本の1手から対局画面の座標へ写す。
## いつ光らせるか(説明を読んでいる間か)は `CardMatchTutorial` が決め、ここは場所だけを答える。

var _screen: CardMatchScreen
var _state: MatchState
var _my_side: int
## 台本の参照名 → 盤面の枠(`CardMatchTutorial._slot_of()`)。
var _slot_of: Callable


func _init(screen: CardMatchScreen, state: MatchState, my_side: int, slot_of: Callable) -> void:
	_screen = screen
	_state = state
	_my_side = my_side
	_slot_of = slot_of


## 台本の手が求める操作の場所。
func action_rects(step: Dictionary) -> Array[Rect2]:
	var found: Array[Rect2] = []
	match str(step.get("kind", "")):
		"mulligan":
			if _state.mulligan_pending and _screen._mulligan != null:
				found.append(_screen._mulligan.confirm_rect())
		"play":
			found.append_array(_hand_rects_for(str(step.get("card_id", ""))))
		"end_turn":
			found.append(_screen._geometry.end_turn_button_rect())
		"attack":
			found.append_array(_attack_rects(step))
		"flip":
			var slot: int = _slot_of.call(_my_side, str(step.get("actor_ref", "")))
			if slot >= 0:
				found.append(_slot_rect(_my_side, slot))
		"flip_right":
			# 反転権のボタンを押す前はボタンを、押した後は対象を囲む(攻撃の段と同じ2段階)。
			if not _screen.selection.is_flip_right():
				found.append(_screen._flip_right.button_rect())
				return found
			var wants_side := (
				_my_side
				if str(step.get("target_side", "")) == "own"
				else MatchState.other_side(_my_side)
			)
			var target: int = _slot_of.call(wants_side, str(step.get("target_ref", "")))
			if target >= 0:
				found.append(_slot_rect(wants_side, target))
	return found


## 台本の手が話題にしている数字(GameDesign.md 18章「数字の光」)。
func number_rects(step: Dictionary) -> Array[Rect2]:
	var found: Array[Rect2] = []
	match str(step.get("topic", "")):
		"mana":
			found.append(_screen._geometry.mana_badge_rect(_my_side))
		"stats":
			var slot: int = _slot_of.call(_my_side, str(step.get("ref", "")))
			if slot >= 0:
				found.append_array(_screen._geometry.unit_stat_rects(_my_side, slot))
		"foe_hp":
			found.append(_screen._geometry.hp_bar_global_rect(MatchState.other_side(_my_side)))
		"flip_right":
			found.append(_screen._geometry.flip_right_gauge_rect())
	return found


func _hand_rects_for(card_id: String) -> Array[Rect2]:
	var found: Array[Rect2] = []
	var hand: Array = _state.hand[_my_side]
	for i in hand.size():
		var card: CardData = hand[i]
		if card.id == card_id and i < _screen._hand_views.size():
			var view := _screen._hand_views[i]
			found.append(Rect2(view.position, view.size))
			break
	return found


## 攻撃の段は2段階で囲む。自分の駒を選ぶ前は台本の駒を、選んだ後はその駒で殴る相手
## (駒か本体のHP帯)を囲み、次に押す場所へ視線を運ぶ(GameDesign.md 18章)。
func _attack_rects(step: Dictionary) -> Array[Rect2]:
	var found: Array[Rect2] = []
	var actor_slot: int = _slot_of.call(_my_side, str(step.get("actor_ref", "")))
	if actor_slot < 0:
		return found
	var foe_side := MatchState.other_side(_my_side)
	var chosen: CardMatchSelection = _screen.selection
	if chosen.is_board_selection() and chosen.slot == actor_slot:
		if str(step.get("target_kind", "")) == "face":
			found.append(_screen._geometry.hp_bar_global_rect(foe_side))
		else:
			var target_slot: int = _slot_of.call(foe_side, str(step.get("target_ref", "")))
			if target_slot >= 0:
				found.append(_slot_rect(foe_side, target_slot))
		return found
	found.append(_slot_rect(_my_side, actor_slot))
	return found


func _slot_rect(side: int, slot: int) -> Rect2:
	var view := _screen.view_at(side, slot)
	return Rect2(view.position, view.size)
