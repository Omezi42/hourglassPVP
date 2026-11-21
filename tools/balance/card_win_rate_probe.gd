class_name CardWinRateProbe
extends RefCounted
## カード1枚の勝率を測る(BalanceReport_v5.md 2章)。
##
##   注目デッキ = そのカード2枚 + 残り28枚をランダム(注目カードを除く)
##   相手デッキ = 30枚すべてランダム(注目カードを除く)
##
## として直接ぶつけ、先手・後手を1戦ごとに入れ替える。

const COPY_LIMIT := 2
const FOCUS_COPIES := 2

## 直前の `measure()` で、注目カードを初めて出した瞬間にHPで負けていた局の数と、そのうち勝った数
## (逆転用の札の値付け。NextCardSet.md・BalanceReport_v5.md)。
var behind_games := 0
var behind_wins := 0

var _rng := RandomNumberGenerator.new()
var _cards: Array[CardData] = []


func _init() -> void:
	_cards = CardLibrary.all_cards()


## 決着しなかった対局は負けとして数える。
func measure(focus: CardData, games: int, seed_value: int) -> float:
	_rng.seed = seed_value
	var wins := 0
	behind_games = 0
	behind_wins = 0
	for game in games:
		var focus_first: bool = game % 2 == 0
		var focus_deck := _deck_with(focus)
		var plain_deck := _deck_without(focus)
		var deck_a: Array = focus_deck if focus_first else plain_deck
		var deck_b: Array = plain_deck if focus_first else focus_deck
		var focus_side: int = MatchState.Side.A if focus_first else MatchState.Side.B
		var played := {}
		var winner := _play_one(deck_a, deck_b, focus, focus_side, played)
		if winner == focus_side:
			wins += 1
		if played.get("behind", false):
			behind_games += 1
			if winner == focus_side:
				behind_wins += 1
	return float(wins) / float(games)


## `played` へ、注目カードを初めて出した瞬間に出した側がHPで負けていたか("behind")を書く。
func _play_one(
	deck_a: Array, deck_b: Array, focus: CardData, focus_side: int, played: Dictionary
) -> int:
	var state := MatchState.new()
	var cpu_a := CardCpuStrategy.new()
	var cpu_b := CardCpuStrategy.new()
	var note := func(side: int, card: CardData) -> void:
		if side == focus_side and card == focus and not played.has("behind"):
			played["behind"] = state.hp[side] < state.hp[MatchState.other_side(side)]
	state.unit_played.connect(
		func(side: int, slot: int) -> void: note.call(side, state.board[side][slot].data)
	)
	state.spell_cast.connect(note)
	state.start_match(deck_a, deck_b, MatchState.Side.A, _rng.randi_range(1, 1 << 30))
	while not state.is_match_over():
		var side := state.current_turn
		var cpu: CardCpuStrategy = cpu_a if side == MatchState.Side.A else cpu_b
		cpu.take_turn(state, side)
	return state.winner


func _deck_with(focus: CardData) -> Array:
	var deck: Array = []
	for i in FOCUS_COPIES:
		deck.append(focus)
	deck.append_array(_random_pool(focus).slice(0, MatchState.DECK_SIZE - FOCUS_COPIES))
	return deck


func _deck_without(focus: CardData) -> Array:
	return _random_pool(focus).slice(0, MatchState.DECK_SIZE)


func _random_pool(exclude: CardData) -> Array:
	var pool: Array = []
	for card in _cards:
		if card == exclude:
			continue
		for i in COPY_LIMIT:
			pool.append(card)
	for i in range(pool.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool
