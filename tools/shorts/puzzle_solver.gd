extends RefCounted
## とどめ問題の総当たりソルバー(撮影用の問題を選ぶためのオフライン専用)。
## 1手番のうちに指せる手(出す・撃つ・反転・反転権・攻撃)をすべて試し、局面が同じになった枝は
## まとめて数える。ゲーム本体のエンドレスは実行速度の都合で総当たりを採らない(Architecture.md
## 10.12.1節)が、撮影用の問題は手元で時間をかけて選べるため、実際のルール(`MatchState`)で解き切る。

const MINE := MatchState.Side.A
const FOE := MatchState.Side.B
## 最大打点を測るときの相手HP(途中で決着して探索が打ち切られないよう十分に大きく)。
const PROBE_HP := 999
const UNREACHABLE := 1 << 20

static var _var_cache := {}

## 探索した局面の数がこれを超えたら打ち切る(問題が大きすぎる)。
var node_budget := 60000
var nodes := 0
var aborted := false

var _min_hp := {}
var _win := {}


## 相手へ与えられる最大ダメージ。打ち切られたら -1。
func max_damage(stage: PuzzleStageData) -> int:
	var probe := stage.duplicate() as PuzzleStageData
	probe.foe_hp = PROBE_HP
	var state := build(probe)
	_min_hp.clear()
	nodes = 0
	aborted = false
	var reached := _min_foe_hp(state)
	state.free()
	return -1 if aborted else PROBE_HP - reached


## 相手HPを stage.foe_hp としたときの難しさ。
## p_random: 指せる手から毎回でたらめに選ぶ人が勝つ確率 / good_first: 勝ちに繋がる初手の数 /
## first: 初手の数 / min_len: 最短の手数 / solution: 最短の正解手順(MatchAction の配列)
func analyze(stage: PuzzleStageData) -> Dictionary:
	var state := build(stage)
	_win.clear()
	nodes = 0
	aborted = false
	var root := _solve(state)
	var result := {}
	if not aborted:
		var good_first := 0
		var first := 0
		for action in actions(state):
			var child := step(state, action)
			if child == null:
				continue
			first += 1
			if float(_solve(child)["p"]) > 0.0:
				good_first += 1
			child.free()
		result = {
			"p_random": root["p"],
			"good_first": good_first,
			"first": first,
			"min_len": root["len"],
			"solution": _line(state),
		}
	state.free()
	return result


func _line(state: MatchState) -> Array:
	var line: Array = []
	var current := clone(state)
	while int(current.hp[FOE]) > 0:
		var best: Dictionary = {}
		var best_len := UNREACHABLE
		for action in actions(current):
			var child := step(current, action)
			if child == null:
				continue
			var entry := _solve(child)
			if float(entry["p"]) > 0.0 and int(entry["len"]) < best_len:
				best_len = int(entry["len"])
				best = action
			child.free()
		if best.is_empty():
			break
		line.append(best)
		var next := step(current, best)
		current.free()
		current = next
	current.free()
	return line


func _min_foe_hp(state: MatchState) -> int:
	var key := key_of(state)
	if _min_hp.has(key):
		return _min_hp[key]
	nodes += 1
	var best := int(state.hp[FOE])
	if nodes > node_budget:
		aborted = true
		return best
	for action in actions(state):
		var child := step(state, action)
		if child == null:
			continue
		best = mini(best, _min_foe_hp(child))
		child.free()
	_min_hp[key] = best
	return best


func _solve(state: MatchState) -> Dictionary:
	if int(state.hp[FOE]) <= 0:
		return {"p": 1.0, "len": 0}
	var key := key_of(state)
	if _win.has(key):
		return _win[key]
	nodes += 1
	var p_sum := 0.0
	var count := 0
	var best_len := UNREACHABLE
	if nodes <= node_budget:
		for action in actions(state):
			var child := step(state, action)
			if child == null:
				continue
			var entry := _solve(child)
			p_sum += float(entry["p"])
			count += 1
			if float(entry["p"]) > 0.0:
				best_len = mini(best_len, int(entry["len"]) + 1)
			child.free()
	else:
		aborted = true
	var result := {"p": p_sum / count if count > 0 else 0.0, "len": best_len}
	_win[key] = result
	return result


# --- 局面 ---------------------------------------------------------------


## `CardMatchPuzzle._apply()` と同じ形の局面を作る(反転権・コインもゲームと同じ扱い)。
static func build(stage: PuzzleStageData) -> MatchState:
	var state := PuzzleGenerator._build_state(stage)
	state.coin_available[MINE] = false
	state.hand[FOE] = []
	return state


## 1手を適用した新しい局面。適用できない手なら null。
static func step(state: MatchState, action: Dictionary) -> MatchState:
	var child := clone(state)
	if not MatchAction.apply(child, action):
		child.free()
		return null
	return child


