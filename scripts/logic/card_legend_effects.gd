class_name CardLegendEffects
extends RefCounted
## 第1弾のレジェンドの固有効果(GameDesign.md 6章「第1弾のレジェンドの固有効果」)。
## `CardEffectResolver` が1000行の上限に近いため、1枚にしか無い効果の解決とCPUの見積もりをここへ切り出す。
## 紋章を知らせる・対象を並べる・墓地から出す処理は `CardEffectResolver` のものを使う(同じ物差しにするため)。

const TYPES := [
	CardEnums.EffectType.DESTROY_RANDOM_BY_EXCESS,
	CardEnums.EffectType.SET_TOTAL,
	CardEnums.EffectType.DROP_SAND_TO_ONE,
	CardEnums.EffectType.RAISE_ALL_SAND,
	CardEnums.EffectType.REVIVE_RANDOM_ALL,
]
## 総量を合わせても体力はこれ未満にしない(効果で自分の駒を砕かないため)。
const MIN_HEALTH := 1

var _state: MatchState
var _resolver: CardEffectResolver


func _init(state: MatchState, resolver: CardEffectResolver) -> void:
	_state = state
	_resolver = resolver


static func handles(effect_type: int) -> bool:
	return TYPES.has(effect_type)


func apply(
	side: int, unit: CardInstance, effect: CardEffectData, from_slot: int, origin: int, hint := {}
) -> void:
	match effect.effect_type:
		CardEnums.EffectType.DESTROY_RANDOM_BY_EXCESS:
			_destroy_excess(side, from_slot, origin)
		CardEnums.EffectType.SET_TOTAL:
			_set_total(side, unit, effect, from_slot, origin)
		CardEnums.EffectType.DROP_SAND_TO_ONE:
			_drop_to_one(side, unit, effect, from_slot, origin, hint)
		CardEnums.EffectType.RAISE_ALL_SAND:
			_raise_all(side, unit, effect, from_slot, origin, hint)
		CardEnums.EffectType.REVIVE_RANDOM_ALL:
			_revive_all(side, from_slot, origin)


## 相手の駒が自分(この駒を含む)より多いぶん。0以下なら破壊しない。
static func excess(state: MatchState, side: int) -> int:
	return state.units(MatchState.other_side(side)).size() - state.units(side).size()


func _destroy_excess(side: int, from_slot: int, origin: int) -> void:
	var foe_side := MatchState.other_side(side)
	var count := excess(_state, side)
	var pool: Array = []
	for slot in MatchState.BOARD_SIZE:
		var foe: CardInstance = _state.board[foe_side][slot]
		if foe != null and not foe.is_dead():
			pool.append({"side": foe_side, "slot": slot})
	var picked: Array = []
	while count > 0 and not pool.is_empty():
		picked.append(pool.pop_at(_state._rng.randi_range(0, pool.size() - 1)))
		count -= 1
	if picked.is_empty():
		return
	picked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["slot"] < b["slot"])
	_resolver._strike_many(side, from_slot, picked, CardEnums.EffectVisualStyle.STRIKE, origin)
	for entry: Dictionary in picked:
		_state.destroy_unit(entry["side"], entry["slot"])


func _set_total(
	side: int, unit: CardInstance, effect: CardEffectData, from_slot: int, origin: int
) -> void:
	var entries: Array = []
	for entry: Dictionary in _resolver._targets(side, unit, effect, {}):
		var target := _resolver._unit_at(entry)
		if target != unit and target.total_sand() != effect.value:
			entries.append(entry)
	_resolver._strike_many(side, from_slot, entries, CardEnums.EffectVisualStyle.DESCEND, origin)
	for entry: Dictionary in entries:
		set_total(_resolver._unit_at(entry), effect.value)


## 総量を `total` にする。差は体力で埋め、体力が1未満になるぶんは攻撃力から引く。
static func set_total(unit: CardInstance, total: int) -> void:
	unit.health += total - unit.total_sand()
	if unit.health < MIN_HEALTH:
		unit.attack -= MIN_HEALTH - unit.health
		unit.health = MIN_HEALTH


