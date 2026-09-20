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
## 本体を狙うとき、HPバーの中心からどれだけ盤面側へ寄せるか。
const FACE_EDGE := 26.0

var _screen: CardMatchScreen
## 演出を組む対象。空なら攻撃ではない手だった。
var _armed := false
var _attacker: CardView
var _target_center := Vector2.ZERO
## 貫通で抜けていく先。抜けないときは無限(`Vector2.INF`)。
var _follow_center := Vector2.INF
## 当たる瞬間まで持ち越す被ダメージ。{"side":..., "slot":..., "amount":...}
var _damage: Array[Dictionary] = []
## このターンに何回攻撃したか。2回目以降は尺を詰める。
var _strikes_this_turn := 0
var _turn_marker := -1
## 当てた駒の攻撃力。**当たった瞬間の揺れの強さに使う**(GameDesign.md 9章)。
## 相打ちで双方が削れるが、揺らすのは「打撃の強さ」なので当てた側の値を採る。
## 適用後は駒が盤面から消えていることがあるため、控えるのは capture() の時点。
var _impact_power := 0
## 相打ちの反撃(GameDesign.md 9章)。砂時計を狙った攻撃で、防御側の攻撃力が1以上のときだけ
## 持つ。攻撃を適用する前に控える(適用後は破壊されて盤面から消えていることがあるため)。
var _defender: CardView
var _defender_dir := 1.0


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
	# キーは `target_slot`(`MatchAction.attack()`)。-1 なら相手プレイヤーを狙う。
	var target: int = int(action.get("target_slot", -1))
	var attacker: CardView = _screen.view_at(side, slot)
	if attacker == null or _screen.state.board[side][slot] == null:
		return
	_attacker = attacker
	_impact_power = _screen.state.board[side][slot].attack
	var foe := MatchState.other_side(side)
	_target_center = _center_of(foe, target)
	_follow_center = _pierce_center(side, slot, target)
	_capture_defender(attacker, foe, target)
	_armed = true
	if _turn_marker != _screen.state.turn_count:
		_turn_marker = _screen.state.turn_count
		_strikes_this_turn = 0


## 被ダメージ:砂が砕けて散る。**設置効果の「紋章の一撃」(`CardMatchEffectStrike`)が
## 組まれている間を先に見る**(相打ちの被ダメージは余砂の発火より前に届くため、
## 攻撃側が先に控える順序は変わらず、余砂の効果(バースト等)の被ダメージだけが
## 紋章の着弾へ揃う)。**攻撃の演出中は当たる瞬間まで持ち越す**
## (渡っている最中に相手の砂が消えると、因果が逆に見えるため)。
func on_unit_damaged(side: int, slot: int, amount: int) -> void:
	if _screen.effect_strike.busy():
		_screen.effect_strike.hold_damage(side, slot, amount)
		return
	if _armed:
		_damage.append({"side": side, "slot": slot, "amount": amount})
		return
	_screen.view_at(side, slot).play_shatter(amount)


## ターン終了の1粒:砂が下の部屋へ流れる。総量は変わらないため、砕く演出とは分ける。
## 紋章の一撃(砂嵐・ラトル・ドリップ等)が組まれている間は、その着弾まで持ち越す。
func on_unit_ticked(side: int, slot: int) -> void:
	if _screen.effect_strike.busy():
		_screen.effect_strike.hold_tick(side, slot)
		return
	_screen.view_at(side, slot).play_drop()


## 演出を始める。始めたら true(続きは当たった瞬間と終わりに進む)。
## 攻撃でなければ false を返し、呼び出し側がそのまま表示を更新する。
func play() -> bool:
	if not _armed:
		return false
	_strikes_this_turn += 1
	var quick: bool = _strikes_this_turn > QUICK_AFTER
	_attacker.strike_impact.connect(_on_impact, CONNECT_ONE_SHOT)
	_attacker.strike_finished.connect(_on_finished, CONNECT_ONE_SHOT)
	_attacker.play_strike(_target_center, quick, _follow_center)
	return true


