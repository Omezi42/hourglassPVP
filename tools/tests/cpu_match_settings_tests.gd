extends RefCounted
## CPU戦の設定(GameDesign.md 13章「CPU戦の設定」・Architecture.md 8.2節)。
## 練習ルールの判定と、HPを変えた対局の最大HP(回復の上限・HPの反転の基準)を見張る。

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_defaults_are_not_practice()
	_test_rule_changes_are_practice()
	_test_matchup_changes_are_not_practice()
	_test_first_side_follows_choice()
	_test_named_cpu_deck_is_used()
	_test_heal_caps_at_raised_max_hp()


func _test_defaults_are_not_practice() -> void:
	_assert.call(
		not CpuMatchSettings.new().is_practice(), "default settings should not be practice"
	)


func _test_rule_changes_are_practice() -> void:
	var changes: Array[Callable] = [
		func(s: CpuMatchSettings) -> void: s.own_hp = 36,
		func(s: CpuMatchSettings) -> void: s.foe_hp = 12,
		func(s: CpuMatchSettings) -> void: s.mulligan = false,
		func(s: CpuMatchSettings) -> void: s.coin = false,
		func(s: CpuMatchSettings) -> void: s.reveal_hand = true,
	]
	for i in changes.size():
		var settings := CpuMatchSettings.new()
		changes[i].call(settings)
		_assert.call(settings.is_practice(), "rule change %d should make the match practice" % i)


func _test_matchup_changes_are_not_practice() -> void:
	var settings := CpuMatchSettings.new()
	settings.first = CpuMatchSettings.First.CPU
	settings.foe_deck = "rush"
	settings.speed = CpuMatchSettings.Speed.FAST
	_assert.call(not settings.is_practice(), "matchup choices should keep rewards")


func _test_first_side_follows_choice() -> void:
	var rng := RandomNumberGenerator.new()
	var settings := CpuMatchSettings.new()
	_assert.call(settings.first_side(rng) == MatchState.Side.A, "default: player goes first")
	settings.first = CpuMatchSettings.First.CPU
	_assert.call(settings.first_side(rng) == MatchState.Side.B, "second: CPU goes first")


func _test_named_cpu_deck_is_used() -> void:
	var settings := CpuMatchSettings.new()
	settings.foe_deck = "heavy"
	var deck := settings.pick_foe_deck(RandomNumberGenerator.new())
	_assert.call(
		deck["name"] == CardCpuDecks.foe_name_of("heavy"), "named CPU deck should be picked"
	)
	_assert.call(
		(deck["cards"] as Array).size() == MatchState.DECK_SIZE, "named CPU deck should be 30 cards"
	)


func _test_heal_caps_at_raised_max_hp() -> void:
	var state := MatchState.new()
	state.start_match(CardPresetDecks.basic(), CardPresetDecks.basic(), MatchState.Side.A, 1)
	state.hp_max[MatchState.Side.A] = 36
	state.hp[MatchState.Side.A] = 30
	state.heal_player(MatchState.Side.A, 3)
	_assert.call(
		state.hp[MatchState.Side.A] == 33, "heal should not cut HP down to 24 when max is 36"
	)
	state.heal_player(MatchState.Side.A, 10)
	_assert.call(state.hp[MatchState.Side.A] == 36, "heal should cap at the raised max HP")
	state.free()
