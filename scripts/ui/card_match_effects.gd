class_name CardMatchEffects
extends RefCounted
## 盤面で起きたことを見せる演出のうち、**駒どうしの攻撃以外**をまとめる進行役
## (GameDesign.md 9章)。設置の着地・破壊の崩落・設置効果の光の筋・硝子の割れる閃光・
## ドローと疲労の山札の脈打ちの5つ。
##
## `CardMatchSound` と同じく **`MatchState` のシグナルだけを見る**。自分の手・CPU・
## オンラインで届いた手・リプレイの再生はいずれも `MatchAction.apply()` を通って同じ
## シグナルを出すため、経路ごとに演出を書き足す必要がなくなる。
##
## **攻撃の演出中に起きたぶんは、当たる瞬間まで持ち越す**(`CardMatchStrike` が砂の飛散を
## 持ち越すのと同じ理由)。解決と同時に見せると、駒がまだ渡っている最中に相手が砕け始める。

## 空き枠へドラッグで放したときの滑り(GameDesign.md 9章「対局画面の手触り」)。
const DROP_GLIDE_DURATION := 0.12

var _screen: CardMatchScreen
## 攻撃の演出中に預かった演出。当たった瞬間にまとめて出す。
var _held: Array[Callable] = []
## ドラッグで放した座標。`"側:枠"` をキーに持ち、`unit_played` が届いた瞬間だけ読む
## (クリックで枠を選んだ場合は積まないため、その場合は従来どおり滑らずに着地する)。
var _drop_origin: Dictionary = {}
## 支払いの吸い込みの行き先(GameDesign.md 9章「対局画面の手触り」)。押した札の
## global位置を側(int)をキーに控え、`unit_played`/`spell_cast` が届いた瞬間だけ読む。
## 手札位置は出す前に消えるため、押した時点(`CardMatchTouch`/`CardMatchSpell`)で
## 控えてもらう。控えが無ければ情報帯のマナ数字付近を既定の行き先にする。
var _spend_origin: Dictionary = {}


func _init(screen: CardMatchScreen) -> void:
	_screen = screen


func watch(state: MatchState) -> void:
	state.unit_played.connect(_on_unit_played)
	state.spell_cast.connect(_on_spell_cast)
	state.unit_destroyed.connect(_on_unit_destroyed)
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


## 空き枠へドラッグで放した座標を控える。放した位置から台座の中心へ短く滑ってから
## 着地演出へ入る(GameDesign.md 9章)。`CardMatchTouch.on_slot_drop()` から呼ぶ。
func queue_drop_origin(side: int, slot: int, global_pos: Vector2) -> void:
	_drop_origin[_drop_key(side, slot)] = global_pos


func _drop_key(side: int, slot: int) -> String:
	return "%d:%d" % [side, slot]


## 押した札のglobal位置を控える。`unit_played`/`spell_cast` が届いた瞬間、支払われた
## ぶんのマナのピップをここへ向けて吸い込ませる(GameDesign.md 9章)。
func queue_spend_origin(side: int, global_pos: Vector2) -> void:
	_spend_origin[side] = global_pos


## 場に出した:台座の少し上から落ちて着地する。ドラッグで放した座標が控えてあれば、
## 先にそこから台座の中心へ滑ってから着地する。**着地の後に銘板を短く光らせる**
## (GameDesign.md 9章「通常の反転と設置の着地」)。
func _on_unit_played(side: int, slot: int) -> void:
	var view := _screen.view_at(side, slot)
	var cost: int = _screen.state.board[side][slot].data.cost
	_play_spend(side, cost)
	var key := _drop_key(side, slot)
	if _drop_origin.has(key):
		var origin: Vector2 = _drop_origin[key]
		_drop_origin.erase(key)
		_glide_to_pedestal(view, origin)
		return
	view.play_land()
	view.play_spark()


## 砂術を撃った(GameDesign.md 6章)。盤面へは出ないため、支払いの吸い込みだけを見せる。
func _on_spell_cast(side: int, card: CardData) -> void:
	_play_spend(side, card.cost)


## 支払われたぶんのマナのピップを、押した札の位置(控えていなければマナの数字付近)へ
## 吸い込ませる。
func _play_spend(side: int, cost: int) -> void:
	if cost <= 0:
		return
	var bar := _screen.bar_for(side)
	var origin: Vector2 = _spend_origin.get(side, bar.mana_label_global())
	_spend_origin.erase(side)
	bar.spend_toward(cost, origin)


func _glide_to_pedestal(view: CardView, global_origin: Vector2) -> void:
	var target := view.position
	view.position = global_origin - view.get_parent().global_position
	var tween := view.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "position", target, DROP_GLIDE_DURATION)
	tween.finished.connect(view.play_land)
	tween.finished.connect(view.play_spark)


## 破壊された:砕けて台座へ崩れ落ちる。**枠が空になった後も演出だけが残る**ため、
## 絵の元になるカードをここで渡しておく。**余砂がその駒自身から発火した場合
## (`effect_strike.is_death_origin()`)は、崩落を持ち越さず即座に出す**——
## そのままだと崩落が紋章の着弾まで持ち越され、「崩落を先に見せてから銘板が飛ぶ」
## 順序と逆になる(Architecture.md 4.0節)。
func _on_unit_destroyed(side: int, slot: int, card: CardData) -> void:
	if _screen.effect_strike.is_death_origin(side, slot):
		_screen.view_at(side, slot).play_break(card)
		return
	_defer(func() -> void: _screen.view_at(side, slot).play_break(card))


## 硝子が最初のダメージを吸った:膜が割れる閃光を出す。
func _on_unit_shielded(side: int, slot: int) -> void:
	_defer(func() -> void: _screen.view_at(side, slot).play_glass_break())


## ドロー:山札を脈打たせ、手札へ砂の筋を流す。
func _on_cards_drawn(side: int, _count: int) -> void:
	var bar := _screen.bar_for(side)
	bar.play_deck_pulse(false)
	var from: Vector2 = bar.position + bar.deck_pile_rect().get_center()
	_screen.beam.play(from, hand_center(side), CardFlipBeam.COLOR)


## 疲労:**発生源が駒ではなく山札にある**ため、山札そのものを赤く脈打たせる
## (GameDesign.md 9章)。HPバーへの数字は情報帯側が従来どおり出す。
func _on_fatigue_damage(side: int, _amount: int) -> void:
	_screen.bar_for(side).play_deck_pulse(true)


## ドローを起こす設置効果・トリガーが、盤面上の駒から発動した(GameDesign.md 9章)。
## その駒の紋章へ短い光の輪を添える。山札の脈打ち(`_on_cards_drawn`)とは別に、
## 「このカードが引かせた」ことを示すため。
func _on_effect_drawn(side: int, slot: int, _count: int) -> void:
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
		return CardMatchScreen.HAND_AREA.get_center()
	var bar := _screen.bar_for(side)
	return bar.position + bar.hand_pile_rect().get_center()
