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
## **上下の情報帯には掛けない。**HP・マナ・山札は読みながら判断するものであり、
## カードの説明を読む間だけ消えてよいものではない。パネルは卓の範囲へ収める。
## **`CardMatchScreen` の const をここの const から参照しない。**互いを参照する
## 定数になり、読み込みが循環して固まる(実際にそうなった)。値は実行時に読む。

var _screen: CardMatchScreen
var _panel: CardDetailPanel
var _timer: Timer
## 盤面の外(ログのモーダル)から出したか。その間は盤面の状態で引っ込めない。
var _off_board := false


func _init(screen: CardMatchScreen) -> void:
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
	hover_card(view.card if view != null else null)


## 駒を持たない所(直前の手の列・ログ)からも同じパネルを出す。
## `off_board` はログのモーダルから読むとき。出さない間の規則は「盤面の上へ重なる」前提の
## ものであり、盤面を覆ったモーダルの上では当たらないため掛けない。
func hover_card(card: CardData, off_board := false) -> void:
	if card == null or (not off_board and not allowed()):
		hide_now()
		return
	_off_board = off_board
	_timer.stop()
	_panel.show_card(card, "" if off_board else _live_text(card))
	_panel.position = _place()
	_panel.visible = true
	# 履歴タイル・ログ(あとから add_child した子)より手前へ出す。
	_panel.move_to_front()


## 自分の手札の札は、反転の回数で伸びる数字をいまの値で見せる(GameDesign.md 6章)。
func _live_text(card: CardData) -> String:
	if _screen.state == null or not _screen.state.hand[_screen.my_side].has(card):
		return ""
	return CardEffectResolver.live_rules_text(_screen.state, _screen.my_side, card)


## **カーソルの近くへ置く**(GameDesign.md 9章)。置き場の規則そのものは
## `CardDetailPanel.place_near()` が持ち、ここは収める範囲だけを決める。
##
## 対角へ出していたのは**パネルの中の語を押しに行く**前提があった頃の名残で、
## 読むだけになったいまは視線を画面の端まで往復させる理由が無い。
func _place() -> Vector2:
	var band := _screen.layout.table_rect
	var bounds := Rect2(
		Vector2(MARGIN, band.position.y),
		Vector2(_screen.layout.play_right - MARGIN * 2.0, band.size.y)
	)
	var shown := _panel.size * _panel.scale
	return CardDetailPanel.place_near(_screen.get_local_mouse_position(), shown, bounds)


## タッチの長押し(GameDesign.md 9章「タッチでの操作」)。指で隠れないよう、カーソルの近くではなく
## 卓の中央の固定位置へ出す。
func show_fixed(card: CardData) -> void:
	if card == null or _screen.state == null:
		return
	_off_board = false
	_timer.stop()
	_panel.show_card(card, _live_text(card))
	_panel.position = _screen.layout.table_rect.get_center() - _panel.size * _panel.scale * 0.5
	_panel.visible = true
	_panel.move_to_front()


## 縦では文字を読める大きさにするため、パネルごと拡大する(GameDesign.md 9章「縦画面」)。
func apply_layout(layout: CardMatchLayout) -> void:
	_panel.scale = Vector2.ONE * layout.detail_scale
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
	if _screen.strike_busy():
		return false
	return _screen.selection.is_empty()
