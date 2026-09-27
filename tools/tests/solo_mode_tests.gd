class_name SoloModeTests
extends RefCounted
## 遠征(ソロモード。GameDesign.md 27章)の検証。`SoloRun`の規則を中心に、
## `MatchState`へ足した3つの上書きプロパティ(Architecture.md 10.15節)、
## `SoloProgress`の保存・記録、関門・恩恵データの健全さを確かめる。

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
	_test_solo_run_battle_win_builds_a_bundle_offer()
	_test_solo_run_gate_win_builds_a_boon_offer_then_a_bundle_offer()
	_test_solo_run_bundle_offer_excludes_owned_pairs_and_repeated_themes()
	_test_solo_run_take_bundle_and_pass_offer()
	_test_solo_run_boons_do_not_repeat_and_apply_their_effects()
	_test_solo_run_workshop_remove_duplicate_and_skip()
	_test_solo_run_loss_ends_the_run()
	_test_solo_run_clearing_the_final_floor_marks_cleared()
	_test_solo_run_round_trips_through_dict()
	_test_solo_run_loads_the_previous_save_format()
	_test_solo_progress_in_battle_run_counts_as_a_loss_on_load()
	_test_solo_progress_milestones_fire_once()
	_test_solo_progress_saves_finished_run_and_takes_it_once()
	_test_solo_progress_interrupted_run_saves_finished_with_abandon_reason()
	_test_solo_gates_load_and_reference_real_units()
	_test_solo_boons_load_and_have_an_effect_each()
	_test_solo_run_depth_conditions_accumulate()
	_test_solo_run_depth_combines_with_boons()
	_test_solo_run_starting_max_hp_and_clear_gold_scale_with_depth()
	_test_solo_run_loads_legacy_save_without_depth()
	_test_solo_progress_unlocked_depth_and_theme_best_depth()


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
	var run := SoloRun.create(theme_id, 0, _rng(1))
	_assert.call(run.deck_ids.size() == 15, "the starting deck should hold 15 cards")
	var seen := {}
	for id in run.deck_ids:
		_assert.call(not seen.has(id), "the starting deck should hold one of each card: " + id)
		seen[id] = true
	_assert.call(run.hp == MatchState.INITIAL_HP, "hp should start at MatchState.INITIAL_HP")
	_assert.call(
		run.max_hp == MatchState.INITIAL_HP, "max_hp should start at MatchState.INITIAL_HP"
	)
	_assert.call(run.floor == 0, "a fresh run should start at floor 0")


## 道の規則(GameDesign.md 27章「道」): 1〜5段目は2〜3個、各段には対局か関門が1つ以上、
## 泉と工房は合わせて1段に1つまで・1段目には出さない。6段目は対局1つだけ。
func _test_solo_run_route_follows_the_rules() -> void:
	for trial in 8:
		var run := SoloRun.create(CardCpuDecks.deck_ids()[0], 0, _rng(100 + trial))
		_assert.call(run.route.size() == SoloRun.FLOOR_COUNT, "the route should hold 6 floors")
		for floor_i in range(SoloRun.FLOOR_COUNT - 1):
			var options: Array = run.route[floor_i]
			_assert.call(
				options.size() >= 2 and options.size() <= 3,
				"floor %d should offer 2-3 destinations" % floor_i
			)
			var non_spring := 0
			var extras := 0
			for dest in options:
				var kind: int = int(dest["kind"])
				if kind == SoloRun.Kind.SPRING or kind == SoloRun.Kind.WORKSHOP:
					extras += 1
				else:
					non_spring += 1
			_assert.call(non_spring >= 1, "floor %d needs a battle or gate" % floor_i)
			_assert.call(extras <= 1, "floor %d should offer at most one spring/workshop" % floor_i)
			if floor_i == 0:
				_assert.call(extras == 0, "the first floor should not offer a spring or workshop")
		var final_options: Array = run.route[SoloRun.FLOOR_COUNT - 1]
		_assert.call(final_options.size() == 1, "the final floor should offer one destination")
		_assert.call(
			int(final_options[0]["kind"]) == SoloRun.Kind.BATTLE,
			"the final floor's destination must be a battle"
		)


func _test_solo_run_cpu_decks_never_repeat_in_a_run() -> void:
	for trial in 8:
		var run := SoloRun.create(CardCpuDecks.deck_ids()[0], 0, _rng(200 + trial))
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


