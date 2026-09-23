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
	# `_perform()` が `_finish_action()` の中で `refresh()` まで済ませる
	# (単体を狙う設置効果は紋章が届くまで遅らせる。`CardMatchEffectStrike`)ため、
	# ここで重ねて呼ぶと、その演出より先に盤面を再同期してしまう。
	# 選択は `_perform()` より先に解除する。残したままだと、その `refresh()` で
	# 詰めて同じ位置へ来た次の手札が選択状態で描かれる。
	_screen.selection.clear()
	_screen._perform(MatchAction.play(_screen.my_side, index, slot))


## 対象選択中の砂時計を、選ばれた1体を対象にして出す。
func confirm(side: int, slot: int) -> void:
	var selection := _screen.selection
	var hand_index := selection.hand_index
	var play_slot := selection.slot
	var target := {"side": side, "slot": slot}
	# **`_perform()` より先に選択を解除する。**`_perform()` は演出を挟まない手なら
	# 同じ呼び出しの中で `refresh()` まで進み、`CardMatchTargets.refresh()` が
	# `selection.is_targeting()` を見て手札を読み直す。選択を残したまま呼ぶと、
	# 既に場へ出て手札から消えたカードを `hand_index` で読みに行き、
	# 「Out of bounds get index」で落ちる(実際に踏んだ)。
	_screen.selection.clear()
	# **ここでも `_screen.refresh()` を重ねて呼ばない**(直前のコメントと同じ理由)。
	# ハンマーのように単体へダメージを与える設置効果は、紋章が対象へ飛んで実際に
	# 当てる演出(`CardMatchEffectStrike`)を組んでおり、`_finish_action()` が
	# その演出が終わるまで `refresh()` を遅らせる。ここで呼び直すと、演出の途中で
	# 既にダメージ・破壊済みの盤面を見せてしまう。
	_screen._perform(MatchAction.play(_screen.my_side, hand_index, play_slot, target))
	_screen._hide_detail()
