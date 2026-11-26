class_name CardTurncoatEffects
extends RefCounted
## 第3弾「寝返りの刻」の固有効果(GameDesign.md 6章「相手の駒を奪う効果」)。
## 相手の砂時計を自分の場へ移す・このターンだけ借りる・相手の駒どうしを戦わせる・持ち場を入れ替える。
## 駒の持ち主の移動は `CardInstance.owner_side`(カードの元の持ち主)と場の側(いまの持ち主)で分けて持つ。

const TYPES := [
	CardEnums.EffectType.SEIZE_UNIT,
	CardEnums.EffectType.SEIZE_UNIT_FOR_TURN,
	CardEnums.EffectType.FORCE_FOE_ATTACK,
	CardEnums.EffectType.SWAP_SIDE_WITH_FOE,
]
## 攻撃させる駒に求める攻撃力の下限(攻撃力0の駒は攻撃させない)。
const MIN_ATTACKER_ATTACK := 1
## CPUの見積もり。奪った駒は相手から消えて自分に付くため、その生涯ダメージの何倍で数えるか。
const SEIZE_FACTOR := 1.6
## このターンだけ借りた駒が殴る攻撃力1点の値打ち。
const LOAN_ATTACK_VALUE := 1.5
## 同士討ちで相手の駒へ入る砂1粒の値打ち。ランダムなときは当たりを見込んで割り引く。
const CLASH_VALUE := 1.0
const RANDOM_CLASH_DISCOUNT := 0.5
## 持ち場を入れ替えるとき、差し出す駒の生涯ダメージの見込み(トレイターは小さい駒)。
const TRAITOR_GIVEN_LIFETIME := 3.0

var _state: MatchState
var _resolver: CardEffectResolver


func _init(state: MatchState, resolver: CardEffectResolver) -> void:
	_state = state
	_resolver = resolver


static func handles(effect_type: int) -> bool:
	return TYPES.has(effect_type)


## カードの持ち主(墓地・手札へ行く先)。奪われていなければ場の側(`board_side`。`CardInstance` は公開メソッドの上限に達しているためここに置く)。
static func card_owner(unit: CardInstance, board_side: int) -> int:
	return board_side if unit.owner_side < 0 else unit.owner_side


## 奪われている駒か(`board_side` はいま場にいる側)。
static func is_seized(unit: CardInstance, board_side: int) -> bool:
	return unit.owner_side >= 0 and unit.owner_side != board_side


## 相手の砂時計の数が、この駒を含む自分の砂時計の数より condition_total 以上多いか(ディフェクト)。
## `own_includes_self` が偽なら、この駒はまだ場にいない(CPUが置く前に見積もる)として数える。
static func leads_met(
	state: MatchState, side: int, effect: CardEffectData, own_includes_self := true
) -> bool:
	if effect.condition_scope != CardEnums.ConditionScope.ENEMY_LEADS_BY:
		return true
	var own := state.units(side).size() + (0 if own_includes_self else 1)
	return state.units(MatchState.other_side(side)).size() - own >= effect.condition_total


## 撃てる砂術か。同士討ちは、別の2体がいて攻撃力1以上の駒がいるときだけ撃てる。
static func castable(state: MatchState, side: int, effect: CardEffectData) -> bool:
	if effect.effect_type != CardEnums.EffectType.FORCE_FOE_ATTACK or effect.random_target:
		return true
	var foes := state.units(MatchState.other_side(side))
	return (
		foes.size() >= 2
		and foes.any(func(foe: CardInstance) -> bool: return foe.attack >= MIN_ATTACKER_ATTACK)
	)


## 駒を from_side の from_slot から to_side の空き枠の左へ移す。移した先の枠を返す(空き枠が無ければ -1)。
## 奪った手番は攻撃も反転もできない(出したばかりの駒と同じ)。`for_turn` なら攻撃・反転でき、手番の終わりに返る。
static func seize(
	state: MatchState, to_side: int, from_side: int, from_slot: int, for_turn := false
) -> int:
	var unit: CardInstance = state.board[from_side][from_slot]
	var empty := state.empty_slots(to_side)
	if unit == null or empty.is_empty():
		return -1
	state.board[from_side][from_slot] = null
	state.board[to_side][empty[0]] = unit
	_mark_moved(unit, from_side, to_side, for_turn)
	return empty[0]


