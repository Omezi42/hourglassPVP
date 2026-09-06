extends RefCounted
## CPU戦の思考レベル(GameDesign.md 13章「CPU戦の思考レベル」)の検証。
## v5_rules_tests.gd が大きいため別ファイルへ切り出している。

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_all_difficulties_finish_a_match()
	_test_beginner_never_flips_or_uses_flip_right()
	_test_expert_avoids_a_lethal_flip()
	_test_expert_mulligan_is_more_aggressive_with_few_light_cards()
	_test_expert_coin_is_more_selective()
	_test_expert_coin_helps_reach_a_better_card()
	_test_expert_avoids_losing_a_guard_unit_in_a_bad_trade()
	_test_expert_avoids_wasting_damage_on_a_glass_shielded_enemy()


func _card(id: String) -> CardData:
	return CardLibrary.find_by_id(id)


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


## 3段階どれで自己対戦させても、貪欲法の骨格が壊れて手詰まりにならないことを確認する。
func _test_all_difficulties_finish_a_match() -> void:
	var difficulties: Array = [
		CardCpuStrategy.Difficulty.BEGINNER,
		CardCpuStrategy.Difficulty.NORMAL,
		CardCpuStrategy.Difficulty.EXPERT,
	]
	for difficulty in difficulties:
		var state := _new_match("sand", "sword")
		var cpu := CardCpuStrategy.new()
		cpu.difficulty = difficulty
		var turns := 0
		while not state.is_match_over() and turns < MatchState.MAX_TURNS + 5:
			cpu.take_turn(state, state.current_turn)
			turns += 1
		_assert.call(state.is_match_over(), "difficulty %d should still reach an end" % difficulty)


## 初級は貪欲法(生涯ダメージの比較)を一切通らないため、対局を通して
## 反転・反転権が一度も選ばれない(GameDesign.md 13章)。
func _test_beginner_never_flips_or_uses_flip_right() -> void:
	var state := _new_match("sand", "sword")
	var cpu := CardCpuStrategy.new()
	cpu.difficulty = CardCpuStrategy.Difficulty.BEGINNER
	var turns := 0
	var saw_flip := false
	while not state.is_match_over() and turns < MatchState.MAX_TURNS + 5:
		var performed: Array = cpu.take_turn(state, state.current_turn)
		for action in performed:
			if str(action.get("type", "")) in ["flip", "flip_right"]:
				saw_flip = true
		turns += 1
	_assert.call(not saw_flip, "beginner should never flip or use flip right")


## 上級は、反転した結果いま相手が持っている攻撃力でその場で仕留められるようになる
## 反転を避ける(GameDesign.md 13章)。中級はこの危険を見ないため同じ場面でも反転する。
func _test_expert_avoids_a_lethal_flip() -> void:
	var state := _new_match()
	var mine: CardInstance = _force_play(state, MatchState.Side.A, "sand", 0)
	mine.summoned_this_turn = false
	mine.drop_sand(3)  # total 5: health=2 / attack=3 → 反転で health=3 / attack=2(得な反転)
	var foe: CardInstance = _force_play(state, MatchState.Side.B, "sword", 0)
	foe.drop_sand(3)  # total 6: health=3 / attack=3(反転後の体力3を仕留められる攻撃力)

	var expert := CardCpuStrategy.new()
	expert.difficulty = CardCpuStrategy.Difficulty.EXPERT
	var risky: Dictionary = expert._choose_flip(state, MatchState.Side.A)
	_assert.call(
		risky.is_empty(),
		"expert should refuse a flip that would leave the unit dead to the foe's attack"
	)

	var normal := CardCpuStrategy.new()
	var accepted: Dictionary = normal._choose_flip(state, MatchState.Side.A)
	_assert.call(
		not accepted.is_empty(), "normal should still take the flip (the risk check is expert-only)"
	)


## 上級は、残す手札のコスト1〜2が少ないほど重いカードをより積極的に戻す
## (GameDesign.md 2章「マリガン」/13章)。中級以下はコストの上限だけで戻す。
func _test_expert_mulligan_is_more_aggressive_with_few_light_cards() -> void:
	var state := _new_match()
	# コスト3が1枚、あとはコスト6。軽いカード(コスト1〜2)は1枚も無い。
	state.hand[MatchState.Side.A] = [_card("sword"), _card("wall"), _card("wall"), _card("wall")]

	var normal := CardCpuStrategy.new()
	var normal_indices: Array = normal.choose_mulligan(state, MatchState.Side.A)
	_assert.call(
		normal_indices.size() == 3, "normal should keep the cost-3 card and mulligan the rest"
	)

	var expert := CardCpuStrategy.new()
	expert.difficulty = CardCpuStrategy.Difficulty.EXPERT
	var expert_indices: Array = expert.choose_mulligan(state, MatchState.Side.A)
	_assert.call(
		expert_indices.size() == 4,
		"expert should mulligan the cost-3 card too when the hand has no cost<=2 cards"
	)


