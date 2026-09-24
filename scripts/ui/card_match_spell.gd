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
	# 出す前に手札の位置を控える(GameDesign.md 9章「対局画面の手触り」)。撃った瞬間には
	# もう墓地へ消えているため、支払いのピップが吸い込まれる先をいまのうちに渡しておく。
	var view := _screen._hand_views[index]
	_screen.effects.queue_spend_origin(_screen.my_side, view.global_position + view.size * 0.5)
	var side := target_side(card)
	if side >= 0 and CardMatchEffectTarget.has_candidate(_screen.state, card, side):
		_screen.selection.await_target(index, -1)
		_screen.refresh()
		return
	# `_perform()` が `_finish_action()` の中で `refresh()` まで済ませるため、
	# ここで重ねて呼ばない(`CardMatchEffectTarget.begin()` と同じ理由)。
	_screen.selection.clear()
	_screen._perform(MatchAction.cast(_screen.my_side, index))
	_screen._hide_detail()


## 対象選択中の砂術を、選ばれた1体へ撃つ。
func cast_at(side: int, slot: int) -> void:
	var index: int = _screen.selection.hand_index
	# **`_perform()` より先に選択を解除する**(`CardMatchEffectTarget.confirm()` と同じ理由。
	# 選択を残したまま呼ぶと、`refresh()` が既に手札から消えたカードを読みに行って落ちる)。
	_screen.selection.clear()
	# **ここでも `_screen.refresh()` を重ねて呼ばない**。単体へダメージを与える砂術
	# (砕砂等)は紋章が対象へ飛ぶ演出(`CardMatchEffectStrike`)を組んでおり、
	# `_finish_action()` がその演出が終わるまで `refresh()` を遅らせる。
	_screen._perform(MatchAction.cast(_screen.my_side, index, {"side": side, "slot": slot}))
	_screen._hide_detail()


## その砂術が対象を1体選ぶなら、どちら側から選ぶか。取らないなら -1。
func target_side(card: CardData) -> int:
	return CardMatchEffectTarget.side_for(card, _screen.my_side)
