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
## マリガンで残すコストの上限。これより重いカードは引き直す。
## 序盤に何も出せない手札が最も負けに直結するため、単純に軽い手札を作りにいく。
const MULLIGAN_KEEP_COST := 3
## 落砂が何回起こせるかの見込みの上限。総量ぶん場に残るが、殴り合いで先に砕けるため
## 頭打ちにする。被弾は1体につき殴り合う回数の見込み。どちらも測って決めた値ではなく、
## **CPUが繰り返しトリガーを無視しないための下駄**である。
const TURN_END_TURNS := 3
const DAMAGED_TIMES := 2.0


## 初手の引き直しで戻すカードの位置を返す(GameDesign.md 2章)。
## 重いカードだけを戻す。序盤の1〜3ターン目に置けるカードがあるかどうかが
## 事故の有無をそのまま決めるため、盤面の強さより早さを優先する。
func choose_mulligan(state: MatchState, side: int) -> Array:
	var indices: Array = []
	var cards: Array = state.hand[side]
	for i in cards.size():
		var card: CardData = cards[i]
		if card.cost > MULLIGAN_KEEP_COST:
			indices.append(i)
	return indices


## この手番で次に指す1手を返す。指す手が無ければ end_turn を返す。
func choose_action(state: MatchState, side: int) -> Dictionary:
	var action := _choose_play(state, side)
	if not action.is_empty():
		return action
	if _should_use_coin(state, side):
		return {"type": "coin", "side": side}
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


## コインは「あと1マナあれば出せるカードがある」ときだけ切る。
## 出せる手が残っているうちは温存し、手詰まりになった時点で使う形にしている。
func _should_use_coin(state: MatchState, side: int) -> bool:
	if not state.coin_available.get(side, false):
		return false
	var reach: int = state.mana[side] + MatchState.COIN_MANA
	for card in state.hand[side]:
		if card.cost <= reach:
			return true
	return false


# --- 出す ---------------------------------------------------------------


func _choose_play(state: MatchState, side: int) -> Dictionary:
	var best: Dictionary = {}
	var best_value := 0.0
	var hand: Array = state.hand[side]
	for index in hand.size():
		var card: CardData = hand[index]
		# 砂術は「出す」の中で一緒に選ぶ(Architecture.md 8章)。段を増やさず、
		# 盤面へ置くカードと同じ物差しで比べる。
		if card.is_spell:
			if not state.can_cast(side, index):
				continue
			var gain := _spell_value(state, side, card)
			if gain <= best_value:
				continue
			best_value = gain
			best = MatchAction.cast(side, index, _effect_target(state, side, card))
			continue
		if not state.can_play(side, index):
			continue
		var placement := _best_slot(state, side, card)
		if placement["value"] <= best_value:
			continue
		best_value = placement["value"]
		best = MatchAction.play(side, index, placement["slot"], _effect_target(state, side, card))
	return best


## 砂術の価値。盤面へ駒を残さないため展開の下駄(DEVELOP_BONUS)は付けない。
## **対象を1体取る砂術は、対象がいなければ撃たない**(自動選択に任せると、
## 対象のいない除去を無駄撃ちする)。
func _spell_value(state: MatchState, side: int, card: CardData) -> float:
	var value := 0.0
	for effect in card.effects_for(CardEnums.Trigger.ON_PLAY):
		if effect.target == CardEnums.EffectTarget.ENEMY_UNIT:
			if _strongest_enemy(state, MatchState.other_side(side)) < 0:
				return 0.0
		elif effect.target == CardEnums.EffectTarget.ALLY_UNIT:
			if _strongest_ally(state, side) < 0:
				return 0.0
			if (
				effect.effect_type == CardEnums.EffectType.SWAP_STATS
				and _best_ally_flip(state, side)["slot"] < 0
			):
				return 0.0
			if (
				effect.effect_type == CardEnums.EffectType.DROP_SAND
				and _best_ally_drop(state, side, effect.value)["slot"] < 0
			):
				return 0.0
		value += _on_play_value(state, side, effect)
	return value


