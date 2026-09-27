class_name SoloModeTests
extends RefCounted
## 遠征(ソロモード。GameDesign.md 27章)の検証。`SoloRun`の規則を中心に、
## `MatchState`へ足した3つの上書きプロパティ(Architecture.md 10.15節)、
## `SoloProgress`の保存・記録、関門データの健全さを確かめる。

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_defaults_match_existing_behavior()
	_test_sand_drop_count_override_drops_extra_grains()
	_test_flip_disabled_blocks_normal_flip_but_not_flip_right()
	_test_clash_damage_multiplier_doubles_combat_damage()
	_test_solo_run_creates_a_fifteen_card_deck_one_of_each()
	_test_solo_run_route_follows_the_rules()
	_test_solo_run_cpu_decks_never_repeat_in_a_run()
	_test_solo_run_win_advances_and_builds_an_offer()
	_test_solo_run_offer_excludes_owned_pairs_solo_only_cards_and_tokens()
	_test_solo_run_take_and_pass_offer()
	_test_solo_run_loss_ends_the_run()
	_test_solo_run_clearing_the_final_floor_marks_cleared()
	_test_solo_run_round_trips_through_dict()
	_test_solo_progress_in_battle_run_counts_as_a_loss_on_load()
	_test_solo_progress_milestones_fire_once()
	_test_solo_progress_saves_finished_run_and_takes_it_once()
	_test_solo_progress_interrupted_run_saves_finished_with_abandon_reason()
	_test_solo_gates_load_and_reference_real_units()


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


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _test_defaults_match_existing_behavior() -> void:
	var state := _new_match()
	_assert.call(state.sand_drop_count == 1, "sand_drop_count should default to 1")
	_assert.call(not state.flip_disabled, "flip_disabled should default to false")
	_assert.call(state.clash_damage_multiplier == 1, "clash_damage_multiplier should default to 1")


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


func _test_solo_run_creates_a_fifteen_card_deck_one_of_each() -> void:
	var theme_id := CardCpuDecks.deck_ids()[0]
	var run := SoloRun.create(theme_id, _rng(1))
	_assert.call(run.deck_ids.size() == 15, "the starting deck should hold 15 cards")
	var seen := {}
	for id in run.deck_ids:
		_assert.call(not seen.has(id), "the starting deck should hold one of each card: " + id)
		seen[id] = true
	_assert.call(run.hp == MatchState.INITIAL_HP, "hp should start at MatchState.INITIAL_HP")
	_assert.call(run.floor == 0, "a fresh run should start at floor 0")


## 道の規則(GameDesign.md 27章「道」): 1〜5段目は2〜3個、各段には対局か関門が1つ以上、
## 泉は1段に1つまで・1段目には出さない。6段目は対局1つだけ。
func _test_solo_run_route_follows_the_rules() -> void:
	for trial in 8:
		var run := SoloRun.create(CardCpuDecks.deck_ids()[0], _rng(100 + trial))
		_assert.call(run.route.size() == SoloRun.FLOOR_COUNT, "the route should hold 6 floors")
		for floor_i in range(SoloRun.FLOOR_COUNT - 1):
			var options: Array = run.route[floor_i]
			_assert.call(
				options.size() >= 2 and options.size() <= 3,
				"floor %d should offer 2-3 destinations" % floor_i
			)
			var non_spring := 0
			var springs := 0
			for dest in options:
				var kind: int = int(dest["kind"])
				if kind == SoloRun.Kind.SPRING:
					springs += 1
				else:
					non_spring += 1
			_assert.call(non_spring >= 1, "floor %d needs a battle or gate" % floor_i)
			_assert.call(springs <= 1, "floor %d should offer at most one spring" % floor_i)
			if floor_i == 0:
				_assert.call(springs == 0, "the first floor should not offer a spring")
		var final_options: Array = run.route[SoloRun.FLOOR_COUNT - 1]
		_assert.call(final_options.size() == 1, "the final floor should offer one destination")
		_assert.call(
			int(final_options[0]["kind"]) == SoloRun.Kind.BATTLE,
			"the final floor's destination must be a battle"
		)


func _test_solo_run_cpu_decks_never_repeat_in_a_run() -> void:
	for trial in 8:
		var run := SoloRun.create(CardCpuDecks.deck_ids()[0], _rng(200 + trial))
		var used := {}
		for options in run.route:
			for dest in options:
				var deck_id := str(dest.get("cpu_deck", ""))
				if deck_id.is_empty():
					continue
				_assert.call(
					not used.has(deck_id),
					"a CPU deck should not appear twice in one run: " + deck_id
				)
				used[deck_id] = true


