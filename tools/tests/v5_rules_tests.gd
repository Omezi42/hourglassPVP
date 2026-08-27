extends RefCounted
## v5.0ルール(MatchState / CardInstance / CardEffectResolver)の検証。
## run_tests.gd が1000行の上限に達しているため別ファイルへ切り出している。

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_all_cards_load()
	_test_lifetime_damage_formula()
	_test_unit_starts_full_health_and_ticks()
	_test_flip_swaps_health_and_attack()
	_test_damage_removes_sand_from_total()
	_test_opening_hands_and_first_turn_draw()
	_test_play_card_spends_mana_and_fills_slot()
	_test_play_card_overwrites_and_sends_to_graveyard()
	_test_summoning_sickness_and_quick()
	_test_combat_is_mutual_and_kills_both()
	_test_guard_forces_targeting()
	_test_glass_negates_first_damage()
	_test_pierce_leaks_excess_to_player()
	_test_lifesteal_heals_owner()
	_test_poison_destroys_damaged_unit()
	_test_double_strike_allows_two_attacks()
	_test_on_play_effects()
	_test_flip_trigger_adds_total()
	_test_fatigue_after_deck_runs_out()
	_test_match_action_round_trip()
	_test_cpu_finishes_a_full_match()
	_test_coin_gives_the_second_player_one_extra_mana()


func _card(id: String) -> CardData:
	return CardLibrary.find_by_id(id)


## 同じカードを20枚並べた検証用デッキ。
func _deck_of(id: String) -> Array:
	var cards: Array = []
	for i in MatchState.DECK_SIZE:
		cards.append(_card(id))
	return cards


func _new_match(deck_a_id: String = "sand", deck_b_id: String = "sand") -> MatchState:
	var state := MatchState.new()
	state.start_match(_deck_of(deck_a_id), _deck_of(deck_b_id), MatchState.Side.A, 12345)
	return state


## 検証したい場面を直接作るため、手札の先頭へカードを差し込んでから出す。
func _force_play(state: MatchState, side: int, id: String, slot: int) -> CardInstance:
	var previous_turn: int = state.current_turn
	state.current_turn = side
	state.hand[side].push_front(_card(id))
	state.mana[side] = MatchState.MAX_MANA
	state.play_card(side, 0, slot)
	state.current_turn = previous_turn
	return state.board[side][slot]


func _test_all_cards_load() -> void:
	var cards := CardLibrary.all_cards()
	_assert.call(cards.size() == 20, "CardLibrary should load 20 cards, got %d" % cards.size())
	for card in cards:
		_assert.call(card.cost > 0, "card %s should have a positive cost" % card.id)
		_assert.call(card.total_sand > 0, "card %s should have a positive total" % card.id)


func _test_lifetime_damage_formula() -> void:
	var unit := CardInstance.new(_card("sand"))
	unit.health = 5
	unit.attack = 1
	# 体力5・攻撃1 なら 5*1 + 5*4/2 = 15
	_assert.call(unit.lifetime_damage() == 15, "lifetime damage of (5,1) should be 15")
	unit.health = 4
	unit.attack = 1
	_assert.call(unit.lifetime_damage() == 10, "lifetime damage of (4,1) should be 10")


func _test_unit_starts_full_health_and_ticks() -> void:
	var unit := CardInstance.new(_card("sand"))
	_assert.call(
		unit.health == 5 and unit.attack == 0, "unit should start at total health, 0 attack"
	)
	unit.tick()
	_assert.call(unit.health == 4 and unit.attack == 1, "one tick should move one grain of sand")
	_assert.call(unit.total_sand() == 5, "ticking should not change the total")


func _test_flip_swaps_health_and_attack() -> void:
	var unit := CardInstance.new(_card("sand"))
	unit.drop_sand(3)
	unit.flip()
	_assert.call(unit.health == 3 and unit.attack == 2, "flip should swap health and attack")


