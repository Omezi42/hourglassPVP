class_name CardEffectPlan
extends RefCounted
## 能力の実演の台本(GameDesign.md 9章)。カード1枚のキーワードと効果のトリガーから
## 「どんな局面で何を指すか」を組む。盤面と演出は本物の対局画面(`CardEffectPreview`)が出す。
##
## **台本はカードごとに書かない。**トリガーとキーワードの種類から自動で組むため、
## カードを足しても台本を書き足す作業が発生しない。対象を選ぶ効果は CPU と同じ選び方を使う。

enum Kind {
	PLAY, CAST, FLIP, DEATH, TURN_END, DAMAGED, ALLY_DEATH, ENEMY_FLIP, STRIKE, DOUBLE, GUARD, RUSH
}

## 実演の駒を置く枠。中央寄りに置き、両隣に味方と相手の駒が並ぶようにする。
const SUBJECT_SLOT := 2
const ALLY_SLOT := 1
## 相手の駒。殴られ役(小さい)と、殴り返して倒す役(大きい)。[id, 体力, 攻撃力]
const FOE_TARGET := ["grain", 2, 1]
const FOE_HEAVY := ["lock", 4, 4]
const FOE_TARGET_SLOT := 2
const FOE_HEAVY_SLOT := 3
const ALLY := ["sand", 4, 1]
## 条件付きの効果(コンボ系)の対象を置く枠。
const MATCH_SLOT := 4
## 墓地を使う効果のための砂時計。
const GRAVE_IDS := ["sand", "grain"]
const HAND_FILLER := ["sand", "grain"]
const FULL_MANA := 10
## HPを反転する効果でも決着しない値にしておく(MatchState.INITIAL_HP = 24)。
const OWN_HP := 14
const FOE_HP := 18
## 殴り合う実演で、実演の駒が反撃で倒れずに残る体力。
const SURVIVE_HEALTH := 3

const STRIKE_KEYWORDS := [
	CardEnums.Keyword.GLASS,
	CardEnums.Keyword.PIERCE,
	CardEnums.Keyword.POISON,
	CardEnums.Keyword.LIFESTEAL,
	CardEnums.Keyword.DAMAGE_BOOST,
]
const TRIGGER_KINDS := {
	CardEnums.Trigger.ON_FLIP: Kind.FLIP,
	CardEnums.Trigger.ON_DEATH: Kind.DEATH,
	CardEnums.Trigger.ON_TURN_END: Kind.TURN_END,
	CardEnums.Trigger.ON_DAMAGED: Kind.DAMAGED,
	CardEnums.Trigger.ON_ALLY_DEATH: Kind.ALLY_DEATH,
	CardEnums.Trigger.ON_ENEMY_FLIP: Kind.ENEMY_FLIP,
}


## 実演の段。キーワード → 効果のトリガーの順に1段ずつ。何も持たなければ「出してターンを終える」1段。
static func kinds(card: CardData) -> Array[int]:
	var found: Array[int] = []
	if card.is_spell:
		found.append(Kind.CAST)
		return found
	for keyword in card.keywords:
		var kind := keyword_kind(keyword)
		if kind >= 0 and not found.has(kind):
			found.append(kind)
	if card.conditional_keyword >= 0 and not found.has(Kind.STRIKE):
		found.append(Kind.STRIKE)
	for effect in card.effects:
		if effect == null:
			continue
		var kind := trigger_kind(effect.trigger)
		if not found.has(kind):
			found.append(kind)
	if found.is_empty():
		found.append(Kind.PLAY)
	return found


## そのトリガーの効果を見せる段。設置は「出す」段。
static func trigger_kind(trigger: int) -> int:
	return int(TRIGGER_KINDS.get(trigger, Kind.PLAY))