## 対局(関門でない)に勝つと、束の候補がすぐ作られる(GameDesign.md 27章「山札を育てる」)。
func _test_solo_run_battle_win_builds_a_bundle_offer() -> void:
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], 0, _rng(3))
	# floor 0 は対局か関門のみ。関門でない行き先を選ぶ。
	var options := run.current_destinations()
	var battle_index := 0
	for i in options.size():
		if int(options[i]["kind"]) == SoloRun.Kind.BATTLE:
			battle_index = i
			break
	run.choose(battle_index, _rng(3))
	_assert.call(run.in_battle, "choosing a battle destination should set in_battle")
	run.finish_battle(true, 18, _rng(4))
	_assert.call(not run.in_battle, "finishing a battle should clear in_battle")
	_assert.call(run.wins == 1, "a win should increase wins")
	_assert.call(run.floor == 1, "a win should advance the floor")
	_assert.call(run.hp == 18, "hp should carry over from the battle")
	_assert.call(run.boon_offer.is_empty(), "a plain battle win should not offer a boon")
	_assert.call(
		run.offer.size() == SoloRun.BUNDLE_COUNT, "a battle win should offer BUNDLE_COUNT bundles"
	)


## 関門に勝つと、まず恩恵の候補ができる。恩恵を選ぶと、そのあとで束の候補ができる
## (GameDesign.md 27章「恩恵」)。
func _test_solo_run_gate_win_builds_a_boon_offer_then_a_bundle_offer() -> void:
	var run: SoloRun = null
	var gate_index := -1
	for trial in 20:
		var candidate := SoloRun.create(CardCpuDecks.deck_ids()[0], 0, _rng(500 + trial))
		var options := candidate.current_destinations()
		for i in options.size():
			if int(options[i]["kind"]) == SoloRun.Kind.GATE:
				gate_index = i
				run = candidate
				break
		if run != null:
			break
	_assert.call(run != null, "at least one of the trial runs should offer a gate on floor 0")
	if run == null:
		return
	run.choose(gate_index, _rng(6))
	run.finish_battle(true, 20, _rng(7))
	_assert.call(run.offer.is_empty(), "a gate win should not build a bundle offer yet")
	_assert.call(
		run.boon_offer.size() == SoloRun.BOON_OFFER_SIZE,
		"a gate win should offer BOON_OFFER_SIZE boons"
	)
	run.take_boon(run.boon_offer[0])
	_assert.call(run.boon_offer.is_empty(), "take_boon should clear the boon offer")
	_assert.call(run.boons.size() == 1, "take_boon should record the boon")
	_assert.call(
		run.offer.size() == SoloRun.BUNDLE_COUNT,
		"take_boon should build the bundle offer afterwards"
	)


func _test_solo_run_bundle_offer_excludes_owned_pairs_and_repeated_themes() -> void:
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], 0, _rng(5))
	# 山札を全カード2枚持ちにしておく(束が「既に2枚あるカード」を外すことを確かめる)。
	run.deck_ids = run.deck_ids.duplicate()
	for id in run.deck_ids.duplicate():
		run.deck_ids.append(id)
	var options := run.current_destinations()
	var battle_index := 0
	for i in options.size():
		if int(options[i]["kind"]) == SoloRun.Kind.BATTLE:
			battle_index = i
			break
	run.choose(battle_index, _rng(5))
	run.finish_battle(true, 18, _rng(6))
	var themes := {}
	for bundle in run.offer:
		var theme_id := str(bundle.get("theme", ""))
		_assert.call(not themes.has(theme_id), "a theme should not appear twice in one offer")
		themes[theme_id] = true
		var cards: Array = bundle.get("cards", [])
		_assert.call(
			cards.size() == SoloRun.BUNDLE_CARDS, "a bundle should hold BUNDLE_CARDS cards"
		)
		var seen := {}
		for id in cards:
			_assert.call(not seen.has(id), "a bundle should not repeat a card: " + str(id))
			seen[id] = true
			var owned_count := 0
			for owned in run.deck_ids:
				if owned == id:
					owned_count += 1
			_assert.call(
				owned_count < SoloRun.MAX_DECK_COPIES,
				"a bundle should not offer an owned pair: " + str(id)
			)
			_assert.call(
				CardCpuDecks.card_ids_of(theme_id).has(str(id)),
				"a bundle's cards should belong to its own theme: " + str(id)
			)


