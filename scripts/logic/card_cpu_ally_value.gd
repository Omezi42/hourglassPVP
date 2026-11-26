class_name CardCpuAllyValue
extends RefCounted
## CPUの見積もりのうち、味方の駒への効果(抜け道・セージ・マエストロ・砂落とし・砂戻し・反転)の値打ちと狙い先。
## `CardCpuStrategy` が1000行の上限に近いため切り出した。評価値は変えていない。

## 守護を無視して攻撃できる駒1体ぶんの価値(抜け道)。守護の駒を避けて殴れる1回を、本体の数点ぶんに見る。
const GUARD_BYPASS_PER_ATTACKER := 2.0
## セージが手札の砂術1枚のコストを1下げることの価値。
const SPELL_DISCOUNT_PER_CARD := 1.0
## マエストロの価値。場にいる反転トリガー持ち1体につき足す。
const FLIP_ECHO_PER_UNIT := 2.0


## 抜け道の価値。相手に守護の駒がいて、自分に攻撃できる駒がいるときだけ、その数に応じて持つ
## (出した駒自身は出したターンに殴れないため数えない)。
static func guard_bypass(state: MatchState, side: int) -> float:
	if state.can_attack_player(side):
		return 0.0
	var ready := 0
	for unit in state.units(side):
		if unit.can_attack() and unit.attack > 0:
			ready += 1
	return ready * GUARD_BYPASS_PER_ATTACKER


## セージの価値。手札の砂術のうち、まだ下げられる(最小コストより上の)ぶんだけ持つ。
static func spell_discount(state: MatchState, side: int, down: int) -> float:
	var saved := 0
	for card: CardData in state.hand[side]:
		if card.is_spell:
			saved += mini(down, maxi(state.play_cost(side, card) - MatchState.MIN_COST, 0))
	return saved * SPELL_DISCOUNT_PER_CARD


## マエストロの価値。反転トリガーを持つ味方の数だけ持つ。
static func flip_echo(state: MatchState, side: int) -> float:
	var echoed := 0
	for unit: CardInstance in state.units(side):
		if not unit.effects_for(CardEnums.Trigger.ON_FLIP).is_empty():
			echoed += 1
	return echoed * FLIP_ECHO_PER_UNIT


## 砂を落として最も得をする味方と、その得の大きさ。得をする駒がいなければ slot は -1。
static func best_drop(state: MatchState, side: int, amount: int) -> Dictionary:
	var best := {"slot": -1, "gain": 0.0}
	for slot in MatchState.BOARD_SIZE:
		var unit: CardInstance = state.board[side][slot]
		if unit == null:
			continue
		var health := unit.health - amount
		# 落としきると砕けるため、得どころか駒を1体失う。
		if health <= 0:
			continue
		var gain := (
			CardCpuStrategy.lifetime_of(health, unit.attack + amount)
			- float(unit.lifetime_damage())
		)
		if gain > best["gain"]:
			best = {"slot": slot, "gain": gain}
	return best


## 砂を上へ戻して最も得をする味方と、その得の大きさ。攻撃力0の駒には効かないため、
## 戻せる砂が無い駒は候補にしない。得をする駒がいなければ slot は -1。
static func best_raise(state: MatchState, side: int, amount: int) -> Dictionary:
	var best := {"slot": -1, "gain": 0.0}
	for slot in MatchState.BOARD_SIZE:
		var unit: CardInstance = state.board[side][slot]
		if unit == null or unit.attack <= 0:
			continue
		var moved: int = mini(amount, unit.attack)
		var gain := (
			CardCpuStrategy.lifetime_of(unit.health + moved, unit.attack - moved)
			- float(unit.lifetime_damage())
		)
		if gain > best["gain"]:
			best = {"slot": slot, "gain": gain}
	return best


## 反転させて最も得をする味方と、その得の大きさ。得をする駒がいなければ slot は -1。
static func best_flip(state: MatchState, side: int) -> Dictionary:
	var best := {"slot": -1, "gain": 0.0}
	for slot in MatchState.BOARD_SIZE:
		var unit: CardInstance = state.board[side][slot]
		if unit == null or not unit.flippable():
			continue
		var gain := (
			CardCpuStrategy.lifetime_of(unit.attack, unit.health) - float(unit.lifetime_damage())
		)
		if gain > best["gain"]:
			best = {"slot": slot, "gain": gain}
	return best
