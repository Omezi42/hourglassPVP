extends RefCounted
## 効果の連鎖の網羅(GameDesign.md 6章「反転」・8章)。ルールの正しさは見ない。
## 全カードを、全種類の砂時計で埋めた盤面へ総当たりで出し・返し・殴って、
## 連鎖が `CardEffectResolver` の上限へ届かない(=止まらなくならない)ことだけを確かめる。
## エラーで落ちた組み合わせは、ログの SCRIPT ERROR として check.sh が拾う。

const SIDE_A := MatchState.Side.A
const SIDE_B := MatchState.Side.B
## 両陣を同じ砂時計で埋める枠数。最後の1枠は出すカードのために空ける。
const FILLED_SLOTS := MatchState.BOARD_SIZE - 1
const SEED := 20261011
## 出したあとに回す手番の数(落砂・相手の反転への反応を通すため)。
const TURNS_AFTER_PLAY := 2
## 失敗した組み合わせをいくつまで名指しするか。
const REPORTED_PAIRS := 5
## 保険の確認で作る駒の総量。上限の深さに届く前に砂が尽きないだけの量。
const RUNAWAY_SAND := 100000
## 正規の連鎖の深さに対して、上限が持つべき余裕の倍率。
const HEADROOM := 2

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_the_guard_stops_runaway_chains()
	_test_every_card_against_every_board_settles()


## 保険そのものの確認。止まらない連鎖を3つの形で作り、上限で1度だけ打ち切られることを見る。
func _test_the_guard_stops_runaway_chains() -> void:
	print("(次の「効果の連鎖が上限に達した」ERROR 3件は、保険の確認のための意図したもの)")
	# 反転のたびに自分を返し直す(深さで止まる)。
	var flipper := _runaway_card(
		CardEnums.Trigger.ON_FLIP, CardEnums.EffectTarget.SELF, CardEnums.EffectType.SWAP_STATS
	)
	var state := _runaway_state(flipper, 1)
	state.flip(SIDE_A, 0)
	_assert_cut_off(state, "反転の無限ループ", true)
	# 被弾のたびに自分を削る。1段に積む呼び出しが最も多い経路で、上限の深さでもスタックが溢れないこと。
	var self_hitter := _runaway_card(
		CardEnums.Trigger.ON_DAMAGED, CardEnums.EffectTarget.SELF, CardEnums.EffectType.DAMAGE_UNIT
	)
	state = _runaway_state(self_hitter, 1)
	state.damage_unit(SIDE_A, 0, 1)
	_assert_cut_off(state, "被弾の無限ループ", true)
	# 被弾のたびに味方すべてを削る(枝分かれするため、深さの打ち切りだけでは終わらず回数で止まる)。
	var splasher := _runaway_card(
		CardEnums.Trigger.ON_DAMAGED,
		CardEnums.EffectTarget.ALL_ALLY_UNITS,
		CardEnums.EffectType.DAMAGE_UNIT
	)
	state = _runaway_state(splasher, MatchState.BOARD_SIZE)
	state.damage_unit(SIDE_A, 0, 1)
	_assert_cut_off(state, "枝分かれする無限ループ", false)


func _runaway_card(trigger: int, target: int, effect_type: int) -> CardData:
	var effect := CardEffectData.new()
	effect.trigger = trigger
	effect.target = target
	effect.effect_type = effect_type
	effect.value = 1
	var card := CardData.new()
	card.id = "runaway_test"
	card.total_sand = RUNAWAY_SAND
	card.effects = [effect]
	return card


func _runaway_state(card: CardData, count: int) -> MatchState:
	var state := _new_state(CardLibrary.find_by_id("mote"))
	for slot in count:
		var unit := CardInstance.new(card)
		unit.summoned_this_turn = false
		state.board[SIDE_A][slot] = unit
	return state


