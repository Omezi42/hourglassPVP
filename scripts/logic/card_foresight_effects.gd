class_name CardForesightEffects
extends RefCounted
## 第2弾「先触の刻」の固有効果(GameDesign.md 6章「山札の上を扱う効果」)。
## `CardEffectResolver` が1000行の上限に近いため、山札の上を墓地へ置く・見て選ぶ・公開する・使う効果の解決と
## CPUの見積もりをここへ切り出す。紋章を知らせる処理は `CardEffectResolver` のものを使う(`CardEarlyBellEffects` と同じ作り)。

const TYPES := [
	CardEnums.EffectType.MILL_DECK,
	CardEnums.EffectType.PEEK_KEEP_OR_MILL,
	CardEnums.EffectType.PEEK_PICK_TO_HAND,
	CardEnums.EffectType.REVEAL_RAISE_SAND,
	CardEnums.EffectType.REVEAL_PLAY_OR_HAND,
	CardEnums.EffectType.MILL_TAKE_BEST_UNIT,
	CardEnums.EffectType.MILL_SPELL_DAMAGE,
	CardEnums.EffectType.PLAY_DECK_TOP,
]
## 見て選ぶ効果の選びを運ぶ hint のキー。予兆は見た札の位置、スコープは0なら墓地へ(無ければそのまま)。
const PEEK_KEY := "peek_index"
## CPUの見積もり。1枚引く値打ち(`DRAW` と同じ)・山札を削る1枚ぶん・山札が尽きかける罰。
const CARD_VALUE := 3.0
const MILL_VALUE_PER_CARD := 0.3
const DECK_OUT_PENALTY := 5.0
const PEEK_VALUE := 1.0
const SPELL_ODDS_VALUE := 0.5
const RAISE_VALUE_PER_SAND := 1.5
## スコープでそのままにする札の最低の値打ち。これを下回る札は墓地へ置く。
const SCOPE_KEEP_VALUE := 5.0

var _state: MatchState
var _resolver: CardEffectResolver


func _init(state: MatchState, resolver: CardEffectResolver) -> void:
	_state = state
	_resolver = resolver


static func handles(effect_type: int) -> bool:
	return TYPES.has(effect_type)


## 出したときに山札の上を見て選ばせる効果(スコープ・予兆)。無ければ null。
static func peek_choice_effect(card: CardData) -> CardEffectData:
	for effect in card.effects_for(CardEnums.Trigger.ON_PLAY):
		if (
			effect.effect_type == CardEnums.EffectType.PEEK_KEEP_OR_MILL
			or effect.effect_type == CardEnums.EffectType.PEEK_PICK_TO_HAND
		):
			return effect
	return null


## 見て選ぶ効果が見る札(山札の上から)。山札が足りなければある分。
static func peeked(state: MatchState, side: int, effect: CardEffectData) -> Array[CardData]:
	var count := 1 if effect.effect_type == CardEnums.EffectType.PEEK_KEEP_OR_MILL else effect.value
	var found: Array[CardData] = []
	for index in mini(count, state.deck[side].size()):
		found.append(state.deck[side][index])
	return found


## 山札の一番上を使う効果(予言)を持つ札か。
static func plays_top(card: CardData) -> bool:
	return card.effects_for(CardEnums.Trigger.ON_PLAY).any(
		func(effect: CardEffectData) -> bool:
			return effect.effect_type == CardEnums.EffectType.PLAY_DECK_TOP
	)


## 山札の一番上が使えるか。砂時計は空き枠が、砂術は撃てる条件が要る。
static func top_usable(state: MatchState, side: int) -> bool:
	if state.deck[side].is_empty():
		return false
	var card: CardData = state.deck[side][0]
	if card.is_spell:
		return CardEffectResolver.castable(state, side, card)
	return not state.empty_slots(side).is_empty()


