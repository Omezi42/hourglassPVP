class_name CardCpuStrategy
extends RefCounted
## v5.0のCPU思考(GameDesign.md 13章)。合法手の組み合わせが多いため探索はせず、
## 生涯ダメージ `体力×攻撃力 + 体力(体力-1)/2` を通貨とした貪欲法で1手ずつ選ぶ。
##
## 1手番の中では「出す → 攻撃する → 反転する → 終える」の順に選ぶ。
## **攻撃してから反転する**のが重要で、逆にすると攻撃力の高い状態を捨ててしまう。
## 反転の最適解は「攻撃力が体力を上回ったとき」(GameDesign.md 1章)。

## 本体を殴る価値の重み。1点の本体ダメージを、この倍率で生涯ダメージと比較する。
## 盤面の取り合いと本体レースの配分がここで決まる(GameDesign.md 7章の目標値30〜60%)。
const FACE_WEIGHT := 1.6
## 空き枠へ出す価値の底上げ。展開しないと何も始まらないため、僅かに前のめりにする。
const DEVELOP_BONUS := 2.0


## この手番で次に指す1手を返す。指す手が無ければ end_turn を返す。
func choose_action(state: MatchState, side: int) -> Dictionary:
	var action := _choose_play(state, side)
	if not action.is_empty():
		return action
	action = _choose_attack(state, side)
	if not action.is_empty():
		return action
	action = _choose_flip(state, side)
	if not action.is_empty():
		return action
	return MatchAction.end_turn(side)


## 手番が自分に回ってから終えるまでを一気に進める(シミュレーション・CPU戦で使う)。
func take_turn(state: MatchState, side: int, action_limit: int = 60) -> Array:
	var performed: Array = []
	for i in action_limit:
		if state.is_match_over():
			return performed
		var action := choose_action(state, side)
		performed.append(action)
		MatchAction.apply(state, action)
		if action["type"] == "end_turn":
			return performed
	MatchAction.apply(state, MatchAction.end_turn(side))
	return performed


# --- 出す ---------------------------------------------------------------


func _choose_play(state: MatchState, side: int) -> Dictionary:
	var best: Dictionary = {}
	var best_value := 0.0
	var hand: Array = state.hand[side]
	for index in hand.size():
		if not state.can_play(side, index):
			continue
		var card: CardData = hand[index]
		var placement := _best_slot(state, side, card)
		if placement["value"] <= best_value:
			continue
		best_value = placement["value"]
		best = MatchAction.play(side, index, placement["slot"], _effect_target(state, side, card))
	return best


## そのカードをどの枠へ置くのが最も得かを返す。空き枠が無い場合は、
## 最も弱い自分の砂時計を上書きする価値を測る(上書きは元のカードを失う)。
func _best_slot(state: MatchState, side: int, card: CardData) -> Dictionary:
	var gain := _card_value(state, side, card) + DEVELOP_BONUS
	var empty: Array = state.empty_slots(side)
	if not empty.is_empty():
		return {"slot": empty[0], "value": gain}
	var worst := -1
	var worst_value := 0.0
	for slot in MatchState.BOARD_SIZE:
		var unit: CardInstance = state.board[side][slot]
		var value := float(unit.lifetime_damage())
		if worst < 0 or value < worst_value:
			worst = slot
			worst_value = value
	return {"slot": worst, "value": gain - worst_value}


## カードを出したときに見込める価値。総量を体力とみなした生涯ダメージに、
## 設置効果ぶんを足す。
func _card_value(state: MatchState, side: int, card: CardData) -> float:
	var total := card.total_sand
	var value := float(total * (total - 1)) / 2.0
	if card.has_keyword(CardEnums.Keyword.QUICK):
		value += 2.0 * FACE_WEIGHT
	if card.has_keyword(CardEnums.Keyword.GUARD):
		value += 2.0
	if card.has_keyword(CardEnums.Keyword.GLASS):
		value += 2.0
	if card.has_keyword(CardEnums.Keyword.LIFESTEAL):
		value += 2.0
	if card.has_keyword(CardEnums.Keyword.DOUBLE_STRIKE):
		value += 3.0
	if card.has_keyword(CardEnums.Keyword.POISON):
		value += 4.0
	if card.has_keyword(CardEnums.Keyword.PIERCE):
		value += 1.0
	for effect in card.effects_for(CardEnums.Trigger.ON_PLAY):
		value += _on_play_value(state, side, effect)
	return value


