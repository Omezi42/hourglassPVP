class_name CardMatchSpell
extends RefCounted
## 砂術を撃つ操作の段取り(GameDesign.md 6章)。
##
## `card_match_screen.gd` が1000行の上限に達しているため切り出した。
## 対局画面の状態を読んで `MatchAction.cast()` を投げるだけで、自分では何も持たない。

var _screen: CardMatchScreen


func _init(screen: CardMatchScreen) -> void:
	_screen = screen


## 手札の1枚を撃つ。盤面の枠を選ばせず、対象を取るものだけ対象選択へ入る。
## **選択の `slot` を -1 のままにしておく**ことで、対象を押したときに
## 「砂術か、置く枠まで決まった砂時計か」を1つの値で見分けられる。
func begin(index: int) -> void:
	var card: CardData = _screen.state.hand[_screen.my_side][index]
	var side := target_side(card)
	if side >= 0 and not _screen.state.units(side).is_empty():
		_screen.selection.await_target(index, -1)
		_screen.refresh()
		return
	_screen._perform(MatchAction.cast(_screen.my_side, index))
	_screen.selection.clear()
	_screen._hide_detail()
	_screen.refresh()


## 対象選択中の砂術を、選ばれた1体へ撃つ。
func cast_at(side: int, slot: int) -> void:
	var index: int = _screen.selection.hand_index
	_screen._perform(MatchAction.cast(_screen.my_side, index, {"side": side, "slot": slot}))
	_screen.selection.clear()
	_screen._hide_detail()
	_screen.refresh()


## その砂術が対象を1体選ぶなら、どちら側から選ぶか。取らないなら -1。
func target_side(card: CardData) -> int:
	for effect in card.effects_for(CardEnums.Trigger.ON_PLAY):
		if effect.target == CardEnums.EffectTarget.ENEMY_UNIT:
			return MatchState.other_side(_screen.my_side)
		if effect.target == CardEnums.EffectTarget.ALLY_UNIT:
			return _screen.my_side
	return -1
