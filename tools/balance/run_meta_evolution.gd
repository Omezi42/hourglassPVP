extends SceneTree

## メタゲーム進化シミュレータ (tools/balance/run_meta_evolution.gd)
## デッキ集団を遺伝的アルゴリズム/自己対戦で進化させ、メタシェアの推移・硬直・多様性を定量分析する。

const DEFAULT_POPULATION := 32
const DEFAULT_GENERATIONS := 25
const DEFAULT_SEED := 100
const MAX_TURNS := 150

var _hourglass_cache: Dictionary = {}


func _init() -> void:
	call_deferred("_run_meta_evolution")


func _run_meta_evolution() -> void:
	var args := _parse_args()
	var pop_size: int = args.get("pop", DEFAULT_POPULATION)
	var generations: int = args.get("gen", DEFAULT_GENERATIONS)
	var sim_seed: int = args.get("seed", DEFAULT_SEED)
	var override_file: String = args.get("override", "")
	var out_dir: String = args.get("out", "tools/balance/out")
	var run_tag: String = args.get("tag", "baseline")

	seed(sim_seed)

	var all_cards := _load_all_hourglasses(override_file)
	if all_cards.is_empty():
		printerr("Error: No hourglasses loaded.")
		quit(1)
		return

	print("==================================================")
	print("Hourglass PvP Meta Evolution Simulator")
	print(
		(
			"Pop: %d | Gen: %d | Seed: %d | Tag: %s | Override: %s"
			% [pop_size, generations, sim_seed, run_tag, override_file]
		)
	)
	print("==================================================")

	var strat := SmartCpuStrategy.new(1)

	# 1. 初期集団生成
	var population := _generate_initial_population(all_cards, strat, pop_size)

	var history: Array[Dictionary] = []
	var start_time := Time.get_ticks_msec()

	for gen in range(generations):
		var gen_start := Time.get_ticks_msec()

		# 2. 総当たり対戦 (先後両方)
		var scores := _evaluate_population(population, all_cards, strat)

		# 3. 世代統計記録
		var gen_stats := _collect_generation_stats(gen, population, scores, all_cards)
		history.append(gen_stats)

		var gen_time := float(Time.get_ticks_msec() - gen_start) / 1000.0
		_print_generation_summary(gen, gen_stats, gen_time)

		# 途中経過保存
		_save_intermediate_history(history, run_tag, out_dir)

		if gen < generations - 1:
			# 4. 次世代の生成 (選抜・交叉・変異)
			population = _evolve_population(population, scores, all_cards, strat, pop_size)

	var total_time := float(Time.get_ticks_msec() - start_time) / 1000.0

	# 最終世代の相性行列算出
	var top_decks := _get_top_unique_decks(population, history.back()["scores"], 6)
	var matchup_matrix := _calculate_matchup_matrix(top_decks, all_cards, strat)

	var final_report := {
		"tag": run_tag,
		"override_file": override_file,
		"pop_size": pop_size,
		"generations": generations,
		"total_time_sec": total_time,
		"history": history,
		"top_decks": top_decks,
		"matchup_matrix": matchup_matrix,
	}

	_export_final_report(final_report, run_tag, out_dir)
	_print_final_summary(final_report, all_cards)

	quit(0)


# 個体(デッキ): {"cards": Array[String], "board": Array[String], "bench": Array[String]}
func _generate_initial_population(
	all_cards: Array[HourglassData], strat: CpuStrategy, size: int
) -> Array[Dictionary]:
	var pop: Array[Dictionary] = []
	for i in range(size):
		var deck_ids := _random_deck_ids(all_cards)
		var deck_objs := _ids_to_cards(deck_ids, all_cards)
		var placement := strat.choose_placement(deck_objs)
		(
			pop
			. append(
				{
					"cards": deck_ids,
					"board": _cards_to_ids(placement["board"]),
					"bench": _cards_to_ids(placement["bench"]),
				}
			)
		)
	return pop


