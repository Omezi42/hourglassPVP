class_name CardFuseSandEffects
extends RefCounted
## 第2弾「導火の刻」の固有効果(GameDesign.md 6章「効果を与える効果」)。
## `CardEffectResolver` が1000行の上限に近いため、効果を与える効果・出したターンの制限を外す効果・攻撃力ぶんのダメージの解決と
## CPUの見積もりをここへ切り出す。紋章を知らせる処理・対象を並べる処理は `CardEffectResolver` のものを使う。

const TYPES := [
	CardEnums.EffectType.GRANT_EFFECT,
	CardEnums.EffectType.LIFT_SUMMON_LIMIT,
	CardEnums.EffectType.DAMAGE_UNIT_BY_OWN_ATTACK,
	CardEnums.EffectType.DESTROY_AND_REPEAT_DEATH,
]
## CPUの見積もり。与えた効果(導火線)を持つ駒が場にいる間に、その効果が働く見込みの回数。
const GRANT_FIRES := 1.0

var _state: MatchState
var _resolver: CardEffectResolver


func _init(state: MatchState, resolver: CardEffectResolver) -> void:
	_state = state
	_resolver = resolver


static func handles(effect_type: int) -> bool:
	return TYPES.has(effect_type)


func apply(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	var entries := _resolver._targets(side, unit, effect, hint)
	match effect.effect_type:
		CardEnums.EffectType.GRANT_EFFECT:
			_resolver._strike_for_targets(
				side, from_slot, effect.target, entries, CardEnums.EffectVisualStyle.DESCEND, origin
			)
			for entry: Dictionary in entries:
				var target := _resolver._unit_at(entry)
				if target != null:
					target.grant_effect(effect.granted_effect)
		CardEnums.EffectType.LIFT_SUMMON_LIMIT:
			var fresh: Array = entries.filter(
				func(entry: Dictionary) -> bool: return _resolver._unit_at(entry).summoned_this_turn
			)
			_resolver._strike_for_targets(
				side, from_slot, effect.target, fresh, CardEnums.EffectVisualStyle.DESCEND, origin
			)
			for entry: Dictionary in fresh:
				_resolver._unit_at(entry).summoned_this_turn = false
		CardEnums.EffectType.DESTROY_AND_REPEAT_DEATH:
			_destroy_and_repeat(side, entries, from_slot, origin)
		CardEnums.EffectType.DAMAGE_UNIT_BY_OWN_ATTACK:
			# 攻撃力0なら鳴らす鐘が無い。紋章も飛ばさない。
			if unit.attack <= 0:
				return
			_resolver._strike_for_targets(
				side, from_slot, effect.target, entries, CardEnums.EffectVisualStyle.STRIKE, origin
			)
			for entry: Dictionary in entries:
				_state.damage_unit(entry["side"], entry["slot"], unit.attack)


## 対象を破壊し(余砂が1回働く)、その余砂をもう一度発動する(爆心)。余砂を持たない駒には何もしない。
func _destroy_and_repeat(side: int, entries: Array, from_slot: int, origin: int) -> void:
	if entries.is_empty():
		return
	var target := _resolver._unit_at(entries[0])
	if target == null or target.effects_for(CardEnums.Trigger.ON_DEATH).is_empty():
		return
	var slot: int = entries[0]["slot"]
	_resolver._strike_for_targets(
		side,
		from_slot,
		CardEnums.EffectTarget.ALLY_UNIT,
		entries,
		CardEnums.EffectVisualStyle.STRIKE,
		origin
	)
	_state.destroy_unit(side, slot)
	_state._fire(side, target, CardEnums.Trigger.ON_DEATH, {"death_slot": slot})


## CPUの見積もり。`unit` は効果を持つ駒(設置の見積もりでは置く前なので null)。
static func cpu_value(state: MatchState, side: int, effect: CardEffectData) -> float:
	var foe_side := MatchState.other_side(side)
	match effect.effect_type:
		CardEnums.EffectType.GRANT_EFFECT:
			var granted := effect.granted_effect
			if granted == null or state.units(side).is_empty():
				return 0.0
			return _granted_value(state, side, granted) * GRANT_FIRES
		CardEnums.EffectType.LIFT_SUMMON_LIMIT:
			var best := 0.0
			for unit: CardInstance in state.units(side):
				if unit.summoned_this_turn and unit.attack > 0:
					best = maxf(best, float(unit.attack) * CardCpuStrategy.FACE_WEIGHT)
			return best
		CardEnums.EffectType.DAMAGE_UNIT_BY_OWN_ATTACK:
			return float(state.units(foe_side).size()) * CardCpuStrategy.FACE_WEIGHT
	return 0.0


## 与える効果1つの見込みの値打ち。全体へのダメージは相手の駒の数だけ積み上がる。
static func _granted_value(state: MatchState, side: int, granted: CardEffectData) -> float:
	var foe_side := MatchState.other_side(side)
	if granted.effect_type == CardEnums.EffectType.DAMAGE_UNIT:
		return float(state.units(foe_side).size() * granted.value)
	return 1.0
