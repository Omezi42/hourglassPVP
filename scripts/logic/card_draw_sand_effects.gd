class_name CardDrawSandEffects
extends RefCounted
## 第3弾「汲砂の刻」の固有効果(GameDesign.md 6章「相手から砂を移す効果」)。
## 相手の攻撃力を抜いて自分へ注ぐ・相手の総量を減らして移す・総量の入れ替え・戦闘で与えた量だけ砂を戻す。
## 抜く相手は対象の指定(`_targets`)で、受け取る自分の駒は `ally_for_gain()` が自動で選ぶ(プレイヤーが選ぶのは相手の駒だけ)。

const TYPES := [
	CardEnums.EffectType.DRAIN_ATTACK_TO_ALLY,
	CardEnums.EffectType.DRAIN_ATTACK_TO_HP,
	CardEnums.EffectType.DRAIN_ATTACK_TO_SELF,
	CardEnums.EffectType.TRANSFER_TOTAL_FROM_FOE,
	CardEnums.EffectType.SWAP_TOTAL_WITH_ALLY,
	CardEnums.EffectType.RAISE_SAND_BY_DEALT,
]
## 体力はこれ未満にしない(総量の入れ替えで自分の駒を砕かないため)。
const MIN_HEALTH := 1
## CPUの見積もり。抜く攻撃力1点・増える体力(総量)1点・減らす相手の総量1点・戦闘で与えた量だけ戻す砂の見込み。
const ATTACK_VALUE := 1.5
const HEALTH_VALUE := 2.0
const FOE_TOTAL_VALUE := 1.0
const DEALT_RAISE_VALUE := 1.0
## 自分のHP1点の値打ち(`HEAL_VALUE` と同じ)。
const HEAL_VALUE := 1.6

var _state: MatchState
var _resolver: CardEffectResolver


func _init(state: MatchState, resolver: CardEffectResolver) -> void:
	_state = state
	_resolver = resolver


static func handles(effect_type: int) -> bool:
	return TYPES.has(effect_type)


## 相手の砂時計の砂が上へ戻ったことを知らせ、その持ち主の相手側の駒(アクイファー)を働かせる。
## 砂を上へ戻す処理はすべてここを通す。戻った駒1体ごとに1回(戻った量は問わない)。
static func note_sand_raised(state: MatchState, side: int, slot: int, amount: int) -> void:
	state.unit_raised.emit(side, slot, amount)
	var owner_side := MatchState.other_side(side)
	for unit: CardInstance in state.units(owner_side):
		if unit.is_dead() or unit.effects_for(CardEnums.Trigger.ON_FOE_SAND_RAISED).is_empty():
			continue
		state._fire(owner_side, unit, CardEnums.Trigger.ON_FOE_SAND_RAISED, {})


## 抜いた砂を受け取る自分の駒(効果を持つ駒自身は除く)。生涯ダメージがいちばん大きい駒で、同点なら左の枠。いなければ null。
static func ally_for_gain(state: MatchState, side: int, exclude: CardInstance) -> CardInstance:
	var best: CardInstance = null
	for unit: CardInstance in state.units(side):
		if unit == exclude or unit.is_dead():
			continue
		if best == null or unit.lifetime_damage() > best.lifetime_damage():
			best = unit
	return best


## 総量を入れ替える自分の駒(効果を持つ駒自身は除く)。総量がいちばん小さい駒で、同点なら左の枠。いなければ null。
static func ally_for_swap(state: MatchState, side: int, exclude: CardInstance) -> CardInstance:
	var best: CardInstance = null
	for unit: CardInstance in state.units(side):
		if unit == exclude or unit.is_dead():
			continue
		if best == null or unit.total_sand() < best.total_sand():
			best = unit
	return best


