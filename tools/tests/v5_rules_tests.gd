extends RefCounted
## v5.0ルール(MatchState / CardInstance / CardEffectResolver)の検証。
## run_tests.gd が1000行の上限に達しているため別ファイルへ切り出している。

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_all_cards_load()
	_test_card_orders()
	_test_lifetime_damage_formula()
	_test_unit_starts_full_health_and_ticks()
	_test_flip_swaps_health_and_attack()
	_test_damage_removes_sand_from_total()
	_test_opening_hands_and_first_turn_draw()
	_test_play_card_spends_mana_and_fills_slot()
	_test_play_card_cannot_overwrite_an_occupied_slot()
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
	_test_card_deck_save_round_trips()
	_test_same_seed_reproduces_the_same_match()
	_test_mulligan_waits_for_both_sides()
	_test_mulligan_never_returns_the_same_cards()
	_test_mulligan_is_order_independent()
	_test_mulligan_match_replays_from_the_record()
	_test_deck_code_round_trips()
	_test_preset_decks_are_legal()
	_test_online_resume_store_round_trips()
	_test_match_stats_accumulate()


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
	# 期待値を定数で持つと、カードを1枚足すたびにこのテストも書き換えることになる。
	# 守りたいのは「pck内で .tres が .tres.remap になっても全件読める」ことなので、
	# data/cards/ のファイル数と突き合わせる(Web版で0件になる不具合が出るのはここ)。
	var expected := _count_card_files()
	_assert.call(
		cards.size() == expected,
		"CardLibrary should load %d cards, got %d" % [expected, cards.size()]
	)
	for card in cards:
		_assert.call(card.cost > 0, "card %s should have a positive cost" % card.id)
		_assert.call(card.total_sand > 0, "card %s should have a positive total" % card.id)


## 一覧の並び替え(GameDesign.md 9章)。コスト順・追加順のどちらも全件を返し、
## 追加順の番号が重複しないことを見る(重複するとどちらが先か決まらない)。
func _test_card_orders() -> void:
	var total := CardLibrary.all_cards().size()
	var by_cost := CardLibrary.sorted_by_cost()
	var by_pool := CardLibrary.sorted_by_pool_index()
	_assert.call(by_cost.size() == total, "sorted_by_cost should return every card")
	_assert.call(by_pool.size() == total, "sorted_by_pool_index should return every card")
	for i in range(1, by_cost.size()):
		_assert.call(
			by_cost[i - 1].cost <= by_cost[i].cost, "sorted_by_cost should be ascending at %d" % i
		)
	var seen: Dictionary = {}
	for card in by_pool:
		_assert.call(card.pool_index > 0, "card %s should have a pool_index" % card.id)
		_assert.call(
			not seen.has(card.pool_index),
			"pool_index %d is used twice (%s)" % [card.pool_index, card.id]
		)
		seen[card.pool_index] = true


## data/cards/ に置かれている**集められる**カードの数。エクスポート後は `.tres.remap` に
## なるため、`.remap` を取り除いた名前で数える(CardLibrary と同じ判定)。
## トークンは all_cards() が返さないので、ここでも数えない。
func _count_card_files() -> int:
	var dir := DirAccess.open("res://data/cards")
	if dir == null:
		return 0
	var found := 0
	for file in dir.get_files():
		var base := file.trim_suffix(".remap")
		if not base.ends_with(".tres"):
			continue
		var card: CardData = load("res://data/cards/" + base)
		if card != null and not card.is_token:
			found += 1
	return found


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
	# 先手3枚・後手4枚で配り、先手は自分の1ターン目からドローする(GameDesign.md 2章)。
	_assert.call(state.hand[MatchState.Side.A].size() == 4, "first player draws on turn 1")
	_assert.call(state.hand[MatchState.Side.B].size() == 4, "second player should hold 4 cards")
	state.end_turn()
	_assert.call(state.current_turn == MatchState.Side.B, "turn should pass to the second player")
	_assert.call(state.hand[MatchState.Side.B].size() == 5, "second player draws on their turn")
	state.end_turn()
	_assert.call(state.hand[MatchState.Side.A].size() == 5, "first player draws every turn")


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


