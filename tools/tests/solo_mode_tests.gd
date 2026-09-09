class_name SoloModeTests
extends RefCounted
## ソロモード(GameDesign.md 27章)がMatchStateへ足す4つの上書きプロパティの検証。
## Architecture.md 10.15節「既定値のままなら今までの全モードを一切変えない」を確かめる。

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_defaults_match_existing_behavior()
	_test_sand_drop_count_override_drops_extra_grains()
	_test_flip_disabled_blocks_normal_flip_but_not_flip_right()
	_test_clash_damage_multiplier_doubles_combat_damage()
	_test_mana_frozen_stops_the_max_mana_increase()
	_test_solo_progress_round_trips_and_reports_first_clear()
	_test_solo_library_unlock_depends_on_required_stages()


func _card(id: String) -> CardData:
	return CardLibrary.find_by_id(id)


func _deck_of(id: String) -> Array:
	var cards: Array = []
	for i in MatchState.DECK_SIZE:
		cards.append(_card(id))
	return cards


func _new_match() -> MatchState:
	var state := MatchState.new()
	state.start_match(_deck_of("sand"), _deck_of("sand"), MatchState.Side.A, 12345)
	return state


func _force_play(state: MatchState, side: int, id: String, slot: int) -> CardInstance:
	var previous_turn: int = state.current_turn
	state.current_turn = side
	state.hand[side].push_front(_card(id))
	state.mana[side] = MatchState.MAX_MANA
	state.play_card(side, 0, slot)
	state.current_turn = previous_turn
	return state.board[side][slot]


func _test_defaults_match_existing_behavior() -> void:
	var state := _new_match()
	_assert.call(state.sand_drop_count == 1, "sand_drop_count should default to 1")
	_assert.call(not state.flip_disabled, "flip_disabled should default to false")
	_assert.call(state.clash_damage_multiplier == 1, "clash_damage_multiplier should default to 1")
	_assert.call(not state.mana_frozen, "mana_frozen should default to false")


func _test_sand_drop_count_override_drops_extra_grains() -> void:
	var state := _new_match()
	var unit := _force_play(state, MatchState.Side.A, "sand", 0)
	state.sand_drop_count = 2
	state.end_turn()
	_assert.call(
		unit.health == 3 and unit.attack == 2,
		"sand_drop_count should move that many grains at turn end"
	)


func _test_flip_disabled_blocks_normal_flip_but_not_flip_right() -> void:
	var state := _new_match()
	var unit := _force_play(state, MatchState.Side.A, "sand", 0)
	unit.summoned_this_turn = false
	# 体力0で反転すると駒が壊れるため、先に砂を落として体力を残しておく。
	unit.drop_sand(2)
	state.flip_disabled = true
	_assert.call(
		not state.can_flip(MatchState.Side.A, 0), "flip_disabled should block the normal flip"
	)
	_assert.call(
		not state.flip(MatchState.Side.A, 0), "flip() should fail while flip_disabled is set"
	)
	state.flip_right_remaining[MatchState.Side.A] = 1
	_assert.call(
		state.use_flip_right(MatchState.Side.A, MatchState.Side.A, 0),
		"flip_disabled should not affect flip_right (GameDesign.md 27章)"
	)
	_assert.call(
		unit.health == 2 and unit.attack == 3, "flip_right should still swap health/attack"
	)


func _test_clash_damage_multiplier_doubles_combat_damage() -> void:
	var state := _new_match()
	var attacker := _force_play(state, MatchState.Side.A, "sand", 0)
	var defender := _force_play(state, MatchState.Side.B, "sand", 0)
	attacker.summoned_this_turn = false
	attacker.drop_sand(1)
	defender.drop_sand(1)
	# 体力4・攻撃1同士。倍率2なら互いに2ずつ砂が消える。
	state.clash_damage_multiplier = 2
	state.attack(MatchState.Side.A, 0, 0)
	_assert.call(
		attacker.health == 2 and attacker.attack == 1,
		"clash_damage_multiplier should double the damage the attacker takes back"
	)
	_assert.call(
		defender.health == 2 and defender.attack == 1,
		"clash_damage_multiplier should double the damage dealt to the defender"
	)


func _test_mana_frozen_stops_the_max_mana_increase() -> void:
	var state := _new_match()
	_assert.call(state.max_mana[MatchState.Side.A] == 1, "turn 1 should grant 1 mana as usual")
	state.mana_frozen = true
	state.end_turn()
	_assert.call(
		state.max_mana[MatchState.Side.B] == 0,
		"mana_frozen should stop the max mana increase on the next turn"
	)
	state.end_turn()
	_assert.call(
		state.max_mana[MatchState.Side.A] == 1,
		"mana_frozen should keep applying to later turns too"
	)


func _test_solo_progress_round_trips_and_reports_first_clear() -> void:
	SoloProgress.reset_for_test()
	_assert.call(
		not SoloProgress.is_cleared("", "stage_1"), "an unrecorded stage should not be cleared"
	)
	_assert.call(SoloProgress.mark_cleared("", "stage_1"), "the first clear should report true")
	_assert.call(SoloProgress.is_cleared("", "stage_1"), "the clear should be recorded")
	_assert.call(
		not SoloProgress.mark_cleared("", "stage_1"),
		"clearing the same stage again should not report a first clear"
	)
	_assert.call(SoloProgress.cleared_count("") == 1, "only one stage should be recorded")


func _test_solo_library_unlock_depends_on_required_stages() -> void:
	SoloProgress.reset_for_test()
	var first := SoloStageData.new()
	first.id = "solo_test_1"
	var second := SoloStageData.new()
	second.id = "solo_test_2"
	second.requires = ["solo_test_1"]
	_assert.call(
		SoloLibrary.is_unlocked(first, ""), "a stage without prerequisites should be unlocked"
	)
	_assert.call(
		not SoloLibrary.is_unlocked(second, ""),
		"a stage should stay locked until its prerequisites are cleared"
	)
	SoloProgress.mark_cleared("", "solo_test_1")
	_assert.call(
		SoloLibrary.is_unlocked(second, ""),
		"clearing the prerequisite should unlock the next stage"
	)