## 相手の駒の総量を amount 減らし、実際に減った数を返す。体力から引き(体力1までは攻撃力を残す)、
## 体力が1未満になるぶんは攻撃力から引く。総量が0になれば体力0で、解決の後に砕ける。
static func shrink_foe_total(unit: CardInstance, amount: int) -> int:
	var cut := mini(amount, unit.total_sand())
	if cut <= 0:
		return 0
	var from_health := mini(cut, maxi(unit.health - MIN_HEALTH, 0))
	unit.health -= from_health
	var rest := cut - from_health
	var from_attack := mini(rest, unit.attack)
	unit.attack -= from_attack
	rest -= from_attack
	unit.health -= rest
	return cut


## 総量 total を、体力と攻撃力の比 (health : attack) を保って分けた (体力, 攻撃力)。攻撃力は四捨五入(ちょうど半分は体力へ)で、
## 残りが体力。体力は1を下回らない。
static func split_total(total: int, attack: int, health: int) -> Vector2i:
	var sum := health + attack
	var new_attack := total if sum <= 0 else (2 * total * attack + sum - 1) / (2 * sum)
	var new_health := total - new_attack
	if new_health < MIN_HEALTH and total >= MIN_HEALTH:
		new_health = MIN_HEALTH
		new_attack = total - MIN_HEALTH
	return Vector2i(new_health, new_attack)