func _test_damage_removes_sand_from_total() -> void:
	var unit := CardInstance.new(_card("sand"))
	unit.drop_sand(1)
	var dealt := unit.take_damage(2)
	_assert.call(dealt == 2, "take_damage should report the sand that disappeared")
	_assert.call(unit.health == 2 and unit.attack == 1, "damage must not raise attack")
	_assert.call(unit.total_sand() == 3, "damage must shrink the total")


func _test_opening_hands_and_first_turn_draw() -> void:
	var state := _new_match()
	# 先手は3枚で始まり1ターン目はドローしないため3枚のまま。
	_assert.call(state.hand[MatchState.Side.A].size() == 3, "first player should hold 3 cards")
	_assert.call(state.hand[MatchState.Side.B].size() == 4, "second player should hold 4 cards")
	state.end_turn()
	_assert.call(state.current_turn == MatchState.Side.B, "turn should pass to the second player")
	_assert.call(state.hand[MatchState.Side.B].size() == 5, "second player draws on their turn")
	state.end_turn()
	_assert.call(state.hand[MatchState.Side.A].size() == 4, "first player draws from turn 3 on")


func _test_play_card_spends_mana_and_fills_slot() -> void:
	var state := _new_match()
	state.hand[MatchState.Side.A] = [_card("sand")]
	state.mana[MatchState.Side.A] = 3
	var played := state.play_card(MatchState.Side.A, 0, 0)
	_assert.call(played, "playing a 2-cost card with 3 mana should succeed")
	_assert.call(state.mana[MatchState.Side.A] == 1, "cost should be deducted from mana")
	var unit: CardInstance = state.board[MatchState.Side.A][0]
	_assert.call(unit != null and unit.health == 5, "unit should enter with health = total")
	state.hand[MatchState.Side.A] = [_card("wall")]
	_assert.call(
		not state.play_card(MatchState.Side.A, 0, 1), "playing without enough mana should fail"
	)


func _test_play_card_overwrites_and_sends_to_graveyard() -> void:
	var state := _new_match()
	_force_play(state, MatchState.Side.A, "sand", 0)
	_force_play(state, MatchState.Side.A, "wall", 0)
	var unit: CardInstance = state.board[MatchState.Side.A][0]
	_assert.call(unit.data.id == "wall", "the new card should occupy the slot")
	_assert.call(
		state.graveyard[MatchState.Side.A].size() == 1,
		"the overwritten card should go to the graveyard"
	)


func _test_summoning_sickness_and_quick() -> void:
	var state := _new_match()
	var sand := _force_play(state, MatchState.Side.A, "sand", 0)
	_assert.call(not sand.can_flip(), "a unit played this turn cannot flip")
	_assert.call(not sand.can_attack(), "a unit played this turn cannot attack")
	var dash := _force_play(state, MatchState.Side.A, "dash", 1)
	_assert.call(dash.health == 2 and dash.attack == 2, "quick should drop 2 grains on entry")
	_assert.call(dash.can_attack(), "quick should let the unit attack immediately")


func _test_combat_is_mutual_and_kills_both() -> void:
	var state := _new_match()
	var attacker := _force_play(state, MatchState.Side.A, "sand", 0)
	var defender := _force_play(state, MatchState.Side.B, "sand", 0)
	attacker.summoned_this_turn = false
	attacker.drop_sand(2)
	defender.drop_sand(2)
	# 体力3・攻撃2 同士。互いに2ずつ砂が消える。
	state.attack(MatchState.Side.A, 0, 0)
	_assert.call(attacker.health == 1 and attacker.attack == 2, "the attacker takes damage too")
	_assert.call(defender.health == 1 and defender.attack == 2, "the defender loses sand")
	_assert.call(attacker.total_sand() == 3, "combat must shrink the total")


func _test_guard_forces_targeting() -> void:
	var state := _new_match()
	_force_play(state, MatchState.Side.B, "sand", 0)
	_force_play(state, MatchState.Side.B, "shield", 1)
	var targets := state.attackable_slots(MatchState.Side.B)
	_assert.call(targets == [1], "guard should be the only legal unit target")
	_assert.call(not state.can_attack_player(MatchState.Side.A), "guard should block face damage")