func apply(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	match effect.effect_type:
		CardEnums.EffectType.MILL_DECK:
			_pulse(side, from_slot, origin)
			MatchDeckTop.mill(_state, side, effect.value)
		CardEnums.EffectType.PEEK_KEEP_OR_MILL:
			_pulse(side, from_slot, origin)
			if int(hint.get(PEEK_KEY, -1)) == 0:
				MatchDeckTop.mill(_state, side, 1)
		CardEnums.EffectType.PEEK_PICK_TO_HAND:
			_peek_pick(side, effect, hint, from_slot, origin)
		CardEnums.EffectType.REVEAL_RAISE_SAND:
			_reveal_raise_sand(side, unit, effect, hint, from_slot, origin)
		CardEnums.EffectType.REVEAL_PLAY_OR_HAND:
			_reveal_play_or_hand(side, effect, from_slot, origin)
		CardEnums.EffectType.MILL_TAKE_BEST_UNIT:
			_pulse(side, from_slot, origin)
			_take_best_unit(side, MatchDeckTop.mill(_state, side, effect.value))
		CardEnums.EffectType.MILL_SPELL_DAMAGE:
			_mill_spell_damage(side, effect, from_slot, origin)
		CardEnums.EffectType.PLAY_DECK_TOP:
			_play_top(side, hint, from_slot, origin)


func _pulse(side: int, from_slot: int, origin: int) -> void:
	_resolver._strike(side, from_slot, side, -1, CardEnums.EffectVisualStyle.PULSE, origin)


## 山札の上から value 枚を見て、選んだ1枚を手札へ、残りを墓地へ。見た札の位置が hint に無ければ最後の札を選ぶ。
func _peek_pick(
	side: int, effect: CardEffectData, hint: Dictionary, from_slot: int, origin: int
) -> void:
	var seen := peeked(_state, side, effect)
	if seen.is_empty():
		return
	_pulse(side, from_slot, origin)
	var pick := int(hint.get(PEEK_KEY, seen.size() - 1))
	if pick < 0 or pick >= seen.size():
		pick = seen.size() - 1
	var cards: Array[CardData] = []
	for i in seen.size():
		cards.append(MatchDeckTop.take_top(_state, side))
	var rest: Array[CardData] = []
	for i in cards.size():
		if i == pick:
			_state.hand[side].append(cards[i])
		else:
			_state.graveyard[side].append(cards[i])
			rest.append(cards[i])
	if not rest.is_empty():
		_state.deck_milled.emit(side, rest.size())
	_state.hand_changed.emit(side)


## 山札の一番上を公開し、そのコストの数だけ対象の砂を上へ戻す。公開した札は山札の一番上に残る。
func _reveal_raise_sand(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	if _state.deck[side].is_empty():
		return
	var top: CardData = _state.deck[side][0]
	_state.deck_revealed.emit(side, top)
	for entry: Dictionary in _resolver._targets(side, unit, effect, hint):
		_resolver._strike(
			side, from_slot, entry["side"], entry["slot"], CardEnums.EffectVisualStyle.DRAIN, origin
		)
		var target := _resolver._unit_at(entry)
		var moved := target.raise_sand(top.cost) if target != null else 0
		if moved > 0:
			_state.unit_raised.emit(entry["side"], entry["slot"], moved)


## 山札の一番上を公開する。コスト value 以下の砂時計なら場に出し(設置効果は働く)、出せなければ・それ以外は手札へ。
func _reveal_play_or_hand(side: int, effect: CardEffectData, from_slot: int, origin: int) -> void:
	if _state.deck[side].is_empty():
		return
	var top: CardData = _state.deck[side][0]
	_state.deck_revealed.emit(side, top)
	var slot := _resolver._first_empty_slot(side)
	var enters := not top.is_spell and top.cost <= effect.value and slot >= 0
	MatchDeckTop.take_top(_state, side)
	if enters:
		_enter_board(side, top, slot, {}, from_slot, origin)
	else:
		_pulse(side, from_slot, origin)
		_state.hand[side].append(top)
		_state.hand_changed.emit(side)


## 墓地へ置いた札の中でコストがいちばん高い砂時計(同じコストなら後に置いた札)を手札へ戻す。
func _take_best_unit(side: int, milled: Array[CardData]) -> void:
	var best: CardData = null
	for card in milled:
		if card.is_spell or card.is_token:
			continue
		if best == null or card.cost >= best.cost:
			best = card
	if best == null:
		return
	var pile: Array = _state.graveyard[side]
	for index in range(pile.size() - 1, -1, -1):
		if pile[index] == best:
			pile.remove_at(index)
			break
	_state.hand[side].append(best)
	_state.hand_changed.emit(side)


func _mill_spell_damage(side: int, effect: CardEffectData, from_slot: int, origin: int) -> void:
	_pulse(side, from_slot, origin)
	var milled := MatchDeckTop.mill(_state, side, 1)
	if milled.is_empty() or not milled[0].is_spell:
		return
	var foe_side := MatchState.other_side(side)
	for entry: Dictionary in _resolver._random_unit(foe_side, -1, effect):
		_resolver._strike(
			side, from_slot, foe_side, entry["slot"], CardEnums.EffectVisualStyle.STRIKE, origin
		)
		_state.damage_unit(foe_side, entry["slot"], effect.value)


## 山札の一番上を、コストを払わずに使う。砂時計は最初の空き枠へ出し、砂術は撃つ。使えなければ山札に残す。
func _play_top(side: int, hint: Dictionary, from_slot: int, origin: int) -> void:
	if not top_usable(_state, side):
		return
	var card := MatchDeckTop.take_top(_state, side)
	if card.is_spell:
		_state.graveyard[side].append(card)
		_state.spell_cast.emit(side, card)
		_state._fire(side, CardInstance.new(card), CardEnums.Trigger.ON_PLAY, hint)
		_state._fire_own_spell(side)
		return
	_enter_board(side, card, _resolver._first_empty_slot(side), hint, from_slot, origin)


## 砂時計を空き枠へ出す(コストは払わない)。設置効果は解決する(手で出したのと同じ)。
func _enter_board(
	side: int, card: CardData, slot: int, hint: Dictionary, from_slot: int, origin: int
) -> void:
	_resolver._strike(side, from_slot, side, slot, CardEnums.EffectVisualStyle.DESCEND, origin)
	var played := CardInstance.new(card)
	if played.has_keyword(CardEnums.Keyword.QUICK):
		played.summoned_this_turn = false
	_state.board[side][slot] = played
	_state.board_changed.emit(side)
	_state._fire(side, played, CardEnums.Trigger.ON_PLAY, hint)
	CardPourSandEffects.fire_entered(_state, side, slot)


## CPUの見積もり(設置・落砂の効果)。砂術は `CardCpuSpellSearch` が撃って測る。
static func cpu_value(state: MatchState, side: int, effect: CardEffectData) -> float:
	var deck_size: int = state.deck[side].size()
	match effect.effect_type:
		CardEnums.EffectType.MILL_DECK:
			if deck_size <= effect.value:
				return -DECK_OUT_PENALTY
			return float(effect.value) * MILL_VALUE_PER_CARD
		CardEnums.EffectType.PEEK_KEEP_OR_MILL:
			return PEEK_VALUE
		CardEnums.EffectType.PEEK_PICK_TO_HAND:
			return CARD_VALUE if deck_size > effect.value else 0.0
		CardEnums.EffectType.REVEAL_RAISE_SAND:
			return _raise_value(state, side)
		CardEnums.EffectType.REVEAL_PLAY_OR_HAND:
			return CARD_VALUE if deck_size > 0 else 0.0
		CardEnums.EffectType.MILL_TAKE_BEST_UNIT:
			if deck_size <= effect.value:
				return -DECK_OUT_PENALTY
			return CARD_VALUE + float(effect.value) * MILL_VALUE_PER_CARD
		CardEnums.EffectType.MILL_SPELL_DAMAGE:
			return SPELL_ODDS_VALUE if deck_size > 1 else -DECK_OUT_PENALTY
		CardEnums.EffectType.PLAY_DECK_TOP:
			return CARD_VALUE if top_usable(state, side) else 0.0
	return 0.0


## ルーンの見積もり。山札の中身の平均コストと、相手のいちばん攻撃力の高い駒のうち小さいほうの砂を戻せる。
static func _raise_value(state: MatchState, side: int) -> float:
	var deck: Array = state.deck[side]
	if deck.is_empty():
		return 0.0
	var total := 0
	for card: CardData in deck:
		total += card.cost
	var average := float(total) / float(deck.size())
	var strongest := 0
	for unit: CardInstance in state.units(MatchState.other_side(side)):
		strongest = maxi(strongest, unit.attack)
	return minf(average, float(strongest)) * RAISE_VALUE_PER_SAND


## 山札の上を見て選ぶ効果(スコープ・予兆)の選び。見た札を `value_of(state, side, card)` の評価値で比べる。
## 予兆は評価がいちばん高い1枚を手札へ、スコープは評価が `SCOPE_KEEP_VALUE` を下回る札だけ墓地へ置く(高ければそのまま)。
static func cpu_peek_hint(
	state: MatchState, side: int, card: CardData, value_of: Callable
) -> Dictionary:
	var effect := peek_choice_effect(card)
	if effect == null:
		return {}
	var seen := peeked(state, side, effect)
	if seen.is_empty():
		return {}
	var values: Array[float] = []
	for seen_card in seen:
		values.append(value_of.call(state, side, seen_card))
	if effect.effect_type == CardEnums.EffectType.PEEK_KEEP_OR_MILL:
		return {PEEK_KEY: 0} if values[0] < SCOPE_KEEP_VALUE else {}
	return {PEEK_KEY: values.find(values.max())}
