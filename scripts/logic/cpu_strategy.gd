class_name CpuStrategy
extends RefCounted


## 現在の局面における合法手をすべて列挙する(反転・移動・交代)。
## 将来より強い思考ロジック(各合法手を評価してスコアの高い手を選ぶ等)を実装する際も
## この列挙をそのまま再利用できるよう、生成ロジックをここに集約する。
static func legal_actions(state: GameState, side: GameState.PlayerSide) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var opponent: GameState.PlayerSide = state.other_side(side)

	for position in range(GameState.BOARD_SIZE):
		if not _is_locked(state, side, position):
			actions.append({"type": "flip", "actor": side, "side": side, "position": position})
		if not _is_locked(state, opponent, position):
			actions.append({"type": "flip", "actor": side, "side": opponent, "position": position})

	for pair in [[0, 1], [0, 2], [1, 2]]:
		actions.append({"type": "move", "side": side, "from": pair[0], "to": pair[1]})

	for bench_index in range(GameState.BENCH_SIZE):
		actions.append({"type": "swap_in", "side": side, "bench_index": bench_index})

	actions.append({"type": "pass", "side": side})

	return actions


## 1手を選択する。サブクラスでオーバーライドし、より強い思考ロジックに差し替える。
func choose_action(_state: GameState, _side: GameState.PlayerSide) -> Dictionary:
	push_error("CpuStrategy.choose_action() must be overridden by a subclass")
	return {}


## 初期配置(場3個・控え2個)を選択する。サブクラスでオーバーライド可能。
## 戻り値: {"board": Array[HourglassData], "bench": Array[HourglassData]}
func choose_placement(deck: Array[HourglassData]) -> Dictionary:
	var shuffled := deck.duplicate()
	shuffled.shuffle()
	return {
		"board": shuffled.slice(0, GameState.BOARD_SIZE),
		"bench": shuffled.slice(GameState.BOARD_SIZE, deck.size()),
	}


static func _is_locked(state: GameState, side: GameState.PlayerSide, position: int) -> bool:
	if state.effect_resolver == null:
		return false
	return state.effect_resolver.is_locked(state, side, position)
