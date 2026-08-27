class_name CardMatchSelection
extends RefCounted
## 対局画面でいま何を選んでいるか。手札の1枚か、自分の場の1枠のどちらかしか選べない。
## 選択の状態を1箇所へまとめ、CardMatchScreen 側の分岐を減らすために切り出している。

enum Kind { NONE, HAND, BOARD }

var kind: int = Kind.NONE
var hand_index := -1
var slot := -1


func clear() -> void:
	kind = Kind.NONE
	hand_index = -1
	slot = -1


func select_hand(index: int) -> void:
	kind = Kind.HAND
	hand_index = index
	slot = -1


func select_board(p_slot: int) -> void:
	kind = Kind.BOARD
	slot = p_slot
	hand_index = -1


func is_hand_selection() -> bool:
	return kind == Kind.HAND


func is_board_selection() -> bool:
	return kind == Kind.BOARD


func is_hand(index: int) -> bool:
	return kind == Kind.HAND and hand_index == index
