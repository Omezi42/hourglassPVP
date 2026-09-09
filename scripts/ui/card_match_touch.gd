class_name CardMatchTouch
extends RefCounted
## 盤面と手札を押す/ドラッグする操作の受け口(GameDesign.md 9章)。
##
## `card_match_screen.gd` が1000行の上限に達しているため切り出した(`CardMatchSpell` と
## 同じ流儀)。**押した先で何が起きるかの分岐だけ**を持ち、実際の適用は
## `MatchState` へ、対象選択の段取りは `CardMatchSpell` / `CardMatchEffectTarget` /
## `CardMatchFlipRight` へ渡す。

var _screen: CardMatchScreen


func _init(screen: CardMatchScreen) -> void:
	_screen = screen


func on_hand_pressed(view: CardView) -> void:
	var index := _screen._hand_views.find(view)
	if index < 0 or not _screen._my_turn():
		return
	if _screen.state.can_cast(_screen.my_side, index):
		_screen._spell.begin(index)
		return
	if not _screen.state.can_play(_screen.my_side, index):
		return
	_screen.selection.select_hand(index)
	_screen.refresh()


## 手札を空き枠へドラッグして出す(GameDesign.md 9章)。押して枠を選ぶ経路と同じ
## `_play_selected()` へ合流させ、設置効果の対象選択も同じように働くようにする。
func on_slot_drop(source: CardView, slot: int) -> void:
	var index := _screen._hand_views.find(source)
	if index < 0 or not _screen._my_turn() or _screen.state.board[_screen.my_side][slot] != null:
		return
	if _screen.state.can_cast(_screen.my_side, index):
		_screen._spell.begin(index)
		return
	if not _screen.state.can_play(_screen.my_side, index):
		return
	_screen.selection.select_hand(index)
	_play_selected(slot)


func on_own_slot_pressed(view: CardView) -> void:
	var slot := _screen._own_slots.find(view)
	if slot < 0 or not _screen._my_turn():
		return
	if _screen.selection.is_flip_right():
		_screen._flip_right.use_at(_screen.my_side, slot)
		return
	if _screen.selection.is_targeting():
		_handle_own_targeting(slot)
		return
	if _screen.selection.is_hand_selection():
		# 上書き設置は行わないため、埋まっている枠は選べない。
		if _screen.state.board[_screen.my_side][slot] == null:
			_play_selected(slot)
		return
	if _screen.state.board[_screen.my_side][slot] == null:
		_screen.selection.clear()
	else:
		_screen.selection.select_board(slot)
	_screen.refresh()


## 対象選択中に自分の場を押したとき(砂術の味方対象 / 設置効果の味方対象)。
func _handle_own_targeting(slot: int) -> void:
	if _screen.state.board[_screen.my_side][slot] == null:
		_screen.selection.clear()
		_screen.refresh()
		return
	# 味方1体を対象に取る砂術は、自分の駒を押して確定する。
	if _screen.selection.slot < 0:
		_screen._spell.cast_at(_screen.my_side, slot)
		return
	# 味方1体を対象に取る設置効果(ハロー/ピボット等)。
	var card: CardData = _screen.state.hand[_screen.my_side][_screen.selection.hand_index]
	if _screen._effect_target.target_side(card) == _screen.my_side:
		_screen._effect_target.confirm(_screen.my_side, slot)
		return
	_screen.selection.clear()
	_screen.refresh()


func on_foe_slot_pressed(view: CardView) -> void:
	var slot := _screen._foe_slots.find(view)
	if slot < 0 or not _screen._my_turn():
		return
	if _screen.selection.is_flip_right():
		_screen._flip_right.use_at(MatchState.other_side(_screen.my_side), slot)
		return
	if _screen.selection.is_targeting():
		_handle_foe_targeting(slot)
		return
	if (
		_screen.selection.is_board_selection()
		and _screen.state.can_attack(_screen.my_side, _screen.selection.slot, slot)
	):
		_screen._perform(MatchAction.attack(_screen.my_side, _screen.selection.slot, slot))
		_screen.selection.clear()
		_screen._hide_detail()
		_screen.refresh()


## 対象選択中に相手の場を押したとき(砂術の相手対象 / 設置効果の相手対象)。
func _handle_foe_targeting(slot: int) -> void:
	var foe := MatchState.other_side(_screen.my_side)
	if _screen.state.board[foe][slot] == null:
		return
	# slot が -1 のままなら砂術(置く枠を持たない)。
	if _screen.selection.slot < 0:
		_screen._spell.cast_at(foe, slot)
		return
	# 味方1体を対象に取る設置効果は相手の場を押しても確定しない
	# (自分の場を押させる。`_handle_own_targeting()` 側で処理する)。
	var card: CardData = _screen.state.hand[_screen.my_side][_screen.selection.hand_index]
	if _screen._effect_target.target_side(card) != foe:
		return
	_screen._effect_target.confirm(foe, slot)


func on_face_pressed() -> void:
	if not _screen._my_turn() or not _screen.selection.is_board_selection():
		return
	if not _screen.state.can_attack(_screen.my_side, _screen.selection.slot, -1):
		return
	_screen._perform(MatchAction.attack(_screen.my_side, _screen.selection.slot, -1))
	_screen.selection.clear()
	_screen.refresh()


## 相手1体・味方1体を対象に取る設置効果は、出す前に対象を選ばせる(GameDesign.md 9章)。
## 対象がいなければ選ばせる意味がないため、そのまま出す(`CardMatchEffectTarget` が判断する)。
func _play_selected(slot: int) -> void:
	_screen._effect_target.begin(_screen.selection.hand_index, slot)
