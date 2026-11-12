class_name CardCpuBeginner
extends RefCounted
## 思考レベル「初級」の指し手(GameDesign.md 13章・Architecture.md 8.1節)。
## 貪欲法(生涯ダメージの比較)を一切通らない別経路のため、`CardCpuStrategy` から切り出している。


## 初級は貪欲法(生涯ダメージの比較)を一切通らない。出せる最初の1枚を出し、
## 攻撃はランダムに選び、反転・反転権は使わない(GameDesign.md 13章)。
static func choose_action(
	state: MatchState, side: int, rng: RandomNumberGenerator, use_coin: bool
) -> Dictionary:
	var play := _choose_play(state, side, rng)
	if not play.is_empty():
		return play
	if use_coin:
		return {"type": "coin", "side": side}
	var attack := _choose_attack(state, side, rng)
	if not attack.is_empty():
		return attack
	return MatchAction.end_turn(side)


## 手札を先頭から見て、出せる最初の1枚をそのまま出す。組み合わせやコスト効率を見ない。
static func _choose_play(state: MatchState, side: int, rng: RandomNumberGenerator) -> Dictionary:
	var hand: Array = state.hand[side]
	for index in hand.size():
		var card: CardData = hand[index]
		if card.is_spell:
			if not state.can_cast(side, index):
				continue
			var acting := CardEffectResolver.acting_card(state, side, card)
			if acting.effects_for(CardEnums.Trigger.ON_PLAY).any(
				func(e: CardEffectData) -> bool: return _needs_target(state, side, e)
			):
				continue
			return MatchAction.cast(side, index, _random_target(state, side, acting, rng))
		if not state.can_play(side, index):
			continue
		var empty: Array = state.empty_slots(side)
		if empty.is_empty():
			continue
		return MatchAction.play(side, index, empty[0], _random_target(state, side, card, rng))
	return {}


## その効果が対象を要求するのに、対象がいなければ true(無駄撃ちを避けるための最低限の判定)。
static func _needs_target(state: MatchState, side: int, effect: CardEffectData) -> bool:
	var foe_side := MatchState.other_side(side)
	if effect.target == CardEnums.EffectTarget.ENEMY_UNIT:
		return state.units(foe_side).is_empty()
	if effect.target == CardEnums.EffectTarget.ALLY_UNIT:
		return state.units(side).is_empty()
	return false


## 対象を1体取る効果をランダムに選ぶ(中級以上の`_effect_target()`は最も効く1体を選ぶが、
## 初級はそこも狙わない)。
static func _random_target(
	state: MatchState, side: int, card: CardData, rng: RandomNumberGenerator
) -> Dictionary:
	var foe_side := MatchState.other_side(side)
	for effect in card.effects_for(CardEnums.Trigger.ON_PLAY):
		if effect.target == CardEnums.EffectTarget.ENEMY_UNIT:
			var slots := state.units(foe_side)
			if not slots.is_empty():
				return {"side": foe_side, "slot": _random_slot_of(state, foe_side, rng)}
		elif effect.target == CardEnums.EffectTarget.ENEMY_UNIT_OR_PLAYER:
			# 本体(-1)も駒と同じ重みで候補に入れる。
			var choices: Array = [-1]
			for slot in MatchState.BOARD_SIZE:
				if state.board[foe_side][slot] != null:
					choices.append(slot)
			return {"side": foe_side, "slot": choices[rng.randi_range(0, choices.size() - 1)]}
		elif effect.target == CardEnums.EffectTarget.ALLY_UNIT:
			var slots := state.units(side)
			if not slots.is_empty():
				return {"side": side, "slot": _random_slot_of(state, side, rng)}
	return {}


static func _random_slot_of(state: MatchState, side: int, rng: RandomNumberGenerator) -> int:
	var occupied: Array = []
	for slot in MatchState.BOARD_SIZE:
		if state.board[side][slot] != null:
			occupied.append(slot)
	if occupied.is_empty():
		return -1
	return occupied[rng.randi_range(0, occupied.size() - 1)]


## 攻撃できる駒と、狙える相手(本体を含む)をそれぞれランダムに選ぶ。
## 守護がいれば無視できないのは `attackable_slots()` が返す集合そのものが保証する。
static func _choose_attack(state: MatchState, side: int, rng: RandomNumberGenerator) -> Dictionary:
	var foe_side := MatchState.other_side(side)
	var attackers: Array = []
	for slot in MatchState.BOARD_SIZE:
		var attacker: CardInstance = state.board[side][slot]
		if attacker != null and attacker.can_attack():
			attackers.append(slot)
	if attackers.is_empty():
		return {}
	var slot: int = attackers[rng.randi_range(0, attackers.size() - 1)]
	var options: Array = state.attackable_slots(foe_side).duplicate()
	if state.can_attack_player(side):
		options.append(-1)
	if options.is_empty():
		return {}
	var target: int = options[rng.randi_range(0, options.size() - 1)]
	return MatchAction.attack(side, slot, target)
