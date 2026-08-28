class_name CardMatchStrike
extends RefCounted
## 攻撃の演出の進行役(GameDesign.md 9章)。駒が対象の斜め上まで渡っていき、
## 反動をつけて当てる一連を、対局画面の代わりに組み立てる。
##
## **攻撃の解決そのもの(`MatchState.attack()`)は演出を待たずに即座に済ませ、
## 演出は結果を後から見せるだけにする。**ロジックを演出の完了へ依存させると、
## リプレイ・観戦・CPUの連続着手がすべて演出の尺に縛られるため。
##
## そのぶん、**被ダメージの砂の飛散だけは当たる瞬間まで持ち越す**。解決と同時に
## 散らすと、駒がまだ渡っている最中に相手の砂が消えて因果が逆に見える。
##
## `card_match_screen.gd` が1000行の上限に近いため、ここへ切り出している。

## 同じターンで何回目の攻撃から尺を詰めるか(GameDesign.md 9章)。
const QUICK_AFTER := 1

var _screen: CardMatchScreen
## 演出を組む対象。空なら攻撃ではない手だった。
var _armed := false
var _attacker: CardView
var _target_center := Vector2.ZERO
## 当たる瞬間まで持ち越す被ダメージ。{"side":..., "slot":..., "amount":...}
var _damage: Array[Dictionary] = []
## このターンに何回攻撃したか。2回目以降は尺を詰める。
var _strikes_this_turn := 0
var _turn_marker := -1


func _init(screen: CardMatchScreen) -> void:
	_screen = screen


## 演出中かどうか。盤面の操作を止めるのに使う。
func busy() -> bool:
	return _armed


## 手を適用する**前**に呼ぶ。攻撃なら、動かす駒と狙う先をこの時点で控えておく
## (適用後は倒された駒が盤面から消えており、位置を引けなくなるため)。
func capture(action: Dictionary) -> void:
	_armed = false
	_damage.clear()
	if _screen.state == null or action.get("type", "") != "attack":
		return
	var side: int = int(action.get("side", MatchState.Side.A))
	var slot: int = int(action.get("slot", -1))
	var target: int = int(action.get("target", -1))
	var attacker: CardView = _screen.view_at(side, slot)
	if attacker == null or _screen.state.board[side][slot] == null:
		return
	_attacker = attacker
	_target_center = _center_of(MatchState.other_side(side), target)
	_armed = true
	if _turn_marker != _screen.state.turn_count:
		_turn_marker = _screen.state.turn_count
		_strikes_this_turn = 0


## 被ダメージを当たる瞬間まで預かる。預かったら true を返す。
func absorb(side: int, slot: int, amount: int) -> bool:
	if not _armed:
		return false
	_damage.append({"side": side, "slot": slot, "amount": amount})
	return true


## 演出を始める。始めたら true(続きは当たった瞬間と終わりに進む)。
## 攻撃でなければ false を返し、呼び出し側がそのまま表示を更新する。
func play() -> bool:
	if not _armed:
		return false
	_strikes_this_turn += 1
	var quick: bool = _strikes_this_turn > QUICK_AFTER
	_attacker.strike_impact.connect(_on_impact, CONNECT_ONE_SHOT)
	_attacker.strike_finished.connect(_on_finished, CONNECT_ONE_SHOT)
	_attacker.play_strike(_target_center, quick)
	return true


## 相手の情報帯・駒の中心。相手プレイヤーを狙う場合はHPバーそのものを的にする
## (「守護がいなければ本体を殴れる」という選択が、駒を殴るときと同じ動きで見える)。
func _center_of(side: int, slot: int) -> Vector2:
	if slot < 0:
		return _screen.hp_bar_center(side)
	var view: CardView = _screen.view_at(side, slot)
	if view == null:
		return _screen.hp_bar_center(side)
	return (
		view.position
		+ Vector2(view.size.x * 0.5, CardView.PEDESTAL_CENTER_Y - CardView.BOARD_ART_SIDE * 0.5)
	)


## 当たった瞬間。預かっていた砂の飛散をここでまとめて出す。
## **盤面の更新はまだ行わない**。倒された駒をこの時点で消すと、砕ける絵が出ないため。
func _on_impact() -> void:
	for hit in _damage:
		var view: CardView = _screen.view_at(hit["side"], hit["slot"])
		if view != null:
			view.play_shatter(hit["amount"])
	_damage.clear()


func _on_finished() -> void:
	_armed = false
	_screen.on_strike_finished()
