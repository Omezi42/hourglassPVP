extends RefCounted
## 誘導対局の台本(`TutorialScriptData`、GameDesign.md 18章)の検証。
## 8段すべての操作が単純な貪欲手で巡ってきて、プレイヤーが勝つことを確かめる
## (Architecture.md 4.1.5節「成立は自動テストが確かめる」)。プールの調整で
## 台本が崩れていないかをここで検知する。

## 反転権を使う閾値(段階7)。相手の駒の攻撃力がこれ以上になるまでは温存する
## (序盤の攻撃力0の駒に無駄撃ちしないため)。
const FLIP_RIGHT_ATTACK_THRESHOLD := 3
const MAX_TURNS_TO_FINISH := 40

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_script_reaches_every_stage_and_player_wins()


func _test_script_reaches_every_stage_and_player_wins() -> void:
	var script: TutorialScriptData = load("res://resources/tutorial/tutorial_script.tres")
	var state := MatchState.new()
	state.keep_deck_order = true
	state.start_match(
		script.deck_a(), script.deck_b(), MatchState.Side.A, 1, MatchState.COIN_ENABLED, true
	)
	var cpu := CardCpuStrategy.new()
	cpu.difficulty = CardCpuStrategy.Difficulty.BEGINNER
	cpu._rng.seed = 7

	var reached := {
		"play": false,
		"end_turn": false,
		"attack_unit": false,
		"attack_face": false,
		"flip": false,
		"flip_right": false,
	}
	var guard_seen_turn := -1
	var attack_unit_turn := -1
	var attack_face_turn := -1

	# 段階0(マリガン):そのまま始める(GameDesign.md 18章「そのまま始めてもいい」)。
	state.mulligan(MatchState.Side.A, [])
	state.mulligan(MatchState.Side.B, [])

	var turns := 0
	while not state.is_match_over() and turns < MAX_TURNS_TO_FINISH:
		turns += 1
		if state.current_turn == MatchState.Side.B:
			cpu.take_turn(state, MatchState.Side.B)
			if guard_seen_turn < 0 and _foe_has_guard(state):
				guard_seen_turn = turns
			continue
		_play_greedy_turn(state, reached)
		if reached["attack_unit"] and attack_unit_turn < 0:
			attack_unit_turn = turns
		if reached["attack_face"] and attack_face_turn < 0:
			attack_face_turn = turns

	_assert.call(
		state.is_match_over(), "the script should finish within %d turns" % MAX_TURNS_TO_FINISH
	)
	_assert.call(
		state.winner == MatchState.Side.A, "the player should win the scripted tutorial match"
	)
	for key: String in reached:
		_assert.call(
			bool(reached[key]), "stage '%s' should become possible during the scripted match" % key
		)
	_assert.call(
		attack_unit_turn > 0 and attack_face_turn > 0 and attack_unit_turn < attack_face_turn,
		"attacking a unit (stage 4) should be reachable before attacking the face (stage 5)"
	)
	_assert.call(
		guard_seen_turn < 0 or guard_seen_turn > attack_face_turn,
		"the foe should not reveal a guard unit before stage 5 (attacking the face) is done"
	)


func _foe_has_guard(state: MatchState) -> bool:
	for slot in MatchState.BOARD_SIZE:
		var unit: CardInstance = state.board[MatchState.Side.B][slot]
		if unit != null and unit.has_keyword(CardEnums.Keyword.GUARD):
			return true
	return false


## プレイヤー側の1手番。「攻撃してから反転する」ではなく、8段の操作が単純な優先順位
## (反転権 → 反転 → 攻撃 → 出す)で貪欲に選べることだけを確かめたいための単純な手。
func _play_greedy_turn(state: MatchState, reached: Dictionary) -> void:
	var side := MatchState.Side.A
	var foe := MatchState.Side.B
	var iterations := 0
	while iterations < 30:
		iterations += 1
		if int(state.flip_right_remaining.get(side, 0)) > 0:
			var flip_right_slot := _highest_attack_enemy_slot(state, foe)
			if flip_right_slot >= 0 and state.use_flip_right(side, foe, flip_right_slot):
				reached["flip_right"] = true
				continue
		var flip_slot := _flip_candidate(state, side)
		if flip_slot >= 0 and state.flip(side, flip_slot):
			reached["flip"] = true
			continue
		var attack_slot := _attack_candidate(state, side)
		if attack_slot >= 0:
			var target := _attack_target(state, side, foe, bool(reached["attack_unit"]))
			if target != -2 and state.attack(side, attack_slot, target):
				if target < 0:
					reached["attack_face"] = true
				else:
					reached["attack_unit"] = true
				continue
		var play_index := _cheapest_playable(state, side)
		if play_index >= 0:
			var empty: Array = state.empty_slots(side)
			var card: CardData = state.hand[side][play_index]
			if state.play_card(side, play_index, empty[0], _auto_target(state, side, card)):
				reached["play"] = true
				continue
		break
	state.end_turn()
	reached["end_turn"] = true


func _highest_attack_enemy_slot(state: MatchState, foe: int) -> int:
	var best_slot := -1
	var best_attack := -1
	for slot in MatchState.BOARD_SIZE:
		var unit: CardInstance = state.board[foe][slot]
		if unit == null or not unit.flippable():
			continue
		if unit.attack > best_attack:
			best_attack = unit.attack
			best_slot = slot
	if best_attack < FLIP_RIGHT_ATTACK_THRESHOLD:
		return -1
	return best_slot


func _flip_candidate(state: MatchState, side: int) -> int:
	for slot in MatchState.BOARD_SIZE:
		var unit: CardInstance = state.board[side][slot]
		if unit != null and unit.attack > unit.health and state.can_flip(side, slot):
			return slot
	return -1


func _attack_candidate(state: MatchState, side: int) -> int:
	for slot in MatchState.BOARD_SIZE:
		var unit: CardInstance = state.board[side][slot]
		if unit != null and unit.can_attack():
			return slot
	return -1


## 駒攻撃(段階4)がまだ済んでいなければ駒を狙う。済んでいれば本体を狙う。
## どちらも選べなければ -2 を返し、呼び出し側はこの攻撃を諦める。
func _attack_target(state: MatchState, side: int, foe: int, unit_stage_done: bool) -> int:
	var options: Array = state.attackable_slots(foe)
	if not unit_stage_done and not options.is_empty():
		return options[0]
	if state.can_attack_player(side):
		return -1
	if not options.is_empty():
		return options[0]
	return -2


func _cheapest_playable(state: MatchState, side: int) -> int:
	var hand: Array = state.hand[side]
	var best_index := -1
	var best_cost := 999
	for i in hand.size():
		var card: CardData = hand[i]
		if card.is_spell or not state.can_play(side, i):
			continue
		if card.cost < best_cost:
			best_cost = card.cost
			best_index = i
	return best_index


func _auto_target(state: MatchState, side: int, card: CardData) -> Dictionary:
	var foe := MatchState.other_side(side)
	for effect: CardEffectData in card.effects_for(CardEnums.Trigger.ON_PLAY):
		if effect.target == CardEnums.EffectTarget.ENEMY_UNIT:
			for slot in MatchState.BOARD_SIZE:
				if state.board[foe][slot] != null:
					return {"side": foe, "slot": slot}
		elif effect.target == CardEnums.EffectTarget.ALLY_UNIT:
			for slot in MatchState.BOARD_SIZE:
				if state.board[side][slot] != null:
					return {"side": side, "slot": slot}
	return {}
