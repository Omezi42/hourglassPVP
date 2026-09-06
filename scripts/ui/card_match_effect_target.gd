class_name CardMatchEffectTarget
extends RefCounted
## 砂時計を場へ出すときの設置効果の対象選択(GameDesign.md 9章)。
##
## `card_match_screen.gd` が1000行の上限に達しているため切り出した。
## `CardMatchSpell` と同じく、対局画面の状態を読んで `MatchAction.play()` を
## 投げるだけで、自分では何も持たない。

var _screen: CardMatchScreen


func _init(screen: CardMatchScreen) -> void:
	_screen = screen


## その砂時計の設置効果が対象を1体選ぶなら、どちら側から選ぶか。取らないなら -1。
func target_side(card: CardData) -> int:
	for effect in card.effects_for(CardEnums.Trigger.ON_PLAY):
		if effect.target == CardEnums.EffectTarget.ENEMY_UNIT:
			return MatchState.other_side(_screen.my_side)
		if effect.target == CardEnums.EffectTarget.ALLY_UNIT:
			return _screen.my_side
	return -1


## 手札の1枚を出す。対象を取り、かつ選べる相手がいるときだけ対象選択へ入る。
func begin(index: int, slot: int) -> void:
	var card: CardData = _screen.state.hand[_screen.my_side][index]
	var side := target_side(card)
	if side >= 0 and not _screen.state.units(side).is_empty():
		_screen.selection.await_target(index, slot)
		_screen.refresh()
		return
	_screen._perform(MatchAction.play(_screen.my_side, index, slot))
	_screen.selection.clear()
	_screen.refresh()


## 対象選択中の砂時計を、選ばれた1体を対象にして出す。
func confirm(side: int, slot: int) -> void:
	var selection := _screen.selection
	var target := {"side": side, "slot": slot}
	_screen._perform(
		MatchAction.play(_screen.my_side, selection.hand_index, selection.slot, target)
	)
	_screen.selection.clear()
	_screen._hide_detail()
	_screen.refresh()