func _test_solo_run_win_advances_and_builds_an_offer() -> void:
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], _rng(3))
	run.choose(0, _rng(3))
	_assert.call(run.in_battle, "choosing a battle/gate destination should set in_battle")
	var was_gate := (
		int(run.active_destination().get("kind", SoloRun.Kind.BATTLE)) == SoloRun.Kind.GATE
	)
	run.finish_battle(true, 18, _rng(4))
	_assert.call(not run.in_battle, "finishing a battle should clear in_battle")
	_assert.call(run.wins == 1, "a win should increase wins")
	_assert.call(run.floor == 1, "a win should advance the floor")
	_assert.call(run.hp == 18, "hp should carry over from the battle")
	var expected_size := SoloRun.GATE_OFFER_SIZE if was_gate else SoloRun.OFFER_SIZE
	_assert.call(run.offer.size() == expected_size, "a win should offer the right number of cards")


func _test_solo_run_offer_excludes_owned_pairs_solo_only_cards_and_tokens() -> void:
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], _rng(5))
	# 山札を全カード2枚持ちにしておく(候補が「既に2枚あるカード」を外すことを確かめる)。
	run.deck_ids = run.deck_ids.duplicate()
	for id in run.deck_ids.duplicate():
		run.deck_ids.append(id)
	run.choose(0, _rng(5))
	run.finish_battle(true, 18, _rng(6))
	for id in run.offer:
		var count := 0
		for owned in run.deck_ids:
			if owned == id:
				count += 1
		_assert.call(
			count < SoloRun.MAX_DECK_COPIES, "the offer should not repeat an owned pair: " + id
		)
		var card := _card(id)
		_assert.call(card != null, "an offered card id should exist: " + id)
		_assert.call(not card.is_token, "the offer should not include a token: " + id)
		_assert.call(
			card.set_id.is_empty() or CardSetLibrary.price(card.set_id) > 0,
			"the offer should not include a price==0 set card: " + id
		)
	var seen := {}
	for id in run.offer:
		_assert.call(not seen.has(id), "the offer should not repeat a card: " + id)
		seen[id] = true


func _test_solo_run_take_and_pass_offer() -> void:
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], _rng(7))
	run.choose(0, _rng(7))
	run.finish_battle(true, 20, _rng(8))
	var offered := run.offer[0]
	var before := run.deck_ids.size()
	run.take(offered)
	_assert.call(run.deck_ids.size() == before + 1, "take() should add the card to the deck")
	_assert.call(run.offer.is_empty(), "take() should clear the offer")

	var run2 := SoloRun.create(CardCpuDecks.deck_ids()[1], _rng(9))
	run2.choose(0, _rng(9))
	run2.finish_battle(true, 20, _rng(10))
	var before2 := run2.deck_ids.size()
	run2.pass_offer()
	_assert.call(run2.deck_ids.size() == before2, "pass_offer() should not change the deck")
	_assert.call(run2.offer.is_empty(), "pass_offer() should clear the offer")


func _test_solo_run_loss_ends_the_run() -> void:
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], _rng(11))
	run.choose(0, _rng(11))
	run.finish_battle(false, 0, _rng(12))
	_assert.call(run.over, "a loss should end the run")
	_assert.call(not run.cleared, "a loss should not count as cleared")


func _test_solo_run_clearing_the_final_floor_marks_cleared() -> void:
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], _rng(13))
	while not run.over:
		var options := run.current_destinations()
		var index := 0
		for i in options.size():
			if int(options[i]["kind"]) != SoloRun.Kind.SPRING:
				index = i
				break
		run.choose(index, _rng(14))
		if run.in_battle:
			run.finish_battle(true, MatchState.INITIAL_HP, _rng(15))
			if not run.offer.is_empty():
				run.pass_offer()
	_assert.call(run.cleared, "winning every battle should clear the run")
	_assert.call(run.floor == SoloRun.FLOOR_COUNT, "a cleared run should reach the final floor")


func _test_solo_run_round_trips_through_dict() -> void:
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], _rng(16))
	run.choose(0, _rng(16))
	run.finish_battle(true, 20, _rng(17))
	var restored := SoloRun.from_dict(run.to_dict())
	_assert.call(restored.theme_id == run.theme_id, "from_dict should restore theme_id")
	_assert.call(restored.deck_ids == run.deck_ids, "from_dict should restore deck_ids")
	_assert.call(restored.hp == run.hp, "from_dict should restore hp")
	_assert.call(restored.floor == run.floor, "from_dict should restore floor")
	_assert.call(restored.wins == run.wins, "from_dict should restore wins")
	_assert.call(restored.offer == run.offer, "from_dict should restore offer")
	_assert.call(restored.route.size() == run.route.size(), "from_dict should restore the route")
	var kind: int = int(restored.route[0][0]["kind"])
	_assert.call(kind == int(run.route[0][0]["kind"]), "from_dict should restore route entry types")


