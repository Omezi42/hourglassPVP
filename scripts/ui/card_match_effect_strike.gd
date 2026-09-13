class_name CardMatchEffectStrike
extends RefCounted
## 設置効果が単体の砂時計を狙う「ダメージ/破壊」の演出の進行役(GameDesign.md 9章)。
## `CardMatchStrike`(実際の攻撃)と同じ考え方で、**状態の解決(`MatchState`)は
## 即座に済ませ、演出は結果を後から見せるだけにする**。紋章が対象へ届くまで、
## 被ダメージ・破壊の演出を持ち越す。
##
## `card_match_screen.gd` が1000行の上限に近いため、ここへ切り出している。

var _screen: CardMatchScreen
var _fx: EmblemStrikeFx
var _armed := false
## 当たる瞬間まで持ち越す被ダメージ。{"side":..., "slot":..., "amount":...}
var _damage: Array[Dictionary] = []


func _init(screen: CardMatchScreen) -> void:
	_screen = screen
	_fx = EmblemStrikeFx.new()
	screen.add_child(_fx)
	_fx.impact.connect(_on_impact)
	_fx.finished.connect(_on_finished)


## 演出中かどうか。攻撃と同じく盤面の再同期を遅らせるのに使う
## (`CardMatchScreen.strike_busy()` がこれも見る)。
func busy() -> bool:
	return _armed


## `MatchState.effect_struck` を受ける。効果の解決(ダメージ・破壊の適用)は
## `CardEffectResolver` が既に済ませているため、ここでは演出だけを組む。
func on_effect_struck(
	source_side: int, source_slot: int, target_side: int, target_slot: int
) -> void:
	if source_slot < 0 or target_slot < 0:
		return
	var source_unit: CardInstance = _screen.state.board[source_side][source_slot]
	if source_unit == null or source_unit.data.emblem == null:
		return
	_armed = true
	var from := CardFlipBeam.unit_center(_screen.view_at(source_side, source_slot))
	var to := CardFlipBeam.unit_center(_screen.view_at(target_side, target_slot))
	_fx.play(source_unit.data.emblem, from, to)


## 攻撃と同じく、紋章が当たるまで被ダメージの砂の飛散を持ち越す
## (`CardMatchStrike.on_unit_damaged()` から呼ぶ)。
func hold_damage(side: int, slot: int, amount: int) -> void:
	_damage.append({"side": side, "slot": slot, "amount": amount})


## 紋章が対象へ届いた瞬間。持ち越していた演出(被ダメージ・破壊・硝子の閃光)を
## まとめて出し、盤面をごく短く揺らす。
func _on_impact() -> void:
	_screen.refresh_bars()
	_screen.sound.flush()
	_screen.effects.flush()
	# 攻撃と同じく、当てた量を揺れの強さにする(GameDesign.md 9章)。破壊のように量を
	# 持たない場合は、控えめな既定値で揺らす。
	var power: int = _damage[0]["amount"] if not _damage.is_empty() else 4
	_screen.shake.hit(power)
	for hit in _damage:
		var view: CardView = _screen.view_at(hit["side"], hit["slot"])
		if view != null:
			view.play_shatter(hit["amount"])
	_damage.clear()


func _on_finished() -> void:
	_armed = false
	_screen.on_strike_finished()