func _test_glass_negates_first_damage() -> void:
	var unit := CardInstance.new(_card("glass"))
	var total: int = unit.data.total_sand
	var first := unit.take_damage(3)
	_assert.call(first == 0 and unit.health == total, "glass should negate the first damage")
	var second := unit.take_damage(3)
	_assert.call(second == 3 and unit.health == total - 3, "glass should only work once")


func _test_pierce_leaks_excess_to_player() -> void:
	var state := _new_match()
	var attacker := _force_play(state, MatchState.Side.A, "drill", 0)
	var defender := _force_play(state, MatchState.Side.B, "sand", 0)
	attacker.summoned_this_turn = false
	attacker.health = 1
	attacker.attack = 5
	defender.health = 2
	defender.attack = 0
	var before: int = state.hp[MatchState.Side.B]
	state.attack(MatchState.Side.A, 0, 0)
	_assert.call(
		state.hp[MatchState.Side.B] == before - 3,
		"pierce should leak attack minus health to the face"
	)


func _test_lifesteal_heals_owner() -> void:
	var state := _new_match()
	var attacker := _force_play(state, MatchState.Side.A, "vamp", 0)
	attacker.summoned_this_turn = false
	attacker.drop_sand(3)
	state.hp[MatchState.Side.A] = 20
	state.attack(MatchState.Side.A, 0, -1)
	_assert.call(state.hp[MatchState.Side.A] == 23, "lifesteal should heal for the damage dealt")
	_assert.call(
		state.hp[MatchState.Side.B] == MatchState.INITIAL_HP - 3, "face damage should land"
	)


func _test_poison_destroys_damaged_unit() -> void:
	var state := _new_match()
	var attacker := _force_play(state, MatchState.Side.A, "poison", 0)
	var defender := _force_play(state, MatchState.Side.B, "wall", 0)
	attacker.summoned_this_turn = false
	attacker.drop_sand(1)
	state.attack(MatchState.Side.A, 0, 0)
	_assert.call(
		state.board[MatchState.Side.B][0] == null, "poison should destroy any unit it damages"
	)


func _test_double_strike_allows_two_attacks() -> void:
	var state := _new_match()
	var unit := _force_play(state, MatchState.Side.A, "twin", 0)
	unit.summoned_this_turn = false
	unit.drop_sand(2)
	state.attack(MatchState.Side.A, 0, -1)
	_assert.call(unit.can_attack(), "double strike should allow a second attack")
	state.attack(MatchState.Side.A, 0, -1)
	_assert.call(not unit.can_attack(), "double strike should stop after two attacks")
	_assert.call(
		state.hp[MatchState.Side.B] == MatchState.INITIAL_HP - 4, "both attacks should land"
	)


func _test_on_play_effects() -> void:
	var state := _new_match()
	_force_play(state, MatchState.Side.A, "sword", 0)
	_assert.call(state.hp[MatchState.Side.B] == MatchState.INITIAL_HP - 2, "sword deals 2 on play")

	var hand_before: int = state.hand[MatchState.Side.A].size()
	_force_play(state, MatchState.Side.A, "echo", 1)
	_assert.call(
		state.hand[MatchState.Side.A].size() == hand_before + 1, "echo should draw one card"
	)

	var victim := _force_play(state, MatchState.Side.B, "sand", 0)
	victim.drop_sand(1)
	_force_play(state, MatchState.Side.A, "eye", 2)
	_assert.call(victim.health == 1 and victim.attack == 4, "eye should swap the enemy's stats")

	var swarm_before: int = state.hp[MatchState.Side.B]
	_force_play(state, MatchState.Side.A, "swarm", 3)
	_assert.call(
		state.hp[MatchState.Side.B] == swarm_before - state.units(MatchState.Side.B).size(),
		"swarm should deal 1 per enemy unit"
	)

	_force_play(state, MatchState.Side.A, "hammer", 4)
	_assert.call(state.units(MatchState.Side.B).size() == 0, "hammer should destroy an enemy unit")

	_force_play(state, MatchState.Side.B, "wall", 0)
	_force_play(state, MatchState.Side.B, "wall", 1)
	_force_play(state, MatchState.Side.A, "sweep", 5)
	var wall_total: int = _card("wall").total_sand
	var shaved: int = _card("sweep").effects_for(CardEnums.Trigger.ON_PLAY)[0].value
	for unit in state.units(MatchState.Side.B):
		_assert.call(
			unit.health == wall_total - shaved, "sweep should shave sand off every enemy unit"
		)