func apply(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	match effect.effect_type:
		CardEnums.EffectType.DRAIN_ATTACK_TO_ALLY:
			_drain_to_ally(side, unit, effect, hint, from_slot, origin)
		CardEnums.EffectType.DRAIN_ATTACK_TO_HP:
			_drain_to_hp(side, unit, effect, hint, from_slot, origin)
		CardEnums.EffectType.DRAIN_ATTACK_TO_SELF:
			_drain_to_self(side, unit, effect, hint, from_slot, origin)
		CardEnums.EffectType.TRANSFER_TOTAL_FROM_FOE:
			_transfer_from_foe(side, unit, effect, hint, from_slot, origin)
		CardEnums.EffectType.SWAP_TOTAL_WITH_ALLY:
			_swap_total(side, unit, effect, hint, from_slot, origin)
		CardEnums.EffectType.RAISE_SAND_BY_DEALT:
			_raise_by_dealt(side, unit, hint)


## 相手の駒の攻撃力を amount まで抜く。抜けた数を返す(0未満にはならない)。
func _drain(foe: CardInstance, amount: int) -> int:
	var moved := mini(amount, foe.attack)
	foe.attack -= moved
	return moved


func _foe_target(side: int, unit: CardInstance, effect: CardEffectData, hint: Dictionary) -> Array:
	return _resolver._targets(side, unit, effect, hint)


func _drain_to_ally(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	var entries := _foe_target(side, unit, effect, hint)
	if entries.is_empty():
		return
	_resolver._strike_for_targets(
		side, from_slot, effect.target, entries, CardEnums.EffectVisualStyle.DRAIN, origin
	)
	var moved := _drain(_resolver._unit_at(entries[0]), effect.value)
	var ally := ally_for_gain(_state, side, null)
	if moved > 0 and ally != null:
		_strike_ally(side, from_slot, ally, origin)
		ally.health += moved


func _drain_to_hp(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	var entries := _foe_target(side, unit, effect, hint)
	if entries.is_empty():
		return
	_resolver._strike_for_targets(
		side, from_slot, effect.target, entries, CardEnums.EffectVisualStyle.DRAIN, origin
	)
	var foe := _resolver._unit_at(entries[0])
	var moved := _drain(foe, foe.attack)
	if moved > 0:
		_state.heal_player(side, moved)


func _drain_to_self(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	var entries := _foe_target(side, unit, effect, hint)
	_resolver._strike_for_targets(
		side, from_slot, effect.target, entries, CardEnums.EffectVisualStyle.DRAIN, origin
	)
	var moved := 0
	for entry: Dictionary in entries:
		moved += _drain(_resolver._unit_at(entry), effect.value)
	unit.health += moved


func _transfer_from_foe(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	var entries := _foe_target(side, unit, effect, hint)
	if entries.is_empty():
		return
	_resolver._strike_for_targets(
		side, from_slot, effect.target, entries, CardEnums.EffectVisualStyle.DRAIN, origin
	)
	var moved := shrink_foe_total(_resolver._unit_at(entries[0]), effect.value)
	var ally := ally_for_gain(_state, side, unit)
	if moved > 0 and ally != null:
		_strike_ally(side, from_slot, ally, origin)
		ally.health += moved if effect.transfer_gain < 0 else effect.transfer_gain


func _swap_total(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	var entries := _foe_target(side, unit, effect, hint)
	var ally := ally_for_swap(_state, side, unit)
	if entries.is_empty() or ally == null:
		return
	var foe := _resolver._unit_at(entries[0])
	_resolver._strike_for_targets(
		side, from_slot, effect.target, entries, CardEnums.EffectVisualStyle.SPIN, origin
	)
	_strike_ally(side, from_slot, ally, origin)
	var foe_total := foe.total_sand()
	var ally_total := ally.total_sand()
	var foe_after := split_total(ally_total, foe.attack, foe.health)
	var ally_after := split_total(foe_total, ally.attack, ally.health)
	foe.health = foe_after.x
	foe.attack = foe_after.y
	ally.health = ally_after.x
	ally.attack = ally_after.y


## 戦闘で与えたダメージ(hint の dealt)の数だけ、この駒の砂を上へ戻す。
func _raise_by_dealt(side: int, unit: CardInstance, hint: Dictionary) -> void:
	var slot := _resolver._slot_of(side, unit)
	var dealt := int(hint.get("dealt", 0))
	if slot < 0 or dealt <= 0:
		return
	var moved := unit.raise_sand(dealt)
	if moved > 0:
		note_sand_raised(_state, side, slot, moved)


func _strike_ally(side: int, from_slot: int, ally: CardInstance, origin: int) -> void:
	var slot := _resolver._slot_of(side, ally)
	if slot >= 0:
		_resolver._strike(side, from_slot, side, slot, CardEnums.EffectVisualStyle.DESCEND, origin)


## CPUの見積もり(`CardCpuStrategy._themed_value()` から)。抜ける量・移る量は、いま場にいる相手の駒で数える。
static func cpu_value(state: MatchState, side: int, effect: CardEffectData) -> float:
	var foe_side := MatchState.other_side(side)
	var has_ally := not state.units(side).is_empty()
	var strongest := CardEffectResolver.highest_attack_slot(state, foe_side, null)
	match effect.effect_type:
		CardEnums.EffectType.DRAIN_ATTACK_TO_ALLY:
			if strongest < 0:
				return 0.0
			var moved := mini(state.board[foe_side][strongest].attack, effect.value)
			return float(moved) * (ATTACK_VALUE + (HEALTH_VALUE if has_ally else 0.0))
		CardEnums.EffectType.DRAIN_ATTACK_TO_HP:
			if strongest < 0:
				return 0.0
			var attack: int = state.board[foe_side][strongest].attack
			return float(attack) * (ATTACK_VALUE + CardCpuStrategy.FACE_WEIGHT)
		CardEnums.EffectType.DRAIN_ATTACK_TO_SELF:
			var total := 0
			for foe: CardInstance in state.units(foe_side):
				total += mini(foe.attack, effect.value)
			return float(total) * (ATTACK_VALUE + HEALTH_VALUE)
		CardEnums.EffectType.TRANSFER_TOTAL_FROM_FOE:
			if state.units(foe_side).is_empty():
				return 0.0
			var gain := effect.value if effect.transfer_gain < 0 else effect.transfer_gain
			return (
				float(effect.value) * FOE_TOTAL_VALUE
				+ (float(gain) * HEALTH_VALUE if has_ally else 0.0)
			)
		CardEnums.EffectType.SWAP_TOTAL_WITH_ALLY:
			var ally := ally_for_swap(state, side, null)
			if ally == null or state.units(foe_side).is_empty():
				return 0.0
			var biggest := 0
			for foe: CardInstance in state.units(foe_side):
				biggest = maxi(biggest, foe.total_sand())
			return maxf(float(biggest - ally.total_sand()), 0.0) * HEALTH_VALUE
		CardEnums.EffectType.RAISE_SAND_BY_DEALT:
			return DEALT_RAISE_VALUE
	return 0.0