func _test_solo_run_take_bundle_and_pass_offer() -> void:
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], 0, _rng(7))
	_win_battle_floor(run, 7)
	var before := run.deck_ids.size()
	var bundle: Dictionary = run.offer[0]
	run.take_bundle(0)
	_assert.call(
		run.deck_ids.size() == before + int(bundle["cards"].size()),
		"take_bundle() should add the bundle's cards to the deck"
	)
	_assert.call(run.offer.is_empty(), "take_bundle() should clear the offer")

	var run2 := SoloRun.create(CardCpuDecks.deck_ids()[1], 0, _rng(9))
	_win_battle_floor(run2, 9)
	var before2 := run2.deck_ids.size()
	run2.pass_offer()
	_assert.call(run2.deck_ids.size() == before2, "pass_offer() should not change the deck")
	_assert.call(run2.offer.is_empty(), "pass_offer() should clear the offer")


## 関門ではない対局を選んで勝つ(束の候補がすぐ作られることを前提にするテスト用)。
func _win_battle_floor(run: SoloRun, seed_value: int) -> void:
	var options := run.current_destinations()
	var index := 0
	for i in options.size():
		if int(options[i]["kind"]) == SoloRun.Kind.BATTLE:
			index = i
			break
	run.choose(index, _rng(seed_value))
	run.finish_battle(true, run.max_hp, _rng(seed_value + 1))


## 対局・関門のどちらでもよいので、いまの段を勝って進める(泉・工房は選ばない)。
func _win_any_floor(run: SoloRun, seed_value: int) -> void:
	var options := run.current_destinations()
	var index := 0
	for i in options.size():
		var kind: int = int(options[i]["kind"])
		if kind == SoloRun.Kind.BATTLE or kind == SoloRun.Kind.GATE:
			index = i
			break
	run.choose(index, _rng(seed_value))
	run.finish_battle(true, run.max_hp, _rng(seed_value + 1))


## 恩恵(GameDesign.md 27章「恩恵」): 同じ恩恵は1回の遠征で1度しか出ず、効果が反映される。
func _test_solo_run_boons_do_not_repeat_and_apply_their_effects() -> void:
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], 0, _rng(30))
	run.boons.append("tough_body")
	_assert.call(run.spring_bonus() == 0, "spring_bonus should be 0 without deep_spring")
	run.boons.append("deep_spring")
	_assert.call(run.spring_bonus() == 4, "deep_spring should add +4 to spring healing")
	run.boons.append("keen_eye")
	_assert.call(run.extra_bundles() == 1, "keen_eye should add one extra bundle")
	run.boons.append("preemptive_sand")
	_assert.call(run.foe_hp_penalty() == 3, "preemptive_sand should subtract 3 from the foe's hp")
	run.boons.append("well_prepared")
	_assert.call(run.extra_opening_draw() == 1, "well_prepared should add one extra opening draw")
	run.boons.append("win_streak")
	_assert.call(run.win_heal() == 3, "win_streak should heal 3 on a win")

	var fresh := SoloRun.create(CardCpuDecks.deck_ids()[0], 0, _rng(31))
	fresh.max_hp = 24
	fresh.hp = 10
	fresh.boon_offer = ["tough_body", "deep_spring", "keen_eye"]
	fresh.take_boon("tough_body")
	_assert.call(fresh.max_hp == 28, "take_boon(tough_body) should raise max_hp by 4")
	_assert.call(fresh.hp == 14, "take_boon(tough_body) should heal by the same amount")
	_assert.call(not fresh.boons.has("deep_spring"), "take_boon should not grant an unchosen boon")


