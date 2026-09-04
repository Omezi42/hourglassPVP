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
	if view == null or view.card == null or not allowed():
		hide_now()
		return
	_timer.stop()
	_panel.show_card(view.card)
	_panel.position = _place()
	_panel.visible = true
	# 履歴タイル(あとから add_child した子)より手前へ出す。
	_panel.move_to_front()


## **カーソルの近くへ置く**(GameDesign.md 9章)。置き場の規則そのものは
## `CardDetailPanel.place_near()` が持ち、ここは収める範囲だけを決める。
##
## 対角へ出していたのは**パネルの中の語を押しに行く**前提があった頃の名残で、
## 読むだけになったいまは視線を画面の端まで往復させる理由が無い。
func _place() -> Vector2:
	var band := CardMatchScreen.TABLE_RECT
	var bounds := Rect2(
		Vector2(MARGIN, band.position.y),
		Vector2(CardMatchScreen.ACTION_COLUMN_X - MARGIN * 2.0, band.size.y)
	)
	return CardDetailPanel.place_near(_screen.get_local_mouse_position(), _panel.size, bounds)


func leave() -> void:
	if _panel.visible:
		_timer.start()


func hide_now() -> void:
	_timer.stop()
	_panel.visible = false


## 盤面が変わったら、出してよい状態でなくなったぶんを引っ込める。
## ホバーは動かなければ再び飛んでこないため、`refresh()` から呼ぶ。
func sync() -> void:
	if _panel.visible and not allowed():
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
