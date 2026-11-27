class_name CardDuelEffects
extends RefCounted
## 第3弾「決闘の刻」の固有効果(GameDesign.md 6章「戦わせる効果」)。
## 自分の駒と相手の駒を戦わせる・出したターンの駒を相手の砂時計へ送り出す・攻撃で砕くたびに働く・戦闘を生き残るたびに働く・反撃を和らげる。
## 戦闘そのものは通常の戦闘(`MatchState._resolve_unit_combat()`)をそのまま使う。

const TYPES := [
	CardEnums.EffectType.FIGHT_FOE,
	CardEnums.EffectType.FIGHT_FOE_TO_DEATH,
	CardEnums.EffectType.RUSH_FOE_ONLY,
	CardEnums.EffectType.BAR_FACE_ATTACK,
	CardEnums.EffectType.REFRESH_ATTACK,
]
## 戦わせる自分の駒の枠を運ぶ hint のキー(相手の駒は通常の対象の指定)。
const OWN_SLOT_KEY := "own_slot"
## 決着がつくまで戦わせる回数の上限。効果で砕けたそばから戻り続けるような駒で止まらなくなるのを防ぐ保険で、通常は数回で終わる。
const MAX_ROUNDS := 32
## CPUの見積もり。出したばかりの駒が相手の砂時計を殴れる1回の値打ち(送り出す駒の攻撃力に掛ける)。
const RUSH_VALUE := 1.5
## もう一度攻撃できる1回の値打ち。
const REFRESH_VALUE := 3.0

var _state: MatchState
var _resolver: CardEffectResolver


func _init(state: MatchState, resolver: CardEffectResolver) -> void:
	_state = state
	_resolver = resolver


static func handles(effect_type: int) -> bool:
	return TYPES.has(effect_type)


static func is_fight(effect_type: int) -> bool:
	return (
		effect_type == CardEnums.EffectType.FIGHT_FOE
		or effect_type == CardEnums.EffectType.FIGHT_FOE_TO_DEATH
	)


## 撃てる砂術か。戦わせるには、自分の駒と相手の駒が1体ずついる必要がある。
static func castable(state: MatchState, side: int, effect: CardEffectData) -> bool:
	if not is_fight(effect.effect_type):
		return true
	return (
		not state.units(side).is_empty() and not state.units(MatchState.other_side(side)).is_empty()
	)


## フェンサー:攻撃した側が受ける反撃のダメージ。`power` は相手の攻撃力(倍撃を含む)で、効果を消されたフェンサーは減らさない。
static func after_recoil_cut(attacker: CardInstance, power: int) -> int:
	if attacker.silenced:
		return power
	return maxi(power - attacker.data.attack_recoil_cut, 0)


## 攻撃で相手の砂時計を砕いたとき(デュエリスト・ナイト・チャンピオン)。攻撃した駒が砕けていなければ働く。
static func fire_attack_kill(
	state: MatchState, side: int, attacker: CardInstance, defender: CardInstance
) -> void:
	if state._match_over or attacker.is_dead() or not defender.is_dead():
		return
	if attacker.effects_for(CardEnums.Trigger.ON_ATTACK_KILL).is_empty():
		return
	state._fire(side, attacker, CardEnums.Trigger.ON_ATTACK_KILL, {})
	state._cleanup_dead()


## 戦闘の後に砕けていなかったとき(ベテラン)。攻撃した・された・戦わされた、のどれでも働く。
static func fire_survived(state: MatchState, side: int, unit: CardInstance) -> void:
	if state._match_over or unit.is_dead():
		return
	if unit.effects_for(CardEnums.Trigger.ON_COMBAT_SURVIVE).is_empty():
		return
	state._fire(side, unit, CardEnums.Trigger.ON_COMBAT_SURVIVE, {})


## 自分の駒と相手の駒を戦わせる。攻撃の回数は使わず、守護も見ない。`to_death` なら、どちらかが砕けるまで繰り返す
## (どちらも攻撃力0なら1回で止める)。攻撃ではないため、攻撃したときの効果・攻撃で砕くたびの効果は働かない。
static func fight(
	state: MatchState, side: int, own_slot: int, foe_slot: int, to_death: bool
) -> void:
	var foe_side := MatchState.other_side(side)
	var own: CardInstance = state.board[side][own_slot]
	var foe: CardInstance = state.board[foe_side][foe_slot]
	if own == null or foe == null:
		return
	for round_index in MAX_ROUNDS:
		state._resolve_unit_combat(side, own_slot, foe_slot, foe_side)
		if not to_death or state._match_over or own.is_dead() or foe.is_dead():
			break
		if own.attack <= 0 and foe.attack <= 0:
			break
		if state.board[side][own_slot] != own or state.board[foe_side][foe_slot] != foe:
			break
	state._cleanup_dead()


## 戦わせる自分の駒の枠。hint の own_slot が生きている自分の駒を指すならそれ、無ければ相手の駒と戦わせて得がいちばん大きい駒。いなければ -1。
static func own_pick(
	state: MatchState, side: int, foe_slot: int, hint: Dictionary, to_death: bool
) -> int:
	var foe: CardInstance = state.board[MatchState.other_side(side)][foe_slot]
	var picked: int = int(hint.get(OWN_SLOT_KEY, -1))
	if picked >= 0 and picked < MatchState.BOARD_SIZE:
		var named: CardInstance = state.board[side][picked]
		if named != null and not named.is_dead():
			return picked
	var best := -1
	var best_gain := 0.0
	for slot in MatchState.BOARD_SIZE:
		var own: CardInstance = state.board[side][slot]
		if own == null or own.is_dead() or foe == null:
			continue
		var gain := pair_gain(own, foe, to_death)
		if best < 0 or gain > best_gain:
			best = slot
			best_gain = gain
	return best