## 工房(GameDesign.md 27章「道」「画面」): 抜く・複製・何もしない、いずれも次の段へ進む。
func _test_solo_run_workshop_remove_duplicate_and_skip() -> void:
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], 0, _rng(40))
	run.hp = run.max_hp
	# 工房が出るところまで段を勝ち進める。
	var workshop_index := -1
	while workshop_index == -1 and not run.over:
		var options := run.current_destinations()
		for i in options.size():
			if int(options[i]["kind"]) == SoloRun.Kind.WORKSHOP:
				workshop_index = i
				break
		if workshop_index != -1:
			break
		_win_any_floor(run, 400 + run.floor)
		if not run.boon_offer.is_empty():
			run.take_boon(run.boon_offer[0])
		if not run.offer.is_empty():
			run.pass_offer()
	if workshop_index == -1:
		return
	var floor_before := run.floor
	run.choose(workshop_index, _rng(41))
	_assert.call(run.workshop_open, "choosing a workshop destination should open it")
	_assert.call(
		run.current_destinations().is_empty(),
		"no destination should be choosable while the workshop is open"
	)

	run.workshop_skip()
	_assert.call(not run.workshop_open, "workshop_skip should close the workshop")
	_assert.call(run.floor == floor_before + 1, "workshop_skip should advance the floor")

	# 抜く。
	var run2 := SoloRun.create(CardCpuDecks.deck_ids()[1], 0, _rng(43))
	run2.workshop_open = true
	var before_size := run2.deck_ids.size()
	var target_id: String = run2.deck_ids[0]
	run2.workshop_remove(target_id)
	_assert.call(run2.deck_ids.size() == before_size - 1, "workshop_remove should remove one copy")
	_assert.call(not run2.workshop_open, "workshop_remove should close the workshop")

	# 複製(同名は2枚まで)。
	var run3 := SoloRun.create(CardCpuDecks.deck_ids()[2], 0, _rng(44))
	run3.workshop_open = true
	var dup_id: String = run3.deck_ids[0]
	run3.workshop_duplicate(dup_id)
	_assert.call(run3.deck_ids.count(dup_id) == 2, "workshop_duplicate should add a second copy")
	_assert.call(not run3.workshop_open, "workshop_duplicate should close the workshop")

	var run4 := SoloRun.create(CardCpuDecks.deck_ids()[3], 0, _rng(45))
	run4.workshop_open = true
	var dup_id4: String = run4.deck_ids[0]
	run4.workshop_duplicate(dup_id4)
	run4.workshop_open = true
	run4.workshop_duplicate(dup_id4)
	_assert.call(run4.deck_ids.count(dup_id4) == 2, "workshop_duplicate should refuse a third copy")


func _test_solo_run_loss_ends_the_run() -> void:
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], 0, _rng(11))
	var options := run.current_destinations()
	var battle_index := 0
	for i in options.size():
		if int(options[i]["kind"]) == SoloRun.Kind.BATTLE:
			battle_index = i
			break
	run.choose(battle_index, _rng(11))
	run.finish_battle(false, 0, _rng(12))
	_assert.call(run.over, "a loss should end the run")
	_assert.call(not run.cleared, "a loss should not count as cleared")


func _test_solo_run_clearing_the_final_floor_marks_cleared() -> void:
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], 0, _rng(13))
	while not run.over:
		if run.workshop_open:
			run.workshop_skip()
			continue
		var options := run.current_destinations()
		var index := 0
		for i in options.size():
			if (
				int(options[i]["kind"]) != SoloRun.Kind.SPRING
				and int(options[i]["kind"]) != SoloRun.Kind.WORKSHOP
			):
				index = i
				break
		run.choose(index, _rng(14))
		if run.in_battle:
			run.finish_battle(true, run.max_hp, _rng(15))
			if not run.boon_offer.is_empty():
				run.take_boon(run.boon_offer[0])
			if not run.offer.is_empty():
				run.pass_offer()
	_assert.call(run.cleared, "winning every battle should clear the run")
	_assert.call(run.floor == SoloRun.FLOOR_COUNT, "a cleared run should reach the final floor")


func _test_solo_run_round_trips_through_dict() -> void:
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], 0, _rng(16))
	_win_battle_floor(run, 16)
	var restored := SoloRun.from_dict(run.to_dict())
	_assert.call(restored.theme_id == run.theme_id, "from_dict should restore theme_id")
	_assert.call(restored.deck_ids == run.deck_ids, "from_dict should restore deck_ids")
	_assert.call(restored.hp == run.hp, "from_dict should restore hp")
	_assert.call(restored.max_hp == run.max_hp, "from_dict should restore max_hp")
	_assert.call(restored.floor == run.floor, "from_dict should restore floor")
	_assert.call(restored.wins == run.wins, "from_dict should restore wins")
	_assert.call(
		restored.offer.size() == run.offer.size(), "from_dict should restore the bundle offer"
	)
	if not run.offer.is_empty():
		_assert.call(
			str(restored.offer[0]["theme"]) == str(run.offer[0]["theme"]),
			"from_dict should restore a bundle's theme"
		)
	_assert.call(restored.route.size() == run.route.size(), "from_dict should restore the route")
	var kind: int = int(restored.route[0][0]["kind"])
	_assert.call(kind == int(run.route[0][0]["kind"]), "from_dict should restore route entry types")


