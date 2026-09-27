class_name SoloStrategyTests
extends RefCounted
## 遠征の主・戦い方を変える恩恵・鏡写し/速攻勝負(GameDesign.md 27章「主」「恩恵」「関門」)の検証。
## `solo_mode_tests.gd`が行数の上限に近いため分けている。

const SIDE_A := MatchState.Side.A
const SIDE_B := MatchState.Side.B

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_bosses_load_with_hp_bonus()
	_test_boss_takes_the_final_floor_and_its_deck()
	_test_boss_survives_save_and_load()
	_test_boon_offer_always_has_a_play_changing_boon()
	_test_glass_heart_lowers_max_hp_and_widens_bundles()
	_test_light_pack_draws_only_with_a_thin_deck()
	_test_modded_deck_changes_copies_only()
	_test_flip_sting_damages_on_own_flips()
	_test_parting_gift_damages_on_own_deaths()
	_test_sand_pouch_adds_a_flip_right()
	_test_early_riser_adds_mana_on_the_first_own_turn()
	_test_mirror_uses_player_deck()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _run_with(boon_ids: Array[String]) -> SoloRun:
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], 0, _rng(1))
	run.boons = boon_ids
	return run


func _deck_of(id: String) -> Array:
	var cards: Array = []
	for i in MatchState.DECK_SIZE:
		cards.append(CardLibrary.find_by_id(id))
	return cards


func _new_match(use_mulligan: bool = false) -> MatchState:
	var state := MatchState.new()
	state.start_match(_deck_of("sand"), _deck_of("sand"), SIDE_A, 12345, false, use_mulligan)
	return state


## 反転しても壊れないよう、砂を落とした駒を直接置く。
func _place(state: MatchState, side: int, slot: int) -> CardInstance:
	var unit := CardInstance.new(CardLibrary.find_by_id("sand"))
	unit.summoned_this_turn = false
	unit.drop_sand(2)
	state.board[side][slot] = unit
	return unit


func _test_bosses_load_with_hp_bonus() -> void:
	var bosses := SoloGateLibrary.all_bosses()
	_assert.call(bosses.size() == 3, "GameDesign.md 27章 lists three bosses")
	for boss in bosses:
		_assert.call(boss.foe_hp_bonus == 8, "a boss should have 8 extra hp: " + boss.id)
		_assert.call(
			SoloGateLibrary.find_by_id(boss.id) == boss, "find_by_id should see bosses: " + boss.id
		)
		_assert.call(
			not SoloGateLibrary.all_gates().has(boss), "bosses must not enter the gate pool"
		)
		if not boss.cpu_deck.is_empty():
			_assert.call(
				CardCpuDecks.deck_ids().has(boss.cpu_deck), "boss deck must exist: " + boss.id
			)


func _test_boss_takes_the_final_floor_and_its_deck() -> void:
	for boss in SoloGateLibrary.all_bosses():
		for trial in 20:
			var run := SoloRun.create(CardCpuDecks.deck_ids()[0], 0, _rng(700 + trial), boss.id)
			var final: Dictionary = run.route[SoloRun.FLOOR_COUNT - 1][0]
			_assert.call(str(final["gate"]) == boss.id, "the final floor should hold the boss")
			var used := {}
			for floor_i in SoloRun.FLOOR_COUNT:
				for dest: Dictionary in run.route[floor_i]:
					var deck := str(dest.get("cpu_deck", ""))
					if deck.is_empty():
						continue
					_assert.call(not used.has(deck), "cpu decks must not repeat in a run")
					used[deck] = true
			if not boss.cpu_deck.is_empty():
				_assert.call(
					str(final["cpu_deck"]) == boss.cpu_deck, "the boss should bring its own deck"
				)
	_assert.call(
		SoloGateLibrary.boss_ids().has(SoloRun.boss_choice(_rng(3))),
		"boss_choice should pick one of the bosses"
	)


func _test_boss_survives_save_and_load() -> void:
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], 0, _rng(5), "quicksand")
	var loaded := SoloRun.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	_assert.call(loaded.boss_id == "quicksand", "boss_id should survive save/load")
	var legacy := run.to_dict()
	legacy.erase("boss_id")
	_assert.call(SoloRun.from_dict(legacy).boss_id == "", "a legacy save has no boss")


func _test_boon_offer_always_has_a_play_changing_boon() -> void:
	for trial in 40:
		var run := SoloRun.create(CardCpuDecks.deck_ids()[0], 0, _rng(900 + trial))
		var offer := run._build_boon_offer(_rng(trial))
		_assert.call(offer.size() == SoloRun.BOON_OFFER_SIZE, "offer should have three boons")
		var has_play := false
		for id in offer:
			_assert.call(offer.count(id) == 1, "offer must not repeat a boon")
			if SoloBoonLibrary.find_by_id(id).changes_play:
				has_play = true
		_assert.call(has_play, "offer should include a play-changing boon (27章 ◆)")