func _evaluate_population(
	pop: Array[Dictionary], all_cards: Array[HourglassData], strat: CpuStrategy
) -> Array[float]:
	var n := pop.size()
	var wins := []
	wins.resize(n)
	wins.fill(0)
	var games_played := []
	games_played.resize(n)
	games_played.fill(0)

	# 総当たり (各ペアで iが先手/jが後手、および jが先手/iが後手 の2試合)
	for i in range(n):
		for j in range(i + 1, n):
			# Match 1: i vs j
			var res1 := _play_single_match(pop[i], pop[j], all_cards, strat)
			if res1 == 1:
				wins[i] += 1
			elif res1 == -1:
				wins[j] += 1
			games_played[i] += 1
			games_played[j] += 1

			# Match 2: j vs i (先後交代)
			var res2 := _play_single_match(pop[j], pop[i], all_cards, strat)
			if res2 == 1:
				wins[j] += 1
			elif res2 == -1:
				wins[i] += 1
			games_played[i] += 1
			games_played[j] += 1

	var scores: Array[float] = []
	for i in range(n):
		scores.append(float(wins[i]) / float(maxi(games_played[i], 1)))
	return scores


func _play_single_match(
	deck_a_dict: Dictionary,
	deck_b_dict: Dictionary,
	all_cards: Array[HourglassData],
	strat: CpuStrategy
) -> int:
	var board_a := _ids_to_cards(deck_a_dict["board"], all_cards)
	var bench_a := _ids_to_cards(deck_a_dict["bench"], all_cards)
	var board_b := _ids_to_cards(deck_b_dict["board"], all_cards)
	var bench_b := _ids_to_cards(deck_b_dict["bench"], all_cards)

	var gs := GameState.new()
	gs.effect_resolver = EffectResolver.new()
	gs.start_match(board_a, bench_a, board_b, bench_b)

	var turns := 0
	while not gs.is_match_over() and turns < MAX_TURNS:
		turns += 1
		var act: Dictionary = strat.choose_action(gs, gs.current_turn)
		OnlineMatch.apply(act, gs)
		gs.advance_and_end_turn()

	if gs.is_match_over():
		if gs.hp[GameState.PlayerSide.B] <= 0:
			return 1  # A win
		if gs.hp[GameState.PlayerSide.A] <= 0:
			return -1  # B win
	return 0  # Draw


func _evolve_population(
	pop: Array[Dictionary],
	scores: Array[float],
	all_cards: Array[HourglassData],
	strat: CpuStrategy,
	target_size: int
) -> Array[Dictionary]:
	var n := pop.size()
	var sorted_indices := []
	for i in range(n):
		sorted_indices.append(i)
	sorted_indices.sort_custom(func(a: int, b: int) -> bool: return scores[a] > scores[b])

	var next_pop: Array[Dictionary] = []

	# エリート保存 (上位 25%)
	var elite_count := maxi(1, target_size / 4)
	for i in range(elite_count):
		next_pop.append(pop[sorted_indices[i]].duplicate(true))

	# 残りを交叉・変異で生成
	while next_pop.size() < target_size:
		# トーナメント選択で親を2つ選ぶ
		var p1: Dictionary = pop[_tournament_select(scores, 3)]
		var p2: Dictionary = pop[_tournament_select(scores, 3)]

		# 交叉 (5枚の組み合わせを混ぜる)
		var child_ids := _crossover_decks(p1["cards"], p2["cards"], all_cards)

		# 変異 (10%の確率で1枚差し替え)
		if randf() < 0.25:
			child_ids = _mutate_deck(child_ids, all_cards)

		# 配置の決定
		var child_cards := _ids_to_cards(child_ids, all_cards)
		var placement := strat.choose_placement(child_cards)

		(
			next_pop
			. append(
				{
					"cards": child_ids,
					"board": _cards_to_ids(placement["board"]),
					"bench": _cards_to_ids(placement["bench"]),
				}
			)
		)

	return next_pop


func _tournament_select(scores: Array[float], k: int) -> int:
	var best_idx := randi() % scores.size()
	for i in range(k - 1):
		var cand := randi() % scores.size()
		if scores[cand] > scores[best_idx]:
			best_idx = cand
	return best_idx


func _crossover_decks(cards1: Array, cards2: Array, all_cards: Array[HourglassData]) -> Array:
	var pool := []
	for c in cards1:
		if not pool.has(c):
			pool.append(c)
	for c in cards2:
		if not pool.has(c):
			pool.append(c)

	pool.shuffle()
	var result: Array = []
	for i in range(mini(5, pool.size())):
		result.append(pool[i])

	while result.size() < 5:
		var extra: HourglassData = all_cards[randi() % all_cards.size()]
		if not result.has(extra.id):
			result.append(extra.id)

	return result


