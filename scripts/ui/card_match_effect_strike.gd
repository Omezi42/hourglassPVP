class_name CardMatchEffectStrike
extends RefCounted
## 設置効果・砂術・余砂が単体(砂時計1体、または相手プレイヤー)を狙う演出の進行役
## (GameDesign.md 9章)。`CardMatchStrike`(実際の攻撃)と同じ考え方で、**状態の解決
## (`MatchState`)は即座に済ませ、演出は結果を後から見せるだけにする**。紋章が対象へ
## 届くまで、被ダメージ・破壊・砂落ちの演出を持ち越す。
##
## 型(`CardEnums.EffectVisualStyle`)は紋章の動き方(`EmblemStrikeFx`)だけを変え、
## ここでは「当たった瞬間に何をするか」(揺れ・反転の演出)を型ごとに振り分ける。
##
## **紋章の出どころ(`CardEnums.EffectOrigin`)によって、飛ぶ絵と発射までの前置きが
## 変わる**(Architecture.md 4.0節)。UNITは盤面の駒の紋章がそのまま飛ぶ。SPELLは
## 手札から撃った砂術の絵を`spell_cast`から控えて使い、自分の情報帯から浮き上がって
## から飛ぶ。DEATHは破壊された駒の絵を墓地の末尾から引き、台座の銘板として残ってから
## 飛ぶ。
##
## `card_match_screen.gd` が1000行の上限に近いため、ここへ切り出している。

var _screen: CardMatchScreen
var _fx: EmblemStrikeFx
var _armed := false
## いま組んでいる演出の型。`_on_impact()` が「打撃だけ揺らす」判断に使う。
var _style := CardEnums.EffectVisualStyle.STRIKE
## いま組んでいる紋章の出どころ。`is_death_origin()` の判定に使う。
var _origin := CardEnums.EffectOrigin.UNIT
var _origin_side := MatchState.Side.A
var _origin_slot := -1
## 当たる瞬間まで持ち越す被ダメージ。{"side":..., "slot":..., "amount":...}
var _damage: Array[Dictionary] = []
## 当たる瞬間まで持ち越すターン終了の1粒(砂嵐・ラトル・ドリップ等)と、
## 効果で上へ戻る砂(巻き戻し・時間停止等。`raise` が true)。
## {"side":..., "slot":..., "raise": bool}
var _ticks: Array[Dictionary] = []
## 反転(SPIN)のときだけ使う。当たった瞬間に `CardView.play_flip()` を呼ぶ対象。
var _spin_target: CardView
## 撃った直近の砂術(GameDesign.md 6章)。出どころが盤面に無いため、
## `spell_cast` から発動元の紋章を控えておく(side → CardData)。
var _last_spell: Dictionary = {}
## 攻撃(`CardMatchStrike`)の演出中に効果が届いた場合、紋章の発射そのものを
## 着弾まで持ち越す(Architecture.md 4.0節)。
var _pending: Array[Callable] = []


func _init(screen: CardMatchScreen) -> void:
	_screen = screen
	_fx = EmblemStrikeFx.new()
	screen.add_child(_fx)
	_fx.impact.connect(_on_impact)
	_fx.finished.connect(_on_finished)


## `MatchState` のシグナルへまとめて接続する(`CardMatchSound`/`CardMatchEffects` と
## 同じ流儀)。`card_match_screen.gd` の行数を増やさないための切り出し。
func watch(state: MatchState) -> void:
	state.effect_struck.connect(on_effect_struck)
	state.effect_struck_many.connect(on_effect_struck_many)
	state.spell_cast.connect(_on_spell_cast)
	state.unit_raised.connect(on_unit_raised)


## 演出中かどうか。攻撃と同じく盤面の再同期を遅らせるのに使う
## (`CardMatchScreen.strike_busy()` がこれも見る)。
func busy() -> bool:
	return _armed


## 破壊の余砂(GameDesign.md 9章):砕けた駒自身から効果が発火した場合、
## `CardMatchEffects` が崩落の演出を持ち越さず即座に出すための問い合わせ。
func is_death_origin(side: int, slot: int) -> bool:
	return (
		_armed
		and _origin == CardEnums.EffectOrigin.DEATH
		and _origin_side == side
		and _origin_slot == slot
	)


func _on_spell_cast(side: int, card: CardData) -> void:
	_last_spell[side] = card


## `MatchState.effect_struck` を受ける。効果の解決(ダメージ・破壊・反転の適用)は
## `CardEffectResolver` が既に済ませているため、ここでは演出だけを組む。
## `target_slot` が -1 なら相手プレイヤーそのものを狙う(GameDesign.md 9章)。
func on_effect_struck(
	source_side: int, source_slot: int, target_side: int, target_slot: int, style: int, origin: int
) -> void:
	var card := _source_card(source_side, source_slot, origin)
	if card == null or card.emblem == null:
		return
	_arm(source_side, source_slot, origin, style)
	var from := _origin_position(source_side, source_slot, origin)
	var to := (
		from
		if style == CardEnums.EffectVisualStyle.PULSE
		else _target_position(target_side, target_slot)
	)
	if style == CardEnums.EffectVisualStyle.SPIN and target_slot >= 0:
		_spin_target = _screen.view_at(target_side, target_slot)
	var emblem := card.emblem
	_queue(func() -> void: _fx.play(emblem, from, to, style, origin))