func _test_glass_heart_lowers_max_hp_and_widens_bundles() -> void:
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], 0, _rng(11))
	var before := run.bundle_target()
	run.boon_offer = ["glass_heart"]
	run.take_boon("glass_heart")
	_assert.call(run.max_hp == MatchState.INITIAL_HP - 6, "glass heart lowers max hp by 6")
	_assert.call(run.hp == run.max_hp, "hp should be capped to the new max hp")
	_assert.call(run.bundle_target() == before + 2, "glass heart adds two bundles")


func _test_light_pack_draws_only_with_a_thin_deck() -> void:
	var run := _run_with(["light_pack"])
	_assert.call(run.extra_opening_draw() == 2, "a 15-card deck is light enough")
	while run.deck_ids.size() <= 20:
		run.deck_ids.append(run.deck_ids[0])
	_assert.call(run.extra_opening_draw() == 0, "a 21-card deck is too heavy for light pack")


func _test_modded_deck_changes_copies_only() -> void:
	var small := CardLibrary.find_by_id("sand")
	var heavy: CardData = null
	for card in CardLibrary.all_cards():
		if not card.is_spell and card.cost >= 5:
			heavy = card
			break
	var original_total := small.total_sand
	var original_cost := heavy.cost
	var modded := SoloBoonEffects.modded_deck(
		[small, heavy], _run_with(["small_army", "heavy_sand"])
	)
	_assert.call(modded[0].total_sand == original_total + 1, "small army adds 1 total")
	_assert.call(modded[1].cost == original_cost - 1, "heavy sand cuts 1 cost")
	_assert.call(small.total_sand == original_total, "shared CardData must stay untouched")
	_assert.call(heavy.cost == original_cost, "shared CardData must stay untouched")
	var plain := SoloBoonEffects.modded_deck([small], _run_with([]))
	_assert.call(plain[0] == small, "without boons the deck is passed through")


func _test_flip_sting_damages_on_own_flips() -> void:
	var state := _new_match()
	var effects := SoloBoonEffects.new()
	effects.attach(state, SIDE_A, _run_with(["flip_sting"]))
	_place(state, SIDE_A, 0)
	_place(state, SIDE_A, 1)
	var foe_hp := int(state.hp[SIDE_B])
	state.flip(SIDE_A, 0)
	_assert.call(state.hp[SIDE_B] == foe_hp - 1, "flipping an own unit should deal 1")
	state.flip_right_remaining[SIDE_A] = 2
	state.use_flip_right(SIDE_A, SIDE_A, 1)
	_assert.call(state.hp[SIDE_B] == foe_hp - 2, "a flip right on an own unit counts too")
	_place(state, SIDE_B, 0)
	state.use_flip_right(SIDE_A, SIDE_B, 0)
	_assert.call(state.hp[SIDE_B] == foe_hp - 2, "flipping a foe unit does not count")


func _test_parting_gift_damages_on_own_deaths() -> void:
	var state := _new_match()
	var effects := SoloBoonEffects.new()
	effects.attach(state, SIDE_A, _run_with(["parting_gift"]))
	_place(state, SIDE_A, 0)
	_place(state, SIDE_B, 0)
	var foe_hp := int(state.hp[SIDE_B])
	state.destroy_unit(SIDE_A, 0)
	_assert.call(state.hp[SIDE_B] == foe_hp - 1, "an own unit's death should deal 1")
	state.destroy_unit(SIDE_B, 0)
	_assert.call(state.hp[SIDE_B] == foe_hp - 1, "a foe unit's death does not count")


func _test_sand_pouch_adds_a_flip_right() -> void:
	var state := _new_match()
	var before := int(state.flip_right_remaining[SIDE_A])
	SoloBoonEffects.new().attach(state, SIDE_A, _run_with(["sand_pouch"]))
	_assert.call(state.flip_right_remaining[SIDE_A] == before + 1, "sand pouch adds a right")


func _test_early_riser_adds_mana_on_the_first_own_turn() -> void:
	var state := _new_match(true)
	var effects := SoloBoonEffects.new()
	effects.attach(state, SIDE_A, _run_with(["early_riser"]))
	state.mulligan(SIDE_A, [])
	state.mulligan(SIDE_B, [])
	_assert.call(state.mana[SIDE_A] == 2, "early riser gives 1 extra mana on turn 1")
	state.end_turn()
	state.end_turn()
	_assert.call(state.mana[SIDE_A] == 2, "the extra mana is for the first turn only")


func _test_mirror_uses_player_deck() -> void:
	_assert.call(
		SoloRun.uses_player_deck({"gate": "mirror", "cpu_deck": "rush"}), "mirror gate copies"
	)
	_assert.call(
		not SoloRun.uses_player_deck({"gate": "", "cpu_deck": "rush"}), "a plain battle does not"
	)
	_assert.call(
		SoloRun.foe_name_of({"gate": "mirror_lord", "cpu_deck": "rush"}).ends_with("あなたの山札"),
		"the mirror foe is named after the player's deck"
	)