## 貫通が本体まで抜けるなら、その行き先(相手のHPバー)を返す。
## **超過分が本体へ抜けるという固有の挙動を、動きそのもので示す**(GameDesign.md 9章)。
func _pierce_center(side: int, slot: int, target: int) -> Vector2:
	if target < 0:
		return Vector2.INF
	var attacker: CardInstance = _screen.state.board[side][slot]
	var foe := MatchState.other_side(side)
	var defender: CardInstance = _screen.state.board[foe][target]
	if attacker == null or defender == null:
		return Vector2.INF
	if not attacker.data.has_keyword(CardEnums.Keyword.PIERCE):
		return Vector2.INF
	if attacker.attack <= defender.health:
		return Vector2.INF
	return _face_target(foe)


## 本体を狙うときの的。**HPバーの中心そのものではなく、盤面側の縁を狙う**。
## 駒は112pxあってバーは24pxしかないため、中心を的にすると当たった瞬間に
## 残りHPの数字が駒で隠れる。数字が変わるのはまさにその瞬間なので、読めなくなる。
func _face_target(side: int) -> Vector2:
	var at := _screen._geometry.hp_bar_center(side)
	var toward_board: float = FACE_EDGE if at.y < _screen.size.y * 0.5 else -FACE_EDGE
	return at + Vector2(0.0, toward_board)


## 相打ちの反撃(GameDesign.md 9章)。砂時計を狙った攻撃で、防御側の攻撃力が1以上のときだけ
## `_defender` を控える(攻撃力0なら実際には反撃していないため突き出さない)。
## 向きは、攻撃側が防御側から見てどちら側に立っているかで決める
## (`CardViewStrike.play()` の `side_x` と同じ符号)。
func _capture_defender(attacker: CardView, foe: int, target: int) -> void:
	_defender = null
	if target < 0:
		return
	var defender_unit: CardInstance = _screen.state.board[foe][target]
	if defender_unit == null or defender_unit.attack <= 0:
		return
	_defender = _screen.view_at(foe, target)
	var anchor := attacker.position + attacker.board_art_box().get_center()
	var dside := signf(anchor.x - _target_center.x)
	_defender_dir = dside if not is_zero_approx(dside) else 1.0


## 相手の情報帯・駒の中心。相手プレイヤーを狙う場合はHPバーそのものを的にする
## (「守護がいなければ本体を殴れる」という選択が、駒を殴るときと同じ動きで見える)。
func _center_of(side: int, slot: int) -> Vector2:
	var view: CardView = _screen.view_at(side, slot) if slot >= 0 else null
	if view == null:
		return _face_target(side)
	return (
		view.position
		+ Vector2(view.size.x * 0.5, CardView.PEDESTAL_CENTER_Y - CardView.BOARD_ART_SIDE * 0.5)
	)


## 当たった瞬間。預かっていた砂の飛散をここでまとめて出す。
## **情報帯だけはここで同期する**。戻りきるまで待つと、当てた瞬間とHPの減りが
## 対応して見えなくなるため。**盤面の駒はまだ更新しない**。倒された駒をこの時点で
## 消すと、砕ける絵が出ないため。
func _on_impact() -> void:
	_screen.refresh_bars()
	# 持ち越していた効果音と演出も、砂の飛散と同じこの瞬間に出す。
	_screen.sound.flush()
	_screen.effects.flush()
	# 相打ちで余砂持ちが砕けた場合、紋章の発射自体をここまで持ち越している
	# (Architecture.md 4.0節)。
	_screen.effect_strike.flush()
	# 打撃の重さは駒の動きだけでは伝わらないため、盤面そのものを短く揺らす。
	_screen.shake.hit(_impact_power)
	for hit in _damage:
		var view: CardView = _screen.view_at(hit["side"], hit["slot"])
		if view != null:
			view.play_shatter(hit["amount"])
	_damage.clear()
	if _defender != null:
		_defender.play_counter(_defender_dir)


func _on_finished() -> void:
	_armed = false
	_screen.on_strike_finished()