func _assert_cut_off(state: MatchState, label: String, by_depth: bool) -> void:
	var resolver: CardEffectResolver = state._effects
	_assert.call(
		resolver.overflow_count == 1, "%sは1度だけ打ち切られる(%d)" % [label, resolver.overflow_count]
	)
	if by_depth:
		_assert.call(
			resolver.peak_depth == CardEffectResolver.MAX_CHAIN_DEPTH, "%sは上限の深さで止まる" % label
		)
	else:
		_assert.call(
			resolver.peak_steps == CardEffectResolver.MAX_CHAIN_STEPS, "%sは上限の回数で止まる" % label
		)
	state.free()


func _test_every_card_against_every_board_settles() -> void:
	var cards := CardLibrary.all_cards()
	var fillers: Array[CardData] = []
	for card in cards:
		if not card.is_spell:
			fillers.append(card)
	var cases := 0
	var peak_depth := 0
	var peak_steps := 0
	var overflowed: Array[String] = []
	for played in cards:
		for filler in fillers:
			var state := _new_state(filler)
			_fill_boards(state, filler)
			_play_out(state, played)
			var resolver: CardEffectResolver = state._effects
			peak_depth = maxi(peak_depth, resolver.peak_depth)
			peak_steps = maxi(peak_steps, resolver.peak_steps)
			if resolver.overflow_count > 0 and overflowed.size() < REPORTED_PAIRS:
				overflowed.append("%s → %s の盤面" % [played.id, filler.id])
			cases += 1
			state.free()
	print("効果の連鎖の網羅: %d通り・最深%d段・最長%d回" % [cases, peak_depth, peak_steps])
	_assert.call(overflowed.is_empty(), "連鎖が上限へ届いた組み合わせ: %s" % [overflowed])
	# 正規の連鎖が上限の近くまで伸びたら、上限の値を見直す合図(打ち切りは不具合のときだけにするため)。
	_assert.call(
		peak_depth * HEADROOM <= CardEffectResolver.MAX_CHAIN_DEPTH,
		"正規の連鎖の深さ(%d)が上限に近い" % peak_depth
	)


func _new_state(filler: CardData) -> MatchState:
	var deck: Array = []
	for i in MatchState.DECK_SIZE:
		deck.append(filler)
	var state := MatchState.new()
	state.start_match(deck, deck.duplicate(), SIDE_A, SEED)
	return state


func _fill_boards(state: MatchState, filler: CardData) -> void:
	for side in [SIDE_A, SIDE_B]:
		for slot in FILLED_SLOTS:
			var unit := CardInstance.new(filler)
			unit.summoned_this_turn = false
			state.board[side][slot] = unit


## 出す → 自陣を全部返す → 反転権で相手を返す → 殴れるだけ殴る → 手番を回して相手も同じことをする。
func _play_out(state: MatchState, played: CardData) -> void:
	state.hand[SIDE_A].insert(0, played)
	state.mana[SIDE_A] = MatchState.MAX_MANA
	state.max_mana[SIDE_A] = MatchState.MAX_MANA
	if played.is_spell:
		state.cast_spell(SIDE_A, 0)
	else:
		state.play_card(SIDE_A, 0, FILLED_SLOTS)
	_act(state, SIDE_A)
	for turn in TURNS_AFTER_PLAY:
		if state.is_match_over():
			return
		state.end_turn()
		_act(state, state.current_turn)


func _act(state: MatchState, side: int) -> void:
	for slot in MatchState.BOARD_SIZE:
		if state.can_flip(side, slot):
			state.flip(side, slot)
	var foe := MatchState.other_side(side)
	for slot in MatchState.BOARD_SIZE:
		if state.board[foe][slot] != null:
			state.use_flip_right(side, foe, slot)
			break
	for slot in MatchState.BOARD_SIZE:
		if state.is_match_over():
			return
		var targets := state.attackable_slots(foe)
		var target_slot: int = -1 if targets.is_empty() else targets[0]
		if state.can_attack(side, slot, target_slot):
			state.attack(side, slot, target_slot)