## 中級以下は「あと1マナで出せる手があるか」だけでコインを切るため、使っても
## 出せる最善が変わらない場面でも切ってしまう。上級はそこを比べて温存する
## (GameDesign.md 13章)。
func _test_expert_coin_is_more_selective() -> void:
	var state := _new_match()
	state.current_turn = MatchState.Side.B
	state.mana[MatchState.Side.B] = 2
	state.coin_available[MatchState.Side.B] = true
	# コスト2のバニラしか無く、マナを3へ増やしても出せる最善は変わらない。
	state.hand[MatchState.Side.B] = [_card("sand"), _card("sand")]

	var normal := CardCpuStrategy.new()
	_assert.call(
		normal._should_use_coin(state, MatchState.Side.B),
		"normal should use the coin whenever reach covers a playable card, even without benefit"
	)

	var expert := CardCpuStrategy.new()
	expert.difficulty = CardCpuStrategy.Difficulty.EXPERT
	_assert.call(
		not expert._should_use_coin(state, MatchState.Side.B),
		"expert should skip the coin when it would not unlock a better card"
	)


## コインを使うことで実際により価値の高い1枚(設置効果を持つソード)へ手が届く場合、
## 上級もちゃんと切る。
func _test_expert_coin_helps_reach_a_better_card() -> void:
	var state := _new_match()
	state.current_turn = MatchState.Side.B
	state.mana[MatchState.Side.B] = 2
	state.coin_available[MatchState.Side.B] = true
	state.hand[MatchState.Side.B] = [_card("sand"), _card("sword")]

	var expert := CardCpuStrategy.new()
	expert.difficulty = CardCpuStrategy.Difficulty.EXPERT
	_assert.call(
		expert._should_use_coin(state, MatchState.Side.B),
		"expert should use the coin when it unlocks a higher-value card"
	)


## 上級は、相打ちで自分の守護持ちを失う交換を割り引く(GameDesign.md 13章)。
## 場に残ることで防いでいた被弾ぶんの近似であり、中級はこれを見ない。
func _test_expert_avoids_losing_a_guard_unit_in_a_bad_trade() -> void:
	var state := _new_match()
	var mine := CardInstance.new(_card("shield"))
	mine.drop_sand(2)  # total 4: health=2 / attack=2(守護持ち)
	var foe := CardInstance.new(_card("sand"))
	foe.drop_sand(3)  # total 5: health=2 / attack=3(相打ちで mine の体力2を上回る)

	var normal := CardCpuStrategy.new()
	var normal_value: float = normal._trade_value(mine, foe, MatchState.Side.A, state)
	_assert.call(normal_value > 0.0, "normal should see this trade as favorable")

	var expert := CardCpuStrategy.new()
	expert.difficulty = CardCpuStrategy.Difficulty.EXPERT
	var expert_value: float = expert._trade_value(mine, foe, MatchState.Side.A, state)
	_assert.call(
		expert_value < normal_value, "expert should discount a trade that costs a guard unit"
	)


## 上級は、ダメージ効果の対象で硝子が残っている相手を避け、実際に通る相手を選ぶ
## (GameDesign.md 13章)。中級は生涯ダメージが最大の駒を機械的に選ぶため、
## 硝子で無効化される一撃を選ぶことがある。
func _test_expert_avoids_wasting_damage_on_a_glass_shielded_enemy() -> void:
	var state := _new_match()
	var foe_side := MatchState.Side.B
	var glass_unit := CardInstance.new(_card("glass"))
	glass_unit.drop_sand(1)  # total 6: health=5 / attack=1、生涯ダメージが高い側
	state.board[foe_side][0] = glass_unit
	var plain_unit := CardInstance.new(_card("sand"))
	plain_unit.drop_sand(1)  # total 5: health=4 / attack=1、生涯ダメージはやや低い
	state.board[foe_side][1] = plain_unit
	_assert.call(
		glass_unit.lifetime_damage() > plain_unit.lifetime_damage(),
		"the glass-shielded unit must be the naive best target for this test to matter"
	)

	var hammer := _card("hammer")
	var normal := CardCpuStrategy.new()
	var normal_target: Dictionary = normal._effect_target(state, MatchState.Side.A, hammer)
	_assert.call(
		int(normal_target.get("slot", -1)) == 0,
		"normal should target the highest lifetime damage even though glass blocks it"
	)

	var expert := CardCpuStrategy.new()
	expert.difficulty = CardCpuStrategy.Difficulty.EXPERT
	var expert_target: Dictionary = expert._effect_target(state, MatchState.Side.A, hammer)
	_assert.call(
		int(expert_target.get("slot", -1)) == 1,
		"expert should skip the glass-shielded enemy and hit the one the damage actually lands on"
	)
