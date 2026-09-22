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
		if _condition_met(side, unit, effect):
			_apply(side, unit, effect, hint)


## コンボ系カードの発動条件(GameDesign.md 6章)。TARGET は対象そのものの絞り込みで
## `_single_unit()` が扱うため、ここでは SELF / ANY_ALLY だけを見る。
func _condition_met(side: int, unit: CardInstance, effect: CardEffectData) -> bool:
	match effect.condition_scope:
		CardEnums.ConditionScope.SELF:
			return unit.total_sand() == effect.condition_total
		CardEnums.ConditionScope.ANY_ALLY:
			for ally in _state.units(side):
				if ally.total_sand() == effect.condition_total:
					return true
			return false
	return true


func _apply(side: int, unit: CardInstance, effect: CardEffectData, hint: Dictionary) -> void:
	var foe_side := MatchState.other_side(side)
	# 対象の解決に使う枠(GameDesign.md 6章の SELF 除外・ALLY_UNIT 除外)。
	# **紋章の出どころ(from_slot)とは分けて持つ**——DEATH で差し替えると
	# ALLY_UNIT の除外や SELF の判定が空の枠を指すことになるため(Architecture.md 4.0節)。
	var from := _slot_of(side, unit)
	# 紋章の出どころ(GameDesign.md 9章「紋章の出どころ」)。UNIT/SPELL/DEATH の
	# いずれかを、この効果1件ぶんの解決の入口で決める。
	var origin := _origin_of(from, hint)
	var from_slot := from if origin == CardEnums.EffectOrigin.UNIT else _origin_slot(hint, origin)
	match effect.effect_type:
		CardEnums.EffectType.DAMAGE_PLAYER:
			var to_side := _player_side_for(side, effect.target)
			_strike(side, from_slot, to_side, -1, CardEnums.EffectVisualStyle.STRIKE, origin)
			_state.damage_player(to_side, effect.value)
		CardEnums.EffectType.HEAL_PLAYER:
			var to_side := _player_side_for(side, effect.target)
			_strike(side, from_slot, to_side, -1, CardEnums.EffectVisualStyle.DESCEND, origin)
			_state.heal_player(to_side, effect.value)
		CardEnums.EffectType.DRAW:
			# 対象を取らない効果(GameDesign.md 9章)。盤面上の駒からならその場で
			# 光る合図(effect_drawn)、砂術・余砂なら紋章がその場で弾けるPULSEにする。
			if origin == CardEnums.EffectOrigin.UNIT:
				_state.effect_drawn.emit(side, from_slot, effect.value)
			else:
				_strike(side, from_slot, side, -1, CardEnums.EffectVisualStyle.PULSE, origin)
			_state.draw(side, effect.value)
		CardEnums.EffectType.DAMAGE_PLAYER_PER_ENEMY_UNIT:
			_strike(side, from_slot, foe_side, -1, CardEnums.EffectVisualStyle.STRIKE, origin)
			_state.damage_player(foe_side, _state.units(foe_side).size() * effect.value)
		CardEnums.EffectType.DAMAGE_UNIT:
			var damage_entries := _targets(side, unit, effect, hint)
			_strike_for_targets(
				side,
				from_slot,
				effect.target,
				damage_entries,
				CardEnums.EffectVisualStyle.STRIKE,
				origin
			)
			for entry in damage_entries:
				_state.damage_unit(entry["side"], entry["slot"], effect.value)
		CardEnums.EffectType.DESTROY_UNIT:
			var destroy_entries := _targets(side, unit, effect, hint)
			_strike_for_targets(
				side,
				from_slot,
				effect.target,
				destroy_entries,
				CardEnums.EffectVisualStyle.STRIKE,
				origin
			)
			for entry in destroy_entries:
				_state.destroy_unit(entry["side"], entry["slot"])
		CardEnums.EffectType.SWAP_STATS:
			var swap_entries := _targets(side, unit, effect, hint)
			_strike_for_targets(
				side,
				from_slot,
				effect.target,
				swap_entries,
				CardEnums.EffectVisualStyle.SPIN,
				origin
			)
			for entry in swap_entries:
				var target := _unit_at(entry)
				if target != null:
					target.flip()
		CardEnums.EffectType.ADD_TOTAL:
			var total_entries := _targets(side, unit, effect, hint)
			_strike_for_targets(
				side,
				from_slot,
				effect.target,
				total_entries,
				CardEnums.EffectVisualStyle.DESCEND,
				origin
			)
			for entry in total_entries:
				var target := _unit_at(entry)
				if target != null:
					target.health += effect.value
		CardEnums.EffectType.ADD_ATTACK:
			var attack_entries := _targets(side, unit, effect, hint)
			_strike_for_targets(
				side,
				from_slot,
				effect.target,
				attack_entries,
				CardEnums.EffectVisualStyle.DESCEND,
				origin
			)
			for entry in attack_entries:
				var target := _unit_at(entry)
				if target != null:
					target.attack += effect.value
		CardEnums.EffectType.DROP_SAND:
			var drop_entries := _targets(side, unit, effect, hint)
			# 相手全体を削るのは打撃、味方全体・味方1体を削るのは自分で払う代償として
			# 恵与の型で見せる(GameDesign.md 9章)。
			var drop_style := (
				CardEnums.EffectVisualStyle.STRIKE
				if effect.target == CardEnums.EffectTarget.ALL_ENEMY_UNITS
				else CardEnums.EffectVisualStyle.DESCEND
			)
			_strike_for_targets(side, from_slot, effect.target, drop_entries, drop_style, origin)
			for entry in drop_entries:
				var target := _unit_at(entry)
				if target != null:
					target.drop_sand(effect.value)
		CardEnums.EffectType.RAISE_SAND:
			var raise_entries := _targets(side, unit, effect, hint)
			# 味方へは寿命を伸ばす恵与、相手へは攻撃力を抜く払拭として見せる(GameDesign.md 9章)。
			var raise_style := (
				CardEnums.EffectVisualStyle.DRAIN
				if _is_enemy_target(effect.target)
				else CardEnums.EffectVisualStyle.DESCEND
			)
			_strike_for_targets(side, from_slot, effect.target, raise_entries, raise_style, origin)
			for entry in raise_entries:
				var target := _unit_at(entry)
				if target == null:
					continue
				var moved := target.raise_sand(effect.value)
				if moved > 0:
					_state.unit_raised.emit(entry["side"], entry["slot"], moved)
		CardEnums.EffectType.SUMMON:
			var summon_slot := _first_empty_slot(side)
			if summon_slot >= 0:
				_strike(
					side, from_slot, side, summon_slot, CardEnums.EffectVisualStyle.DESCEND, origin
				)
			_summon(side, effect.card_id)
		CardEnums.EffectType.GRANT_KEYWORD:
			var keyword_entries := _targets(side, unit, effect, hint)
			_strike_for_targets(
				side,
				from_slot,
				effect.target,
				keyword_entries,
				CardEnums.EffectVisualStyle.DESCEND,
				origin
			)
			for entry in keyword_entries:
				var target := _unit_at(entry)
				if target != null and effect.keyword >= 0:
					target.grant_keyword(effect.keyword)
		CardEnums.EffectType.INVERT_PLAYER_HP:
			var to_side := _player_side_for(side, effect.target)
			_strike(side, from_slot, to_side, -1, CardEnums.EffectVisualStyle.SPIN, origin)
			_invert_hp(to_side)
		CardEnums.EffectType.RETURN_TO_HAND:
			for entry in _targets(side, unit, effect, hint):
				_strike(
					side,
					from_slot,
					entry["side"],
					entry["slot"],
					CardEnums.EffectVisualStyle.RECALL,
					origin
				)
				_return_to_hand(entry["side"], entry["slot"])
		CardEnums.EffectType.SILENCE:
			var silence_entries := _targets(side, unit, effect, hint)
			_strike_for_targets(
				side,
				from_slot,
				effect.target,
				silence_entries,
				CardEnums.EffectVisualStyle.DRAIN,
				origin
			)
			for entry in silence_entries:
				var target := _unit_at(entry)
				if target != null:
					target.silence()