func _on_play_value(state: MatchState, side: int, effect: CardEffectData) -> float:
	var foe_side := MatchState.other_side(side)
	var value := 0.0
	match effect.effect_type:
		CardEnums.EffectType.DAMAGE_PLAYER:
			value = effect.value * FACE_WEIGHT
		CardEnums.EffectType.DAMAGE_PLAYER_PER_ENEMY_UNIT:
			value = state.units(foe_side).size() * effect.value * FACE_WEIGHT
		CardEnums.EffectType.DRAW:
			value = effect.value * 3.0
		CardEnums.EffectType.DESTROY_UNIT:
			var target := _strongest_enemy(state, foe_side)
			if target >= 0:
				value = float(state.board[foe_side][target].lifetime_damage())
		CardEnums.EffectType.DAMAGE_UNIT:
			for unit in state.units(foe_side):
				value += _damage_value(unit, effect.value)
		CardEnums.EffectType.SWAP_STATS:
			var slot := _strongest_enemy(state, foe_side)
			if slot >= 0:
				var unit: CardInstance = state.board[foe_side][slot]
				value = maxf(0.0, unit.lifetime_damage() - _lifetime_of(unit.attack, unit.health))
	return value


## 対象を1体選ぶ設置効果のための指定。選ばない効果なら空を返す。
func _effect_target(state: MatchState, side: int, card: CardData) -> Dictionary:
	var foe_side := MatchState.other_side(side)
	for effect in card.effects_for(CardEnums.Trigger.ON_PLAY):
		if effect.target != CardEnums.EffectTarget.ENEMY_UNIT:
			continue
		var slot := _strongest_enemy(state, foe_side)
		if slot >= 0:
			return {"side": foe_side, "slot": slot}
	return {}


# --- 攻撃する -----------------------------------------------------------


func _choose_attack(state: MatchState, side: int) -> Dictionary:
	var foe_side := MatchState.other_side(side)
	var best: Dictionary = {}
	var best_value := 0.0
	for slot in MatchState.BOARD_SIZE:
		var attacker: CardInstance = state.board[side][slot]
		if attacker == null or not attacker.can_attack():
			continue
		# 本体を削りきれるなら、盤面を無視してそこで終わる。
		if state.can_attack_player(side) and attacker.attack >= state.hp[foe_side]:
			return MatchAction.attack(side, slot, -1)
		if state.can_attack_player(side):
			var face_value := attacker.attack * FACE_WEIGHT
			if face_value > best_value:
				best_value = face_value
				best = MatchAction.attack(side, slot, -1)
		for target_slot in state.attackable_slots(foe_side):
			var value := _trade_value(attacker, state.board[foe_side][target_slot], side, state)
			if value > best_value:
				best_value = value
				best = MatchAction.attack(side, slot, target_slot)
	return best


## 砂時計同士をぶつけたときの損得。相打ちのため自分が失う分も引く。
func _trade_value(
	attacker: CardInstance, defender: CardInstance, side: int, state: MatchState
) -> float:
	var gained := _damage_value(defender, attacker.attack)
	var lost := _damage_value(attacker, defender.attack)
	if attacker.has_keyword(CardEnums.Keyword.POISON) and attacker.attack > 0:
		gained = float(defender.lifetime_damage())
	if defender.has_keyword(CardEnums.Keyword.POISON) and defender.attack > 0:
		lost = float(attacker.lifetime_damage())
	if attacker.has_keyword(CardEnums.Keyword.PIERCE):
		gained += maxf(0.0, attacker.attack - defender.health) * FACE_WEIGHT
	if attacker.has_keyword(CardEnums.Keyword.LIFESTEAL):
		gained += minf(attacker.attack, defender.health)
	# 守護を残すと本体を殴れないため、取り除くこと自体に価値がある。
	if defender.has_keyword(CardEnums.Keyword.GUARD) and attacker.attack >= defender.health:
		gained += 3.0
	if state.hp[side] <= 10:
		lost *= 0.6
	return gained - lost


## その砂時計へ amount のダメージを与えたときに失われる生涯ダメージ。
func _damage_value(unit: CardInstance, amount: int) -> float:
	if amount <= 0:
		return 0.0
	if unit.glass_intact:
		return 0.0
	var before := float(unit.lifetime_damage())
	var health := unit.health - amount
	if health <= 0:
		return before
	return before - _lifetime_of(health, unit.attack)


func _lifetime_of(health: int, attack: int) -> float:
	return float(health * attack) + float(health * (health - 1)) / 2.0


func _strongest_enemy(state: MatchState, foe_side: int) -> int:
	var best := -1
	var best_value := -1
	for slot in MatchState.BOARD_SIZE:
		var unit: CardInstance = state.board[foe_side][slot]
		if unit == null:
			continue
		var value := unit.lifetime_damage()
		if value > best_value:
			best_value = value
			best = slot
	return best


# --- 反転する -----------------------------------------------------------


func _choose_flip(state: MatchState, side: int) -> Dictionary:
	var best: Dictionary = {}
	var best_gain := 0.0
	for slot in MatchState.BOARD_SIZE:
		var unit: CardInstance = state.board[side][slot]
		if unit == null or not unit.can_flip():
			continue
		var gain := _lifetime_of(unit.attack, unit.health) - float(unit.lifetime_damage())
		if unit.data.effects_for(CardEnums.Trigger.ON_FLIP).size() > 0:
			gain += 2.0
		if gain > best_gain:
			best_gain = gain
			best = MatchAction.flip(side, slot)
	return best