func _drop_to_one(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	from_slot: int,
	origin: int,
	hint: Dictionary
) -> void:
	var entries: Array = []
	for entry: Dictionary in _resolver._targets(side, unit, effect, hint):
		if _resolver._unit_at(entry).health > MIN_HEALTH:
			entries.append(entry)
	_resolver._strike_many(side, from_slot, entries, CardEnums.EffectVisualStyle.STRIKE, origin)
	for entry: Dictionary in entries:
		var target := _resolver._unit_at(entry)
		target.drop_sand(target.health - MIN_HEALTH)


func _raise_all(
	side: int, unit: CardInstance, effect: CardEffectData, from_slot: int, origin: int, hint := {}
) -> void:
	var entries: Array = []
	for entry: Dictionary in _resolver._targets(side, unit, effect, hint):
		if _resolver._unit_at(entry).attack > 0:
			entries.append(entry)
	_resolver._strike_many(side, from_slot, entries, CardEnums.EffectVisualStyle.DRAIN, origin)
	for entry: Dictionary in entries:
		var target := _resolver._unit_at(entry)
		var moved := target.raise_sand(target.attack)
		_state.unit_raised.emit(entry["side"], entry["slot"], moved)


## 空き枠を左から埋める。出す砂時計は墓地の選べるもの(目覚めの砂と同じ)からランダムに選ぶ。
func _revive_all(side: int, from_slot: int, origin: int) -> void:
	var plan: Array = []
	var taken: Array[int] = []
	for slot in MatchState.BOARD_SIZE:
		if _state.board[side][slot] != null:
			continue
		var choices: Array[int] = []
		for index in CardEffectResolver.grave_choices(_state, side):
			if not taken.has(index):
				choices.append(index)
		if choices.is_empty():
			break
		var index := choices[_state._rng.randi_range(0, choices.size() - 1)]
		taken.append(index)
		plan.append({"side": side, "slot": slot, "card": _state.graveyard[side][index]})
	if plan.is_empty():
		return
	_resolver._strike_many(side, from_slot, plan, CardEnums.EffectVisualStyle.PULSE, origin)
	for entry: Dictionary in plan:
		var index: int = _state.graveyard[side].find(entry["card"])
		_resolver._revive(side, index, entry["slot"])


## CPUの見積もり(`CardCpuStrategy._on_play_value()`)。置く前の盤面で数える。
static func cpu_value(state: MatchState, side: int, effect: CardEffectData) -> float:
	var foe_side := MatchState.other_side(side)
	var value := 0.0
	match effect.effect_type:
		CardEnums.EffectType.DESTROY_RANDOM_BY_EXCESS:
			# 置いた後は自分の駒が1体増える。壊れる駒は選べないため相手の駒の平均で見る。
			var foes := state.units(foe_side)
			var count := mini(foes.size() - state.units(side).size() - 1, foes.size())
			if count > 0:
				for foe: CardInstance in foes:
					value += float(foe.lifetime_damage()) * count / foes.size()
		CardEnums.EffectType.SET_TOTAL:
			for ally: CardInstance in state.units(side):
				value += float(effect.value - ally.total_sand()) * 2.0
		CardEnums.EffectType.DROP_SAND_TO_ONE:
			for foe: CardInstance in state.units(foe_side):
				var before := float(foe.lifetime_damage())
				value += (
					before - CardCpuStrategy.lifetime_of(MIN_HEALTH, foe.total_sand() - MIN_HEALTH)
				)
		CardEnums.EffectType.RAISE_ALL_SAND:
			for foe: CardInstance in state.units(foe_side):
				value += float(foe.attack) * CardCpuStrategy.FACE_WEIGHT
		CardEnums.EffectType.REVIVE_RANDOM_ALL:
			var room := MatchState.BOARD_SIZE - state.units(side).size() - 1
			var choices := CardEffectResolver.grave_choices(state, side)
			var revived := mini(room, choices.size())
			for index in choices:
				var card: CardData = state.graveyard[side][index]
				value += float(card.total_sand) * revived / choices.size()
	return value