## 空き枠へ砂時計を1体出す。**空きが無ければ何もしない**(GameDesign.md 6章)。
## 出した駒の設置効果は解決しない。連鎖すると1枚のカードが何をするか読めなくなるため。
## 置く先は `_apply()` が `_first_empty_slot()` で先に求めた枠と同じ(紋章の飛ぶ先)。
func _summon(side: int, card_id: String) -> void:
	if card_id.is_empty():
		return
	var card := CardLibrary.find_by_id(card_id)
	if card == null:
		return
	var slot := _first_empty_slot(side)
	if slot < 0:
		return
	_state.board[side][slot] = CardInstance.new(card)
	_state.board_changed.emit(side)


func _first_empty_slot(side: int) -> int:
	for slot in MatchState.BOARD_SIZE:
		if _state.board[side][slot] == null:
			return slot
	return -1


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


## 紋章の出どころ(GameDesign.md 9章 2026-09-21・Architecture.md 4.0節)。
## 盤面に残っている駒(UNIT)ならその枠、砕けた駒の余砂(DEATH)なら `_fire()` が
## 運んだ `death_slot`、それ以外(手札から撃った砂術。SPELL)は出どころを持たない。
func _origin_of(from: int, hint: Dictionary) -> int:
	if from >= 0:
		return CardEnums.EffectOrigin.UNIT
	if hint.has("death_slot"):
		return CardEnums.EffectOrigin.DEATH
	return CardEnums.EffectOrigin.SPELL


## DEATH の出どころの枠(砕けた枠)。SPELL は枠を持たないため -1。
## UNIT は呼び出し側(`from`)がそのまま使うため、ここでは扱わない。
func _origin_slot(hint: Dictionary, origin: int) -> int:
	if origin == CardEnums.EffectOrigin.DEATH:
		return hint.get("death_slot", -1)
	return -1