func _test_play_card_cannot_overwrite_an_occupied_slot() -> void:
	var state := _new_match()
	_force_play(state, MatchState.Side.A, "sand", 0)
	state.hand[MatchState.Side.A] = [_card("wall")]
	state.mana[MatchState.Side.A] = MatchState.MAX_MANA
	_assert.call(
		not state.play_card(MatchState.Side.A, 0, 0), "playing onto an occupied slot should fail"
	)
	var unit: CardInstance = state.board[MatchState.Side.A][0]
	_assert.call(unit.data.id == "sand", "the existing unit should stay on the slot")
	_assert.call(
		state.graveyard[MatchState.Side.A].is_empty(), "nothing should be sent to the graveyard"
	)
	_assert.call(state.hand[MatchState.Side.A].size() == 1, "the card should stay in hand")
	for slot in range(1, MatchState.BOARD_SIZE):
		_force_play(state, MatchState.Side.A, "sand", slot)
	state.hand[MatchState.Side.A] = [_card("wall")]
	state.mana[MatchState.Side.A] = MatchState.MAX_MANA
	_assert.call(
		not state.can_play(MatchState.Side.A, 0), "a full board should make every card unplayable"
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


## デッキの保存と読み込み。実データを壊さないよう、必ずバックアップ→上書き→復元で往復する。
func _test_card_deck_save_round_trips() -> void:
	var backup := ""
	var had_file := FileAccess.file_exists(CardDeckSave.SAVE_PATH)
	if had_file:
		backup = FileAccess.open(CardDeckSave.SAVE_PATH, FileAccess.READ).get_as_text()

	var default_deck := CardDeckSave.default_deck()
	_assert.call(
		default_deck.size() == MatchState.DECK_SIZE,
		"the default deck should hold exactly %d cards" % MatchState.DECK_SIZE
	)
	for card in default_deck:
		var copies := 0
		for entry in default_deck:
			if entry == card:
				copies += 1
		_assert.call(copies <= CardDeckSave.COPY_LIMIT, "the default deck must obey the copy limit")

	var deck: Array = []
	for i in MatchState.DECK_SIZE:
		deck.append(CardLibrary.all_cards()[i % 10])
	# デッキは何個でも保存でき、対局で使うものは選択の初期値として覚える(GameDesign.md 9章)。
	CardDeckSave.save_decks([])
	CardDeckSave.add_deck("いち", deck)
	CardDeckSave.add_deck("に", CardDeckSave.default_deck())
	var decks := CardDeckSave.list_decks()
	_assert.call(decks.size() == 2, "both saved decks should load back")
	_assert.call(
		CardLibrary.ids_from_deck(decks[0]["cards"]) == CardLibrary.ids_from_deck(deck),
		"a saved deck should load back unchanged"
	)
	CardDeckSave.set_selected_index(1)
	_assert.call(
		(
			CardLibrary.ids_from_deck(CardDeckSave.selected_deck())
			== CardLibrary.ids_from_deck(CardDeckSave.default_deck())
		),
		"the selected deck should be the one the picker confirmed"
	)
	CardDeckSave.move_deck(0, 1)
	_assert.call(
		CardDeckSave.list_decks()[1]["name"] == "いち", "reordering should swap the two decks"
	)
	CardDeckSave.remove_deck(0)
	_assert.call(CardDeckSave.list_decks().size() == 1, "deleting should drop exactly one deck")
	_assert.call(
		CardDeckSave.selected_index() == 0,
		"the selection should fall back into range after a delete"
	)

	if had_file:
		FileAccess.open(CardDeckSave.SAVE_PATH, FileAccess.WRITE).store_string(backup)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CardDeckSave.SAVE_PATH))