func _test_flip_trigger_adds_total() -> void:
	var state := _new_match()
	var unit := _force_play(state, MatchState.Side.A, "glow", 0)
	unit.summoned_this_turn = false
	unit.drop_sand(2)
	state.flip(MatchState.Side.A, 0)
	# 砂を2粒落としてから反転するので、体力=2 / 攻撃力=総量-2。そこへ総量+1。
	var total: int = _card("glow").total_sand
	_assert.call(
		unit.health == 3 and unit.attack == total - 2, "the flip trigger should add one grain"
	)


func _test_fatigue_after_deck_runs_out() -> void:
	var state := _new_match()
	state.deck[MatchState.Side.A] = []
	state.draw(MatchState.Side.A, 1)
	var before: int = state.hp[MatchState.Side.A]
	state.end_turn()
	_assert.call(
		state.hp[MatchState.Side.A] == before - 1, "an empty deck should cost 1 hp per turn"
	)


func _test_match_action_round_trip() -> void:
	var state := _new_match()
	state.hand[MatchState.Side.A] = [_card("sand")]
	state.mana[MatchState.Side.A] = 5
	var played := MatchAction.apply(state, MatchAction.play(MatchState.Side.A, 0, 0))
	_assert.call(played, "MatchAction should route a play action to the board")
	MatchAction.apply(state, MatchAction.end_turn(MatchState.Side.A))
	_assert.call(state.current_turn == MatchState.Side.B, "end_turn should pass the turn")
	MatchAction.apply(state, {"type": "surrender", "side": MatchState.Side.B})
	_assert.call(
		state.winner == MatchState.Side.A, "surrender should hand the win to the other side"
	)


## CPU同士が最後まで指し切れること。無限ループ・不正手で止まらないことの回帰テスト。
func _test_cpu_finishes_a_full_match() -> void:
	var state := _new_match("sand", "sword")
	var cpu := CardCpuStrategy.new()
	var turns := 0
	while not state.is_match_over() and turns < MatchState.MAX_TURNS + 5:
		cpu.take_turn(state, state.current_turn)
		turns += 1
	_assert.call(state.is_match_over(), "a cpu vs cpu match should reach an end")
	_assert.call(
		state.hp[MatchState.Side.A] <= 0 or state.hp[MatchState.Side.B] <= 0 or state.winner < 0,
		"the match should end because a player ran out of hp (or hit the turn cap)"
	)


## コインは後手だけが1対局に1度使える(GameDesign.md 2章の手番補正)。
func _test_coin_gives_the_second_player_one_extra_mana() -> void:
	var state := MatchState.new()
	state.start_match(_deck_of("sand"), _deck_of("sand"), MatchState.Side.A, 999, true)
	_assert.call(
		not state.coin_available[MatchState.Side.A], "the first player should not hold a coin"
	)
	_assert.call(state.coin_available[MatchState.Side.B], "the second player should hold a coin")
	_assert.call(not state.use_coin(MatchState.Side.B), "the coin cannot be used off-turn")
	state.end_turn()
	var before: int = state.mana[MatchState.Side.B]
	_assert.call(state.use_coin(MatchState.Side.B), "the coin should be usable on your own turn")
	_assert.call(
		state.mana[MatchState.Side.B] == before + MatchState.COIN_MANA, "the coin should add mana"
	)
	_assert.call(not state.use_coin(MatchState.Side.B), "the coin should only work once")
