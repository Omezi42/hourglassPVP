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
	if selection.is_targeting():
		# 砂術は置く枠を持たないため slot が -1 のまま。対象がどちら側かはカードが決める
		# (GameDesign.md 6章)。砂時計の設置効果は従来どおり相手側だけを光らせる。
		var side := foe
		if selection.slot < 0:
			var card: CardData = state.hand[my_side][selection.hand_index]
			side = _screen._spell.target_side(card)
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
		_show_preview(view, slot)
	_screen.foe_bar.targetable = state.can_attack_player(my_side)


## 「この攻撃の後どうなるか」を、狙える相手の駒と自分の駒の両方へ出す。
## 相打ちである以上、攻撃側の結果まで見せないと判断できない。
## 攻撃側の予測は狙える相手が複数いると1つに定まらないため、**最も自分が削られる組**
## (最悪の場合)を出す。安全に見えて実は死ぬ、という取り違えを避けるため。
func _show_preview(view: CardView, target_slot: int) -> void:
	var selection := _screen.selection
	var preview: Dictionary = _screen.state.combat_preview(
		_screen.my_side, selection.slot, target_slot
	)
	if preview.is_empty():
		return
	view.preview_health = preview["target_health"]
	view.preview_dead = preview["target_dead"]
	var own: CardView = _screen.view_at(_screen.my_side, selection.slot)
	var worse: bool = own.preview_health < 0 or preview["attacker_health"] < own.preview_health
	if worse:
		own.preview_health = preview["attacker_health"]
		own.preview_dead = preview["attacker_dead"]