func _test_solo_progress_in_battle_run_counts_as_a_loss_on_load() -> void:
	SoloProgress.reset_for_test()
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], _rng(18))
	run.choose(0, _rng(18))
	_assert.call(run.in_battle, "the setup battle should be in progress")
	SoloProgress.save_run("", run)
	var loaded := SoloProgress.load_run("")
	_assert.call(loaded == null, "loading a run stuck in_battle should discard it")
	_assert.call(
		SoloProgress.best_wins("") == 0, "the discarded run should count as a loss, not a win"
	)


func _test_solo_progress_milestones_fire_once() -> void:
	SoloProgress.reset_for_test()
	var run := SoloRun.new()
	run.wins = 2
	var reached := SoloProgress.record("", run)
	_assert.call(reached.size() == 1, "reaching 2 wins should fire exactly one milestone")
	_assert.call(
		str(reached[0]["id"]) == "solo_wins_2", "the 2-win milestone should fire at 2 wins"
	)
	var reached_again := SoloProgress.record("", run)
	_assert.call(reached_again.is_empty(), "the same milestone should not fire twice")
	_assert.call(SoloProgress.best_wins("") == 2, "record() should update best_wins")


## 遠征の記録(GameDesign.md 27章「画面」)。負けたときの`SoloRun.to_dict()`を
## `"finished"`として保存し、読んだら消える(1度だけ出すため)。
func _test_solo_progress_saves_finished_run_and_takes_it_once() -> void:
	SoloProgress.reset_for_test()
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], _rng(19))
	run.choose(0, _rng(19))
	run.finish_battle(false, 0, _rng(20))
	_assert.call(run.over, "the run should be over after a loss")
	SoloProgress.save_finished("", run, "")
	var finished := SoloProgress.take_finished("")
	_assert.call(not finished.is_empty(), "save_finished should be readable via take_finished")
	_assert.call(
		str(finished.get("reason", "x")) == "", "a normal loss should save an empty reason"
	)
	var restored := SoloRun.from_dict(finished.get("run", {}))
	_assert.call(restored.over, "the saved run should round-trip as over")
	var second := SoloProgress.take_finished("")
	_assert.call(second.is_empty(), "take_finished should clear the record after reading it once")


## `SoloProgress.load_run()`で中断扱いになったときは、理由「対局の途中で抜けた」を持つ
## (GameDesign.md 27章「中断と再開」)。
func _test_solo_progress_interrupted_run_saves_finished_with_abandon_reason() -> void:
	SoloProgress.reset_for_test()
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], _rng(21))
	run.choose(0, _rng(21))
	_assert.call(run.in_battle, "the setup battle should be in progress")
	SoloProgress.save_run("", run)
	var loaded := SoloProgress.load_run("")
	_assert.call(loaded == null, "an interrupted run should not be resumable")
	var finished := SoloProgress.take_finished("")
	_assert.call(not finished.is_empty(), "an interrupted run should be recorded as finished")
	_assert.call(
		str(finished.get("reason", "")) == "abandoned_mid_battle",
		"an interrupted run should carry the abandoned_mid_battle reason"
	)


func _test_solo_gates_load_and_reference_real_units() -> void:
	var gates := SoloGateLibrary.all_gates()
	_assert.call(gates.size() == 7, "GameDesign.md 27章 lists seven gates")
	var seen := {}
	for gate in gates:
		_assert.call(not seen.has(gate.id), "gate ids must be unique: " + gate.id)
		seen[gate.id] = true
		_assert.call(not gate.display_name.is_empty(), "a gate needs a name: " + gate.id)
		_assert.call(not gate.description.is_empty(), "a gate needs a description: " + gate.id)
		for row in gate.own_board_units + gate.foe_board_units:
			var parsed := PuzzleStageData.parse_unit(row)
			_assert.call(
				not parsed.is_empty(), "gate unit row must parse: %s (%s)" % [row, gate.id]
			)
		if gate.win_condition == SoloGateData.WinCondition.SURVIVE_TURNS:
			_assert.call(gate.survive_turns > 0, "a survival gate needs a target: " + gate.id)
