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

var _screen: CardMatchScreen
## 攻撃の演出中に預かった演出。当たった瞬間にまとめて出す。
var _held: Array[Callable] = []


func _init(screen: CardMatchScreen) -> void:
	_screen = screen


func watch(state: MatchState) -> void:
	state.unit_played.connect(_on_unit_played)
	state.unit_destroyed.connect(_on_unit_destroyed)
	state.unit_shielded.connect(_on_unit_shielded)
	state.cards_drawn.connect(_on_cards_drawn)
	state.fatigue_damage.connect(_on_fatigue_damage)
	state.effect_targeted.connect(_on_effect_targeted)


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


## 場に出した:台座の少し上から落ちて着地する。
func _on_unit_played(side: int, slot: int) -> void:
	_screen.view_at(side, slot).play_land()


## 破壊された:砕けて台座へ崩れ落ちる。**枠が空になった後も演出だけが残る**ため、
## 絵の元になるカードをここで渡しておく。
func _on_unit_destroyed(side: int, slot: int, card: CardData) -> void:
	_defer(func() -> void: _screen.view_at(side, slot).play_break(card))


## 硝子が最初のダメージを吸った:膜が割れる閃光を出す。
func _on_unit_shielded(side: int, slot: int) -> void:
	_defer(func() -> void: _screen.view_at(side, slot).play_glass_break())


## ドロー:山札を脈打たせ、手札へ砂の筋を流す。
func _on_cards_drawn(side: int, _count: int) -> void:
	var bar := _screen.bar_for(side)
	bar.play_deck_pulse(false)
	var from: Vector2 = bar.position + bar.deck_pile_rect().get_center()
	_screen.beam.play(from, _hand_center(side, bar), CardFlipBeam.COLOR)


## 疲労:**発生源が駒ではなく山札にある**ため、山札そのものを赤く脈打たせる
## (GameDesign.md 9章)。HPバーへの数字は情報帯側が従来どおり出す。
func _on_fatigue_damage(side: int, _amount: int) -> void:
	_screen.bar_for(side).play_deck_pulse(true)


## 設置効果:出した駒から対象へ筋を伸ばす。余砂は既に盤面から降りているため
## 出どころが無く、その場合は筋を出さない。
func _on_effect_targeted(
	source_side: int, source_slot: int, target_side: int, target_slot: int
) -> void:
	if source_slot < 0:
		return
	var source := _screen.view_at(source_side, source_slot)
	var to: Vector2 = (
		_screen.hp_bar_center(target_side)
		if target_slot < 0
		else CardFlipBeam.unit_center(_screen.view_at(target_side, target_slot))
	)
	var hostile: bool = target_side != source_side
	var color: Color = CardFlipBeam.EFFECT_HOSTILE if hostile else CardFlipBeam.EFFECT_FRIENDLY
	var from := CardFlipBeam.unit_center(source)
	_defer(func() -> void: _screen.beam.play(from, to, color))


## ドローの行き先。自分の手札は画面下の帯、相手の手札は枚数の山で表している
## (中身は伏せるため。GameDesign.md 9章)。
func _hand_center(side: int, bar: PlayerInfoBar) -> Vector2:
	if side == _screen.my_side:
		return CardMatchScreen.HAND_AREA.get_center()
	return bar.position + bar.hand_pile_rect().get_center()
