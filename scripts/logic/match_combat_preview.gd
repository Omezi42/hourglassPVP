class_name MatchCombatPreview
extends RefCounted
## 戦闘の予測。`MatchState` の行数を抑えるため切り出した(Architecture.md 10.8.6節)。


## 攻撃した場合に双方がどうなるかを、盤面を変えずに計算する(GameDesign.md 9章)。
## **戦闘は相打ちで、攻撃側も必ず削れる**ため、UIはこれを対象選択の間ずっと出す。
## 判定の順序は `MatchState._resolve_unit_combat()` と同じにすること(硝子→毒砂の順)。
static func compute(state: MatchState, side: int, slot: int, target_slot: int) -> Dictionary:
	var foe_side := MatchState.other_side(side)
	var attacker: CardInstance = state.board[side][slot]
	if attacker == null:
		return {}
	if target_slot < 0:
		return {
			"attacker_health": attacker.health,
			"attacker_dead": false,
			"target_health": state.hp[foe_side] - attacker.attack,
			"target_dead": state.hp[foe_side] - attacker.attack <= 0,
			"pierce": 0,
		}
	var defender: CardInstance = state.board[foe_side][target_slot]
	if defender == null:
		return {}
	var attacker_power := attacker.attack * state.clash_damage_multiplier
	var defender_power := defender.attack * state.clash_damage_multiplier
	if attacker.has_keyword(CardEnums.Keyword.DAMAGE_BOOST):
		attacker_power *= 2
	if defender.has_keyword(CardEnums.Keyword.DAMAGE_BOOST):
		defender_power *= 2
	var to_defender := _preview_damage(defender, attacker_power)
	var to_attacker := _preview_damage(attacker, defender_power)
	var defender_health := defender.health - to_defender
	var attacker_health := attacker.health - to_attacker
	if to_defender > 0 and attacker.has_keyword(CardEnums.Keyword.POISON):
		defender_health = 0
	if to_attacker > 0 and defender.has_keyword(CardEnums.Keyword.POISON):
		attacker_health = 0
	var pierce := 0
	if to_defender > 0 and attacker.has_keyword(CardEnums.Keyword.PIERCE):
		pierce = maxi(attacker_power - defender.health, 0)
	return {
		"attacker_health": maxi(attacker_health, 0),
		"attacker_dead": attacker_health <= 0,
		"target_health": maxi(defender_health, 0),
		"target_dead": defender_health <= 0,
		"pierce": pierce,
	}


## 硝子が残っていれば最初の1回は通らない(`CardInstance.take_damage()` と同じ判定)。
static func _preview_damage(unit: CardInstance, amount: int) -> int:
	if amount <= 0:
		return 0
	return 0 if unit.glass_intact else amount


## `side` が本体へ `damage` を受けたとき、新しく越える刻み線の数(2章)。
## 相手に反転権を渡す損(CPUの評価)と、器の刻み目の予測(UI)の両方が読む。
static func new_tick_lines(state: MatchState, side: int, damage: int) -> int:
	var lost: int = int(state.hp_lost.get(side, 0)) + mini(damage, int(state.hp[side]))
	var reached := 0
	for line in state.hp_tick_lines:
		if lost >= line:
			reached += 1
	return reached - int(state.tick_lines_fired.get(side, 0))