## そのカードをどの枠へ置くのが最も得かを返す。空き枠が無ければ出せない
## (上書き設置は廃止したため、value を 0 にして選ばれないようにする)。
func _best_slot(state: MatchState, side: int, card: CardData) -> Dictionary:
	var gain := _card_value(state, side, card) + DEVELOP_BONUS
	var empty: Array = state.empty_slots(side)
	if empty.is_empty():
		return {"slot": -1, "value": 0.0}
	return {"slot": empty[0], "value": gain}


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
	if card.cannot_attack:
		# 攻撃できないぶん、生涯ダメージの見積もりは成り立たない。壁としての厚みだけを見る。
		value = float(total)
	for effect in card.effects_for(CardEnums.Trigger.ON_PLAY):
		value += _on_play_value(state, side, effect)
	# 繰り返し働くトリガーは、場に残る見込みのターン数ぶん価値が積み上がる
	# (GameDesign.md 6章)。落砂は毎ターン1回、被弾は殴り合うたびに起きる。
	value += _repeating_value(state, side, card)
	return value


## 落砂・被弾の効果を、起こせる回数の見込みで割り引いて足す。
## 総量が大きいほど長く場に残るため、落砂は総量に比例させる。
func _repeating_value(state: MatchState, side: int, card: CardData) -> float:
	var value := 0.0
	for effect in card.effects_for(CardEnums.Trigger.ON_TURN_END):
		value += _on_play_value(state, side, effect) * mini(card.total_sand, TURN_END_TURNS)
	for effect in card.effects_for(CardEnums.Trigger.ON_DAMAGED):
		value += _on_play_value(state, side, effect) * DAMAGED_TIMES
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
			# **対象の広さを見る。**全体(ALL_ENEMY_UNITS)は並んでいるぶんだけ積み上がるが、
			# 単体(ENEMY_UNIT)は1体ぶんしかない。区別しないと単体除去を過大評価する。
			if effect.target == CardEnums.EffectTarget.ENEMY_UNIT:
				var slot := _strongest_enemy(state, foe_side)
				if slot >= 0:
					value = _damage_value(state.board[foe_side][slot], effect.value)
			else:
				for unit in state.units(foe_side):
					value += _damage_value(unit, effect.value)
		CardEnums.EffectType.SWAP_STATS:
			# **味方を反転させる効果は、相手を反転させるのと価値の向きが逆**。
			# 攻撃力が体力を上回った駒を戻すと寿命が伸びる(GameDesign.md 1章)。
			if effect.target == CardEnums.EffectTarget.ALLY_UNIT:
				value = float(_best_ally_flip(state, side)["gain"])
			elif effect.target == CardEnums.EffectTarget.ALL_ALLY_UNITS:
				# 自分の盤面をまとめて反転するのは**得とは限らない**。損になる駒も
				# あるため、増減をそのまま足し合わせる(負の値になりうる)。
				for unit in state.units(side):
					value += _lifetime_of(unit.attack, unit.health) - float(unit.lifetime_damage())
			elif effect.target == CardEnums.EffectTarget.ALL_ENEMY_UNITS:
				for unit in state.units(foe_side):
					value += _swap_value(unit)
			else:
				var slot := _strongest_enemy(state, foe_side)
				if slot >= 0:
					value = _swap_value(state.board[foe_side][slot])
		CardEnums.EffectType.RETURN_TO_HAND:
			# 相手の駒を1体、盤面から丸ごと消す。破壊と違い撃ち直されるため、
			# 生涯ダメージそのままではなく控えめに見る。
			var slot := _strongest_enemy(state, foe_side)
			if slot >= 0:
				value = float(state.board[foe_side][slot].lifetime_damage()) * 0.7
		CardEnums.EffectType.HEAL_PLAYER:
			value = effect.value * FACE_WEIGHT
		CardEnums.EffectType.ADD_TOTAL:
			value = effect.value * 2.0
		CardEnums.EffectType.DROP_SAND:
			# 相手全体の砂を落とすのは諸刃(体力が減るが攻撃力が上がる)。
			# 寿命を縮めるぶんだけを見る。
			if effect.target == CardEnums.EffectTarget.ALL_ENEMY_UNITS:
				value = state.units(foe_side).size() * effect.value * 0.8
			elif effect.target == CardEnums.EffectTarget.ALLY_UNIT:
				# 味方の砂を落とすのは「体力を攻撃力へ換える」取引であり、
				# 得な駒とそうでない駒がある。いちばん得をする駒の増分を見る。
				value = float(_best_ally_drop(state, side, effect.value)["gain"])
		CardEnums.EffectType.INVERT_PLAYER_HP:
			# 残りHPと失ったHPを入れ替える。**劣勢のときだけ得になる**(満タンで撃つと負ける)。
			var own: int = state.hp[side]
			value = float(MatchState.INITIAL_HP - own * 2) * FACE_WEIGHT
		CardEnums.EffectType.ADD_ATTACK:
			value = effect.value * 2.0
		CardEnums.EffectType.SUMMON:
			var token := CardLibrary.find_by_id(effect.card_id)
			if token != null and state.units(side).size() < MatchState.BOARD_SIZE:
				value = float(token.total_sand * (token.total_sand - 1)) / 2.0
		CardEnums.EffectType.GRANT_KEYWORD:
			value = 2.0
		CardEnums.EffectType.SILENCE:
			var slot := _strongest_enemy(state, foe_side)
			if slot >= 0 and not state.board[foe_side][slot].keywords().is_empty():
				value = 3.0
	return value


