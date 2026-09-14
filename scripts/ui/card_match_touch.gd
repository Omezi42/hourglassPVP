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
	# 放した座標を控えておく。台座の中心へ短く滑ってから着地する
	# (GameDesign.md 9章「対局画面の手触り」)。クリックで枠を選んだ場合は控えないため、
	# その場合は従来どおり滑らずに着地する。
	_screen.effects.queue_drop_origin(_screen.my_side, slot, _screen.get_global_mouse_position())
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
		_screen._cancel_selection()
	else:
		_screen.selection.select_board(slot)
	_screen.refresh()


## 対象選択中に自分の場を押したとき(砂術の味方対象 / 設置効果の味方対象)。
func _handle_own_targeting(slot: int) -> void:
	if _screen.state.board[_screen.my_side][slot] == null:
		_screen._cancel_selection()
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
	if _screen.selection.is_board_selection():
		_attack(_screen.selection.slot, slot)


## 自分の駒をドラッグで掴んだ瞬間、押して選んだのと同じ状態にする(GameDesign.md 9章)。
## 狙える相手が光り、相打ちの予測が出た状態で運べる。**駒の中心から指先へ矢印を引く**
## (同章「対局画面の手触り」)。
func on_own_slot_drag_started(view: CardView) -> void:
	var slot := _screen._own_slots.find(view)
	if slot < 0 or not _screen._my_turn() or _screen.state.board[_screen.my_side][slot] == null:
		return
	_screen.selection.select_board(slot)
	_screen._hide_detail()
	_screen.refresh()
	_screen.drag_arrow.begin(CardFlipBeam.unit_center(view))


## ドラッグを放した/取り消した(GameDesign.md 9章「対局画面の手触り」)。矢印を消す。
func on_own_slot_drag_ended() -> void:
	_screen.drag_arrow.end()


## 自分の駒を相手の駒へ落として攻撃する。押して選ぶ経路と同じ `_attack()` へ合流させる。
func on_foe_slot_drop(source: CardView, slot: int) -> void:
	_attack(_screen._own_slots.find(source), slot)


## 自分の駒を相手のHP帯へ落として本体を殴る。
func on_face_drop(source: CardView) -> void:
	_attack(_screen._own_slots.find(source), -1)


func _attack(slot: int, target_slot: int) -> void:
	if slot < 0 or not _screen._my_turn():
		return
	if not _screen.state.can_attack(_screen.my_side, slot, target_slot):
		return
	# **ここで `_screen.refresh()` を呼んではいけない。**攻撃は `_perform()` の中で
	# `CardMatchStrike` が演出を組み、盤面の再同期(`refresh()`)は演出が当たって
	# 台座へ戻りきった `on_strike_finished()` まで自然に遅延される。ここで
	# 即座に呼び直すと、`MatchAction.apply()` で既に更新済みの盤面(破壊された駒が
	# `null` になった状態)を演出の最中に読み直してしまい、**攻撃側・防御側の
	# どちらも、実際に当たるより前に消えて見える**(実際にこれで踏んだ)。
	_screen._perform(MatchAction.attack(_screen.my_side, slot, target_slot))
	_screen.selection.clear()
	_screen._hide_detail()


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
	if _screen.selection.is_board_selection():
		_attack(_screen.selection.slot, -1)


## 相手1体・味方1体を対象に取る設置効果は、出す前に対象を選ばせる(GameDesign.md 9章)。
## 対象がいなければ選ばせる意味がないため、そのまま出す(`CardMatchEffectTarget` が判断する)。
func _play_selected(slot: int) -> void:
	# 出す前に手札の位置を控える(GameDesign.md 9章「対局画面の手触り」)。出た瞬間には
	# もう手札から消えているため、支払いのピップが吸い込まれる先をいまのうちに渡しておく。
	var hand_index := _screen.selection.hand_index
	if hand_index >= 0 and hand_index < _screen._hand_views.size():
		var view := _screen._hand_views[hand_index]
		_screen.effects.queue_spend_origin(_screen.my_side, view.global_position + view.size * 0.5)
	_screen._effect_target.begin(hand_index, slot)