static func clone(src: MatchState) -> MatchState:
	var dst := MatchState.new()
	for name in _script_vars(src, ["_effects", "_rng", "deck", "graveyard"]):
		var value: Variant = src.get(name)
		if value is Dictionary or value is Array:
			value = value.duplicate(true)
		dst.set(name, value)
	dst.deck = {MINE: [], FOE: []}
	dst.graveyard = {MINE: [], FOE: []}
	for side in [MINE, FOE]:
		var slots: Array = dst.board[side]
		for i in slots.size():
			if slots[i] != null:
				slots[i] = _clone_unit(slots[i])
	return dst


static func _clone_unit(src: CardInstance) -> CardInstance:
	var dst := CardInstance.new(src.data)
	for name in _script_vars(src, ["data"]):
		var value: Variant = src.get(name)
		if value is Array:
			value = value.duplicate()
		dst.set(name, value)
	return dst


## 写す変数の名前(スクリプトごとに1度だけ調べる)。山札と墓地はこの1手番の結果に関わらないため写さない。
static func _script_vars(object: Object, skip: Array) -> Array:
	var script: Script = object.get_script()
	if _var_cache.has(script):
		return _var_cache[script]
	var names: Array = []
	for prop in object.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE and not skip.has(prop["name"]):
			names.append(prop["name"])
	_var_cache[script] = names
	return names


static func key_of(state: MatchState) -> String:
	var parts: PackedStringArray = [
		str(state.hp[MINE]),
		str(state.hp[FOE]),
		str(state.mana[MINE]),
		str(state.flip_right_remaining.get(MINE, 0)),
	]
	var hand_ids: PackedStringArray = []
	for card in state.hand[MINE]:
		hand_ids.append((card as CardData).id)
	hand_ids.sort()
	parts.append(",".join(hand_ids))
	for side in [MINE, FOE]:
		for unit in state.board[side]:
			if unit == null:
				parts.append("-")
				continue
			var u := unit as CardInstance
			(
				parts
				. append(
					(
						"%s:%d:%d:%d%d%d%d%d:%s"
						% [
							u.data.id,
							u.health,
							u.attack,
							int(u.summoned_this_turn),
							int(u.flipped_this_turn),
							u.attacks_this_turn,
							int(u.glass_intact),
							int(u.silenced),
							str(u.granted_keywords),
						]
					)
				)
			)
	return "|".join(parts)


## 自分の手番で指せる手の候補(適用できるかは `step()` が確かめる)。
## 同じカードが手札に2枚あれば1枚ぶんだけ、砂時計は最初の空き枠へだけ出す。
static func actions(state: MatchState) -> Array:
	var found: Array = []
	var hand: Array = state.hand[MINE]
	var seen := {}
	for i in hand.size():
		var card: CardData = hand[i]
		if seen.has(card.id):
			continue
		seen[card.id] = true
		if card.is_spell:
			if state.can_cast(MINE, i):
				for target in _targets(state, card):
					found.append(MatchAction.cast(MINE, i, target))
		elif state.can_play(MINE, i):
			var slot: int = state.empty_slots(MINE)[0]
			for target in _targets(state, card):
				found.append(MatchAction.play(MINE, i, slot, target))
	for slot in MatchState.BOARD_SIZE:
		var unit: CardInstance = state.board[MINE][slot]
		if unit == null:
			continue
		if state.can_flip(MINE, slot):
			found.append(MatchAction.flip(MINE, slot))
		if unit.can_attack():
			for target_slot in state.attackable_slots(FOE):
				found.append(MatchAction.attack(MINE, slot, target_slot))
			if state.can_attack_player(MINE):
				found.append(MatchAction.attack(MINE, slot, -1))
	if int(state.flip_right_remaining.get(MINE, 0)) > 0:
		for side in [MINE, FOE]:
			for slot in MatchState.BOARD_SIZE:
				if state.board[side][slot] != null:
					found.append(MatchAction.flip_right(MINE, side, slot))
	return found


static func _targets(state: MatchState, card: CardData) -> Array:
	for effect in card.effects:
		if effect.trigger != CardEnums.Trigger.ON_PLAY:
			continue
		var side := -1
		if effect.target == CardEnums.EffectTarget.ENEMY_UNIT:
			side = FOE
		elif effect.target == CardEnums.EffectTarget.ALLY_UNIT:
			side = MINE
		if side < 0:
			continue
		var targets: Array = []
		for slot in MatchState.BOARD_SIZE:
			if state.board[side][slot] != null:
				targets.append({"side": side, "slot": slot})
		if not targets.is_empty():
			return targets
	return [{}]
