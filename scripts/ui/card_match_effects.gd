class_name CardMatchEffects
extends RefCounted
## 盤面で起きたことを見せる演出のうち、**駒どうしの攻撃以外**をまとめる進行役
## (GameDesign.md 9章)。設置(札がほどけて着地する)・破壊の崩落・設置効果の光の筋・硝子の割れる閃光・
## ドローと疲労の山札の脈打ちの5つ。
##
## `CardMatchSound` と同じく **`MatchState` のシグナルだけを見る**。自分の手・CPU・
## オンラインで届いた手・リプレイの再生はいずれも `MatchAction.apply()` を通って同じ
## シグナルを出すため、経路ごとに演出を書き足す必要がなくなる。
##
## **攻撃の演出中に起きたぶんは、当たる瞬間まで持ち越す**(`CardMatchStrike` が砂の飛散を
## 持ち越すのと同じ理由)。解決と同時に見せると、駒がまだ渡っている最中に相手が砕け始める。

## コストの重い駒が着地したときの卓の揺れ(GameDesign.md 9章「着地の重さはコストで3段」)。
const HEAVY_LAND_SHAKE := 6

## この対局で一度出した登場の演出(カード id)。2回目以降は短縮版にする(GameDesign.md 9章)。
var _seen_entrances: Dictionary = {}

var _screen: Control
## 攻撃の演出中に預かった演出。当たった瞬間にまとめて出す。
var _held: Array[Callable] = []
## 手元で出した札の位置(ドラッグなら放した位置、押して枠を選んだなら手札の札の中心)。
## `"側:枠"` をキーに持ち、`unit_played` が届いた瞬間だけ読む。控えが無ければ相手・再生の手として札を見せる。
var _drop_origin: Dictionary = {}
## 支払いの吸い込みの行き先(GameDesign.md 9章「対局画面の手触り」)。押した札の
## global位置を側(int)をキーに控え、`unit_played`/`spell_cast` が届いた瞬間だけ読む。
## 手札位置は出す前に消えるため、押した時点(`CardMatchTouch`/`CardMatchSpell`)で
## 控えてもらう。控えが無ければ情報帯のマナ数字付近を既定の行き先にする。
var _spend_origin: Dictionary = {}
## 毒砂で体力が0になった枠(`"側:枠"`)。続く `unit_destroyed` を溶解で見せる(GameDesign.md 9章)。
var _poisoned: Dictionary = {}
## 札がほどけて器になる演出(GameDesign.md 9章)。
var _place: CardPlaceFx


func _init(screen: Control) -> void:
	_screen = screen
	_place = CardPlaceFx.new()
	screen.add_child(_place)
	# 着地を待っていた設置効果の紋章を放つ。
	_place.finished.connect(func() -> void: _screen.effect_strike.flush())


## 札がほどけて器になる演出の最中か(`CardMatchEffectStrike` が紋章を持ち越すのに使う)。
func placing() -> bool:
	return _place.busy()


func stop_placing() -> void:
	_place.stop()


func watch(state: MatchState) -> void:
	_seen_entrances.clear()
	state.unit_played.connect(_on_unit_played)
	state.spell_cast.connect(_on_spell_cast)
	state.unit_destroyed.connect(_on_unit_destroyed)
	state.unit_poisoned.connect(_on_unit_poisoned)
	state.unit_shielded.connect(_on_unit_shielded)
	state.unit_returned.connect(_on_unit_returned)
	state.cards_drawn.connect(_on_cards_drawn)
	state.fatigue_damage.connect(_on_fatigue_damage)
	state.effect_drawn.connect(_on_effect_drawn)


## 攻撃が当たった瞬間。`CardMatchStrike` から呼ぶ。
func flush() -> void:
	var pending := _held.duplicate()
	_held.clear()
	for step in pending:
		step.call()


func _defer(step: Callable) -> void:
	if _screen.strike_busy():
		_held.append(step)
		return
	step.call()


## 手元で出した札の位置を控える。札はそこから台座の上へ移ってほどける(GameDesign.md 9章)。
## `CardMatchTouch._play_selected()` から呼ぶ。
func queue_drop_origin(side: int, slot: int, global_pos: Vector2) -> void:
	_drop_origin[_drop_key(side, slot)] = global_pos


