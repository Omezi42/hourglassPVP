class_name CardExchangeEffects
extends RefCounted
## 第3弾テーマ外のレジェンドの固有効果(Hourglasses.md「第3弾 テーマ外のレジェンド」)。
## 場の砂時計を敵味方すべて入れ替える(ミラージュ)・自分と相手のHPを入れ替える(ヤヌス)。
## 駒の入れ替えは寝返りの刻の奪う決まり(`CardTurncoatEffects.mark_moved`)を両側へ同時に当てる。

const TYPES := [
	CardEnums.EffectType.SWAP_ALL_UNITS,
	CardEnums.EffectType.SWAP_PLAYER_HP,
]

var _state: MatchState
var _resolver: CardEffectResolver


func _init(state: MatchState, resolver: CardEffectResolver) -> void:
	_state = state
	_resolver = resolver


static func handles(effect_type: int) -> bool:
	return TYPES.has(effect_type)


func apply(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	_hint: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	match effect.effect_type:
		CardEnums.EffectType.SWAP_ALL_UNITS:
			_swap_units(side, unit, from_slot, origin)
		CardEnums.EffectType.SWAP_PLAYER_HP:
			_swap_hp(side, from_slot, origin)


## この駒を除く、場の砂時計を敵味方すべて入れ替える。入る枠が足りないぶんは左から順に入る数だけ動き、残りはその場に残る。
func _swap_units(side: int, keeper: CardInstance, from_slot: int, origin: int) -> void:
	var foe_side := MatchState.other_side(side)
	var keeper_slot := _resolver._slot_of(side, keeper)
	var own_slots := _unit_slots(side, keeper_slot)
	var foe_slots := _unit_slots(foe_side, -1)
	# 自分の場へ入れる枠は、動かない駒(ミラージュ)の枠以外。相手の場も、動かない駒が残るぶんだけ減る。
	var own_room := MatchState.BOARD_SIZE - (_state.units(side).size() - own_slots.size())
	var foe_movers := foe_slots.slice(0, own_room)
	var foe_room := MatchState.BOARD_SIZE - (foe_slots.size() - foe_movers.size())
	var own_movers := own_slots.slice(0, foe_room)
	var entries: Array = []
	for slot: int in own_movers:
		entries.append({"side": side, "slot": slot})
	for slot: int in foe_movers:
		entries.append({"side": foe_side, "slot": slot})
	if entries.is_empty():
		return
	_resolver._strike_many(side, from_slot, entries, CardEnums.EffectVisualStyle.SPIN, origin)
	var own_units := _lift(side, own_movers)
	var foe_units := _lift(foe_side, foe_movers)
	_land(foe_side, side, foe_units)
	_land(side, foe_side, own_units)
	_state._refresh_held_keywords()
	_state.board_changed.emit(side)
	_state.board_changed.emit(foe_side)


## side の場の駒がいる枠(左から)。`except` の枠は含めない。
func _unit_slots(side: int, except: int) -> Array[int]:
	var found: Array[int] = []
	for slot in MatchState.BOARD_SIZE:
		if slot != except and _state.board[side][slot] != null:
			found.append(slot)
	return found


## 枠の駒を場から外して返す。
func _lift(side: int, slots: Array) -> Array[CardInstance]:
	var lifted: Array[CardInstance] = []
	for slot: int in slots:
		lifted.append(_state.board[side][slot])
		_state.board[side][slot] = null
	return lifted


## 駒を to_side の空き枠へ左から置く。持ち主は変わらず、置かれた駒はその手番は攻撃も反転もできない。
func _land(from_side: int, to_side: int, units: Array[CardInstance]) -> void:
	for moved in units:
		var empty := _state.empty_slots(to_side)
		_state.board[to_side][empty[0]] = moved
		CardTurncoatEffects.mark_moved(moved, from_side, to_side, false)


## 自分と相手のHPを入れ替える。回復でもダメージでもないため、吸命・被弾・HPを失うたびの効果は働かない。
## 最大HPを超える側は最大HPで止める(最大HPが同じ通常の対局では起きない)。
func _swap_hp(side: int, from_slot: int, origin: int) -> void:
	var foe_side := MatchState.other_side(side)
	_resolver._strike(side, from_slot, foe_side, -1, CardEnums.EffectVisualStyle.SPIN, origin)
	var own_hp: int = _state.hp[side]
	var foe_hp: int = _state.hp[foe_side]
	_state.hp[side] = mini(foe_hp, int(_state.hp_max.get(side, MatchState.INITIAL_HP)))
	_state.hp[foe_side] = mini(own_hp, int(_state.hp_max.get(foe_side, MatchState.INITIAL_HP)))
	_state.hp_changed.emit(side, _state.hp[side])
	_state.hp_changed.emit(foe_side, _state.hp[foe_side])
	_state._refresh_held_keywords()


## CPUの見積もり。駒の入れ替えは、相手から来る駒の生涯ダメージから出ていく自分の駒の生涯ダメージを引いた差。
## HPの入れ替えは、相手のHPが自分より多いぶんだけ得(少なければ負)。
static func cpu_value(state: MatchState, side: int, effect: CardEffectData) -> float:
	var foe_side := MatchState.other_side(side)
	if effect.effect_type == CardEnums.EffectType.SWAP_PLAYER_HP:
		return float(int(state.hp[foe_side]) - int(state.hp[side])) * CardCpuStrategy.FACE_WEIGHT
	var gain := 0.0
	for foe: CardInstance in state.units(foe_side):
		gain += float(foe.lifetime_damage())
	# 出す前の盤面で数える(ミラージュ自身は動かない)。
	for own: CardInstance in state.units(side):
		gain -= float(own.lifetime_damage())
	return gain
