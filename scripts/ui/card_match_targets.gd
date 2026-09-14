class_name CardMatchTargets
extends RefCounted
## 選んでいるものに応じて、置ける枠・殴れる相手を光らせ、戦闘の予測を出す
## (GameDesign.md 9章)。
##
## `card_match_screen.gd` が1000行の上限に達しているため切り出した。
## 対局画面の状態(選択・盤面の表示)を読むだけで、自分では何も持たない。

var _screen: CardMatchScreen


func _init(screen: CardMatchScreen) -> void:
	_screen = screen


func refresh() -> void:
	var state := _screen.state
	var selection := _screen.selection
	var my_side := _screen.my_side
	var foe := MatchState.other_side(my_side)
	_screen.foe_bar.targetable = false
	if selection.is_flip_right():
		# 反転権は敵味方どちらの砂時計も対象に取れる(GameDesign.md 2章)。
		for side in [my_side, foe]:
			for slot in MatchState.BOARD_SIZE:
				_screen.view_at(side, slot).selected = state.board[side][slot] != null
		return
	if selection.is_targeting():
		# 砂術は置く枠を持たないため slot が -1 のまま。対象がどちら側かはカードが決める
		# (GameDesign.md 6章)。砂時計の設置効果(ハロー/ピボット等の味方対象を含む)も
		# 同じくカードが決めた側を光らせる。
		var card: CardData = state.hand[my_side][selection.hand_index]
		var side: int = (
			_screen._spell.target_side(card)
			if selection.slot < 0
			else _screen._effect_target.target_side(card)
		)
		for slot in MatchState.BOARD_SIZE:
			_screen.view_at(side, slot).selected = state.board[side][slot] != null
		return
	if selection.is_hand_selection():
		for slot in MatchState.BOARD_SIZE:
			_screen.view_at(my_side, slot).selected = state.board[my_side][slot] == null
		return
	if not selection.is_board_selection():
		return
	_screen.view_at(my_side, selection.slot).selected = true
	var attacker: CardInstance = state.board[my_side][selection.slot]
	if attacker == null or not attacker.can_attack():
		return
	for slot in state.attackable_slots(foe):
		var view := _screen.view_at(foe, slot)
		view.selected = true
		var preview: Dictionary = state.combat_preview(my_side, selection.slot, slot)
		view.preview_health = preview["target_health"]
		view.preview_dead = preview["target_dead"]
	_screen.foe_bar.targetable = state.can_attack_player(my_side)
	refresh_own_preview()


## 攻撃側の「この攻撃の後どうなるか」だけを組み直す。指している相手が変わったときに
## 盤面全体を同期し直さずに済むよう、相手側の予測とは分けてある。
##
## 相打ちである以上、攻撃側の結果まで見せないと判断できない。**狙う相手の上に
## カーソルがある間はその1組の結果**を出し、離れているときは狙える相手が複数いて
## 1つに定まらないため**最も自分が削られる組**(最悪の場合)を出す(GameDesign.md 9章)。
## 安全に見えて実は死ぬ、という取り違えを避けるため。
func refresh_own_preview() -> void:
	var state := _screen.state
	var selection := _screen.selection
	var my_side := _screen.my_side
	var own: CardView = _screen.view_at(my_side, selection.slot)
	own.preview_health = -1
	own.preview_dead = false
	own.queue_redraw()
	if not selection.is_board_selection():
		return
	var attacker: CardInstance = state.board[my_side][selection.slot]
	if attacker == null or not attacker.can_attack():
		return
	var candidates: Array = state.attackable_slots(MatchState.other_side(my_side))
	if state.can_attack_player(my_side):
		candidates.append(CardMatchSelection.FACE)
	if selection.hover_target in candidates:
		candidates = [selection.hover_target]
	for slot in candidates:
		var preview: Dictionary = state.combat_preview(my_side, selection.slot, slot)
		var worse: bool = own.preview_health < 0 or preview["attacker_health"] < own.preview_health
		if worse:
			own.preview_health = preview["attacker_health"]
			own.preview_dead = preview["attacker_dead"]
