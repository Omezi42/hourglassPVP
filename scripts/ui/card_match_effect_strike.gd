class_name CardMatchEffectStrike
extends RefCounted
## 設置効果が単体(砂時計1体、または相手プレイヤー)を狙う演出の進行役(GameDesign.md 9章)。
## `CardMatchStrike`(実際の攻撃)と同じ考え方で、**状態の解決(`MatchState`)は
## 即座に済ませ、演出は結果を後から見せるだけにする**。紋章が対象へ届くまで、
## 被ダメージ・破壊の演出を持ち越す。
##
## 型(`CardEnums.EffectVisualStyle`)は紋章の動き方(`EmblemStrikeFx`)だけを変え、
## ここでは「当たった瞬間に何をするか」(揺れ・反転の演出)を型ごとに振り分ける。
##
## `card_match_screen.gd` が1000行の上限に近いため、ここへ切り出している。

var _screen: CardMatchScreen
var _fx: EmblemStrikeFx
var _armed := false
## いま組んでいる演出の型。`_on_impact()` が「打撃だけ揺らす」判断に使う。
var _style := CardEnums.EffectVisualStyle.STRIKE
## 当たる瞬間まで持ち越す被ダメージ。{"side":..., "slot":..., "amount":...}
var _damage: Array[Dictionary] = []
## 反転(SPIN)のときだけ使う。当たった瞬間に `CardView.play_flip()` を呼ぶ対象。
var _spin_target: CardView


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


## `MatchState.effect_struck` を受ける。効果の解決(ダメージ・破壊・反転の適用)は
## `CardEffectResolver` が既に済ませているため、ここでは演出だけを組む。
## `target_slot` が -1 なら相手プレイヤーそのものを狙う(GameDesign.md 9章)。
func on_effect_struck(
	source_side: int, source_slot: int, target_side: int, target_slot: int, style: int
) -> void:
	if source_slot < 0:
		return
	var source_unit: CardInstance = _screen.state.board[source_side][source_slot]
	if source_unit == null or source_unit.data.emblem == null:
		return
	_armed = true
	_style = style
	_spin_target = null
	if style == CardEnums.EffectVisualStyle.SPIN and target_slot >= 0:
		_spin_target = _screen.view_at(target_side, target_slot)
	var from := CardFlipBeam.unit_center(_screen.view_at(source_side, source_slot))
	var to := (
		_screen._geometry.hp_bar_center(target_side)
		if target_slot < 0
		else CardFlipBeam.unit_center(_screen.view_at(target_side, target_slot))
	)
	_fx.play(source_unit.data.emblem, from, to, style)


## 攻撃と同じく、紋章が当たるまで被ダメージの砂の飛散を持ち越す
## (`CardMatchStrike.on_unit_damaged()` から呼ぶ)。
func hold_damage(side: int, slot: int, amount: int) -> void:
	_damage.append({"side": side, "slot": slot, "amount": amount})


## 紋章が対象へ届いた瞬間。持ち越していた演出(被ダメージ・破壊・硝子の閃光)を
## まとめて出す。**盤面の揺れは「打撃」だけ**(恵与・払拭・反転はそれぞれの
## 演出自体が当たりの手応えを持つため、重ねて揺らすと騒がしくなる)。
func _on_impact() -> void:
	_screen.refresh_bars()
	_screen.sound.flush()
	_screen.effects.flush()
	if _style == CardEnums.EffectVisualStyle.STRIKE:
		# 破壊だけの効果(`DESTROY_UNIT`)は `unit_damaged` を伴わないため、
		# 量を持たないときは控えめな既定値で揺らす。
		var power: int = _damage[0]["amount"] if not _damage.is_empty() else 4
		_screen.shake.hit(power)
	for hit in _damage:
		var view: CardView = _screen.view_at(hit["side"], hit["slot"])
		if view != null:
			view.play_shatter(hit["amount"])
	_damage.clear()
	if _spin_target != null:
		_spin_target.play_flip()
		_spin_target = null


func _on_finished() -> void:
	_armed = false
	_screen.on_strike_finished()