func _mutate_deck(deck_ids: Array, all_cards: Array[HourglassData]) -> Array:
	var res := deck_ids.duplicate()
	var replace_idx := randi() % res.size()
	var new_card: HourglassData = all_cards[randi() % all_cards.size()]
	while res.has(new_card.id):
		new_card = all_cards[randi() % all_cards.size()]
	res[replace_idx] = new_card.id
	return res


func _collect_generation_stats(
	gen: int, pop: Array[Dictionary], scores: Array[float], all_cards: Array[HourglassData]
) -> Dictionary:
	var card_counts: Dictionary = {}
	for card in all_cards:
		card_counts[card.id] = 0

	var unique_decks: Dictionary = {}
	for d in pop:
		var key := _deck_key(d["cards"])
		unique_decks[key] = unique_decks.get(key, 0) + 1
		for cid in d["cards"]:
			card_counts[cid] = card_counts.get(cid, 0) + 1

	var pop_size := float(pop.size())
	var shares: Dictionary = {}
	var entropy := 0.0
	for cid in card_counts:
		var count: int = card_counts[cid]
		var share := float(count) / (pop_size * 5.0)
		shares[cid] = share
		if share > 0.0:
			entropy -= share * (log(share) / log(2.0))

	return {
		"gen": gen,
		"shares": shares,
		"unique_deck_count": unique_decks.size(),
		"entropy": entropy,
		"avg_score": _calc_avg_float(scores),
		"max_score": _calc_max_float(scores),
		"scores": scores,
	}


func _print_generation_summary(gen: int, stats: Dictionary, gen_time: float) -> void:
	print(
		(
			"Gen %2d (%.1fs) | UniqDecks: %2d | Entropy: %.2f | TopShares: %s"
			% [
				gen,
				gen_time,
				stats["unique_deck_count"],
				stats["entropy"],
				_top_shares_str(stats["shares"])
			]
		)
	)


func _top_shares_str(shares: Dictionary) -> String:
	var items := []
	for k in shares:
		items.append({"id": k, "share": shares[k]})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["share"] > b["share"])

	var s := ""
	for i in range(mini(4, items.size())):
		s += "%s:%.0f%% " % [items[i]["id"], items[i]["share"] * 100.0]
	return s.strip_edges()


func _get_top_unique_decks(
	pop: Array[Dictionary], scores: Array[float], top_n: int
) -> Array[Dictionary]:
	var indices := []
	for i in range(pop.size()):
		indices.append(i)
	indices.sort_custom(func(a: int, b: int) -> bool: return scores[a] > scores[b])

	var seen: Dictionary = {}
	var result: Array[Dictionary] = []
	for idx in indices:
		var d: Dictionary = pop[idx]
		var key := _deck_key(d["cards"])
		if not seen.has(key):
			seen[key] = true
			result.append(d)
			if result.size() >= top_n:
				break
	return result


func _calculate_matchup_matrix(
	top_decks: Array[Dictionary], all_cards: Array[HourglassData], strat: CpuStrategy
) -> Array:
	var m := top_decks.size()
	var matrix: Array = []
	var games_per_pair := 20

	for i in range(m):
		var row: Array[float] = []
		for j in range(m):
			if i == j:
				row.append(0.5)
				continue
			var i_wins := 0
			for g in range(games_per_pair):
				# i先手 vs j後手
				var r1 := _play_single_match(top_decks[i], top_decks[j], all_cards, strat)
				if r1 == 1:
					i_wins += 1
				# j先手 vs i後手
				var r2 := _play_single_match(top_decks[j], top_decks[i], all_cards, strat)
				if r2 == -1:
					i_wins += 1
			row.append(float(i_wins) / float(games_per_pair * 2))
		matrix.append(row)
	return matrix


