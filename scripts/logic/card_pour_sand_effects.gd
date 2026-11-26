class_name CardPourSandEffects
extends RefCounted
## 第2弾「注砂の刻」と、テーマ外のレジェンド・テルミヌスの固有効果(GameDesign.md 6章「残りのマナを使う効果」「味方が出るたびに働く効果」「特殊勝利」)。
## `CardEffectResolver` が1000行の上限に近いため、残りのマナを使う・総量を移す・砕けた攻撃力を配る・特殊勝利の解決と、
## 札の文に添える「(いま使うと +n)」、CPUの見積もりをここへ切り出す。紋章を知らせる処理は `CardEffectResolver` のものを使う。

const TYPES := [
	CardEnums.EffectType.SPEND_MANA_ADD_TOTAL,
	CardEnums.EffectType.SPEND_MANA_DAMAGE_RANDOM,
	CardEnums.EffectType.ADD_TOTAL_PER_UNUSED_MANA,
	CardEnums.EffectType.TRANSFER_TOTAL_TO_SELF,
	CardEnums.EffectType.DISTRIBUTE_TOTAL_BY_OWN_ATTACK,
	CardEnums.EffectType.WIN_IF_DECK_EMPTY,
]
## 総量を減らしても体力はこれ未満にしない(効果で自分の駒を砕かないため)。
const MIN_HEALTH := 1
## 対局中の札の文に添える、いま使うと得られる量(GameDesign.md 6章「残りのマナを使う効果」)。
const ADD_NOTE := "(いま使うと +%d)"
const DAMAGE_NOTE := "(いま使うと %dダメージ)"
## CPUの見積もり。総量1の値打ち(`ADD_TOTAL` と同じ)・勝ちの値打ち・総量を移す1点・使わずに残すマナの見込み・砕けて配る攻撃力の見込み。
const TOTAL_VALUE := 2.0
const WIN_VALUE := 1000.0
const TRANSFER_VALUE_PER_POINT := 1.0
const UNUSED_MANA_GUESS := 0.5
const SPILL_ATTACK_RATIO := 0.5

var _state: MatchState
var _resolver: CardEffectResolver


func _init(state: MatchState, resolver: CardEffectResolver) -> void:
	_state = state
	_resolver = resolver


static func handles(effect_type: int) -> bool:
	return TYPES.has(effect_type)


## この効果が `CardCpuStrategy` の一般の見積もりではなく、ここで見積もる効果か(固有の種類か、残りのマナを条件にする効果)。
static func handles_effect(effect: CardEffectData) -> bool:
	return (
		handles(effect.effect_type)
		or effect.condition_scope == CardEnums.ConditionScope.OWN_MANA_AT_LEAST
	)


## 「残りのマナが n 以上なら」(OWN_MANA_AT_LEAST)。ほかの条件は見ない。コストを払った後のいまのマナで判定する。
static func mana_condition_met(state: MatchState, side: int, effect: CardEffectData) -> bool:
	if effect.condition_scope == CardEnums.ConditionScope.OWN_MANA_AT_LEAST:
		return int(state.mana[side]) >= effect.condition_total
	return true


## 手札のこの札を使ったとき、コストを払った後に残るマナ。
static func spare_mana(state: MatchState, side: int, card: CardData) -> int:
	return maxi(int(state.mana[side]) - state.play_cost(side, card), 0)


## 札の文に添える「(いま使うと +n)」。残りのマナをすべて使う効果を持たない札は空。
static func live_note(state: MatchState, side: int, card: CardData) -> String:
	for effect in card.effects_for(CardEnums.Trigger.ON_PLAY):
		var spare := spare_mana(state, side, card)
		match effect.effect_type:
			CardEnums.EffectType.SPEND_MANA_ADD_TOTAL:
				return ADD_NOTE % (spare * effect.value)
			CardEnums.EffectType.SPEND_MANA_DAMAGE_RANDOM:
				return DAMAGE_NOTE % (spare * effect.value)
	return ""


## 自分が砂時計を出したときに働く効果(ファウンテン)を、場にいる他の自分の駒から発火する。
## 手から出したときも効果で出したとき(トークン・蘇生・スタンピード・未来視・予言・シビル)も、出した直後にここを通る。
## 出た駒自身は働かない。出た駒が既に砕けていれば何も起きない。
static func fire_entered(state: MatchState, side: int, slot: int) -> void:
	var entered: CardInstance = state.board[side][slot]
	if entered == null or entered.is_dead():
		return
	for unit: CardInstance in state.units(side):
		if unit == entered or unit.is_dead():
			continue
		if not unit.effects_for(CardEnums.Trigger.ON_ALLY_ENTER).is_empty():
			state._fire(side, unit, CardEnums.Trigger.ON_ALLY_ENTER, {"entered_slot": slot})