## 以前の形式(束ではなくカードidの配列。max_hp無し)を読んでも壊れない
## (Pitfalls.md「データとコードの境目」)。
func _test_solo_run_loads_the_previous_save_format() -> void:
	var legacy := {
		"theme_id": CardCpuDecks.deck_ids()[0],
		"deck_ids": ["sand", "grain"],
		"hp": 12,
		"floor": 2,
		"wins": 2,
		"route": [],
		"offer": ["sand", "grain", "wand"],
		"chosen": [0, 0],
		"in_battle": false,
		"over": false,
		"cleared": false,
	}
	var run := SoloRun.from_dict(legacy)
	_assert.call(run.max_hp == MatchState.INITIAL_HP, "a legacy save should default max_hp")
	_assert.call(run.hp == 12, "a legacy save should keep hp")
	_assert.call(run.offer.is_empty(), "a legacy string offer should be discarded")
	_assert.call(run.boon_offer.is_empty(), "a legacy save should have no boon offer")
	_assert.call(run.boons.is_empty(), "a legacy save should have no boons")
	_assert.call(not run.workshop_open, "a legacy save should not have the workshop open")


func _test_solo_progress_in_battle_run_counts_as_a_loss_on_load() -> void:
	SoloProgress.reset_for_test()
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], 0, _rng(18))
	var options := run.current_destinations()
	var battle_index := 0
	for i in options.size():
		if int(options[i]["kind"]) == SoloRun.Kind.BATTLE:
			battle_index = i
			break
	run.choose(battle_index, _rng(18))
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
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], 0, _rng(19))
	var options := run.current_destinations()
	var battle_index := 0
	for i in options.size():
		if int(options[i]["kind"]) == SoloRun.Kind.BATTLE:
			battle_index = i
			break
	run.choose(battle_index, _rng(19))
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
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], 0, _rng(21))
	var options := run.current_destinations()
	var battle_index := 0
	for i in options.size():
		if int(options[i]["kind"]) == SoloRun.Kind.BATTLE:
			battle_index = i
			break
	run.choose(battle_index, _rng(21))
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
	_assert.call(gates.size() == 10, "GameDesign.md 27章 lists ten gates")
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
		if (
			gate.win_condition
			in [SoloGateData.WinCondition.SURVIVE_TURNS, SoloGateData.WinCondition.WIN_WITHIN_TURNS]
		):
			_assert.call(gate.survive_turns > 0, "a turn-count gate needs a target: " + gate.id)


