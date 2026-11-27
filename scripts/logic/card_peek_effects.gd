class_name CardPeekEffects
extends RefCounted
## 第3弾「盗み見の刻」の固有効果(GameDesign.md 6章「相手のカードを見る・写す効果」)。
## 相手の手札・山札の一番上を見る・相手のカードの写しを手札へ加える・相手の手札を山札の底へ戻す。
## 写しは「引く」ではないため、相手のドローに反応する効果は働かず、相手の手札・山札は変わらない(山札の底へ戻す・墓地へ置く効果を除く)。
## 手札・山札の中身は両者の端末が同じ対局を再現して持っているため、見る・選ぶの結果はそのまま手として送り合える。

const TYPES := [
	CardEnums.EffectType.COPY_FOE_TOP_TO_HAND,
	CardEnums.EffectType.COPY_FOE_HAND_RANDOM_TO_HAND,
	CardEnums.EffectType.PEEK_FOE_TOP_KEEP_OR_MILL,
	CardEnums.EffectType.REVEAL_FOE_HAND,
	CardEnums.EffectType.COPY_FOE_SPELL_TO_HAND,
	CardEnums.EffectType.FOE_HAND_RANDOM_TO_DECK_BOTTOM,
	CardEnums.EffectType.COPY_FOE_HAND_PICK_TO_HAND,
]
## 選びを運ぶ hint のキー。スパイは0なら相手の墓地へ(無ければそのまま)、ファントムは相手の手札の位置。
const PEEK_KEY := "peek_index"
## フォージャーが写す砂術を運ぶ hint のキー(ON_FOE_SPELL)。
const SPELL_KEY := "spell"
## ゴシップを使っていない印。
const NOT_SEEN := -1
## CPUの見積もり。写しを1枚手札へ加える値打ち(「引く」より低い。相手のカードは自分のデッキに合うとは限らない)。
const COPY_VALUE := 2.5
## 写しをランダムでなく選んで取る値打ち(ファントム)。
const PICK_VALUE := 3.0
const PEEK_VALUE := 1.0
## 相手の手札の1枚を山札の底へ遠ざける値打ち。
const BANISH_VALUE := 1.5
## 相手の手札を見る値打ち。CPUは見た中身を読み取らないため小さい。
const SEE_HAND_VALUE := 0.5
const SEE_DECK_TOP_VALUE := 1.0
## 余砂で写しを取る見込み(砕けるとは限らない)。
const DEATH_FACTOR := 0.7
## 相手の砂術を写す1回の値打ち。
const SPELL_COPY_VALUE := 2.0
## スパイで相手の山札の一番上を墓地へ置くとき、その札が相手にとっていくら以上なら置くか。
const MILL_VALUE := 4.0

var _state: MatchState
var _resolver: CardEffectResolver


func _init(state: MatchState, resolver: CardEffectResolver) -> void:
	_state = state
	_resolver = resolver


static func handles(effect_type: int) -> bool:
	return TYPES.has(effect_type)


## この手番のあいだ、side が相手の手札を見られるか(ゴシップ)。
static func hand_seen(state: MatchState, side: int) -> bool:
	return int(state.foe_hand_seen_on.get(side, NOT_SEEN)) == state.turn_count


## 場にいるあいだ、side が相手の山札の一番上を見られるか(スカウト)。効果を消されたスカウトは見えず、山札が空なら見るものが無い。
static func deck_top_seen(state: MatchState, side: int) -> bool:
	if state.deck[MatchState.other_side(side)].is_empty():
		return false
	return state.units(side).any(
		func(unit: CardInstance) -> bool: return unit.data.sees_foe_deck_top and not unit.silenced
	)


## 出したときに相手のカードを見て選ばせる効果(スパイ・ファントム)。無ければ null。
static func choice_effect(card: CardData) -> CardEffectData:
	for effect in card.effects_for(CardEnums.Trigger.ON_PLAY):
		if (
			effect.effect_type == CardEnums.EffectType.PEEK_FOE_TOP_KEEP_OR_MILL
			or effect.effect_type == CardEnums.EffectType.COPY_FOE_HAND_PICK_TO_HAND
		):
			return effect
	return null