## 場の側が変わった駒の印を直す。元の持ち主へ戻ったなら印は消える。
static func _mark_moved(unit: CardInstance, from_side: int, to_side: int, for_turn: bool) -> void:
	if unit.owner_side < 0:
		unit.owner_side = from_side
	if unit.owner_side == to_side:
		unit.owner_side = -1
	unit.loaned = for_turn
	unit.summoned_this_turn = not for_turn
	unit.flipped_this_turn = false
	unit.attacks_this_turn = 0


## 手番の終わり(落砂の後)に、このターンだけ借りた駒を元の持ち主の空き枠の左へ返す。枠が無ければ破壊する。
static func return_loaned(state: MatchState, side: int) -> void:
	for slot in MatchState.BOARD_SIZE:
		var unit: CardInstance = state.board[side][slot]
		if unit == null or not unit.loaned or unit.is_dead():
			continue
		var home := unit.owner_side
		if home < 0 or home == side:
			unit.loaned = false
			continue
		if seize(state, home, side, slot) < 0:
			state.destroy_unit(side, slot)
			continue
		unit.summoned_this_turn = false
	state.board_changed.emit(MatchState.other_side(side))


## 相手の駒どうしの戦闘。攻撃した扱いで、通常の戦闘と同じく相打ち・被弾・与ダメージの効果が働く(守護は無視する)。
static func clash(state: MatchState, side: int, attacker_slot: int, defender_slot: int) -> void:
	var attacker: CardInstance = state.board[side][attacker_slot]
	state._resolve_unit_combat(side, attacker_slot, defender_slot, side)
	state._cleanup_dead()
	state._fire_attacked(side, attacker)


func apply(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	match effect.effect_type:
		CardEnums.EffectType.SEIZE_UNIT:
			_seize(side, unit, effect, hint, from_slot, origin, false)
		CardEnums.EffectType.SEIZE_UNIT_FOR_TURN:
			_seize(side, unit, effect, hint, from_slot, origin, true)
		CardEnums.EffectType.FORCE_FOE_ATTACK:
			_force_attack(side, unit, effect, hint, from_slot, origin)
		CardEnums.EffectType.SWAP_SIDE_WITH_FOE:
			_swap_side(side, unit, effect, hint, from_slot, origin)


func _seize(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	from_slot: int,
	origin: int,
	for_turn: bool
) -> void:
	var entries := _live_entries(_resolver._targets(side, unit, effect, hint))
	# 攻撃力の高い順(同点は左の枠)に、空き枠の数まで。
	entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var attack_a: int = _resolver._unit_at(a).attack
			var attack_b: int = _resolver._unit_at(b).attack
			return attack_a > attack_b or (attack_a == attack_b and a["slot"] < b["slot"])
	)
	entries = entries.slice(0, _state.empty_slots(side).size())
	if entries.is_empty():
		return
	_resolver._strike_for_targets(
		side, from_slot, effect.target, entries, CardEnums.EffectVisualStyle.SPIN, origin
	)
	# 枠の番号は奪うたびに変わらない(奪った駒は自分の場へ移るだけで、相手の場の枠は詰まらない)。
	for entry: Dictionary in entries:
		seize(_state, side, entry["side"], entry["slot"], for_turn)
	_state.board_changed.emit(side)
	_state.board_changed.emit(MatchState.other_side(side))


func _live_entries(entries: Array) -> Array:
	return entries.filter(
		func(entry: Dictionary) -> bool: return not _resolver._unit_at(entry).is_dead()
	)