## 砂の深さ(GameDesign.md 27章「砂の深さ」)の条件は積み重なる。
func _test_solo_run_depth_conditions_accumulate() -> void:
	var run0 := SoloRun.create(CardCpuDecks.deck_ids()[0], 0, _rng(60))
	_assert.call(
		run0.expert_from_floor() == SoloRun.EXPERT_FROM_FLOOR,
		"depth 0 keeps the normal expert floor"
	)
	_assert.call(run0.spring_heal() == SoloRun.SPRING_HEAL, "depth 0 keeps the normal spring heal")
	_assert.call(run0.foe_hp_delta() == 0, "depth 0 has no foe hp delta")
	_assert.call(
		run0.bundle_target() == SoloRun.BUNDLE_COUNT, "depth 0 keeps the normal bundle count"
	)

	var run1 := SoloRun.create(CardCpuDecks.deck_ids()[0], 1, _rng(61))
	_assert.call(run1.expert_from_floor() == 0, "depth 1 should make the CPU expert from floor 0")
	_assert.call(
		run1.spring_heal() == SoloRun.SPRING_HEAL, "depth 1 should not yet change spring heal"
	)

	var run2 := SoloRun.create(CardCpuDecks.deck_ids()[0], 2, _rng(62))
	_assert.call(run2.expert_from_floor() == 0, "depth 2 should still keep the depth 1 condition")
	_assert.call(run2.spring_heal() == 5, "depth 2 should set the spring heal to 5")
	_assert.call(run2.foe_hp_delta() == 0, "depth 2 should not yet add a foe hp bonus")

	var run3 := SoloRun.create(CardCpuDecks.deck_ids()[0], 3, _rng(63))
	_assert.call(run3.foe_hp_delta() == 4, "depth 3 should add +4 to the foe's starting hp")
	_assert.call(
		run3.bundle_target() == SoloRun.BUNDLE_COUNT, "depth 3 should not yet reduce bundles"
	)

	var run4 := SoloRun.create(CardCpuDecks.deck_ids()[0], 4, _rng(64))
	_assert.call(
		run4.bundle_target() == SoloRun.BUNDLE_COUNT - 1,
		"depth 4 should reduce the bundle count by 1"
	)
	_assert.call(
		run4.max_hp == MatchState.INITIAL_HP, "depth 4 should not yet raise the starting max hp"
	)

	var run5 := SoloRun.create(CardCpuDecks.deck_ids()[0], 5, _rng(65))
	_assert.call(run5.max_hp == 20, "depth 5 should start at 20 max hp")
	_assert.call(run5.hp == 20, "depth 5 should start with full hp at the new max")
	# 深さ5でも1〜4段目の条件はすべて残る。
	_assert.call(run5.expert_from_floor() == 0, "depth 5 should keep the depth 1 condition")
	_assert.call(run5.spring_heal() == 5, "depth 5 should keep the depth 2 condition")
	_assert.call(run5.foe_hp_delta() == 4, "depth 5 should keep the depth 3 condition")
	_assert.call(
		run5.bundle_target() == SoloRun.BUNDLE_COUNT - 1,
		"depth 5 should keep the depth 4 condition"
	)

	_assert.call(
		SoloRun.depth_condition_lines(0).is_empty(), "depth 0 should offer no condition lines"
	)
	_assert.call(
		SoloRun.depth_condition_lines(3).size() == 3, "depth 3 should offer three condition lines"
	)
	_assert.call(
		SoloRun.depth_condition_lines(5).size() == 5,
		"depth 5 should offer all five condition lines"
	)


## 深さの条件は恩恵と合算する(GameDesign.md 27章「恩恵」「砂の深さ」)。
func _test_solo_run_depth_combines_with_boons() -> void:
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], 3, _rng(66))
	run.boons.append("preemptive_sand")
	_assert.call(
		run.foe_hp_delta() == 4 - 3, "depth 3's +4 should combine with preemptive_sand's -3"
	)

	var spring_run := SoloRun.create(CardCpuDecks.deck_ids()[0], 2, _rng(67))
	spring_run.boons.append("deep_spring")
	_assert.call(
		spring_run.spring_heal() + spring_run.spring_bonus() == 5 + 4,
		"depth 2's base heal of 5 should combine with deep_spring's +4"
	)

	var bundle_run := SoloRun.create(CardCpuDecks.deck_ids()[0], 4, _rng(68))
	bundle_run.boons.append("keen_eye")
	_assert.call(
		bundle_run.bundle_target() == SoloRun.BUNDLE_COUNT - 1 + 1,
		"depth 4's -1 should combine with keen_eye's +1"
	)


## 開始の最大HP・踏破の砂金は深さに応じて増える(GameDesign.md 27章「砂の深さ」
## 「遠征をまたいで残るもの」)。
func _test_solo_run_starting_max_hp_and_clear_gold_scale_with_depth() -> void:
	_assert.call(
		SoloRun.starting_max_hp(4) == MatchState.INITIAL_HP,
		"depth 4 should not raise the starting max hp"
	)
	_assert.call(SoloRun.starting_max_hp(5) == 20, "depth 5 should raise the starting max hp to 20")

	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], 3, _rng(69))
	_assert.call(
		run.clear_gold() == SoloRun.CLEAR_GOLD + 3 * SoloRun.CLEAR_GOLD_PER_DEPTH,
		"clear_gold should add CLEAR_GOLD_PER_DEPTH per depth"
	)
	var run0 := SoloRun.create(CardCpuDecks.deck_ids()[0], 0, _rng(70))
	_assert.call(
		run0.clear_gold() == SoloRun.CLEAR_GOLD, "depth 0 should not change the clear gold"
	)


## 深さの無い旧データは深さ0として読む(Pitfalls.md「データとコードの境目」)。
func _test_solo_run_loads_legacy_save_without_depth() -> void:
	var legacy := {
		"theme_id": CardCpuDecks.deck_ids()[0],
		"deck_ids": ["sand"],
		"hp": 12,
		"max_hp": 24,
		"floor": 1,
		"wins": 1,
		"route": [],
		"chosen": [0],
		"in_battle": false,
		"over": false,
		"cleared": false,
	}
	var run := SoloRun.from_dict(legacy)
	_assert.call(run.depth == 0, "a save without a depth field should default to depth 0")