## 見て選ぶ効果が見る札。スパイは相手の山札の一番上(無ければ空)、ファントムは相手の手札すべて。
static func seen_cards(state: MatchState, side: int, effect: CardEffectData) -> Array[CardData]:
	var foe_side := MatchState.other_side(side)
	var found: Array[CardData] = []
	if effect.effect_type == CardEnums.EffectType.PEEK_FOE_TOP_KEEP_OR_MILL:
		if not state.deck[foe_side].is_empty():
			found.append(state.deck[foe_side][0])
		return found
	for card: CardData in state.hand[foe_side]:
		found.append(card)
	return found


## 相手が砂術を使ったとき(フォージャー)。砂術を解決し終えた後に、場にいる相手側の駒が反応する。
static func fire_foe_spell(state: MatchState, caster: int, spell: CardData) -> void:
	var watcher_side := MatchState.other_side(caster)
	for unit: CardInstance in state.units(watcher_side):
		if not unit.is_dead() and not unit.effects_for(CardEnums.Trigger.ON_FOE_SPELL).is_empty():
			state._fire(watcher_side, unit, CardEnums.Trigger.ON_FOE_SPELL, {SPELL_KEY: spell})
	state._cleanup_dead()


func apply(
	side: int,
	_unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	var foe_side := MatchState.other_side(side)
	var foe_hand: Array = _state.hand[foe_side]
	match effect.effect_type:
		CardEnums.EffectType.COPY_FOE_TOP_TO_HAND:
			if not _state.deck[foe_side].is_empty():
				_add_copy(side, _state.deck[foe_side][0], from_slot, origin)
		CardEnums.EffectType.COPY_FOE_HAND_RANDOM_TO_HAND:
			if not foe_hand.is_empty():
				var picked: CardData = foe_hand[_state._rng.randi_range(0, foe_hand.size() - 1)]
				_add_copy(side, picked, from_slot, origin)
		CardEnums.EffectType.PEEK_FOE_TOP_KEEP_OR_MILL:
			_pulse(side, from_slot, origin)
			if int(hint.get(PEEK_KEY, -1)) == 0:
				MatchDeckTop.mill(_state, foe_side, 1)
		CardEnums.EffectType.REVEAL_FOE_HAND:
			_pulse(side, from_slot, origin)
			_state.foe_hand_seen_on[side] = _state.turn_count
		CardEnums.EffectType.COPY_FOE_SPELL_TO_HAND:
			var spell: CardData = hint.get(SPELL_KEY)
			if spell != null:
				_add_copy(side, spell, from_slot, origin)
		CardEnums.EffectType.FOE_HAND_RANDOM_TO_DECK_BOTTOM:
			_banish_random(side, foe_side, from_slot, origin)
		CardEnums.EffectType.COPY_FOE_HAND_PICK_TO_HAND:
			if not foe_hand.is_empty():
				_add_copy(side, foe_hand[_pick_index(foe_hand, hint)], from_slot, origin)


## 選んだ位置。hint に無い・範囲外ならコストがいちばん高い札(同じなら左)。
static func _pick_index(cards: Array, hint: Dictionary) -> int:
	var named := int(hint.get(PEEK_KEY, -1))
	if named >= 0 and named < cards.size():
		return named
	var best := 0
	for index in cards.size():
		if cards[index].cost > cards[best].cost:
			best = index
	return best


func _pulse(side: int, from_slot: int, origin: int) -> void:
	_resolver._strike(side, from_slot, side, -1, CardEnums.EffectVisualStyle.PULSE, origin)


## 写しを手札へ加える。「引く」ではないため `cards_drawn` は出さない。
func _add_copy(side: int, card: CardData, from_slot: int, origin: int) -> void:
	if origin == CardEnums.EffectOrigin.UNIT:
		_state.effect_drawn.emit(side, from_slot, 1)
	else:
		_pulse(side, from_slot, origin)
	_state.hand[side].append(card)
	_state.hand_changed.emit(side)


## 相手の手札からランダムな1枚を相手の山札の一番下へ戻す。山札が空だった相手は疲労の印を下ろす(山札が1枚になる)。
func _banish_random(side: int, foe_side: int, from_slot: int, origin: int) -> void:
	var hand: Array = _state.hand[foe_side]
	if hand.is_empty():
		return
	_pulse(side, from_slot, origin)
	var card: CardData = hand.pop_at(_state._rng.randi_range(0, hand.size() - 1))
	_state.deck[foe_side].append(card)
	_state._deck_exhausted[foe_side] = false
	_state.hand_changed.emit(foe_side)


## CPUの見積もり(設置・常在の効果)。相手の手札・山札は枚数だけを見る(中身は読まない)。
static func cpu_value(state: MatchState, side: int, effect: CardEffectData) -> float:
	var foe_side := MatchState.other_side(side)
	var foe_hand: int = state.hand[foe_side].size()
	var foe_deck: int = state.deck[foe_side].size()
	match effect.effect_type:
		CardEnums.EffectType.COPY_FOE_TOP_TO_HAND:
			return COPY_VALUE if foe_deck > 0 else 0.0
		CardEnums.EffectType.COPY_FOE_HAND_RANDOM_TO_HAND:
			return COPY_VALUE if foe_hand > 0 else 0.0
		CardEnums.EffectType.PEEK_FOE_TOP_KEEP_OR_MILL:
			return PEEK_VALUE if foe_deck > 0 else 0.0
		CardEnums.EffectType.REVEAL_FOE_HAND:
			return SEE_HAND_VALUE
		CardEnums.EffectType.COPY_FOE_SPELL_TO_HAND:
			return SPELL_COPY_VALUE
		CardEnums.EffectType.FOE_HAND_RANDOM_TO_DECK_BOTTOM:
			return BANISH_VALUE if foe_hand > 0 else 0.0
		CardEnums.EffectType.COPY_FOE_HAND_PICK_TO_HAND:
			return PICK_VALUE if foe_hand > 0 else 0.0
	return 0.0


## 札そのものの見積もり。余砂で写しを取る札と、場にいるあいだ相手の山札の一番上を見る札(`CardCpuStrategy._card_value()` から)。
static func cpu_card_value(state: MatchState, side: int, card: CardData) -> float:
	var value := SEE_DECK_TOP_VALUE if card.sees_foe_deck_top else 0.0
	for effect in card.effects_for(CardEnums.Trigger.ON_DEATH):
		if handles(effect.effect_type):
			value += cpu_value(state, side, effect) * DEATH_FACTOR
	return value


## 見て選ぶ効果(スパイ・ファントム)の選び。`value_of(state, side, card)` で札の値打ちを比べる。
## スパイは相手にとって `MILL_VALUE` 以上の札なら相手の墓地へ置き、ファントムは自分にとって値打ちがいちばん高い札を選ぶ。
static func cpu_peek_hint(
	state: MatchState, side: int, card: CardData, value_of: Callable
) -> Dictionary:
	var effect := choice_effect(card)
	if effect == null:
		return {}
	var seen := seen_cards(state, side, effect)
	if seen.is_empty():
		return {}
	if effect.effect_type == CardEnums.EffectType.PEEK_FOE_TOP_KEEP_OR_MILL:
		var worth: float = value_of.call(state, MatchState.other_side(side), seen[0])
		return {PEEK_KEY: 0} if worth >= MILL_VALUE else {}
	var values: Array[float] = []
	for seen_card in seen:
		values.append(value_of.call(state, side, seen_card))
	return {PEEK_KEY: values.find(values.max())}