func _force_attack(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	var entries := _live_entries(_resolver._targets(side, unit, effect, hint))
	if entries.is_empty():
		return
	var foe_side: int = entries[0]["side"]
	var defender_slot: int = entries[0]["slot"]
	var attacker_slot := _attacker_slot(foe_side, defender_slot, effect.random_target)
	if attacker_slot < 0:
		return
	_resolver._strike(
		side, from_slot, foe_side, defender_slot, CardEnums.EffectVisualStyle.STRIKE, origin
	)
	clash(_state, foe_side, attacker_slot, defender_slot)


## 攻撃させる駒の枠。守る側以外で攻撃力が下限以上の駒から、ランダムなら引き、そうでなければ攻撃力がいちばん高い駒(同点は左)。
func _attacker_slot(foe_side: int, defender_slot: int, random_pick: bool) -> int:
	var candidates: Array[int] = []
	for slot in MatchState.BOARD_SIZE:
		var candidate: CardInstance = _state.board[foe_side][slot]
		if candidate == null or slot == defender_slot or candidate.is_dead():
			continue
		if candidate.attack >= MIN_ATTACKER_ATTACK:
			candidates.append(slot)
	if candidates.is_empty():
		return -1
	if random_pick:
		return candidates[_state._rng.randi_range(0, candidates.size() - 1)]
	var best: int = candidates[0]
	for slot in candidates:
		if _state.board[foe_side][slot].attack > _state.board[foe_side][best].attack:
			best = slot
	return best


func _swap_side(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	var entries := _live_entries(_resolver._targets(side, unit, effect, hint))
	var own_slot := _resolver._slot_of(side, unit)
	if entries.is_empty() or own_slot < 0:
		return
	var foe_side: int = entries[0]["side"]
	var foe_slot: int = entries[0]["slot"]
	var foe: CardInstance = _state.board[foe_side][foe_slot]
	_resolver._strike(side, from_slot, foe_side, foe_slot, CardEnums.EffectVisualStyle.SPIN, origin)
	_state.board[side][own_slot] = foe
	_state.board[foe_side][foe_slot] = unit
	_mark_moved(foe, foe_side, side, false)
	_mark_moved(unit, side, foe_side, false)
	_state.board_changed.emit(side)
	_state.board_changed.emit(foe_side)


## CPUの見積もり(`CardCpuStrategy._themed_value()` から)。奪える駒・同士討ちで削れる砂は、いま場にいる相手の駒で数える。
static func cpu_value(state: MatchState, side: int, effect: CardEffectData) -> float:
	var foe_side := MatchState.other_side(side)
	match effect.effect_type:
		CardEnums.EffectType.SEIZE_UNIT:
			return _seize_value(state, side, effect)
		CardEnums.EffectType.SEIZE_UNIT_FOR_TURN:
			var strongest := 0
			for foe: CardInstance in state.units(foe_side):
				strongest = maxi(strongest, foe.attack)
			return float(strongest) * LOAN_ATTACK_VALUE
		CardEnums.EffectType.FORCE_FOE_ATTACK:
			return _clash_value(state, foe_side, effect)
		CardEnums.EffectType.SWAP_SIDE_WITH_FOE:
			var biggest := 0.0
			for foe: CardInstance in state.units(foe_side):
				biggest = maxf(biggest, float(foe.lifetime_damage()))
			return maxf(biggest - TRAITOR_GIVEN_LIFETIME, 0.0) * SEIZE_FACTOR
	return 0.0


## 奪える駒の生涯ダメージ。全体は攻撃力の高い順に空き枠の数まで足し、ランダムは候補の平均、単体はいちばん大きい駒。
static func _seize_value(state: MatchState, side: int, effect: CardEffectData) -> float:
	# 置く前の盤面で見積もる。出す駒自身の枠のぶんを1つ引く。
	var room := state.empty_slots(side).size() - 1
	var foes: Array = state.units(MatchState.other_side(side)).filter(
		func(foe: CardInstance) -> bool: return CardEffectResolver.eligible_target(foe, effect)
	)
	if room <= 0 or foes.is_empty():
		return 0.0
	var lifetimes: Array[float] = []
	foes.sort_custom(func(a: CardInstance, b: CardInstance) -> bool: return a.attack > b.attack)
	for foe: CardInstance in foes:
		lifetimes.append(float(foe.lifetime_damage()))
	var total := 0.0
	if effect.target == CardEnums.EffectTarget.ALL_ENEMY_UNITS:
		for lifetime in lifetimes.slice(0, room):
			total += lifetime
	elif effect.random_target:
		for lifetime in lifetimes:
			total += lifetime
		total /= float(lifetimes.size())
	else:
		total = lifetimes.max()
	return total * SEIZE_FACTOR


## 同士討ちで相手の駒へ入る砂。攻撃力がいちばん高い駒が、いちばん生涯ダメージの大きい別の駒を殴る見込み。
static func _clash_value(state: MatchState, foe_side: int, effect: CardEffectData) -> float:
	var foes := state.units(foe_side)
	var attacker: CardInstance = null
	for foe: CardInstance in foes:
		if foe.attack >= MIN_ATTACKER_ATTACK and (attacker == null or foe.attack > attacker.attack):
			attacker = foe
	if attacker == null:
		return 0.0
	var defender: CardInstance = null
	for foe: CardInstance in foes:
		if (
			foe != attacker
			and (defender == null or foe.lifetime_damage() > defender.lifetime_damage())
		):
			defender = foe
	if defender == null:
		return 0.0
	var dealt := mini(attacker.attack, defender.health) + mini(defender.attack, attacker.health)
	var value := float(dealt) * CLASH_VALUE
	return value * RANDOM_CLASH_DISCOUNT if effect.random_target else value