## 総量を amount 減らす。体力から引き、体力が1未満になるぶんは攻撃力から引く。総量が1になるまでしか減らさない。
static func shrink_total(unit: CardInstance, amount: int) -> void:
	var cut := mini(amount, unit.total_sand() - MIN_HEALTH)
	if cut <= 0:
		return
	unit.health -= cut
	if unit.health < MIN_HEALTH:
		unit.attack -= MIN_HEALTH - unit.health
		unit.health = MIN_HEALTH


func apply(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	match effect.effect_type:
		CardEnums.EffectType.SPEND_MANA_ADD_TOTAL:
			_spend_add_total(side, unit, effect, hint, from_slot, origin)
		CardEnums.EffectType.SPEND_MANA_DAMAGE_RANDOM:
			_spend_damage(side, effect, from_slot, origin)
		CardEnums.EffectType.ADD_TOTAL_PER_UNUSED_MANA:
			_add_per_unused_mana(side, unit, effect, hint, from_slot, origin)
		CardEnums.EffectType.TRANSFER_TOTAL_TO_SELF:
			_transfer(side, unit, effect, hint, from_slot, origin)
		CardEnums.EffectType.DISTRIBUTE_TOTAL_BY_OWN_ATTACK:
			_distribute(side, unit, from_slot, origin)
		CardEnums.EffectType.WIN_IF_DECK_EMPTY:
			_win_if_deck_empty(side, from_slot, origin)


## 残りのマナをすべて0にして、使った量を返す。
func _spend_all(side: int) -> int:
	var spent := int(_state.mana[side])
	_state.mana[side] = 0
	_state.mana_changed.emit(side, 0, _state.max_mana[side])
	return spent


func _spend_add_total(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	var amount := _spend_all(side) * effect.value
	if amount > 0:
		_add_total(side, unit, effect, hint, amount, from_slot, origin)


func _add_per_unused_mana(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	var amount := maxi(int(_state.mana[side]), 0) * effect.value
	if amount > 0:
		_add_total(side, unit, effect, hint, amount, from_slot, origin)


func _add_total(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	amount: int,
	from_slot: int,
	origin: int
) -> void:
	var entries := _resolver._targets(side, unit, effect, hint)
	_resolver._strike_for_targets(
		side, from_slot, effect.target, entries, CardEnums.EffectVisualStyle.DESCEND, origin
	)
	for entry: Dictionary in entries:
		var target := _resolver._unit_at(entry)
		if target != null:
			target.health += amount


## 使った数だけ1回ずつ、その時点で場にいる(砕けていない)相手の砂時計からランダムに選んでダメージを与える。
## 乱数は対局の乱数から引く(リプレイ・オンラインで一致させるため)。相手の駒がいなくなったら残りは捨てる。
func _spend_damage(side: int, effect: CardEffectData, from_slot: int, origin: int) -> void:
	var foe_side := MatchState.other_side(side)
	for i in _spend_all(side):
		var pool: Array[int] = []
		for slot in MatchState.BOARD_SIZE:
			var foe: CardInstance = _state.board[foe_side][slot]
			if foe != null and not foe.is_dead():
				pool.append(slot)
		if pool.is_empty():
			return
		var slot: int = pool[_state._rng.randi_range(0, pool.size() - 1)]
		_resolver._strike(
			side, from_slot, foe_side, slot, CardEnums.EffectVisualStyle.STRIKE, origin
		)
		_state.damage_unit(foe_side, slot, effect.value)


## 対象の総量を減らし、この砂時計の総量を同じ値だけ増やす。対象がいなければ何も起きない。
func _transfer(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	var entries := _resolver._targets(side, unit, effect, hint)
	if entries.is_empty():
		return
	var target := _resolver._unit_at(entries[0])
	if target == null or target.is_dead():
		return
	_resolver._strike_for_targets(
		side, from_slot, effect.target, entries, CardEnums.EffectVisualStyle.DRAIN, origin
	)
	shrink_total(target, effect.value)
	unit.health += effect.value


## 砕けた時の攻撃力の数だけ、自分の他の砂時計へ左から順に1ずつ総量を足す。一周したら左から。
## 同じ一撃で砕けた駒(体力0)へは足さない(息を吹き返してしまうため)。
func _distribute(side: int, unit: CardInstance, from_slot: int, origin: int) -> void:
	var entries: Array = []
	for slot in MatchState.BOARD_SIZE:
		var other: CardInstance = _state.board[side][slot]
		if other != null and other != unit and not other.is_dead():
			entries.append({"side": side, "slot": slot})
	if entries.is_empty() or unit.attack <= 0:
		return
	_resolver._strike_many(side, from_slot, entries, CardEnums.EffectVisualStyle.DESCEND, origin)
	for i in unit.attack:
		_resolver._unit_at(entries[i % entries.size()]).health += 1


## 山札が0枚なら、その時点で対局に勝つ。相手のHPは問わない。
func _win_if_deck_empty(side: int, from_slot: int, origin: int) -> void:
	if not _state.deck[side].is_empty():
		return
	_resolver._strike(side, from_slot, side, -1, CardEnums.EffectVisualStyle.PULSE, origin)
	_state._finish(side, MatchState.EndReason.SPECIAL_WIN)


## CPUの見積もり(繰り返し働くトリガーの効果。`CardCpuStrategy._on_play_value()` から)。
static func cpu_value(_state: MatchState, _side: int, effect: CardEffectData) -> float:
	match effect.effect_type:
		CardEnums.EffectType.ADD_TOTAL_PER_UNUSED_MANA:
			return float(effect.value) * UNUSED_MANA_GUESS * TOTAL_VALUE
	return 0.0


## CPUの見積もり(設置の効果と、この札ひとつぶん)。`spare` は札を出した後に残るマナ。砂術は撃って測るためここへ来ない。
static func cpu_play_value(
	state: MatchState, side: int, effect: CardEffectData, spare: int
) -> float:
	if not mana_condition_met_with(effect, spare):
		return 0.0
	var allies := float(state.units(side).size() + 1)
	match effect.effect_type:
		CardEnums.EffectType.SPEND_MANA_ADD_TOTAL:
			var reach := 1.0 if effect.target == CardEnums.EffectTarget.SELF else allies
			return float(spare * effect.value) * TOTAL_VALUE * reach
		CardEnums.EffectType.TRANSFER_TOTAL_TO_SELF:
			if state.units(side).is_empty():
				return 0.0
			return float(effect.value) * TRANSFER_VALUE_PER_POINT
		CardEnums.EffectType.WIN_IF_DECK_EMPTY:
			return WIN_VALUE if state.deck[side].is_empty() else 0.0
		CardEnums.EffectType.ADD_TOTAL:
			return float(effect.value) * TOTAL_VALUE * allies
	return 0.0


## 札を出した後に残るマナ `spare` で、残りのマナを条件にする効果が働くか(効果に条件が無ければ働く)。
static func mana_condition_met_with(effect: CardEffectData, spare: int) -> bool:
	if effect.condition_scope == CardEnums.ConditionScope.OWN_MANA_AT_LEAST:
		return spare >= effect.condition_total
	return true


## 総量を移す効果(デカンタ)で減らす味方。減らしても痛みの少ない、生涯ダメージのいちばん小さい駒(総量が足りない駒は後回し)。
static func cpu_transfer_slot(state: MatchState, side: int, amount: int) -> int:
	var best := -1
	var best_key := Vector2i.ZERO
	for slot in MatchState.BOARD_SIZE:
		var unit: CardInstance = state.board[side][slot]
		if unit == null:
			continue
		var key := Vector2i(0 if unit.total_sand() > amount else 1, unit.lifetime_damage())
		if best < 0 or key.x < best_key.x or (key.x == best_key.x and key.y < best_key.y):
			best = slot
			best_key = key
	return best


## 砕けた時に働く効果(アンフォラ)の、CPUの見積もり。砕けた時の攻撃力は総量の半分ほどと見込む。
static func cpu_death_value(card: CardData) -> float:
	var value := 0.0
	for effect in card.effects_for(CardEnums.Trigger.ON_DEATH):
		if effect.effect_type == CardEnums.EffectType.DISTRIBUTE_TOTAL_BY_OWN_ATTACK:
			value += float(card.total_sand) * SPILL_ATTACK_RATIO * TOTAL_VALUE
	return value
