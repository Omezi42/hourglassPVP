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
	_test_solo_stages_form_a_single_path()
	_test_solo_stages_are_playable()
	_test_solo_puzzle_stages_are_solvable()


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


## v1のステージは1本道(GameDesign.md 27章)。**順番と前提が食い違うと、
## クリアしても次が開かない**という形でしか気づけないため、並びごと確かめる。
func _test_solo_stages_form_a_single_path() -> void:
	var stages := SoloLibrary.all_stages()
	_assert.call(stages.size() == 10, "v1 should ship ten solo stages")
	var seen := {}
	for i in stages.size():
		var stage := stages[i]
		_assert.call(not seen.has(stage.id), "solo stage ids must be unique: " + stage.id)
		seen[stage.id] = true
		_assert.call(stage.order == i + 1, "solo stage order should be 1..10: " + stage.id)
		_assert.call(not stage.display_name.is_empty(), "a solo stage needs a name: " + stage.id)
		_assert.call(stage.reward_gold > 0, "a solo stage must pay gold: " + stage.id)
		if i == 0:
			_assert.call(stage.requires.is_empty(), "the first stage must be open from the start")
		else:
			_assert.call(
				stage.requires == [stages[i - 1].id],
				"stage %s should require the one before it" % stage.id
			)
		if not stage.reward_card_set_id.is_empty():
			_assert.call(
				CardSetLibrary.has_set(stage.reward_card_set_id),
				"reward card set must exist: " + stage.reward_card_set_id
			)


## デッキ・盤面の中身が実際に読めること。カードidの打ち間違いはここで出る。
func _test_solo_stages_are_playable() -> void:
	for stage in SoloLibrary.all_stages():
		if stage.stage_type == SoloStageData.Kind.PUZZLE:
			_assert.call(stage.puzzle != null, "a puzzle stage needs a puzzle: " + stage.id)
			_check_units(stage.puzzle.own_units + stage.puzzle.foe_units, stage.id)
			for id in stage.puzzle.hand_ids:
				_assert.call(_card(id) != null, "hand card must exist: " + id)
			continue
		var config := stage.match_config
		_assert.call(config != null, "a match stage needs a config: " + stage.id)
		for deck: Array[String] in [config.player_deck_ids, config.opponent_deck_ids]:
			_assert.call(
				deck.size() == MatchState.DECK_SIZE,
				"a fixed deck must hold %d cards: %s" % [MatchState.DECK_SIZE, stage.id]
			)
			var counts := {}
			for id in deck:
				_assert.call(_card(id) != null, "deck card must exist: " + id)
				counts[id] = int(counts.get(id, 0)) + 1
				_assert.call(counts[id] <= 2, "a fixed deck may hold two copies at most: " + id)
		_check_units(config.own_board_units + config.foe_board_units, stage.id)
		if config.win_condition == SoloMatchConfig.WinCondition.SURVIVE_TURNS:
			_assert.call(config.survive_turns > 0, "a survival stage needs a target: " + stage.id)


## 盤面の1行が読めて、体力+攻撃力がそのカードの総量を超えていないこと。
## 超えていると、砂が落ちて出来上がるはずのない駒を出題してしまう。
func _check_units(rows: Array[String], stage_id: String) -> void:
	for row in rows:
		var parsed := PuzzleStageData.parse_unit(row)
		_assert.call(not parsed.is_empty(), "unit row must parse: %s (%s)" % [row, stage_id])
		if parsed.is_empty():
			continue
		var card: CardData = parsed["card"]
		var sand: int = int(parsed["health"]) + int(parsed["attack"])
		_assert.call(int(parsed["health"]) > 0, "a placed unit must be alive: " + row)
		_assert.call(
			sand <= card.total_sand, "a placed unit cannot hold more sand than its total: " + row
		)


## **パズル型は「解ける」ことまで確かめる**(リーサルパズルと同じ理由)。
## 手順は問題ごとの解答にあたる。
func _test_solo_puzzle_stages_are_solvable() -> void:
	# 第1問: 守護(体力3)をちょうど割れるのは攻撃力3のロックだけ。サンドやウォールで
	# 割ると余った打点がそのまま消え、本体へ13が届かない。
	var answers := {
		"solo_1": [["cast", 0], ["attack", 1, 0], ["attack", 0, -1], ["attack", 2, -1]],
		# 第3問: 砕砂を硝子のミラーへ撃つと膜に吸われて消える。守護のゲートを削り、
		# 弱ったところへ貫通を通して超過分を本体へ抜く。
		"solo_3": [["cast", 0, 1, 0], ["attack", 0, 0], ["attack", 1, -1]],
	}
	for stage in SoloLibrary.all_stages():
		if stage.stage_type != SoloStageData.Kind.PUZZLE:
			continue
		_assert.call(answers.has(stage.id), "no answer recorded for " + stage.id)
		if not answers.has(stage.id):
			continue
		_assert.call(
			PuzzleSolver.solve(stage.puzzle, answers[stage.id]),
			"solo puzzle should be solvable: " + stage.id
		)
