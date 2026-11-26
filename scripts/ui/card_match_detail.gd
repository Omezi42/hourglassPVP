class_name CardMatchDetail
extends RefCounted
## 対局中のカード詳細の出し消し(GameDesign.md 9章)。
##
## **カードや駒にカーソルを乗せている間だけ出す。**クリックで開く形は、
## 自分の駒を読むだけで攻撃・反転の選択に入ってしまうため採らない。
##
## そのぶん **パネルは `interactive = false`** で作る。語のボタンも実演も持たないため、
## カーソルを動かして触る先が無く、外れたら消える形が成立する。
##
## `card_match_screen.gd` が1000行の上限に近いため、ここへ切り出している。

## 外れてから消すまでの猶予。隣の駒へ移る途中で点滅させないため。
const HIDE_DELAY := 0.15
## 盤面へ重ねる以上、幅は狭いほどよい。効果の文が読める下限として340pxを採った。
const WIDTH := 340.0
const MARGIN := 12.0
## 縦は指している駒と反対側の半分へ出し、レールの帯との間をこれだけ空ける。
const RAIL_GAP := 8.0
## 縦で詳細の拡大を詰める下限(横の詰めた表示の1.3倍)。
const MIN_PORTRAIT_SCALE := 1.3
## **上下の情報帯には掛けない。**HP・マナ・山札は読みながら判断するものであり、
## カードの説明を読む間だけ消えてよいものではない。パネルは卓の範囲へ収める。
## **`CardMatchScreen` の const をここの const から参照しない。**互いを参照する
## 定数になり、読み込みが循環して固まる(実際にそうなった)。値は実行時に読む。

var _screen: Control
var _panel: CardDetailPanel
var _timer: Timer
## 盤面の外(ログのモーダル)から出したか。その間は盤面の状態で引っ込めない。
var _off_board := false
## いま指している(押している)駒や札の矩形。縦はこれのある側と反対の半分へ出す。
var _anchor := Rect2()


func _init(screen: Control) -> void:
	_screen = screen
	_panel = CardDetailPanel.new()
	_panel.interactive = false
	# 大きなイラストを捨てた縦積み。盤面の上へ置くため、隠す面積を最小にする。
	_panel.compact = true
	_panel.compact_width = WIDTH
	_panel.visible = false
	# **パネルはホバーを奪わない。**盤面へ重ねる以上、塞ぐと下の駒を指せなくなる。
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(_panel)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = HIDE_DELAY
	_timer.timeout.connect(hide_now)
	screen.add_child(_timer)


## カードへカーソルが乗った。出してよい状態でなければ何も出さない。
func hover(view: CardView) -> void:
	var avoid := Rect2()
	var anchor := Rect2()
	if view != null:
		anchor = view.get_transform() * Rect2(Vector2.ZERO, view.size)
		if view.mode == CardView.Mode.BOARD:
			avoid = anchor
	hover_card(
		view.card if view != null else null,
		false,
		avoid,
		anchor,
		view.unit if view != null else null
	)


## 駒を持たない所(直前の手の列・ログ)からも同じパネルを出す。
## `off_board` はログのモーダルから読むとき。出さない間の規則は「盤面の上へ重なる」前提の
## ものであり、盤面を覆ったモーダルの上では当たらないため掛けない。
func hover_card(
	card: CardData,
	off_board := false,
	avoid := Rect2(),
	anchor := Rect2(),
	unit: CardInstance = null
) -> void:
	if card == null or (not off_board and not allowed()):
		hide_now()
		return
	_off_board = off_board
	_anchor = anchor
	_timer.stop()
	_panel.show_card(card, "" if off_board else _live_text(card, unit))
	_fit_scale()
	_panel.position = _place(avoid)
	_panel.visible = true
	# 履歴タイル・ログ(あとから add_child した子)より手前へ出す。
	_panel.move_to_front()


## 自分の手札の札は、反転の回数で伸びる数字をいまの値で見せる(GameDesign.md 6章)。
## 場の駒は、与えられた効果(導火線)を札の文の末尾へ足して見せる(GameDesign.md 6章「効果を与える効果」)。
func _live_text(card: CardData, unit: CardInstance = null) -> String:
	if unit != null and not unit.silenced and not unit.granted_effects.is_empty():
		var text := card.rules_text
		for effect in unit.granted_effects:
			text += "\n" + effect.shown_text
		return text
	if _screen.state == null or not _screen.state.hand[_screen.my_side].has(card):
		return ""
	return CardEffectResolver.live_rules_text(_screen.state, _screen.my_side, card)


