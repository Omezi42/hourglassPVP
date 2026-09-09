class_name CardMatchGeometry
extends RefCounted
## 対局画面の座標にまつわる小さな問い合わせをまとめる。
## `card_match_screen.gd`が1000行の上限に近いため切り出した(Architecture.md 4.0節)。
## `_screen`参照を持つ切り出しという既存の流儀に従う。

var _screen: CardMatchScreen


func _init(screen: CardMatchScreen) -> void:
	_screen = screen


## HPバーの中心。攻撃が相手プレイヤーを狙うときの的。
func hp_bar_center(side: int) -> Vector2:
	var bar: PlayerInfoBar = _screen._own_bar if side == _screen.my_side else _screen._foe_bar
	return bar.position + bar.hp_bar_rect().get_center()


## 盤面の1枠の中心。実況の吹き出しを出す位置に使う。
func slot_center(side: int, slot: int) -> Vector2:
	if slot < 0:
		return Vector2(_screen.size.x * 0.5, CardMatchScreen.FOE_ROW_TOP)
	var view := _screen.view_at(side, slot)
	return view.position + Vector2(view.size.x * 0.5, CardView.PEDESTAL_CENTER_Y)


## いま出せる手札の矩形。誘導対局が「これを押す」と光らせるのに使う。
func playable_hand_rects() -> Array[Rect2]:
	var found: Array[Rect2] = []
	for view in _screen._hand_views:
		if view.visible and view.enabled:
			found.append(Rect2(view.position, view.size))
	return found


## ターン終了ボタンの矩形。誘導対局が「ここを押す」と光らせるのに使う。
func end_turn_button_rect() -> Rect2:
	return Rect2(_screen._end_turn_button.position, _screen._end_turn_button.size)