## 同じデッキと同じ種から始め、同じ手を流せば同じ盤面になること。
## オンライン対戦は両者がこの再現性の上で同じ対局を進め、リプレイも同じ経路で再生する。
func _test_same_seed_reproduces_the_same_match() -> void:
	var deck_a := _deck_of("sand")
	var deck_b := _deck_of("sword")
	var seed_value := 20260827

	var live := MatchState.new()
	live.start_match(deck_a, deck_b, MatchState.Side.A, seed_value)
	var recorded: Array = []
	var cpu := CardCpuStrategy.new()
	var guard := 0
	while not live.is_match_over() and guard < 400:
		guard += 1
		var action := cpu.choose_action(live, live.current_turn)
		recorded.append(action)
		MatchAction.apply(live, action)
	_assert.call(live.is_match_over(), "the recorded match should have reached an end")

	var replay := MatchState.new()
	replay.start_match(deck_a, deck_b, MatchState.Side.A, seed_value)
	for action in recorded:
		MatchAction.apply(replay, action)
	_assert.call(
		(
			replay.hp[MatchState.Side.A] == live.hp[MatchState.Side.A]
			and replay.hp[MatchState.Side.B] == live.hp[MatchState.Side.B]
		),
		"replaying the same actions should reach the same hp"
	)
	_assert.call(replay.winner == live.winner, "replaying should reach the same winner")
	_assert.call(
		replay.turn_count == live.turn_count, "replaying should take the same number of turns"
	)
	for side in [MatchState.Side.A, MatchState.Side.B]:
		for slot in MatchState.BOARD_SIZE:
			var a: CardInstance = live.board[side][slot]
			var b: CardInstance = replay.board[side][slot]
			var same := (
				(a == null and b == null)
				or (a != null and b != null and a.data == b.data and a.health == b.health)
			)
			_assert.call(same, "replaying should reach the same board at %d/%d" % [side, slot])


## 20種すべてを1枚ずつ並べた検証用デッキ(引き直したカードを見分けるため)。
func _mixed_deck() -> Array:
	var cards: Array = []
	for card in CardLibrary.all_cards():
		cards.append(card)
		if cards.size() >= MatchState.DECK_SIZE:
			break
	return cards


func _new_mulligan_match() -> MatchState:
	var state := MatchState.new()
	state.start_match(_mixed_deck(), _mixed_deck(), MatchState.Side.A, 777, true, true)
	return state


func _test_mulligan_waits_for_both_sides() -> void:
	var state := _new_mulligan_match()
	_assert.call(state.mulligan_pending, "the match should wait for the mulligan")
	_assert.call(state.turn_count == 0, "no turn should begin before the mulligan is settled")
	_assert.call(
		state.hand[MatchState.Side.A].size() == MatchState.FIRST_PLAYER_HAND,
		"the first player should hold the opening hand during the mulligan"
	)
	state.mulligan(MatchState.Side.A, [0])
	_assert.call(state.mulligan_pending, "one side alone should not settle the mulligan")
	_assert.call(state.turn_count == 0, "the turn should not begin until both sides choose")
	state.mulligan(MatchState.Side.B, [])
	_assert.call(not state.mulligan_pending, "both choices should settle the mulligan")
	_assert.call(state.turn_count == 1, "the first turn should begin once both sides choose")
	_assert.call(
		state.hand[MatchState.Side.A].size() == MatchState.FIRST_PLAYER_HAND + 1,
		"the first player should draw for the turn after the mulligan"
	)


func _test_mulligan_never_returns_the_same_cards() -> void:
	var state := _new_mulligan_match()
	var before: Array = state.hand[MatchState.Side.A].duplicate()
	var deck_size: int = state.deck[MatchState.Side.A].size()
	var indices: Array = []
	for i in before.size():
		indices.append(i)
	state.mulligan(MatchState.Side.A, indices)
	state.mulligan(MatchState.Side.B, [])
	var after: Array = state.hand[MatchState.Side.A]
	_assert.call(
		after.size() == before.size() + 1,
		"a full mulligan should keep the hand size (plus the turn draw)"
	)
	_assert.call(
		state.deck[MatchState.Side.A].size() == deck_size - 1,
		"the returned cards should go back into the deck"
	)
	for card in before:
		_assert.call(
			not after.has(card), "a mulliganed card should not come straight back to the hand"
		)