func _drop_key(side: int, slot: int) -> String:
	return "%d:%d" % [side, slot]


## 押した札のglobal位置を控える。`unit_played`/`spell_cast` が届いた瞬間、支払われた
## ぶんのマナのピップをここへ向けて吸い込ませる(GameDesign.md 9章)。
func queue_spend_origin(side: int, global_pos: Vector2) -> void:
	_spend_origin[side] = global_pos


## 場に出した:札がほどけて器になり、コストの重さで着地する(GameDesign.md 9章)。
## 手元で出した札(ドラッグで放した位置・押した札の位置を控えてある)はそこから台座へ向かい、
## 控えが無いもの(相手・リプレイ・観戦)は先に卓の中央で開いて読ませる。
## 固有の登場を持つカードは、ほどけてから登場の演出へ続く。
func _on_unit_played(side: int, slot: int) -> void:
	_poisoned.erase(_drop_key(side, slot))
	var view: CardView = _screen.view_at(side, slot)
	var unit: CardInstance = _screen.state.board[side][slot]
	var data: CardData = unit.data
	_play_spend(side, _screen.state.play_cost(side, data))
	# 盤面の描き直しは設置効果の演出が終わるまで待たされるため、出た駒だけ先に映す。
	view.show_unit(unit)
	var key := _drop_key(side, slot)
	var reveal := not _drop_origin.has(key)
	var origin: Vector2 = _screen.get_global_transform() * hand_center(side)
	if not reveal:
		origin = _drop_origin[key]
	_drop_origin.erase(key)
	var entrance := SignatureLibrary.entrance(data)
	var land := func() -> void:
		if entrance != null:
			_play_entrance(view, data, entrance)
		else:
			_land(view, CardUnitFx.weight_for_cost(data.cost))
	var face_scale: float = _screen.layout.hand_scale if _screen.layout.portrait else 1.0
	var local_origin := _place.get_global_transform().affine_inverse() * origin
	var center: Vector2 = _screen.layout.table_rect.get_center()
	_place.play(view, data, local_origin, reveal, face_scale, center, land)


## コストの重さで着地し、重いものは落ちきった瞬間に卓を揺らす。
func _land(view: CardView, weight: int, time_rate := 1.0) -> void:
	view._fx.play_land_weighted(weight, time_rate)
	if weight != CardUnitFx.Weight.HEAVY:
		view.play_spark()
		return
	var landed := view.get_tree().create_timer(CardUnitFx.land_duration(weight) * time_rate)
	landed.timeout.connect(
		func() -> void:
			_screen.shake.hit(HEAVY_LAND_SHAKE)
			view.play_spark()
	)


## 登場の演出(GameDesign.md 9章)。駒が台座へ落ちきった瞬間(`impact`)に銘板を光らせ、
## 重く落ちる登場なら卓を大きく揺らす。重なっても切れないよう、1回ごとに再生役を作る。
## 落ち方は登場の指定(重い)を優先し、無ければコストの重さで落ちる。
func _play_entrance(view: CardView, data: CardData, move: SignatureMove) -> void:
	var short := _seen_entrances.has(data.id)
	_seen_entrances[data.id] = true
	move.from = view.position + Vector2(view.size.x * 0.5, CardView.PEDESTAL_CENTER_Y)
	var weight := (
		CardUnitFx.Weight.HEAVY if move.heavy_land() else CardUnitFx.weight_for_cost(data.cost)
	)
	view._fx.play_land_weighted(weight, SignatureFxPlayer.rate(short))
	var player := SignatureFxPlayer.new()
	_screen.add_child(player)
	player.impact.connect(
		func() -> void:
			if move.heavy_land():
				_screen.shake.hit(CardMatchFinale.IMPACT_SHAKE_POWER)
			elif weight == CardUnitFx.Weight.HEAVY:
				_screen.shake.hit(HEAVY_LAND_SHAKE)
			view.play_spark()
	)
	player.finished.connect(player.queue_free)
	player.play(move, short, SoundBank.Sfx.PLACE)


## 砂術を撃った(GameDesign.md 6章)。盤面へは出ないため、支払いの吸い込みだけを見せる。
func _on_spell_cast(side: int, card: CardData) -> void:
	_play_spend(side, _screen.state.play_cost(side, card))


