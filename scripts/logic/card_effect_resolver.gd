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
	for effect in unit.effects_for(trigger):
		_apply(side, unit, effect, hint)


func _apply(side: int, unit: CardInstance, effect: CardEffectData, hint: Dictionary) -> void:
	var foe_side := MatchState.other_side(side)
	# 光の筋の出どころ(GameDesign.md 9章)。余砂は既に盤面から降りているため -1 になり、
	# その場合は筋を出さない(呼び出し側の判断)。
	var from := _slot_of(side, unit)
	match effect.effect_type:
		CardEnums.EffectType.DAMAGE_PLAYER:
			var to_side := _player_side_for(side, effect.target)
			_beam(side, from, to_side, -1)
			_state.damage_player(to_side, effect.value)
		CardEnums.EffectType.HEAL_PLAYER:
			var to_side := _player_side_for(side, effect.target)
			_beam(side, from, to_side, -1)
			_state.heal_player(to_side, effect.value)
		CardEnums.EffectType.DRAW:
			_state.draw(side, effect.value)
		CardEnums.EffectType.DAMAGE_PLAYER_PER_ENEMY_UNIT:
			_beam(side, from, foe_side, -1)
			_state.damage_player(foe_side, _state.units(foe_side).size() * effect.value)
		CardEnums.EffectType.DAMAGE_UNIT:
			for entry in _targets(side, unit, effect, hint):
				_beam(side, from, entry["side"], entry["slot"])
				_state.damage_unit(entry["side"], entry["slot"], effect.value)
		CardEnums.EffectType.DESTROY_UNIT:
			for entry in _targets(side, unit, effect, hint):
				_beam(side, from, entry["side"], entry["slot"])
				_state.destroy_unit(entry["side"], entry["slot"])
		CardEnums.EffectType.SWAP_STATS:
			for entry in _targets(side, unit, effect, hint):
				var target := _unit_at(entry)
				if target != null:
					_beam(side, from, entry["side"], entry["slot"])
					target.flip()
		CardEnums.EffectType.ADD_TOTAL:
			for entry in _targets(side, unit, effect, hint):
				var target := _unit_at(entry)
				if target != null:
					_beam(side, from, entry["side"], entry["slot"])
					target.health += effect.value
		CardEnums.EffectType.ADD_ATTACK:
			for entry in _targets(side, unit, effect, hint):
				var target := _unit_at(entry)
				if target != null:
					_beam(side, from, entry["side"], entry["slot"])
					target.attack += effect.value
		CardEnums.EffectType.DROP_SAND:
			for entry in _targets(side, unit, effect, hint):
				var target := _unit_at(entry)
				if target != null:
					_beam(side, from, entry["side"], entry["slot"])
					target.drop_sand(effect.value)
		CardEnums.EffectType.SUMMON:
			_summon(side, effect.card_id)
		CardEnums.EffectType.GRANT_KEYWORD:
			for entry in _targets(side, unit, effect, hint):
				var target := _unit_at(entry)
				if target != null and effect.keyword >= 0:
					_beam(side, from, entry["side"], entry["slot"])
					target.grant_keyword(effect.keyword)
		CardEnums.EffectType.INVERT_PLAYER_HP:
			var to_side := _player_side_for(side, effect.target)
			_beam(side, from, to_side, -1)
			_invert_hp(to_side)
		CardEnums.EffectType.RETURN_TO_HAND:
			for entry in _targets(side, unit, effect, hint):
				_beam(side, from, entry["side"], entry["slot"])
				_return_to_hand(entry["side"], entry["slot"])
		CardEnums.EffectType.SILENCE:
			for entry in _targets(side, unit, effect, hint):
				var target := _unit_at(entry)
				if target != null:
					_beam(side, from, entry["side"], entry["slot"])
					target.silence()


## 空き枠へ砂時計を1体出す。**空きが無ければ何もしない**(GameDesign.md 6章)。
## 出した駒の設置効果は解決しない。連鎖すると1枚のカードが何をするか読めなくなるため。
func _summon(side: int, card_id: String) -> void:
	if card_id.is_empty():
		return
	var card := CardLibrary.find_by_id(card_id)
	if card == null:
		return
	for slot in MatchState.BOARD_SIZE:
		if _state.board[side][slot] == null:
			_state.board[side][slot] = CardInstance.new(card)
			_state.board_changed.emit(side)
			return


## プレイヤーのHPを反転する(砂術。GameDesign.md 6章)。**残りHPと失ったHPを入れ替える**もので、
## 砂時計の反転(上の部屋と下の部屋の入れ替え)をプレイヤー自身へ持ち込んだもの。
##
## 増減は既存の `heal_player()` / `damage_player()` へ渡す。HPの上限・0での決着・
## シグナルの発行がすべてそこにあり、ここで直接書き換えると3つとも取りこぼす
## (満タンで撃つと自分が負ける、という肝心の挙動が働かなくなる)。
func _invert_hp(side: int) -> void:
	var target := MatchState.INITIAL_HP - int(_state.hp[side])
	var current := int(_state.hp[side])
	if target > current:
		_state.heal_player(side, target - current)
	elif target < current:
		_state.damage_player(side, current - target)


## 砂時計を持ち主の手札へ戻す(砂術。GameDesign.md 6章)。**破壊ではないため余砂は
## 発火しない。**戻るのは CardData であり、受けたダメージも与えられたキーワードも失われる。
## **`_summon()` と対になる**ため、盤面への出し入れは両方ともここが持つ。
func _return_to_hand(side: int, slot: int) -> void:
	var unit: CardInstance = _state.board[side][slot]
	if unit == null:
		return
	_state.board[side][slot] = null
	_state.hand[side].append(unit.data)
	_state.unit_returned.emit(side, slot, unit.data)
	_state.hand_changed.emit(side)
	_state.board_changed.emit(side)


## 効果が対象を取ったことを知らせる。**適用の直前に出す**ことで、対象が破壊されて
## 盤面から消える効果でも、筋の行き先がまだ盤面に残っている状態で受け取れる。
func _beam(side: int, from: int, target_side: int, target_slot: int) -> void:
	_state.effect_targeted.emit(side, from, target_side, target_slot)


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
			return _single_unit(foe_side, hint)
		CardEnums.EffectTarget.ALLY_UNIT:
			# **自分自身は選べない**(GameDesign.md 6章)。効果を持つ駒が自分を強化すると
			# 「他の駒を助ける」というカードの読みが崩れ、対象を選ぶ意味も無くなるため。
			return _single_unit(side, hint, _slot_of(side, unit))
	return []


## 対象を1体だけ選ぶ効果の解決。相手側(ENEMY_UNIT)も自分側(ALLY_UNIT)もここを通る。
func _single_unit(target_side: int, hint: Dictionary, exclude_slot := -1) -> Array:
	if hint.has("slot") and hint.get("side", target_side) == target_side:
		var slot: int = hint["slot"]
		if slot != exclude_slot and _state.board[target_side][slot] != null:
			return [{"side": target_side, "slot": slot}]
	# 指定が無い・すでに居なくなっている場合は、最も生涯ダメージの大きい1体を選ぶ。
	var best := -1
	var best_value := -1
	for slot in MatchState.BOARD_SIZE:
		var candidate: CardInstance = _state.board[target_side][slot]
		if candidate == null or slot == exclude_slot:
			continue
		var value := candidate.lifetime_damage()
		if value > best_value:
			best_value = value
			best = slot
	return [] if best < 0 else [{"side": target_side, "slot": best}]


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