## 届いた順に適用すると山札の切り直しの順序が変わり、同じ対局が再現できなくなる。
func _test_mulligan_is_order_independent() -> void:
	var first := _new_mulligan_match()
	MatchAction.apply(first, MatchAction.mulligan(MatchState.Side.A, [0, 1]))
	MatchAction.apply(first, MatchAction.mulligan(MatchState.Side.B, [2]))

	var second := _new_mulligan_match()
	MatchAction.apply(second, MatchAction.mulligan(MatchState.Side.B, [2]))
	MatchAction.apply(second, MatchAction.mulligan(MatchState.Side.A, [0, 1]))

	for side in [MatchState.Side.A, MatchState.Side.B]:
		var a: Array = first.hand[side]
		var b: Array = second.hand[side]
		_assert.call(a.size() == b.size(), "both arrival orders should deal the same hand size")
		for i in a.size():
			_assert.call(a[i] == b[i], "both arrival orders should deal the same hand")
		var deck_a: Array = first.deck[side]
		var deck_b: Array = second.deck[side]
		for i in deck_a.size():
			_assert.call(deck_a[i] == deck_b[i], "both arrival orders should leave the same deck")


## 棋譜にマリガンが含まれていても、初期状態から手を並べ直せば同じ対局になる
## (リプレイ・観戦はこの経路で局面を作る)。
func _test_mulligan_match_replays_from_the_record() -> void:
	var deck_a := _deck_of("sand")
	var deck_b := _deck_of("sword")
	var seed_value := 20260828
	var cpu := CardCpuStrategy.new()

	var live := MatchState.new()
	live.start_match(deck_a, deck_b, MatchState.Side.A, seed_value, MatchState.COIN_ENABLED, true)
	var recorded: Array = []
	for side in [MatchState.Side.B, MatchState.Side.A]:
		var choice := MatchAction.mulligan(side, cpu.choose_mulligan(live, side))
		recorded.append(choice)
		MatchAction.apply(live, choice)
	_assert.call(not live.mulligan_pending, "both mulligans should settle the opening")
	var guard := 0
	while not live.is_match_over() and guard < 400:
		guard += 1
		var action := cpu.choose_action(live, live.current_turn)
		recorded.append(action)
		MatchAction.apply(live, action)
	_assert.call(live.is_match_over(), "the recorded match should have reached an end")
	_assert.call(
		MatchAction.contains_mulligan(recorded), "the record should be detected as a mulligan game"
	)

	var replay := MatchState.new()
	replay.start_match(
		deck_a,
		deck_b,
		MatchState.Side.A,
		seed_value,
		MatchState.COIN_ENABLED,
		MatchAction.contains_mulligan(recorded)
	)
	for action in recorded:
		MatchAction.apply(replay, action)
	_assert.call(
		(
			replay.hp[MatchState.Side.A] == live.hp[MatchState.Side.A]
			and replay.hp[MatchState.Side.B] == live.hp[MatchState.Side.B]
		),
		"replaying a mulligan game should reach the same hp"
	)
	_assert.call(replay.winner == live.winner, "replaying a mulligan game should reach the winner")


## デッキの中身は指紋・テキストのどちらでも往復できること、壊れた入力で例外を
## 出さないこと(GameDesign.md 9章)。画面へ出す8桁のコードは中身を持たないため、
## ここで測るのは預ける中身そのものになる。
func _test_deck_code_round_trips() -> void:
	for preset in CardPresetDecks.PRESETS:
		var deck := CardPresetDecks.deck_of(preset["id"])
		var before := CardLibrary.ids_from_deck(deck)
		before.sort()
		for back: Array in [
			CardDeckCode.deck_from_fingerprint(CardDeckCode.fingerprint(deck)),
			CardDeckCode.from_text(CardDeckCode.to_text(deck))
		]:
			_assert.call(
				back.size() == MatchState.DECK_SIZE,
				"decoding %s should give 20 cards" % preset["id"]
			)
			var after := CardLibrary.ids_from_deck(back)
			after.sort()
			_assert.call(before == after, "decoding %s should give the same cards" % preset["id"])
	for broken in ["", "HG1-", "HG1-!!!!", "nope", "HG1-QUJD"]:
		_assert.call(
			CardDeckCode.deck_from_fingerprint(broken).is_empty(),
			"a broken fingerprint should decode to nothing"
		)
	for broken_text in ["", "sand", "sand*99", "nosuchcard*2", "sand*2"]:
		_assert.call(
			CardDeckCode.from_text(broken_text).is_empty(),
			"a broken deck text should decode to nothing"
		)
	# 8桁の数字であること(DeckCodeService が発行する形)。
	var issued := DeckCodeService.random_code()
	_assert.call(
		issued.length() == DeckCodeService.CODE_LENGTH and issued.is_valid_int(),
		"a deck code should be %d digits" % DeckCodeService.CODE_LENGTH
	)
	_assert.call(
		RoomMatch.random_code().length() == RoomMatch.CODE_LENGTH,
		"a room code should be %d digits" % RoomMatch.CODE_LENGTH
	)


