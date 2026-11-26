class_name CardEarlyBellEffects
extends RefCounted
## 第2弾「早鐘の刻」の固有効果(GameDesign.md 6章「マナを動かす効果」)。
## `CardEffectResolver` が1000行の上限に近いため、マナを動かす効果の解決・条件の判定・CPUの見積もりをここへ切り出す。
## 紋章を知らせる処理は `CardEffectResolver` のものを使う(`CardBlazeSandEffects` と同じ作り)。

const TYPES := [
	CardEnums.EffectType.GAIN_MAX_MANA,
	CardEnums.EffectType.RAISE_MAX_MANA_TO_CAP,
	CardEnums.EffectType.GAIN_MANA,
	CardEnums.EffectType.DELAY_MANA,
]
## CPUの見積もり。マナ1つ・最大マナ1つ・次の手番のマナ1つの値打ち。
const MAX_MANA_VALUE := 4.0
const DELAY_VALUE := 1.5
## 場にいる間のコスト下げ(クロックワーク)で、手札1枚のコストが1下がることの値打ち。
const COST_DOWN_VALUE_PER_CARD := 1.0
## 余ったマナを次の手番へ持ち越すこと(スルース)の値打ち。持ち越せるマナの見込みは1ほど。
const CARRY_MANA_VALUE := 2.0
## 払えば負ける・払ってHPが尽きる手を選ばないための罰。
const SELF_KILL_PENALTY := 1000.0

var _state: MatchState
var _resolver: CardEffectResolver


func _init(state: MatchState, resolver: CardEffectResolver) -> void:
	_state = state
	_resolver = resolver


static func handles(effect_type: int) -> bool:
	return TYPES.has(effect_type)


## 「自分の最大マナが上限に届いているなら」(MAX_MANA_FULL)。ほかの条件は見ない。
static func mana_condition_met(state: MatchState, side: int, effect: CardEffectData) -> bool:
	if effect.condition_scope == CardEnums.ConditionScope.MAX_MANA_FULL:
		return int(state.max_mana[side]) >= MatchState.MAX_MANA
	return true


## 最大マナを増やす。上限を超えない。今の手番のマナは増えない。増えた量を返す。
static func raise_max_mana(state: MatchState, side: int, amount: int) -> int:
	var gained := clampi(MatchState.MAX_MANA - int(state.max_mana[side]), 0, maxi(amount, 0))
	state.max_mana[side] += gained
	state.mana_changed.emit(side, state.mana[side], state.max_mana[side])
	return gained


## 今の手番のマナを増やす。上限を超えるぶんは捨てる。
static func gain_mana(state: MatchState, side: int, amount: int) -> void:
	state.mana[side] = mini(int(state.mana[side]) + maxi(amount, 0), MatchState.MAX_MANA)
	state.mana_changed.emit(side, state.mana[side], state.max_mana[side])


## 次の手番のマナを少なく始まるようにする。重なれば足す(`MatchState._begin_turn()` が回復の後に引く)。
static func delay_mana(state: MatchState, side: int, amount: int) -> void:
	state.mana_debt[side] = int(state.mana_debt.get(side, 0)) + maxi(amount, 0)
	state.mana_changed.emit(side, state.mana[side], state.max_mana[side])


func apply(side: int, effect: CardEffectData, from_slot: int, origin: int) -> void:
	var to_side := _resolver._player_side_for(side, effect.target)
	var style := (
		CardEnums.EffectVisualStyle.DRAIN
		if effect.effect_type == CardEnums.EffectType.DELAY_MANA and to_side != side
		else CardEnums.EffectVisualStyle.DESCEND
	)
	match effect.effect_type:
		CardEnums.EffectType.GAIN_MAX_MANA:
			_resolver._strike(side, from_slot, to_side, -1, style, origin)
			raise_max_mana(_state, to_side, effect.value)
		CardEnums.EffectType.RAISE_MAX_MANA_TO_CAP:
			var gained := raise_max_mana(_state, to_side, MatchState.MAX_MANA)
			if gained > 0:
				_resolver._strike(side, from_slot, to_side, -1, style, origin)
				_state.damage_player(to_side, gained * effect.value)
		CardEnums.EffectType.GAIN_MANA:
			_resolver._strike(side, from_slot, to_side, -1, style, origin)
			gain_mana(_state, to_side, effect.value)
		CardEnums.EffectType.DELAY_MANA:
			_resolver._strike(side, from_slot, to_side, -1, style, origin)
			delay_mana(_state, to_side, effect.value)


