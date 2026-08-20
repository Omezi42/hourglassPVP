class_name RandomCpuStrategy
extends CpuStrategy

## 合法手から一様ランダムに1手を選ぶ、CPUの初期実装。


func choose_action(state: GameState, side: GameState.PlayerSide) -> Dictionary:
	var actions := legal_actions(state, side)
	return actions[randi() % actions.size()]
