extends SceneTree
## 1枚のカードの強さを測る。混成デッキ全体の平均勝率(run_v5_simulation.gd)では、
## 20種のプールから20枚を引くと1デッキに13種前後が入ってしまい、
## カード1枚の差が勝率へほとんど現れない。そこで
##
##   注目デッキ = そのカード2枚 + 残り18枚をランダム(注目カードを除く)
##   相手デッキ = 20枚すべてランダム(注目カードを除く)
##
## として直接ぶつけ、先手・後手を交互に入れ替えて測る。
##
## 使い方:
##   Godot --headless --path . --script tools/balance/run_v5_card_check.gd -- \
##       focus=hammer games=600 seed=42 cost=5 total=2
##
## cost / total を与えると、その値へ**メモリ上だけ**書き換えて測る(.tres は変えない)。
## `sweep=cost1,cost2,...` を与えると、その各コストで測って一覧にする。

const COPY_LIMIT := 2
const FOCUS_COPIES := 2

var _rng := RandomNumberGenerator.new()
var _cards: Array[CardData] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var focus_id: String = args.get("focus", "")
	var games: int = int(args.get("games", "600"))
	var base_seed: int = int(args.get("seed", "42"))
	_cards = CardLibrary.all_cards()
	var focus := CardLibrary.find_by_id(focus_id)
	if focus == null:
		printerr("unknown card id: ", focus_id)
		quit(1)
		return

	if args.has("total"):
		focus.total_sand = int(args["total"])
	var costs: Array = []
	if args.has("sweep"):
		for value in str(args["sweep"]).split(","):
			costs.append(int(value))
	else:
		costs.append(int(args.get("cost", str(focus.cost))))

	var totals: Array = []
	if args.has("totals"):
		for value in str(args["totals"]).split(","):
			totals.append(int(value))
	else:
		totals.append(focus.total_sand)

	print("=== %s の値付け検証(各%d戦)===" % [focus.display_name, games])
	print("効果: %s" % focus.describe())
	for cost in costs:
		for total in totals:
			focus.cost = cost
			focus.total_sand = total
			_rng.seed = base_seed
			var rate := _measure(focus, games)
			print("  コスト %d / 総量 %d -> 勝率 %.1f%%" % [cost, total, rate * 100.0])
	quit()


func _measure(focus: CardData, games: int) -> float:
	var wins := 0
	for game in games:
		var focus_first: bool = game % 2 == 0
		var focus_deck := _deck_with(focus)
		var plain_deck := _deck_without(focus)
		var deck_a: Array = focus_deck if focus_first else plain_deck
		var deck_b: Array = plain_deck if focus_first else focus_deck
		var winner := _play_one(deck_a, deck_b)
		if winner < 0:
			continue
		var focus_side: int = MatchState.Side.A if focus_first else MatchState.Side.B
		if winner == focus_side:
			wins += 1
	return float(wins) / float(games)


func _play_one(deck_a: Array, deck_b: Array) -> int:
	var state := MatchState.new()
	var cpu_a := CardCpuStrategy.new()
	var cpu_b := CardCpuStrategy.new()
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


func _parse_args() -> Dictionary:
	var parsed: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			parsed[pair[0]] = pair[1]
	return parsed