## CPUの見積もり。`spent` はこの効果を持つ砂術のために払うマナ(砂時計なら0)。
static func cpu_value(
	state: MatchState, side: int, effect: CardEffectData, spent: int = 0
) -> float:
	if not mana_condition_met(state, side, effect):
		return 0.0
	var own := effect.target == CardEnums.EffectTarget.OWN_PLAYER
	match effect.effect_type:
		CardEnums.EffectType.GAIN_MAX_MANA:
			var room := MatchState.MAX_MANA - int(state.max_mana[side])
			return float(mini(effect.value, room)) * MAX_MANA_VALUE
		CardEnums.EffectType.RAISE_MAX_MANA_TO_CAP:
			var gained := MatchState.MAX_MANA - int(state.max_mana[side])
			if gained <= 0:
				return 0.0
			var cost := gained * effect.value
			if int(state.hp[side]) <= cost:
				return -SELF_KILL_PENALTY
			return float(gained) * MAX_MANA_VALUE - float(cost) * CardCpuStrategy.FACE_WEIGHT
		CardEnums.EffectType.GAIN_MANA:
			return _gain_mana_value(state, side, effect.value, spent)
		CardEnums.EffectType.DELAY_MANA:
			var amount := float(effect.value) * DELAY_VALUE
			return -amount if own else amount
	return 0.0


## 増えたマナで、いまは出せない手札の砂時計が出せるようになるときだけ値打ちがある(無駄撃ちを避ける)。
## (砂術を撃たなくても出せる札は数えない)出せるようになる中でいちばん高い1枚の生涯ダメージを数える。
static func _gain_mana_value(state: MatchState, side: int, amount: int, spent: int) -> float:
	var have := int(state.mana[side]) - spent
	var reach := mini(have + amount, MatchState.MAX_MANA)
	var best := 0.0
	for card: CardData in state.hand[side]:
		if card.is_spell:
			continue
		var cost := state.play_cost(side, card)
		if cost > int(state.mana[side]) and cost <= reach:
			best = maxf(
				best, CardCpuStrategy.lifetime_of(card.initial_health(), card.initial_attack)
			)
	return best


## 砂術のCPUの見積もりに足す、マナの動きの値打ち(`CardCpuSpellSearch.best_cast()`)。盤面の差には現れないため別に足す。
static func spell_bonus(state: MatchState, side: int, card: CardData) -> float:
	var total := 0.0
	var spent := state.play_cost(side, card)
	for effect in card.effects_for(CardEnums.Trigger.ON_PLAY):
		if handles(effect.effect_type):
			total += cpu_value(state, side, effect, spent)
	return total


## 最大マナが上限のとき、場の駒が自分のカードのコストを下げる量の合計(クロックワーク)。効果を消された駒は数えない。
static func full_mana_cost_down(state: MatchState, side: int) -> int:
	if int(state.max_mana.get(side, 0)) < MatchState.MAX_MANA:
		return 0
	var down := 0
	for unit: CardInstance in state.units(side):
		if not unit.silenced:
			down += unit.data.ally_cost_down_at_full_mana
	return down


## 場の駒が、手番の終わりに残したマナを持ち越させるか(スルース)。効果を消された駒は数えない。
static func carries_mana(state: MatchState, side: int) -> bool:
	return state.units(side).any(
		func(unit: CardInstance) -> bool: return unit.data.carries_mana and not unit.silenced
	)


## 次の手番のマナの増減の見込み(持ち越し − 「次 −n」。画面の札が出す。GameDesign.md 6章)。
## 持ち越しは手番の終わりに決まるため、自分の手番の間は「いま終えたら」持ち越す数で数える。
static func next_mana_shift(state: MatchState, side: int) -> int:
	var carry := int(state.mana_carry.get(side, 0))
	if state.current_turn == side and carries_mana(state, side):
		carry = maxi(int(state.mana[side]), 0)
	return carry - int(state.mana_debt.get(side, 0))


## 場にいる間の常在(クロックワークのコスト下げ・スルースの持ち越し)の、CPUの見積もり。
## コスト下げは最大マナが上限のときだけ働くため、上限に届いているときに下がる手札の枚数ぶんだけ見る。
static func cpu_standing_value(state: MatchState, side: int, card: CardData) -> float:
	var value := 0.0
	if card.ally_cost_down_at_full_mana > 0 and int(state.max_mana[side]) >= MatchState.MAX_MANA:
		for hand_card: CardData in state.hand[side]:
			if state.play_cost(side, hand_card) > MatchState.MIN_COST:
				value += float(card.ally_cost_down_at_full_mana) * COST_DOWN_VALUE_PER_CARD
	if card.carries_mana:
		value += CARRY_MANA_VALUE
	return value
