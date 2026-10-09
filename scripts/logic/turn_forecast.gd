class_name TurnForecast
extends RefCounted
## 反転・ターン終了の予測(GameDesign.md 9章)。盤面を変えずに計算する。
## **落砂の効果は含めない**(砂の落下だけを数える)。数え方は `CardInstance.ticked()` に揃える。


## 反転した場合の値と、その後この手番の終わりに砂が落ちた値。
static func flip(state: MatchState, side: int, slot: int) -> Dictionary:
	var unit: CardInstance = state.board[side][slot]
	if unit == null:
		return {}
	var after := unit.ticked(unit.attack, unit.health, state.sand_drop_count)
	return {
		"health": unit.attack,
		"attack": unit.health,
		"health_after": after.x,
		"attack_after": after.y,
	}


## この手番の終わりに砂が落ちて割れる駒の枠。
static func doomed_slots(state: MatchState, side: int) -> Array[int]:
	var doomed: Array[int] = []
	for slot in MatchState.BOARD_SIZE:
		var unit: CardInstance = state.board[side][slot]
		if unit != null and unit.ticked(unit.health, unit.attack, state.sand_drop_count).x <= 0:
			doomed.append(slot)
	return doomed