## 単体を狙う「紋章の一撃」を知らせる。適用の直前に出す(GameDesign.md 9章)。
## `style` は `CardEnums.EffectVisualStyle`、`origin` は `CardEnums.EffectOrigin`。
func _strike(
	side: int, from_slot: int, target_side: int, target_slot: int, style: int, origin: int
) -> void:
	_state.effect_struck.emit(side, from_slot, target_side, target_slot, style, origin)


## 複数の対象へ同時に紋章の一撃を知らせる。`_strike()` の複数版で、全体に効く効果
## (ALL_ENEMY_UNITS / ALL_ALLY_UNITS)が対象の数だけ同時に紋章を飛ばすために使う
## (GameDesign.md 9章)。
func _strike_many(side: int, from_slot: int, entries: Array, style: int, origin: int) -> void:
	if entries.is_empty():
		return
	_state.effect_struck_many.emit(side, from_slot, entries, style, origin)


## 対象の数に応じて `_strike()`(単体を数だけ)か `_strike_many()`(全体を1度)を
## 選んで知らせる。**全体に効く効果(ALL_ENEMY_UNITS / ALL_ALLY_UNITS)以外は
## すべて単体として扱う**(SELF は自分自身の1体、ALLY_UNIT/ENEMY_UNIT も1体に絞られる)。
func _strike_for_targets(
	side: int, from_slot: int, target: int, entries: Array, style: int, origin: int
) -> void:
	if _is_single_unit_target(target):
		for entry in entries:
			_strike(side, from_slot, entry["side"], entry["slot"], style, origin)
	else:
		_strike_many(side, from_slot, entries, style, origin)


func _player_side_for(side: int, target: int) -> int:
	if target == CardEnums.EffectTarget.OWN_PLAYER:
		return side
	return MatchState.other_side(side)


## 単体を狙う対象指定か(GameDesign.md 9章)。ALL_ENEMY_UNITS / ALL_ALLY_UNITS だけが
## 対象を複数持ちうるため、それ以外(SELF / ENEMY_UNIT / ALLY_UNIT)は常に単体として扱う。
func _is_single_unit_target(target: int) -> bool:
	return (
		target != CardEnums.EffectTarget.ALL_ENEMY_UNITS
		and target != CardEnums.EffectTarget.ALL_ALLY_UNITS
	)


func _is_enemy_target(target: int) -> bool:
	return (
		target == CardEnums.EffectTarget.ENEMY_UNIT
		or target == CardEnums.EffectTarget.ALL_ENEMY_UNITS
	)


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
			return _single_unit(foe_side, hint, -1, effect)
		CardEnums.EffectTarget.ALLY_UNIT:
			# **自分自身は選べない**(GameDesign.md 6章)。効果を持つ駒が自分を強化すると
			# 「他の駒を助ける」というカードの読みが崩れ、対象を選ぶ意味も無くなるため。
			return _single_unit(side, hint, _slot_of(side, unit), effect)
	return []


## 対象を1体だけ選ぶ効果の解決。相手側(ENEMY_UNIT)も自分側(ALLY_UNIT)もここを通る。
## effect.condition_scope が対象の絞り込み(TARGET / ATTACK_OVER_HEALTH)のとき、
## 条件を満たす候補だけへ絞る(GameDesign.md 6章)。
func _single_unit(
	target_side: int, hint: Dictionary, exclude_slot := -1, effect: CardEffectData = null
) -> Array:
	if hint.has("slot") and hint.get("side", target_side) == target_side:
		var slot: int = hint["slot"]
		var hinted: CardInstance = _state.board[target_side][slot]
		if slot != exclude_slot and hinted != null and eligible_target(hinted, effect):
			return [{"side": target_side, "slot": slot}]
	# 指定が無い・条件を満たさない場合は、条件を満たす中で最も生涯ダメージの大きい1体を選ぶ。
	var best := -1
	var best_value := -1
	for slot in MatchState.BOARD_SIZE:
		var candidate: CardInstance = _state.board[target_side][slot]
		if candidate == null or slot == exclude_slot:
			continue
		if not eligible_target(candidate, effect):
			continue
		var value := candidate.lifetime_damage()
		if value > best_value:
			best_value = value
			best = slot
	return [] if best < 0 else [{"side": target_side, "slot": best}]


## 対象の絞り込み(GameDesign.md 6章)。TARGET は総量の一致、ATTACK_OVER_HEALTH は
## 攻撃力が体力より多いこと。UI・CPUも同じ物差しで候補を絞れるよう公開する。
static func eligible_target(unit: CardInstance, effect: CardEffectData) -> bool:
	if effect == null:
		return true
	match effect.condition_scope:
		CardEnums.ConditionScope.TARGET:
			return unit.total_sand() == effect.condition_total
		CardEnums.ConditionScope.ATTACK_OVER_HEALTH:
			return unit.attack > unit.health
	return true


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
