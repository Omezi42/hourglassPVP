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
	return bar.get_transform() * bar.hp_bar_rect().get_center()


## 盤面の1枠の中心。実況の吹き出しを出す位置に使う。
func slot_center(side: int, slot: int) -> Vector2:
	if slot < 0:
		return Vector2(_screen.size.x * 0.5, _screen.layout.foe_row_top)
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


## マナのバッジと粒の列(GameDesign.md 18章「数字の光」)。話題が「使ったマナ」の段(出す)でだけ使う。
func mana_badge_rect(side: int) -> Rect2:
	var bar: PlayerInfoBar = _screen._own_bar if side == _screen.my_side else _screen._foe_bar
	return _to_screen(bar, bar.mana_rect())


## 盤面の1体の体力・攻撃力のバッジ(GameDesign.md 18章「数字の光」)。
## 話題が「駒の体力と攻撃力」の段(読むだけ)でだけ使う。
func unit_stat_rects(side: int, slot: int) -> Array[Rect2]:
	var view := _screen.view_at(side, slot)
	var y := CardView.PEDESTAL_CENTER_Y + 6.0
	var r := CardView.STAT_RADIUS * view.stat_scale
	var attack := _badge_rect(Vector2(r + 2.0, y), r)
	var health := _badge_rect(Vector2(view.size.x - r - 2.0, y), r)
	return [_to_screen(view, attack), _to_screen(view, health)] as Array[Rect2]


## HPバーの矩形(GameDesign.md 18章「数字の光」)。話題が「相手HP」の段でだけ使う。
func hp_bar_global_rect(side: int) -> Rect2:
	var bar: PlayerInfoBar = _screen._own_bar if side == _screen.my_side else _screen._foe_bar
	return _to_screen(bar, bar.hp_bar_rect())


## 反転権の残り回数を示す粒(GameDesign.md 18章「数字の光」)。話題が「反転権の残り」の
## 段でだけ使う。
func flip_right_gauge_rect() -> Rect2:
	var gauge: FlipRightGauge = _screen._flip_right._gauge
	return Rect2(gauge.position, FlipRightGauge.GAUGE_SIZE)


func _badge_rect(center: Vector2, radius: float) -> Rect2:
	return Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)


## 部品のローカル矩形を画面座標へ(縮尺・軸を通す)。
func _to_screen(control: Control, local: Rect2) -> Rect2:
	return Rect2(control.get_transform() * local.position, local.size * control.scale)