## 支払われたぶんのマナのピップを、押した札の位置(控えていなければマナの数字付近)へ
## 吸い込ませる。
func _play_spend(side: int, cost: int) -> void:
	if cost <= 0:
		return
	var bar: PlayerInfoBar = _screen.bar_for(side)
	var origin: Vector2 = _spend_origin.get(side, bar.mana_label_global())
	_spend_origin.erase(side)
	bar.spend_toward(cost, origin)


## 破壊された:砕けて台座へ崩れ落ちる。**枠が空になった後も演出だけが残る**ため、
## 絵の元になるカードをここで渡しておく。**余砂がその駒自身から発火した場合
## (`effect_strike.is_death_origin()`)は、崩落を持ち越さず即座に出す**——
## そのままだと崩落が紋章の着弾まで持ち越され、「崩落を先に見せてから銘板が飛ぶ」
## 順序と逆になる(Architecture.md 4.0節)。
func _on_unit_destroyed(side: int, slot: int, card: CardData) -> void:
	var melted := _poisoned.has(_drop_key(side, slot))
	_poisoned.erase(_drop_key(side, slot))
	var fall := func() -> void:
		var view: CardView = _screen.view_at(side, slot)
		if melted:
			view.play_melt(card)
		else:
			view.play_break(card)
	if _screen.effect_strike.is_death_origin(side, slot):
		fall.call()
		return
	_defer(fall)


func _on_unit_poisoned(side: int, slot: int) -> void:
	_poisoned[_drop_key(side, slot)] = true


## 硝子が最初のダメージを吸った:膜が割れる閃光を出す。
func _on_unit_shielded(side: int, slot: int) -> void:
	_defer(func() -> void: _screen.view_at(side, slot).play_glass_break())


## ドロー:山札を脈打たせ、札を山札から手札へ飛ばす(GameDesign.md 9章)。相手の手札は
## 伏せた枚数の山で表しているため、相手側は札の代わりに砂の筋を流す。
func _on_cards_drawn(side: int, _count: int) -> void:
	var bar: PlayerInfoBar = _screen.bar_for(side)
	bar.play_deck_pulse(false)
	var from: Vector2 = bar.position + bar.deck_pile_rect().get_center()
	if side == _screen.my_side:
		_screen._hand_layout.queue_draw_from(from)
		return
	_screen.beam.play(from, hand_center(side), CardFlipBeam.COLOR)


## 疲労:**発生源が駒ではなく山札にある**ため、山札そのものを赤く脈打たせる
## (GameDesign.md 9章)。HPバーへの数字は情報帯側が従来どおり出す。
func _on_fatigue_damage(side: int, _amount: int) -> void:
	_screen.bar_for(side).play_deck_pulse(true)


## ドローを起こす設置効果・トリガーが、盤面上の駒から発動した(GameDesign.md 9章)。
## その駒の紋章へ短い光の輪を添える。山札の脈打ち(`_on_cards_drawn`)とは別に、
## 「このカードが引かせた」ことを示すため。カードの演出を持つカードは、光の輪の代わりにそれを出す。
func _on_effect_drawn(side: int, slot: int, _count: int) -> void:
	if _screen.effect_strike.play_drawn(side, slot):
		return
	_defer(func() -> void: _screen.view_at(side, slot).play_spark())


## 砂へ還す(GameDesign.md 9章):紋章が対象を包んだ後、駒が縮んで持ち主の手札の
## 方向へ吸い込まれる。`RECALL` の紋章が armed の間は `_defer()` が持ち越すため、
## 着弾の瞬間にこの消え方が起きる。
func _on_unit_returned(side: int, slot: int, card: CardData) -> void:
	_defer(func() -> void: _screen.view_at(side, slot)._fx.play_recall(card, hand_center(side)))


## ドローの行き先。自分の手札は画面下の帯、相手の手札は枚数の山で表している
## (中身は伏せるため。GameDesign.md 9章)。
func hand_center(side: int) -> Vector2:
	if side == _screen.my_side:
		return _screen.layout.hand_area.get_center()
	var bar: PlayerInfoBar = _screen.bar_for(side)
	return bar.position + bar.hand_pile_rect().get_center()