## プリセットは3つとも20枚・同名2枚までに収まっていること(GameDesign.md 18章)。
func _test_preset_decks_are_legal() -> void:
	for preset in CardPresetDecks.PRESETS:
		var deck := CardPresetDecks.deck_of(preset["id"])
		_assert.call(
			deck.size() == MatchState.DECK_SIZE, "preset %s should hold 20 cards" % preset["id"]
		)
		for card: CardData in deck:
			_assert.call(
				deck.count(card) <= CardDeckSave.COPY_LIMIT,
				"preset %s should not hold more than 2 copies of %s" % [preset["id"], card.id]
			)


## 切断からの復帰(GameDesign.md 11章)で覚えておく内容の往復。
## `user://` の実データを壊さないよう、既存の中身を控えてから書き、最後に戻す。
func _test_online_resume_store_round_trips() -> void:
	var backup := ""
	var had_file := FileAccess.file_exists(OnlineResume.SAVE_PATH)
	if had_file:
		var file := FileAccess.open(OnlineResume.SAVE_PATH, FileAccess.READ)
		if file != null:
			backup = file.get_as_text()
			file.close()

	OnlineResume.clear()
	_assert.call(OnlineResume.pending().is_empty(), "no match should be remembered after clear")
	OnlineResume.remember("m_test", MatchState.Side.B, true, "uid-foe")
	var record := OnlineResume.pending()
	_assert.call(record.get("match_id", "") == "m_test", "the match id should round trip")
	_assert.call(int(record.get("side", -1)) == MatchState.Side.B, "the side should round trip")
	_assert.call(bool(record.get("is_room", false)), "the match kind should round trip")
	OnlineResume.clear()
	_assert.call(OnlineResume.pending().is_empty(), "clearing should forget the match")

	if had_file:
		var file := FileAccess.open(OnlineResume.SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(backup)
			file.close()


## 戦績(GameDesign.md 19章)。`reset_for_test()` を通すため `user://` へは書かない。
func _test_match_stats_accumulate() -> void:
	MatchStats.reset_for_test({})
	var deck := CardPresetDecks.basic()
	MatchStats.record("uid-a", CurrencyRules.MatchKind.CPU, true, 20, deck)
	MatchStats.record("uid-a", CurrencyRules.MatchKind.CPU, false, 30, deck)
	MatchStats.record("uid-a", CurrencyRules.MatchKind.RANDOM, true, 10, deck)
	MatchStats.record("uid-b", CurrencyRules.MatchKind.CPU, true, 40, deck)

	var all := MatchStats.totals("uid-a")
	_assert.call(int(all["games"]) == 3, "the owner should have three games")
	_assert.call(int(all["wins"]) == 2, "the owner should have two wins")
	_assert.call(int(all["turns"]) == 60, "turns should add up")
	var cpu := MatchStats.totals("uid-a", CurrencyRules.MatchKind.CPU)
	_assert.call(int(cpu["games"]) == 2, "cpu games should be counted apart")
	var other := MatchStats.totals("uid-b")
	_assert.call(int(other["games"]) == 1, "accounts should not share their records")

	# 同じカードを2枚積んでも1局は1局(GameDesign.md 19章)。
	var rows := MatchStats.cards("uid-a")
	_assert.call(not rows.is_empty(), "cards should be recorded")
	for row: Dictionary in rows:
		_assert.call(int(row["games"]) == 3, "a card in every deck should show three games")
	var decks := MatchStats.decks("uid-a")
	_assert.call(decks.size() == 1, "the same build should be one deck row")
	_assert.call(int(decks[0]["games"]) == 3, "the build should show three games")
