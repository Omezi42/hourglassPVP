class_name CardMatchSpell
extends RefCounted
## 砂術を撃つ操作の段取り(GameDesign.md 6章)。
##
## `card_match_screen.gd` が1000行の上限に達しているため切り出した。
## 対局画面の状態を読んで `MatchAction.cast()` を投げるだけで、自分では何も持たない。

var _screen: CardMatchScreen


func _init(screen: CardMatchScreen) -> void:
	_screen = screen


## 対象を1体選ばない砂術を、手札の上端より上で離して撃つ(GameDesign.md 9章「砂術」)。
## 墓地から選ぶものはここで一覧を開く。対象を取るのに選べる対象がいないものは、対象なしで撃つ(不発)。
func release(index: int) -> void:
	var card: CardData = _screen.state.hand[_screen.my_side][index]
	# 出す前に手札の位置を控える(GameDesign.md 9章「対局画面の手触り」)。撃った瞬間には
	# もう墓地へ消えているため、支払いのピップが吸い込まれる先をいまのうちに渡しておく。
	var view := _screen._hand_views[index]
	_screen.effects.queue_spend_origin(_screen.my_side, view.global_position + view.size * 0.5)
	if CardMatchEffectTarget.choose_from_grave(
		_screen,
		CardEffectResolver.acting_card(_screen.state, _screen.my_side, card),
		func(target: Dictionary) -> void:
			_screen._perform(MatchAction.cast(_screen.my_side, index, target))
	):
		return
	# `_perform()` が `_finish_action()` の中で `refresh()` まで済ませるため、
	# ここで重ねて呼ばない(`CardMatchEffectTarget.begin()` と同じ理由)。
	_screen.selection.clear()
	_screen._perform(MatchAction.cast(_screen.my_side, index))
	_screen._hide_detail()


## 対象選択中の砂術を、選ばれた1体へ撃つ。
func cast_at(side: int, slot: int) -> void:
	var index: int = _screen.selection.hand_index
	var view := _screen._hand_views[index]
	_screen.effects.queue_spend_origin(_screen.my_side, view.global_position + view.size * 0.5)
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
