class_name CardEffectResolver
extends RefCounted
## カード効果(トリガー × ターゲット × エフェクト)の評価と適用を1箇所に集約する。
## 新しいエフェクト種別を足すときは、ここへ1分岐を加えるだけで済む形を保つ。

var _state: MatchState


func _init(p_state: MatchState) -> void:
	_state = p_state


## unit が持つ trigger の効果をすべて適用する。
## hint は対象を選ばせる効果のための指定 {"side":..., "slot":...}。
func resolve(side: int, unit: CardInstance, trigger: int, hint: Dictionary) -> void:
	for effect in unit.data.effects_for(trigger):
		_apply(side, unit, effect, hint)


func _apply(side: int, unit: CardInstance, effect: CardEffectData, hint: Dictionary) -> void:
	var foe_side := MatchState.other_side(side)
	match effect.effect_type:
		CardEnums.EffectType.DAMAGE_PLAYER:
			_state.damage_player(_player_side_for(side, effect.target), effect.value)
		CardEnums.EffectType.HEAL_PLAYER:
			_state.heal_player(_player_side_for(side, effect.target), effect.value)
		CardEnums.EffectType.DRAW:
			_state.draw(side, effect.value)
		CardEnums.EffectType.DAMAGE_PLAYER_PER_ENEMY_UNIT:
			_state.damage_player(foe_side, _state.units(foe_side).size() * effect.value)
		CardEnums.EffectType.DAMAGE_UNIT:
			for entry in _targets(side, unit, effect, hint):
				_state.damage_unit(entry["side"], entry["slot"], effect.value)
		CardEnums.EffectType.DESTROY_UNIT:
			for entry in _targets(side, unit, effect, hint):
				_state.destroy_unit(entry["side"], entry["slot"])
		CardEnums.EffectType.SWAP_STATS:
			for entry in _targets(side, unit, effect, hint):
				var target := _unit_at(entry)
				if target != null:
					target.flip()
		CardEnums.EffectType.ADD_TOTAL:
			for entry in _targets(side, unit, effect, hint):
				var target := _unit_at(entry)
				if target != null:
					target.health += effect.value
		CardEnums.EffectType.DROP_SAND:
			for entry in _targets(side, unit, effect, hint):
				var target := _unit_at(entry)
				if target != null:
					target.drop_sand(effect.value)


func _player_side_for(side: int, target: int) -> int:
	if target == CardEnums.EffectTarget.OWN_PLAYER:
		return side
	return MatchState.other_side(side)


func _unit_at(entry: Dictionary) -> CardInstance:
	return _state.board[entry["side"]][entry["slot"]]


## 効果の対象になる砂時計を {"side":..., "slot":...} の配列として返す。
func _targets(side: int, unit: CardInstance, effect: CardEffectData, hint: Dictionary) -> Array:
	var foe_side := MatchState.other_side(side)
	match effect.target:
		CardEnums.EffectTarget.SELF:
			var slot := _slot_of(side, unit)
			return [] if slot < 0 else [{"side": side, "slot": slot}]
		CardEnums.EffectTarget.ALL_ENEMY_UNITS:
			return _all_slots(foe_side)
		CardEnums.EffectTarget.ALL_ALLY_UNITS:
			return _all_slots(side)
		CardEnums.EffectTarget.ENEMY_UNIT:
			return _single_enemy(foe_side, hint)
	return []


func _single_enemy(foe_side: int, hint: Dictionary) -> Array:
	if hint.has("slot") and hint.get("side", foe_side) == foe_side:
		var slot: int = hint["slot"]
		if _state.board[foe_side][slot] != null:
			return [{"side": foe_side, "slot": slot}]
	# 指定が無い・すでに居なくなっている場合は、最も生涯ダメージの大きい1体を選ぶ。
	var best := -1
	var best_value := -1
	for slot in MatchState.BOARD_SIZE:
		var candidate: CardInstance = _state.board[foe_side][slot]
		if candidate == null:
			continue
		var value := candidate.lifetime_damage()
		if value > best_value:
			best_value = value
			best = slot
	return [] if best < 0 else [{"side": foe_side, "slot": best}]


func _all_slots(side: int) -> Array:
	var found: Array = []
	for slot in MatchState.BOARD_SIZE:
		if _state.board[side][slot] != null:
			found.append({"side": side, "slot": slot})
	return found


func _slot_of(side: int, unit: CardInstance) -> int:
	for slot in MatchState.BOARD_SIZE:
		if _state.board[side][slot] == unit:
			return slot
	return -1