## `MatchState.effect_struck_many` を受ける。全体に効く効果(スイープ・レガシー等)が
## 対象の数だけ同時に紋章を飛ばす(GameDesign.md 9章)。`_on_impact()` は元々 `_damage`
## を配列として持ち越す形になっており、複数のヒットもそのまま捌ける。
func on_effect_struck_many(
	source_side: int, source_slot: int, targets: Array, style: int, origin: int
) -> void:
	if targets.is_empty():
		return
	var card := _source_card(source_side, source_slot, origin)
	if card == null or card.emblem == null:
		return
	_arm(source_side, source_slot, origin, style)
	var from := _origin_position(source_side, source_slot, origin)
	var tos: Array[Vector2] = []
	for entry in targets:
		tos.append(_target_position(entry["side"], entry["slot"]))
	var emblem := card.emblem
	_queue(func() -> void: _fx.play_many(emblem, from, tos, style, origin))


func _arm(source_side: int, source_slot: int, origin: int, style: int) -> void:
	_armed = true
	_style = style
	_origin = origin
	_origin_side = source_side
	_origin_slot = source_slot
	_spin_target = null


## 攻撃(`CardMatchStrike`)の演出中は、紋章の発射そのものを着弾まで持ち越す
## (Architecture.md 4.0節「砕けた駒の余砂は、崩落を先に見せてから銘板が飛ぶ」)。
func _queue(step: Callable) -> void:
	if _screen._strike.busy():
		_pending.append(step)
		return
	step.call()


## 持ち越していた紋章の発射をまとめて始める。`CardMatchStrike._on_impact()` が
## `effects.flush()` の直後に呼ぶ。
func flush() -> void:
	var pending := _pending.duplicate()
	_pending.clear()
	for step in pending:
		step.call()


## 攻撃と同じく、紋章が当たるまで被ダメージの砂の飛散を持ち越す
## (`CardMatchStrike.on_unit_damaged()` から呼ぶ)。
func hold_damage(side: int, slot: int, amount: int) -> void:
	_damage.append({"side": side, "slot": slot, "amount": amount})


## ターン終了の1粒(砂嵐・ラトル・ドリップ等)も、紋章が当たるまで持ち越す
## (`CardMatchStrike.on_unit_ticked()` から呼ぶ)。以前は紋章が届く前に砂が流れていた。
func hold_tick(side: int, slot: int) -> void:
	_ticks.append({"side": side, "slot": slot, "raise": false})


## 効果で砂が上へ戻った(`MatchState.unit_raised`。GameDesign.md 6章)。落砂の逆向きの
## 流れとして描き、紋章が当たるまで持ち越す。**落砂・被ダメージと同じシグナルに
## 相乗りさせない**(取り違えるとルールを誤解する。GameDesign.md 9章)。
func on_unit_raised(side: int, slot: int, _amount: int) -> void:
	if _armed:
		_ticks.append({"side": side, "slot": slot, "raise": true})
		return
	var view: CardView = _screen.view_at(side, slot)
	if view != null:
		view.play_raise()


## 紋章が対象へ届いた瞬間。持ち越していた演出(被ダメージ・砂落ち・反転)を
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
	for tick in _ticks:
		var view: CardView = _screen.view_at(tick["side"], tick["slot"])
		if view == null:
			continue
		if tick["raise"]:
			view.play_raise()
		else:
			view.play_drop()
	_ticks.clear()
	if _spin_target != null:
		_spin_target.play_flip()
		_spin_target = null
	_screen.finale.on_impact()


func _on_finished() -> void:
	_armed = false
	_screen.on_strike_finished()


## 紋章として飛ばすカードを、出どころの型から引く(Architecture.md 4.0節)。
func _source_card(source_side: int, source_slot: int, origin: int) -> CardData:
	match origin:
		CardEnums.EffectOrigin.SPELL:
			return _last_spell.get(source_side)
		CardEnums.EffectOrigin.DEATH:
			var pile: Array = _screen.state.graveyard[source_side]
			return pile.back() if not pile.is_empty() else null
	if source_slot < 0:
		return null
	var unit: CardInstance = _screen.state.board[source_side][source_slot]
	return unit.data if unit != null else null


## 紋章が飛び始める位置。UNITは駒の中心、SPELLは自分の情報帯の中心、DEATHは
## 砕けた台座の銘板の位置(Architecture.md 4.0節の表)。
func _origin_position(source_side: int, source_slot: int, origin: int) -> Vector2:
	match origin:
		CardEnums.EffectOrigin.SPELL:
			var bar := _screen.bar_for(source_side)
			return bar.position + bar.size * 0.5
		CardEnums.EffectOrigin.DEATH:
			var view := _screen.view_at(source_side, source_slot)
			return view.position + Vector2(view.size.x * 0.5, CardView.PEDESTAL_CENTER_Y - 4.0)
	return CardFlipBeam.unit_center(_screen.view_at(source_side, source_slot))


func _target_position(target_side: int, target_slot: int) -> Vector2:
	return (
		_screen._geometry.hp_bar_center(target_side)
		if target_slot < 0
		else CardFlipBeam.unit_center(_screen.view_at(target_side, target_slot))
	)
