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
const TOP := 40.0
const MARGIN := 12.0

var _screen: CardMatchScreen
var _panel: CardDetailPanel
var _timer: Timer


func _init(screen: CardMatchScreen) -> void:
	_screen = screen
	_panel = CardDetailPanel.new()
	_panel.interactive = false
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
	# 指しているカードと反対の端へ出す。読みたいものを自分で隠さないため。
	var to_right: bool = view.position.x + view.size.x * 0.5 < _screen.size.x * 0.5
	var left := _screen.size.x - CardDetailPanel.PANEL_SIZE.x - MARGIN if to_right else MARGIN
	_panel.position = Vector2(left, TOP)
	_panel.visible = true


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