## 戦わせたときの得(相手の駒が失う生涯ダメージ − 自分の駒が失う生涯ダメージ)。硝子と倍撃だけを見る概算。
static func pair_gain(own: CardInstance, foe: CardInstance, to_death: bool) -> float:
	var own_health := own.health
	var foe_health := foe.health
	var own_glass := own.glass_intact
	var foe_glass := foe.glass_intact
	var to_foe := _power(own)
	var to_own := _power(foe)
	for round_index in MAX_ROUNDS:
		if to_foe > 0:
			if foe_glass:
				foe_glass = false
			else:
				foe_health -= to_foe
		if to_own > 0:
			if own_glass:
				own_glass = false
			else:
				own_health -= to_own
		if not to_death or own_health <= 0 or foe_health <= 0 or (to_foe <= 0 and to_own <= 0):
			break
	return _loss(foe, foe_health) - _loss(own, own_health)


static func _power(unit: CardInstance) -> int:
	return unit.attack * (2 if unit.has_keyword(CardEnums.Keyword.DAMAGE_BOOST) else 1)


## 体力が `after` になったときに失う生涯ダメージ。
static func _loss(unit: CardInstance, after: int) -> float:
	var kept := 0.0
	if after > 0:
		kept = float(after * unit.attack + after * (after - 1) / 2)
	return float(unit.lifetime_damage()) - kept


## CPUの砂術の1手読み用。戦わせられる自分の駒と相手の駒の組をすべて並べる(相手の駒は通常の対象の指定、自分の駒は own_slot)。
static func candidate_pairs(state: MatchState, side: int) -> Array:
	var foe_side := MatchState.other_side(side)
	var found: Array = []
	for foe_slot in MatchState.BOARD_SIZE:
		if state.board[foe_side][foe_slot] == null:
			continue
		for own_slot in MatchState.BOARD_SIZE:
			if state.board[side][own_slot] != null:
				found.append({"side": foe_side, "slot": foe_slot, OWN_SLOT_KEY: own_slot})
	return found


func apply(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	var entries := _resolver._targets(side, unit, effect, hint).filter(
		func(entry: Dictionary) -> bool: return not _resolver._unit_at(entry).is_dead()
	)
	if entries.is_empty():
		return
	match effect.effect_type:
		CardEnums.EffectType.FIGHT_FOE, CardEnums.EffectType.FIGHT_FOE_TO_DEATH:
			_fight(side, effect, hint, entries[0], from_slot, origin)
		CardEnums.EffectType.RUSH_FOE_ONLY, CardEnums.EffectType.BAR_FACE_ATTACK:
			_mark_allies(side, effect, entries, from_slot, origin)
		CardEnums.EffectType.REFRESH_ATTACK:
			_resolver._strike_for_targets(
				side, from_slot, effect.target, entries, CardEnums.EffectVisualStyle.DESCEND, origin
			)
			for entry: Dictionary in entries:
				var target := _resolver._unit_at(entry)
				target.attacks_this_turn = maxi(target.attacks_this_turn - effect.value, 0)


func _fight(
	side: int,
	effect: CardEffectData,
	hint: Dictionary,
	foe_entry: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	var to_death := effect.effect_type == CardEnums.EffectType.FIGHT_FOE_TO_DEATH
	var foe_slot: int = foe_entry["slot"]
	var own_slot := own_pick(_state, side, foe_slot, hint, to_death)
	if own_slot < 0:
		return
	_resolver._strike(
		side, from_slot, foe_entry["side"], foe_slot, CardEnums.EffectVisualStyle.STRIKE, origin
	)
	fight(_state, side, own_slot, foe_slot, to_death)


func _mark_allies(
	side: int, effect: CardEffectData, entries: Array, from_slot: int, origin: int
) -> void:
	_resolver._strike_for_targets(
		side, from_slot, effect.target, entries, CardEnums.EffectVisualStyle.DESCEND, origin
	)
	for entry: Dictionary in entries:
		var target := _resolver._unit_at(entry)
		target.face_barred = true
		if effect.effect_type == CardEnums.EffectType.RUSH_FOE_ONLY:
			target.rushed = true
	_state.board_changed.emit(side)


## CPUの見積もり(`CardCpuStrategy._themed_value()` から)。戦わせる得は、いま場にいる駒の組でいちばん大きいもので数える。
static func cpu_value(state: MatchState, side: int, effect: CardEffectData) -> float:
	match effect.effect_type:
		CardEnums.EffectType.FIGHT_FOE, CardEnums.EffectType.FIGHT_FOE_TO_DEATH:
			var to_death := effect.effect_type == CardEnums.EffectType.FIGHT_FOE_TO_DEATH
			var best := 0.0
			for foe: CardInstance in state.units(MatchState.other_side(side)):
				for own: CardInstance in state.units(side):
					best = maxf(best, pair_gain(own, foe, to_death))
			return best
		CardEnums.EffectType.RUSH_FOE_ONLY:
			var biggest := 0
			for ally: CardInstance in state.units(side):
				if not ally.can_attack():
					biggest = maxi(biggest, ally.attack)
			return float(biggest) * RUSH_VALUE
		CardEnums.EffectType.REFRESH_ATTACK:
			return REFRESH_VALUE
	return 0.0