## **カーソルの近くへ置く**(GameDesign.md 9章)。置き場の規則そのものは
## `CardDetailPanel.place_near()` が持ち、ここは収める範囲だけを決める。
##
## 対角へ出していたのは**パネルの中の語を押しに行く**前提があった頃の名残で、
## 読むだけになったいまは視線を画面の端まで往復させる理由が無い。
func _place(avoid := Rect2()) -> Vector2:
	var shown := _panel.size * _panel.scale
	var bounds := _bounds()
	var at := CardDetailPanel.place_near(_screen.get_local_mouse_position(), shown, bounds, avoid)
	if _rail_split():
		at.y = _centered_y(bounds, shown.y)
	return at


## 縦は卓の中ほどをレールが横切るため、指している駒と反対側の半分(レールの帯を除く)へ収める
## (GameDesign.md 9章「詳細パネル」)。横と、指している物の無い出し方は卓の全体。
func _bounds() -> Rect2:
	var table: Rect2 = _screen.layout.table_rect
	var left := MARGIN
	var width: float = _screen.layout.play_right - MARGIN * 2.0
	if not _rail_split():
		return Rect2(Vector2(left, table.position.y), Vector2(width, table.size.y))
	var rail: Rect2 = _screen.layout.rail_band
	if _anchor.get_center().y < rail.get_center().y:
		var top := rail.end.y + RAIL_GAP
		return Rect2(Vector2(left, top), Vector2(width, table.end.y - top))
	var bottom := rail.position.y - RAIL_GAP
	return Rect2(Vector2(left, table.position.y), Vector2(width, bottom - table.position.y))


func _rail_split() -> bool:
	return _screen.layout.portrait and _anchor.has_area()


## 範囲の縦の中央へ。入りきらないときは範囲の上端へ寄せる。
func _centered_y(bounds: Rect2, height: float) -> float:
	return bounds.position.y + maxf((bounds.size.y - height) * 0.5, 0.0)


## 縦の拡大(`detail_scale`)に文字の大きさの設定(GameDesign.md 9章)を掛ける。
## 範囲に収まるところまで倍率を戻す(縦の下限は `MIN_PORTRAIT_SCALE`、横は `detail_scale`)。
func _fit_scale() -> void:
	var wanted: float = _screen.layout.detail_scale * TextSize.factor()
	var floor_scale: float = _screen.layout.detail_scale
	if _rail_split():
		floor_scale = minf(MIN_PORTRAIT_SCALE, floor_scale)
	var room := _bounds().size / _panel.size
	_panel.scale = Vector2.ONE * maxf(minf(wanted, minf(room.x, room.y)), floor_scale)


## タッチの長押し(GameDesign.md 9章「タッチでの操作」)。指で隠れないよう、カーソルの近くではなく
## 固定位置へ出す。横は卓の中央、縦は押している札と反対側の半分の中央(`anchor` は押している札の矩形)。
func show_fixed(card: CardData, anchor := Rect2()) -> void:
	if card == null or _screen.state == null:
		return
	_off_board = false
	_anchor = anchor
	_timer.stop()
	_panel.show_card(card, _live_text(card))
	_fit_scale()
	var shown := _panel.size * _panel.scale
	var bounds := _bounds()
	var center := bounds.get_center()
	if _rail_split():
		center.y = _centered_y(bounds, shown.y) + shown.y * 0.5
	_panel.position = center - shown * 0.5
	_panel.visible = true
	_panel.move_to_front()


## 縦では文字を読める大きさにするため、パネルごと拡大する(GameDesign.md 9章「縦画面」)。
## 倍率は出すたびに `_fit_scale()` が決める。
func apply_layout(_layout: CardMatchLayout) -> void:
	hide_now()


func leave() -> void:
	if _panel.visible:
		_timer.start()


func hide_now() -> void:
	_timer.stop()
	_panel.visible = false


## 盤面が変わったら、出してよい状態でなくなったぶんを引っ込める。
## ホバーは動かなければ再び飛んでこないため、`refresh()` から呼ぶ。
func sync() -> void:
	if _panel.visible and not _off_board and not allowed():
		hide_now()


## 出してよい状態か(GameDesign.md 9章)。**対象選択中・マリガン中・演出中は出さない。**
## いずれも「いま読みたいものの上にパネルが乗る」場面にあたる。
func allowed() -> bool:
	if _screen.state == null:
		return false
	if _screen.state.mulligan_pending or _screen.mulligan_open():
		return false
	if _screen.strike_busy() or _screen._spell_drag.active():
		return false
	return _screen.selection.is_empty()
