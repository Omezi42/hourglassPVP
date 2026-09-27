extends SceneTree
## CPUデッキ(GameDesign.md 13章、`CardCpuDecks`)どうしの総当たり。ソロモード(27章)は
## 8つを順に相手取るため、1つだけ突出して強い/弱いと段ごとの手応えが崩れる。
## 各組を先手・後手入れ替えて回し、デッキごとの勝率と、ランダム混成デッキ相手の勝率を出す。
##
## 使い方:
##   Godot --headless --path . --script tools/balance/run_cpu_deck_league.gd -- \
##       games=100 seed=42
##
## `trial=id,id,...`(15種・各2枚)を与えると、表を変えずにその候補を8つとランダム混成へぶつける。

const COPY_LIMIT := 2

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var games: int = int(args.get("games", "100"))
	_rng.seed = int(args.get("seed", "42"))
	if args.has("trial"):
		_run_trial(str(args["trial"]).split(","), games)
		quit()
		return
	var ids := CardCpuDecks.deck_ids()
	var wins := {}
	var played := {}
	var vs_random := {}
	for id in ids:
		wins[id] = 0
		played[id] = 0
		vs_random[id] = 0
	var table := {}

	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: String = ids[i]
			var b: String = ids[j]
			var a_wins := 0
			var decisive := 0
			for g in games:
				var a_first := g % 2 == 0
				var winner_is_a := _play(CardCpuDecks.deck_of(a), CardCpuDecks.deck_of(b), a_first)
				if winner_is_a < 0:
					continue
				decisive += 1
				a_wins += winner_is_a
			wins[a] += a_wins
			wins[b] += decisive - a_wins
			played[a] += decisive
			played[b] += decisive
			table["%s/%s" % [a, b]] = float(a_wins) / maxf(decisive, 1)

	for id in ids:
		var w := 0
		var d := 0
		for g in games:
			var r := _play(CardCpuDecks.deck_of(id), _random_deck(), g % 2 == 0)
			if r < 0:
				continue
			d += 1
			w += r
		vs_random[id] = float(w) / maxf(d, 1)

	print("=== CPUデッキ総当たり(各組%d戦・先後交互) ===" % games)
	for id in ids:
		print(
			(
				"%-8s 総当たり %5.1f%%  対ランダム %5.1f%%"
				% [
					CardCpuDecks.name_of(id),
					float(wins[id]) / maxf(played[id], 1) * 100.0,
					vs_random[id] * 100.0
				]
			)
		)
	print("")
	print("--- 組ごと(左の勝率) ---")
	for key: String in table:
		var pair := key.split("/")
		print(
			(
				"%s vs %s: %5.1f%%"
				% [CardCpuDecks.name_of(pair[0]), CardCpuDecks.name_of(pair[1]), table[key] * 100.0]
			)
		)
	quit()


func _run_trial(card_ids: PackedStringArray, games: int) -> void:
	var counts := {}
	for id in card_ids:
		counts[id] = COPY_LIMIT
	var trial := CardPresetDecks.build(counts)
	if trial.size() != MatchState.DECK_SIZE:
		printerr("trial deck has %d cards" % trial.size())
		return
	var total_wins := 0
	var total_decisive := 0
	for id in CardCpuDecks.deck_ids():
		var rate := _rate(trial, CardCpuDecks.deck_of(id), games)
		total_wins += rate[0]
		total_decisive += rate[1]
		print("候補 vs %-6s %5.1f%%" % [CardCpuDecks.name_of(id), _pct(rate)])
	print("候補 総当たり   %5.1f%%" % _pct([total_wins, total_decisive]))
	var w := 0
	var d := 0
	for g in games:
		var r := _play(trial, _random_deck(), g % 2 == 0)
		if r >= 0:
			d += 1
			w += r
	print("候補 対ランダム %5.1f%%" % _pct([w, d]))


func _rate(left: Array, right: Array, games: int) -> Array:
	var w := 0
	var d := 0
	for g in games:
		var r := _play(left, right, g % 2 == 0)
		if r >= 0:
			d += 1
			w += r
	return [w, d]


func _pct(rate: Array) -> float:
	return float(rate[0]) / maxf(rate[1], 1) * 100.0


## 左のデッキが勝てば1、負ければ0、引き分けは-1。
func _play(deck_left: Array, deck_right: Array, left_first: bool) -> int:
	var state := MatchState.new()
	var cpu_a := CardCpuStrategy.new()
	var cpu_b := CardCpuStrategy.new()
	var deck_a := deck_left if left_first else deck_right
	var deck_b := deck_right if left_first else deck_left
	state.start_match(deck_a, deck_b, MatchState.Side.A, _rng.randi_range(1, 1 << 30))
	if state.mulligan_pending:
		state.mulligan(MatchState.Side.A, cpu_a.choose_mulligan(state, MatchState.Side.A))
		state.mulligan(MatchState.Side.B, cpu_b.choose_mulligan(state, MatchState.Side.B))
	while not state.is_match_over():
		var side := state.current_turn
		var cpu: CardCpuStrategy = cpu_a if side == MatchState.Side.A else cpu_b
		cpu.take_turn(state, side)
	if state.winner < 0:
		return -1
	var left_side := MatchState.Side.A if left_first else MatchState.Side.B
	return 1 if state.winner == left_side else 0


func _random_deck() -> Array:
	var pool: Array = []
	for card in CardLibrary.all_cards():
		if not card.set_id.is_empty() and CardSetLibrary.price(card.set_id) <= 0:
			continue
		for i in COPY_LIMIT:
			pool.append(card)
	for i in range(pool.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, MatchState.DECK_SIZE)


func _parse_args() -> Dictionary:
	var parsed: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			parsed[pair[0]] = pair[1]
	return parsed
