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


## マナのバッジ(GameDesign.md 18章「数字の光」)。話題が「使ったマナ」の段(出す)でだけ使う。
func mana_badge_rect(side: int) -> Rect2:
	var bar: PlayerInfoBar = _screen._own_bar if side == _screen.my_side else _screen._foe_bar
	return _badge_rect(
		bar.position + PlayerInfoBar.MANA_BADGE_CENTER, PlayerInfoBar.MANA_BADGE_RADIUS
	)


## 盤面の1体の体力・攻撃力のバッジ(GameDesign.md 18章「数字の光」)。
## 話題が「駒の体力と攻撃力」の段(読むだけ)でだけ使う。
func unit_stat_rects(side: int, slot: int) -> Array[Rect2]:
	var view := _screen.view_at(side, slot)
	var y := CardView.PEDESTAL_CENTER_Y + 6.0
	var r := CardView.STAT_RADIUS
	var attack_center := view.position + Vector2(r + 2.0, y)
	var health_center := view.position + Vector2(view.size.x - r - 2.0, y)
	return [_badge_rect(attack_center, r), _badge_rect(health_center, r)] as Array[Rect2]


## HPバーの矩形(GameDesign.md 18章「数字の光」)。話題が「相手HP」の段でだけ使う。
func hp_bar_global_rect(side: int) -> Rect2:
	var bar: PlayerInfoBar = _screen._own_bar if side == _screen.my_side else _screen._foe_bar
	var local := bar.hp_bar_rect()
	return Rect2(bar.position + local.position, local.size)


## 反転権の残り回数を示す粒(GameDesign.md 18章「数字の光」)。話題が「反転権の残り」の
## 段でだけ使う。
func flip_right_gauge_rect() -> Rect2:
	var gauge: FlipRightGauge = _screen._flip_right._gauge
	return Rect2(gauge.position, FlipRightGauge.GAUGE_SIZE)


func _badge_rect(center: Vector2, radius: float) -> Rect2:
	return Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
