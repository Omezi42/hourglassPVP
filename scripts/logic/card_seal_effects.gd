class_name CardSealEffects
extends RefCounted
## 第3弾「封じの刻」の固有効果(GameDesign.md 6章「封じる効果」)。
## 次の相手の手番に攻撃できない・場にいるあいだ攻撃できない・反転できなくなる・反転を使えない・コストが上がる。
## 駒ごとの状態は `CardInstance` が、プレイヤーごとの状態は `MatchState.flip_lock` が持つ。
## 静止を与える・静止の駒を壊す札は、既存の `GRANT_KEYWORD` と `ConditionScope.TARGET_IS_STILL` で表す。

## 台座に出す印(`CardView.lock_mark`)。
enum Mark { NONE, CHAIN, CAGE }

const TYPES := [
	CardEnums.EffectType.LOCK_ATTACK,
	CardEnums.EffectType.LOCK_ATTACK_WHILE_ALIVE,
	CardEnums.EffectType.SEAL_FLIP,
	CardEnums.EffectType.LOCK_FLIP,
]
## CPUの見積もり。攻撃を止めた1回ぶんの値打ち(止めた駒の攻撃力に掛ける)。
const LOCK_VALUE := 1.5
## 檻は封じ続けるため、封じた駒の生涯ダメージの何割を止めたと見るか。
const CAGE_FACTOR := 0.6
## 反転できなくした駒の値打ち。
const SEAL_VALUE := 3.0
## 反転を1手番まるごと封じる値打ち。相手の反転権1回ぶんを足す。
const JAIL_VALUE := 2.0
const JAIL_RIGHT_VALUE := 1.5
## 静止を与えて止まる、砂の伸びの見込み(落ちる砂が生む攻撃力の割引)。
const STILL_FACTOR := 0.8
## トールが止める、相手の手札1枚ぶんの値打ち(手札の枚数が4を超えても数えない)。
const TOLL_VALUE_PER_CARD := 1.0
const TOLL_CARDS_CAP := 4
## 対局の評価(`CardCpuSpellSearch`)で、封じられた駒を割り引く率。
const LOCKED_UNIT_FACTOR := 0.75

## ケージの印の通し番号。対局をまたいで増えるだけで、同じ値の一致だけが意味を持つ。
static var _next_key := 1

var _state: MatchState
var _resolver: CardEffectResolver


func _init(state: MatchState, resolver: CardEffectResolver) -> void:
	_state = state
	_resolver = resolver


static func handles(effect_type: int) -> bool:
	return TYPES.has(effect_type)


## 駒の台座へ出す封じの印。檻(ケージの封じ)のほうが長く続くため、両方なら檻を出す。
static func mark_of(unit: CardInstance) -> int:
	if unit == null:
		return Mark.NONE
	if unit.held_caged:
		return Mark.CAGE
	return Mark.CHAIN if unit.attack_locked else Mark.NONE


## `side` の反転(通常の反転・反転権)がジェイラーに封じられているか。
static func flip_locked(state: MatchState, side: int) -> bool:
	return bool(state.flip_lock.get(side, false))


## 手番の終わりに、その側の封じ(次の手番の攻撃・反転)を解く。
static func release_turn_locks(state: MatchState, side: int) -> void:
	state.flip_lock[side] = false
	for unit in state.units(side):
		unit.attack_locked = false


## `side` が出す・使うカードのコストを、相手の場にいる駒が上げる量(トール)。消された駒は上げない。
static func toll(state: MatchState, side: int) -> int:
	var up := 0
	for unit: CardInstance in state.units(MatchState.other_side(side)):
		if not unit.silenced:
			up += unit.data.foe_cost_up
	return up


## 封じたケージが場を離れた駒の檻を解き、まだ場にいるぶんは `held_caged` を立てる。盤面の変わるたびに `MatchState` が呼ぶ。
static func refresh_cages(state: MatchState) -> void:
	var keys: Array[int] = []
	for side in [MatchState.Side.A, MatchState.Side.B]:
		for unit: CardInstance in state.units(side):
			if unit.cage_key != 0:
				keys.append(unit.cage_key)
	for side in [MatchState.Side.A, MatchState.Side.B]:
		for unit: CardInstance in state.units(side):
			if unit.caged_by != 0 and not keys.has(unit.caged_by):
				unit.caged_by = 0
			unit.held_caged = unit.caged_by != 0