## そのキーワードを見せる段。見せる動きを持たない語は -1。
static func keyword_kind(keyword: int) -> int:
	if STRIKE_KEYWORDS.has(keyword):
		return Kind.STRIKE
	match keyword:
		CardEnums.Keyword.DOUBLE_STRIKE:
			return Kind.DOUBLE
		CardEnums.Keyword.GUARD:
			return Kind.GUARD
		CardEnums.Keyword.QUICK:
			return Kind.RUSH
		CardEnums.Keyword.STILL:
			return Kind.TURN_END
	return -1


## 局面を組み、指す手を順に返す。`state` は開始済みの対局で、盤面・手札・墓地・マナを差し替える。
static func stage(state: MatchState, side: int, card: CardData, kind: int) -> Array[Dictionary]:
	var foe := MatchState.other_side(side)
	_reset(state, side, card)
	var subject: CardInstance = null
	if not kind in [Kind.PLAY, Kind.CAST, Kind.RUSH]:
		var total := _demo_total(card)
		var health := _subject_health(total, kind)
		subject = _place(state, side, SUBJECT_SLOT, card, health, total - health)
	_place_condition_match(state, side, card, subject)
	var actions: Array[Dictionary] = []
	match kind:
		Kind.CAST:
			actions.append(MatchAction.cast(side, 0, _target(state, side, card)))
		Kind.PLAY:
			actions.append(MatchAction.play(side, 0, SUBJECT_SLOT, _target(state, side, card)))
			if card.effects.is_empty():
				actions.append(MatchAction.end_turn(side))
		Kind.RUSH:
			actions.append(MatchAction.play(side, 0, SUBJECT_SLOT, _target(state, side, card)))
			actions.append(MatchAction.attack(side, SUBJECT_SLOT, FOE_TARGET_SLOT))
		Kind.FLIP:
			actions.append(MatchAction.flip(side, SUBJECT_SLOT))
		Kind.TURN_END:
			actions.append(MatchAction.end_turn(side))
		Kind.ENEMY_FLIP:
			state.flip_right_remaining[side] = 1
			actions.append(MatchAction.flip_right(side, foe, FOE_TARGET_SLOT))
		Kind.ALLY_DEATH:
			state.board[side][ALLY_SLOT].health = 1
			actions.append(MatchAction.attack(side, ALLY_SLOT, FOE_HEAVY_SLOT))
		Kind.DEATH:
			# 相手の番に殴られる駒は、ターン終わりの1粒で先に崩れないよう1粒ぶん多く残す。
			if not state.can_attack(side, SUBJECT_SLOT, FOE_HEAVY_SLOT):
				subject.health += 1
				subject.attack = maxi(subject.attack - 1, 0)
			actions.append_array(_be_struck(state, side, FOE_HEAVY_SLOT))
		Kind.DAMAGED, Kind.GUARD:
			actions.append_array(_be_struck(state, side, FOE_TARGET_SLOT))
		Kind.STRIKE, Kind.DOUBLE:
			if not state.can_attack(side, SUBJECT_SLOT, FOE_TARGET_SLOT):
				actions.append_array(_be_struck(state, side, FOE_TARGET_SLOT))
			else:
				actions.append(MatchAction.attack(side, SUBJECT_SLOT, FOE_TARGET_SLOT))
				if kind == Kind.DOUBLE:
					actions.append(MatchAction.attack(side, SUBJECT_SLOT, FOE_HEAVY_SLOT))
	return actions


static func _reset(state: MatchState, side: int, card: CardData) -> void:
	var foe := MatchState.other_side(side)
	for s in [side, foe]:
		for slot in MatchState.BOARD_SIZE:
			state.board[s][slot] = null
		state.mana[s] = FULL_MANA
		state.max_mana[s] = FULL_MANA
	state.hp[side] = OWN_HP
	state.hp[foe] = FOE_HP
	state.current_turn = side
	var hand: Array = [card]
	var grave: Array = []
	for id in HAND_FILLER:
		hand.append(CardLibrary.find_by_id(id))
	for id in GRAVE_IDS:
		grave.append(CardLibrary.find_by_id(id))
	state.hand[side] = hand
	state.graveyard[side] = grave
	_place(state, side, ALLY_SLOT, _card(ALLY[0]), ALLY[1], ALLY[2])
	_place(state, foe, FOE_TARGET_SLOT, _card(FOE_TARGET[0]), FOE_TARGET[1], FOE_TARGET[2])
	_place(state, foe, FOE_HEAVY_SLOT, _card(FOE_HEAVY[0]), FOE_HEAVY[1], FOE_HEAVY[2])