func _print_final_summary(rep: Dictionary, _all_cards: Array[HourglassData]) -> void:
	print("\n==================================================")
	print("Evolution Complete [%s] in %.2fs" % [rep["tag"], rep["total_time_sec"]])
	print("==================================================")

	var history: Array = rep["history"]
	var first_gen: Dictionary = history[0]
	var last_gen: Dictionary = history.back()

	print("\n--- Meta Share Evolution (Gen 0 -> Gen %d) ---" % [last_gen["gen"]])
	print("%-12s | Gen 0 Share | Final Share | Shift" % ["Card ID"])
	print("--------------------------------------------------")
	for cid in first_gen["shares"]:
		var s0: float = first_gen["shares"][cid] * 100.0
		var s1: float = last_gen["shares"][cid] * 100.0
		var diff := s1 - s0
		var diff_str := "+%.1f%%" % diff if diff >= 0 else "%.1f%%" % diff
		print("%-12s |      %5.1f%% |      %5.1f%% | %s" % [cid, s0, s1, diff_str])

	print("\n--- Top Decks of Final Generation ---")
	var top_decks: Array = rep["top_decks"]
	for i in range(top_decks.size()):
		var d: Dictionary = top_decks[i]
		print("  Deck #%d: Board=%s | Bench=%s" % [i + 1, str(d["board"]), str(d["bench"])])

	print("\n--- Matchup Matrix (Win rate of Row vs Column) ---")
	var mat: Array = rep["matchup_matrix"]
	var hdr := "       "
	for j in range(top_decks.size()):
		hdr += " D%-2d  " % [j + 1]
	print(hdr)
	for i in range(mat.size()):
		var r_str := "  D%-2d: " % [i + 1]
		for j in range(mat[i].size()):
			r_str += " %4.0f%%" % [mat[i][j] * 100.0]
		print(r_str)


func _save_intermediate_history(history: Array, tag: String, out_dir: String) -> void:
	var dir := DirAccess.open("res://")
	if not dir.dir_exists(out_dir):
		dir.make_dir_recursive(out_dir)
	var file := FileAccess.open("%s/meta_history_%s.json" % [out_dir, tag], FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(history, "\t"))


func _export_final_report(rep: Dictionary, tag: String, out_dir: String) -> void:
	var dir := DirAccess.open("res://")
	if not dir.dir_exists(out_dir):
		dir.make_dir_recursive(out_dir)
	var file_path := "%s/meta_report_%s.json" % [out_dir, tag]
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(rep, "\t"))
		print("\nExported Meta Report: %s" % file_path)


func _random_deck_ids(all_cards: Array[HourglassData]) -> Array:
	var shuffled := all_cards.duplicate()
	shuffled.shuffle()
	var res: Array = []
	for i in range(5):
		res.append(shuffled[i].id)
	return res


func _ids_to_cards(ids: Array, all_cards: Array[HourglassData]) -> Array[HourglassData]:
	var result: Array[HourglassData] = []
	for id in ids:
		for card in all_cards:
			if card.id == id:
				result.append(card)
				break
	return result


func _cards_to_ids(cards: Array) -> Array:
	var res: Array = []
	for c in cards:
		res.append(c.id)
	return res


func _deck_key(ids: Array) -> String:
	var s := ids.duplicate()
	s.sort()
	return "-".join(s)


func _calc_avg_float(arr: Array[float]) -> float:
	if arr.is_empty():
		return 0.0
	var sum := 0.0
	for v in arr:
		sum += v
	return sum / float(arr.size())


func _calc_max_float(arr: Array[float]) -> float:
	if arr.is_empty():
		return 0.0
	var m := -INF
	for v in arr:
		if v > m:
			m = v
	return m


func _load_all_hourglasses(override_file: String) -> Array[HourglassData]:
	var cards := MatchSetup.all_hourglasses()
	if override_file != "" and FileAccess.file_exists(override_file):
		_apply_override_json(cards, override_file)
	return cards


func _apply_override_json(cards: Array[HourglassData], path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	var json = JSON.parse_string(text)
	if not (json is Dictionary):
		return

	for card in cards:
		if json.has(card.id):
			var data: Dictionary = json[card.id]
			if data.has("fall_damage"):
				card.fall_damage = int(data["fall_damage"])
			if data.has("effects"):
				var effects_override: Array = data["effects"]
				for i in range(mini(card.effects.size(), effects_override.size())):
					var eff_dict: Dictionary = effects_override[i]
					if eff_dict.has("value"):
						card.effects[i].value = int(eff_dict["value"])


func _parse_args() -> Dictionary:
	var result := {}
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--"):
			var pair := arg.substr(2).split("=", true, 1)
			if pair.size() == 2:
				var key := pair[0]
				var val := pair[1]
				if key == "pop" or key == "gen" or key == "seed":
					result[key] = int(val)
				else:
					result[key] = val
	return result