## 砂を落として最も得をする味方と、その得の大きさ。得をする駒がいなければ slot は -1。
func _best_ally_drop(state: MatchState, side: int, amount: int) -> Dictionary:
	var best := {"slot": -1, "gain": 0.0}
	for slot in MatchState.BOARD_SIZE:
		var unit: CardInstance = state.board[side][slot]
		if unit == null:
			continue
		var health := unit.health - amount
		# 落としきると砕けるため、得どころか駒を1体失う。
		if health <= 0:
			continue
		var gain := _lifetime_of(health, unit.attack + amount) - float(unit.lifetime_damage())
		if gain > best["gain"]:
			best = {"slot": slot, "gain": gain}
	return best


## 反転させて最も得をする味方と、その得の大きさ。得をする駒がいなければ slot は -1。
func _best_ally_flip(state: MatchState, side: int) -> Dictionary:
	var best := {"slot": -1, "gain": 0.0}
	for slot in MatchState.BOARD_SIZE:
		var unit: CardInstance = state.board[side][slot]
		if unit == null:
			continue
		var gain := _lifetime_of(unit.attack, unit.health) - float(unit.lifetime_damage())
		if gain > best["gain"]:
			best = {"slot": slot, "gain": gain}
	return best


## 反転させたときに相手の生涯ダメージがどれだけ下がるか。攻撃力の高い駒ほど大きい。
func _swap_value(unit: CardInstance) -> float:
	return maxf(0.0, unit.lifetime_damage() - _lifetime_of(unit.attack, unit.health))


## 対象を1体選ぶ設置効果のための指定。選ばない効果なら空を返す。
func _effect_target(state: MatchState, side: int, card: CardData) -> Dictionary:
	var foe_side := MatchState.other_side(side)
	for effect in card.effects_for(CardEnums.Trigger.ON_PLAY):
		if effect.target == CardEnums.EffectTarget.ENEMY_UNIT:
			var slot := _strongest_enemy(state, foe_side)
			if slot >= 0:
				return {"side": foe_side, "slot": slot}
		elif effect.target == CardEnums.EffectTarget.ALLY_UNIT:
			# 反転と砂落としは「最も強い味方」ではなく「効かせて最も得をする味方」を選ぶ。
			var slot: int = _strongest_ally(state, side)
			if effect.effect_type == CardEnums.EffectType.SWAP_STATS:
				slot = _best_ally_flip(state, side)["slot"]
			elif effect.effect_type == CardEnums.EffectType.DROP_SAND:
				slot = _best_ally_drop(state, side, effect.value)["slot"]
			if slot >= 0:
				return {"side": side, "slot": slot}
	return {}


## 味方のうち、いちばん生涯ダメージの大きい1体。強化はここへ乗せるのが効く。
func _strongest_ally(state: MatchState, side: int) -> int:
	var best := -1
	var best_value := -1.0
	for slot in MatchState.BOARD_SIZE:
		var unit: CardInstance = state.board[side][slot]
		if unit == null:
			continue
		var value := float(unit.lifetime_damage())
		if value > best_value:
			best_value = value
			best = slot
	return best


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