## 殴られる実演。自分から殴れるなら殴り返しを受け、殴れない駒は相手の番に殴られる。
static func _be_struck(state: MatchState, side: int, foe_slot: int) -> Array[Dictionary]:
	var foe := MatchState.other_side(side)
	if state.can_attack(side, SUBJECT_SLOT, foe_slot):
		return [MatchAction.attack(side, SUBJECT_SLOT, foe_slot)]
	return [MatchAction.end_turn(side), MatchAction.attack(foe, foe_slot, SUBJECT_SLOT)]


## 実演の駒の総量。条件付きのキーワードを持つ駒は、条件を満たす総量で置く。
static func _demo_total(card: CardData) -> int:
	if card.conditional_keyword >= 0 and card.conditional_keyword_total > 0:
		return card.conditional_keyword_total
	return card.total_sand


## 実演の駒の体力。倒れる実演は1、殴り合う実演は反撃に耐える分を残し、残りを攻撃力へ落とす。
static func _subject_health(total: int, kind: int) -> int:
	if kind == Kind.DEATH:
		return 1
	if kind in [Kind.STRIKE, Kind.DOUBLE, Kind.DAMAGED, Kind.GUARD]:
		return mini(total, maxi(SURVIVE_HEALTH, total - FOE_TARGET[1] - 2))
	return total


## 条件付きの効果が働くよう、条件どおりの駒を置く(コンボ系。GameDesign.md 6章)。
static func _place_condition_match(
	state: MatchState, side: int, card: CardData, subject: CardInstance
) -> void:
	var foe := MatchState.other_side(side)
	for effect in card.effects:
		if effect == null or effect.condition_scope == CardEnums.ConditionScope.NONE:
			continue
		var need := maxi(effect.condition_total, 1)
		match effect.condition_scope:
			CardEnums.ConditionScope.SELF:
				if subject != null:
					subject.health = maxi(need - subject.attack, 1)
			CardEnums.ConditionScope.ANY_ALLY:
				state.board[side][ALLY_SLOT].health = need
				state.board[side][ALLY_SLOT].attack = 0
			CardEnums.ConditionScope.ATTACK_OVER_HEALTH:
				_place(state, foe, MATCH_SLOT, _card(FOE_TARGET[0]), 1, 2)
				_place(state, side, MATCH_SLOT, _card(ALLY[0]), 1, 2)
			_:
				_place(state, foe, MATCH_SLOT, _card(FOE_TARGET[0]), need, 0)
				_place(state, side, MATCH_SLOT, _card(ALLY[0]), need, 0)


## 対象を選ぶ効果の指定。CPU と同じ選び方を使う(実演だけの選び方を持たない)。
static func _target(state: MatchState, side: int, card: CardData) -> Dictionary:
	return CardCpuStrategy.new()._effect_target(state, side, card)


static func _place(
	state: MatchState, side: int, slot: int, card: CardData, health: int, attack := -1
) -> CardInstance:
	var unit := CardInstance.new(card)
	unit.health = maxi(health, 1)
	unit.attack = attack if attack >= 0 else maxi(card.total_sand - unit.health, 0)
	unit.summoned_this_turn = false
	unit.attacks_this_turn = 0
	unit.flipped_this_turn = false
	state.board[side][slot] = unit
	return unit


static func _card(id: String) -> CardData:
	return CardLibrary.find_by_id(id)