func apply(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	if effect.effect_type == CardEnums.EffectType.LOCK_FLIP:
		_lock_flip(side, effect, from_slot, origin)
		return
	var entries := _resolver._targets(side, unit, effect, hint).filter(
		func(entry: Dictionary) -> bool: return not _resolver._unit_at(entry).is_dead()
	)
	if entries.is_empty():
		return
	_resolver._strike_for_targets(
		side, from_slot, effect.target, entries, CardEnums.EffectVisualStyle.DRAIN, origin
	)
	for entry: Dictionary in entries:
		var target := _resolver._unit_at(entry)
		match effect.effect_type:
			CardEnums.EffectType.LOCK_ATTACK:
				target.attack_locked = true
			CardEnums.EffectType.LOCK_ATTACK_WHILE_ALIVE:
				_cage(unit, target)
			CardEnums.EffectType.SEAL_FLIP:
				if not target.silenced:
					target.flip_sealed = true
	_state.board_changed.emit(MatchState.other_side(side))


## `cage` が場にいるあいだ `target` を封じる。1体のケージが封じられるのは1体(後から封じたほうだけ)。
func _cage(cage: CardInstance, target: CardInstance) -> void:
	if cage.cage_key == 0:
		cage.cage_key = _next_key
		_next_key += 1
	for other_side in [MatchState.Side.A, MatchState.Side.B]:
		for other: CardInstance in _state.units(other_side):
			if other.caged_by == cage.cage_key:
				other.caged_by = 0
	target.caged_by = cage.cage_key
	_state._refresh_held_keywords()


## 相手のプレイヤーを、次の相手の手番のあいだ反転できなくする。
func _lock_flip(side: int, effect: CardEffectData, from_slot: int, origin: int) -> void:
	var to_side := _resolver._player_side_for(side, effect.target)
	_resolver._strike(side, from_slot, to_side, -1, CardEnums.EffectVisualStyle.PULSE, origin)
	_state.flip_lock[to_side] = true


## 静止を与える効果(`GRANT_KEYWORD` の STILL)のCPUの見積もり。相手の駒へなら攻撃力の伸びを止めたぶん、自分の駒へなら失うぶん。
static func still_value(state: MatchState, side: int, effect: CardEffectData) -> float:
	var foe_side := MatchState.other_side(side)
	var stopped := func(unit: CardInstance) -> float:
		if unit.has_keyword(CardEnums.Keyword.STILL):
			return 0.0
		return float(unit.health * (unit.health - 1)) / 2.0 * STILL_FACTOR
	match effect.target:
		CardEnums.EffectTarget.ENEMY_UNIT:
			var best := 0.0
			for foe: CardInstance in state.units(foe_side):
				best = maxf(best, stopped.call(foe))
			return best
		CardEnums.EffectTarget.ALL_ENEMY_UNITS:
			var total := 0.0
			for foe: CardInstance in state.units(foe_side):
				total += stopped.call(foe)
			return total
		CardEnums.EffectTarget.ALL_ALLY_UNITS:
			var cost := 0.0
			for ally: CardInstance in state.units(side):
				cost += stopped.call(ally)
			return -cost
	return 0.0


## 場に残るあいだ働く常在の値打ち(トール)。相手の手札が多いほど効く。
static func cpu_standing_value(state: MatchState, side: int, card: CardData) -> float:
	if card.foe_cost_up <= 0:
		return 0.0
	var cards := mini(state.hand[MatchState.other_side(side)].size(), TOLL_CARDS_CAP)
	return float(card.foe_cost_up * cards) * TOLL_VALUE_PER_CARD


## 対局の評価で、封じられた駒の値を割り引く(`CardCpuSpellSearch.unit_value()` から)。
## 静止の駒は砂が落ちないため、生涯ダメージは伸びない分を除いて数える。
static func adjusted_unit_value(unit: CardInstance, value: float) -> float:
	if unit.has_keyword(CardEnums.Keyword.STILL):
		value -= float(unit.health * (unit.health - 1)) / 2.0
	if unit.attack_locked or unit.held_caged:
		value *= LOCKED_UNIT_FACTOR
	return value


## CPUの見積もり(`CardCpuStrategy._themed_value()` から)。止める相手の駒は、いま場にいる駒で数える。
static func cpu_value(state: MatchState, side: int, effect: CardEffectData) -> float:
	var foe_side := MatchState.other_side(side)
	var foes := state.units(foe_side)
	match effect.effect_type:
		CardEnums.EffectType.LOCK_ATTACK:
			if effect.target == CardEnums.EffectTarget.ALL_ENEMY_UNITS:
				var total := 0.0
				for foe: CardInstance in foes:
					total += float(foe.attack) * LOCK_VALUE
				return total
			var strongest := 0
			for foe: CardInstance in foes:
				strongest = maxi(strongest, foe.attack)
			return float(strongest) * LOCK_VALUE
		CardEnums.EffectType.LOCK_ATTACK_WHILE_ALIVE:
			var biggest := 0.0
			for foe: CardInstance in foes:
				biggest = maxf(biggest, float(foe.lifetime_damage()))
			return biggest * CAGE_FACTOR
		CardEnums.EffectType.SEAL_FLIP:
			return (
				SEAL_VALUE
				if foes.any(func(foe: CardInstance) -> bool: return foe.flippable())
				else 0.0
			)
		CardEnums.EffectType.LOCK_FLIP:
			var rights := float(state.flip_right_remaining.get(foe_side, 0))
			var flippers := foes.filter(func(foe: CardInstance) -> bool: return foe.flippable())
			return 0.0 if flippers.is_empty() else JAIL_VALUE + rights * JAIL_RIGHT_VALUE
	return 0.0