## 選べる最大の深さは踏破するとN+1に伸び(上限は`DEPTH_MAX`)、作戦ごとの最も深い踏破も
## 別々に覚える(GameDesign.md 27章「砂の深さ」「遠征をまたいで残るもの」)。
func _test_solo_progress_unlocked_depth_and_theme_best_depth() -> void:
	SoloProgress.reset_for_test()
	var theme_a := CardCpuDecks.deck_ids()[0]
	var theme_b := CardCpuDecks.deck_ids()[1]
	_assert.call(SoloProgress.unlocked_depth("") == 0, "a fresh account should only unlock depth 0")
	_assert.call(
		SoloProgress.theme_best_depth("", theme_a) == -1, "an uncleared theme should report -1"
	)
	_assert.call(SoloProgress.cleared_theme_count("") == 0, "a fresh account has cleared no themes")

	var run_a := SoloRun.new()
	run_a.theme_id = theme_a
	run_a.depth = 2
	run_a.wins = SoloRun.FLOOR_COUNT
	run_a.cleared = true
	SoloProgress.record("", run_a)
	_assert.call(SoloProgress.unlocked_depth("") == 3, "clearing depth 2 should unlock depth 3")
	_assert.call(
		SoloProgress.theme_best_depth("", theme_a) == 2, "theme_a's best depth should be recorded"
	)
	_assert.call(SoloProgress.cleared_theme_count("") == 1, "one theme should now be cleared")

	# 別の作戦を浅い深さで踏破しても、他の作戦の記録は減らない。
	var run_b := SoloRun.new()
	run_b.theme_id = theme_b
	run_b.depth = 0
	run_b.wins = SoloRun.FLOOR_COUNT
	run_b.cleared = true
	SoloProgress.record("", run_b)
	_assert.call(
		SoloProgress.unlocked_depth("") == 3,
		"unlocked_depth should not drop when a shallower run clears"
	)
	_assert.call(
		SoloProgress.theme_best_depth("", theme_a) == 2, "theme_a's record should be unaffected"
	)
	_assert.call(
		SoloProgress.theme_best_depth("", theme_b) == 0, "theme_b's best depth should be recorded"
	)
	_assert.call(SoloProgress.cleared_theme_count("") == 2, "two themes should now be cleared")

	# depth 5を踏破しても上限(DEPTH_MAX=5)を超えない。
	var run_max := SoloRun.new()
	run_max.theme_id = theme_a
	run_max.depth = SoloRun.DEPTH_MAX
	run_max.wins = SoloRun.FLOOR_COUNT
	run_max.cleared = true
	SoloProgress.record("", run_max)
	_assert.call(
		SoloProgress.unlocked_depth("") == SoloRun.DEPTH_MAX,
		"unlocked_depth should cap at DEPTH_MAX"
	)

	SoloProgress.set_last_depth("", 3)
	_assert.call(
		SoloProgress.last_depth("") == 3, "set_last_depth should be readable via last_depth"
	)


## 恩恵(GameDesign.md 27章「恩恵」)は6つ、どれもちょうど1つの効果を持つ。
func _test_solo_boons_load_and_have_an_effect_each() -> void:
	var boons := SoloBoonLibrary.all_boons()
	_assert.call(boons.size() == 14, "GameDesign.md 27章 lists fourteen boons")
	var seen := {}
	for boon in boons:
		_assert.call(not seen.has(boon.id), "boon ids must be unique: " + boon.id)
		seen[boon.id] = true
		_assert.call(not boon.display_name.is_empty(), "a boon needs a name: " + boon.id)
		_assert.call(not boon.description.is_empty(), "a boon needs a description: " + boon.id)
		var effects := 0
		for field in [
			"max_hp_bonus",
			"spring_bonus",
			"extra_bundles",
			"foe_hp_penalty",
			"extra_opening_draw",
			"win_heal",
			"light_deck_draw",
			"small_total_bonus",
			"heavy_cost_cut",
			"flip_damage",
			"death_damage",
			"extra_flip_rights",
			"first_turn_mana",
		]:
			if int(boon.get(field)) != 0:
				effects += 1
		_assert.call(effects >= 1, "a boon should have a nonzero effect: " + boon.id)
