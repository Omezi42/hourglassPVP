class_name CardBackWaterEffects
extends RefCounted
## 第2弾「背水の刻」の固有効果(GameDesign.md 6章「自分のHPを参照する効果」)。
## `CardEffectResolver` が1000行の上限に近いため、HPの差を読む効果の解決・条件の判定・CPUの見積もりをここへ切り出す。
## 紋章を知らせる処理は `CardEffectResolver` のものを使う(`CardLegendEffects` と同じ作り)。

const TYPES := [
	CardEnums.EffectType.HEAL_PLAYER_HALF_HP_GAP,
	CardEnums.EffectType.DAMAGE_RANDOM_UNITS_BY_HP_GAP,
]
## ラストアワーの1回ぶんのダメージ。
const HIT_DAMAGE := 1

var _state: MatchState
var _resolver: CardEffectResolver


func _init(state: MatchState, resolver: CardEffectResolver) -> void:
	_state = state
	_resolver = resolver


static func handles(effect_type: int) -> bool:
	return TYPES.has(effect_type)


## 自分のHPが相手より少ないぶん。0以下なら劣勢ではない(同じなら満たさない)。
static func hp_gap(state: MatchState, side: int) -> int:
	return int(state.hp[MatchState.other_side(side)]) - int(state.hp[side])


## HPを見る発動条件(OWN_HP_BELOW_FOE / OWN_HP_AT_MOST)を満たしているか。ほかの条件は見ない。
## 解決側とCPUの見積もりが同じ物差しで判定できるよう公開する。
static func hp_condition_met(state: MatchState, side: int, effect: CardEffectData) -> bool:
	match effect.condition_scope:
		CardEnums.ConditionScope.OWN_HP_BELOW_FOE:
			return hp_gap(state, side) > 0
		CardEnums.ConditionScope.OWN_HP_AT_MOST:
			return int(state.hp[side]) <= effect.condition_total
	return true


## リブラの回復量。HP差の半分(切り上げ)。
static func half_gap(state: MatchState, side: int) -> int:
	return (maxi(hp_gap(state, side), 0) + 1) / 2


func apply(side: int, effect: CardEffectData, from_slot: int, origin: int) -> void:
	match effect.effect_type:
		CardEnums.EffectType.HEAL_PLAYER_HALF_HP_GAP:
			_heal_half_gap(side, from_slot, origin)
		CardEnums.EffectType.DAMAGE_RANDOM_UNITS_BY_HP_GAP:
			_hit_random_units(side, from_slot, origin)


func _heal_half_gap(side: int, from_slot: int, origin: int) -> void:
	var amount := half_gap(_state, side)
	if amount <= 0:
		return
	_resolver._strike(side, from_slot, side, -1, CardEnums.EffectVisualStyle.DESCEND, origin)
	_state.heal_player(side, amount)


## 差の数だけ1点ずつ、その時点で場にいる(砕けていない)相手の砂時計からランダムに選んで与える。
## 乱数は対局の乱数から引く(リプレイ・オンラインで一致させるため)。相手の駒がいなくなったら残りは捨てる。
func _hit_random_units(side: int, from_slot: int, origin: int) -> void:
	var foe_side := MatchState.other_side(side)
	var hits := maxi(hp_gap(_state, side), 0)
	for i in hits:
		var pool: Array[int] = []
		for slot in MatchState.BOARD_SIZE:
			var foe: CardInstance = _state.board[foe_side][slot]
			if foe != null and not foe.is_dead():
				pool.append(slot)
		if pool.is_empty():
			return
		var slot: int = pool[_state._rng.randi_range(0, pool.size() - 1)]
		_resolver._strike(
			side, from_slot, foe_side, slot, CardEnums.EffectVisualStyle.STRIKE, origin
		)
		_state.damage_unit(foe_side, slot, HIT_DAMAGE)


## CPUの見積もり(`CardCpuStrategy._on_play_value()`)。条件を満たさない盤面では0。
static func cpu_value(state: MatchState, side: int, effect: CardEffectData) -> float:
	var value := 0.0
	match effect.effect_type:
		CardEnums.EffectType.HEAL_PLAYER_HALF_HP_GAP:
			value = float(half_gap(state, side)) * CardCpuStrategy.FACE_WEIGHT
		CardEnums.EffectType.DAMAGE_RANDOM_UNITS_BY_HP_GAP:
			var foes := state.units(MatchState.other_side(side))
			var hits := maxi(hp_gap(state, side), 0)
			# 1点ずつ無作為に散るため、どの駒にも同じ確率で当たるものとして1点ぶんの値打ちを均す。
			for foe: CardInstance in foes:
				value += _hit_value(foe) * hits / foes.size()
	return value


## 駒へ1点与えたときに減る生涯ダメージ(硝子が残っていれば吸われる)。
static func _hit_value(unit: CardInstance) -> float:
	if unit.glass_intact:
		return 0.0
	var before := float(unit.lifetime_damage())
	var health := unit.health - HIT_DAMAGE
	if health <= 0:
		return before
	return before - CardCpuStrategy.lifetime_of(health, unit.attack)
