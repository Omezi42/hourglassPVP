class_name SoloBoonEffects
extends RefCounted
## 恩恵のうち対局の中で働くもの(GameDesign.md 27章「恩恵」の◆、Architecture.md 10.15節)。
##
## 山札の中身を変える恩恵は`modded_deck()`が写しへ当て、手番・反転・破壊に応じて働く恩恵は
## `attach()`で`MatchState`の信号へつなぐ。`MatchState`を持ち替えるたびに作り直す。
## ソロモードの自分の側にだけ当て、他のモードの経路は通らない。

var _state: MatchState
var _side := MatchState.Side.A
var _flip_damage := 0
var _death_damage := 0
var _first_turn_mana := 0
var _first_turn_done := false


## 小さな軍勢・重い砂を当てた山札を返す。**`CardData`は全モードで共有するため書き換えず、
## 当てるカードだけ写しを作る。**手札・詳細パネルはこの写しを読むため、変えたあとの値で出る。
static func modded_deck(cards: Array, run: SoloRun) -> Array:
	var boons := run.owned_boons()
	var result: Array = []
	for card: CardData in cards:
		result.append(_modded(card, boons))
	return result


## 急ぎの主: 砂時計へ速落を足した写しを返す(GameDesign.md 27章「主」)。
static func quick_deck(cards: Array) -> Array:
	var result: Array = []
	for card: CardData in cards:
		if card.is_spell or card.keywords.has(CardEnums.Keyword.QUICK):
			result.append(card)
			continue
		var copy: CardData = card.duplicate()
		var keywords := copy.keywords.duplicate()
		keywords.append(CardEnums.Keyword.QUICK)
		copy.keywords = keywords
		result.append(copy)
	return result


static func _modded(card: CardData, boons: Array[SoloBoonData]) -> CardData:
	if card.is_spell:
		return card
	var copy: CardData = null
	for boon in boons:
		if boon.small_total_bonus > 0 and card.cost <= boon.small_cost_max:
			copy = copy if copy != null else card.duplicate()
			copy.total_sand += boon.small_total_bonus
		if boon.heavy_cost_cut > 0 and card.cost >= boon.heavy_cost_min:
			copy = copy if copy != null else card.duplicate()
			copy.cost = maxi(copy.cost - boon.heavy_cost_cut, 0)
	return copy if copy != null else card


## 対局の開始直後(最初の自分の手番より前)に呼ぶ。反転権はここで足す。
func attach(state: MatchState, side: int, run: SoloRun) -> void:
	_state = state
	_side = side
	_flip_damage = run.boon_total("flip_damage")
	_death_damage = run.boon_total("death_damage")
	_first_turn_mana = run.boon_total("first_turn_mana")
	_first_turn_done = false
	var extra_rights := run.boon_total("extra_flip_rights")
	if extra_rights > 0:
		state.flip_right_remaining[side] = (
			int(state.flip_right_remaining.get(side, 0)) + extra_rights
		)
	if _flip_damage > 0:
		state.unit_flipped.connect(_on_unit_flipped)
		state.flip_right_used.connect(_on_flip_right_used)
	if _death_damage > 0:
		state.unit_destroyed.connect(_on_unit_destroyed)
	if _first_turn_mana > 0:
		state.turn_started.connect(_on_turn_started)
		# マリガンを挟まずに最初の手番が始まっていた場合も取りこぼさない。
		if state.turn_count > 0 and state.current_turn == side:
			_on_turn_started(side)


func _on_unit_flipped(side: int, _slot: int) -> void:
	if side == _side:
		_state.damage_player(MatchState.other_side(_side), _flip_damage)


func _on_flip_right_used(actor_side: int, target_side: int, _slot: int) -> void:
	if actor_side == _side and target_side == _side:
		_state.damage_player(MatchState.other_side(_side), _flip_damage)


func _on_unit_destroyed(side: int, _slot: int, _card: CardData) -> void:
	if side == _side:
		_state.damage_player(MatchState.other_side(_side), _death_damage)


func _on_turn_started(side: int) -> void:
	if side != _side or _first_turn_done:
		return
	_first_turn_done = true
	_state.mana[side] = int(_state.mana[side]) + _first_turn_mana
	_state.mana_changed.emit(side, _state.mana[side], _state.max_mana[side])
