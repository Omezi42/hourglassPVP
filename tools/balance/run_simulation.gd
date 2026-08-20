extends SceneTree

## バランス検証シミュレータ (tools/balance/run_simulation.gd)
## UIや通信に依存せず、ヘッドレスで高速に対局シミュレーションを実行し定量データを収集・出力する。

const DEFAULT_GAMES := 1000
const DEFAULT_SEED := 42
const MAX_TURNS := 200

var _hourglass_cache: Dictionary = {}


func _init() -> void:
	call_deferred("_run_simulation")


func _run_simulation() -> void:
	var args := _parse_args()
	var num_games: int = args.get("games", DEFAULT_GAMES)
	var sim_seed: int = args.get("seed", DEFAULT_SEED)
	var mode: String = args.get("mode", "smart_vs_smart")
	var override_file: String = args.get("override", "")
	var out_dir: String = args.get("out", "tools/balance/out")

	seed(sim_seed)

	var all_cards := _load_all_hourglasses(override_file)
	if all_cards.is_empty():
		printerr("Error: No hourglasses loaded.")
		quit(1)
		return

	print("==================================================")
	print("Hourglass PvP Balance Simulation")
	print(
		(
			"Games: %d | Seed: %d | Mode: %s | Override: %s"
			% [num_games, sim_seed, mode, override_file]
		)
	)
	print("==================================================")

	var strat_a: CpuStrategy
	var strat_b: CpuStrategy

	match mode:
		"random_vs_random":
			strat_a = RandomCpuStrategy.new()
			strat_b = RandomCpuStrategy.new()
		"smart_vs_random":
			strat_a = SmartCpuStrategy.new(1)
			strat_b = RandomCpuStrategy.new()
		"random_vs_smart":
			strat_a = RandomCpuStrategy.new()
			strat_b = SmartCpuStrategy.new(1)
		"smart_vs_smart":
			strat_a = SmartCpuStrategy.new(1)
			strat_b = SmartCpuStrategy.new(1)
		_:
			strat_a = SmartCpuStrategy.new(1)
			strat_b = SmartCpuStrategy.new(1)

	var results := _simulate_matches(all_cards, strat_a, strat_b, num_games)

	_print_summary(results, mode)
	_export_results(results, mode, out_dir)

	quit(0)


func _simulate_matches(
	all_cards: Array[HourglassData], strat_a: CpuStrategy, strat_b: CpuStrategy, num_games: int
) -> Dictionary:
	var a_wins := 0
	var b_wins := 0
	var draws := 0
	var turn_counts: Array[int] = []
	var total_damages_a: Array[int] = []
	var total_damages_b: Array[int] = []

	var action_types := {"flip": 0, "move": 0, "swap_in": 0, "pass": 0}
	var flip_targets := {"own": 0, "opponent": 0}

	# 駒別統計: { id: { "picks": 0, "wins": 0, "falls": 0, "flips_received": 0, ... } }
	var card_stats: Dictionary = {}
	for card in all_cards:
		card_stats[card.id] = {
			"picks": 0,
			"wins": 0,
			"falls": 0,
			"flips_received": 0,
			"swaps": 0,
			"pos_left": 0,
			"pos_center": 0,
			"pos_right": 0,
			"pos_bench": 0,
		}

	var start_time := Time.get_ticks_msec()

	for g in range(num_games):
		# デッキ選出 (5種類)
		var shuffled := all_cards.duplicate()
		shuffled.shuffle()
		var deck_a: Array[HourglassData] = []
		var deck_b: Array[HourglassData] = []
		for i in range(5):
			deck_a.append(shuffled[i])
		shuffled.shuffle()
		for i in range(5):
			deck_b.append(shuffled[i])

		# 初期配置決定
		var place_a := strat_a.choose_placement(deck_a)
		var place_b := strat_b.choose_placement(deck_b)

		var board_a: Array[HourglassData] = []
		board_a.assign(place_a["board"])
		var bench_a: Array[HourglassData] = []
		bench_a.assign(place_a["bench"])

		var board_b: Array[HourglassData] = []
		board_b.assign(place_b["board"])
		var bench_b: Array[HourglassData] = []
		bench_b.assign(place_b["bench"])

		# 配置記録
		for card in board_a:
			card_stats[card.id]["picks"] += 1
		for card in bench_a:
			card_stats[card.id]["picks"] += 1
		for card in board_b:
			card_stats[card.id]["picks"] += 1
		for card in bench_b:
			card_stats[card.id]["picks"] += 1

		card_stats[board_a[0].id]["pos_left"] += 1
		card_stats[board_a[1].id]["pos_center"] += 1
		card_stats[board_a[2].id]["pos_right"] += 1
		card_stats[bench_a[0].id]["pos_bench"] += 1
		card_stats[bench_a[1].id]["pos_bench"] += 1

		card_stats[board_b[0].id]["pos_left"] += 1
		card_stats[board_b[1].id]["pos_center"] += 1
		card_stats[board_b[2].id]["pos_right"] += 1
		card_stats[bench_b[0].id]["pos_bench"] += 1
		card_stats[bench_b[1].id]["pos_bench"] += 1

		# 対局実行
		var gs := GameState.new()
		gs.effect_resolver = EffectResolver.new()

		# イベントトラッキング用
		var match_flips: Dictionary = {GameState.PlayerSide.A: 0, GameState.PlayerSide.B: 0}
		gs.hourglass_state_changed.connect(
			func(side: GameState.PlayerSide, pos: int, nstate: int) -> void:
				if nstate == GameEnums.HourglassState.FALLEN:
					var inst: HourglassInstance = gs.board[side][pos]
					card_stats[inst.data.id]["falls"] += 1
		)

		gs.start_match(board_a, bench_a, board_b, bench_b)

		var turns := 0
		while not gs.is_match_over() and turns < MAX_TURNS:
			turns += 1
			var act: Dictionary
			if gs.current_turn == GameState.PlayerSide.A:
				act = strat_a.choose_action(gs, GameState.PlayerSide.A)
			else:
				act = strat_b.choose_action(gs, GameState.PlayerSide.B)

			var atype: String = act.get("type", "pass")
			action_types[atype] = action_types.get(atype, 0) + 1

			if atype == "flip":
				var target_side: GameState.PlayerSide = act["side"]
				var target_pos: int = act["position"]
				var target_inst: HourglassInstance = gs.board[target_side][target_pos]
				card_stats[target_inst.data.id]["flips_received"] += 1
				if target_side == gs.current_turn:
					flip_targets["own"] += 1
				else:
					flip_targets["opponent"] += 1
			elif atype == "swap_in":
				var target_inst: HourglassInstance = gs.board[gs.current_turn][0]
				card_stats[target_inst.data.id]["swaps"] += 1

			OnlineMatch.apply(act, gs)
			gs.advance_and_end_turn()

		turn_counts.append(turns)
		total_damages_a.append(GameState.INITIAL_HP - gs.hp[GameState.PlayerSide.B])
		total_damages_b.append(GameState.INITIAL_HP - gs.hp[GameState.PlayerSide.A])

		if gs.is_match_over():
			if gs.hp[GameState.PlayerSide.B] <= 0:
				a_wins += 1
				for card in deck_a:
					card_stats[card.id]["wins"] += 1
			elif gs.hp[GameState.PlayerSide.A] <= 0:
				b_wins += 1
				for card in deck_b:
					card_stats[card.id]["wins"] += 1
		else:
			draws += 1

	var elapsed_sec := float(Time.get_ticks_msec() - start_time) / 1000.0

	return {
		"games": num_games,
		"elapsed_sec": elapsed_sec,
		"a_wins": a_wins,
		"b_wins": b_wins,
		"draws": draws,
		"turn_counts": turn_counts,
		"damages_a": total_damages_a,
		"damages_b": total_damages_b,
		"action_types": action_types,
		"flip_targets": flip_targets,
		"card_stats": card_stats,
	}


func _print_summary(res: Dictionary, mode: String) -> void:
	var total: int = res["games"]
	var a_wins: int = res["a_wins"]
	var b_wins: int = res["b_wins"]
	var draws: int = res["draws"]

	var a_rate := float(a_wins) / float(total) * 100.0
	var b_rate := float(b_wins) / float(total) * 100.0
	var draw_rate := float(draws) / float(total) * 100.0

	var ci_a := 1.96 * sqrt((a_rate / 100.0) * (1.0 - a_rate / 100.0) / float(total)) * 100.0

	var turns: Array[int] = res["turn_counts"]
	turns.sort()
	var avg_turns := _calc_avg(turns)
	var med_turns := _calc_percentile(turns, 0.5)
	var p10_turns := _calc_percentile(turns, 0.1)
	var p90_turns := _calc_percentile(turns, 0.9)
	var max_turns: int = turns.back() if not turns.is_empty() else 0

	print(
		(
			"\n--- Summary [%s] (Time: %.2fs, %.1f games/s) ---"
			% [mode, res["elapsed_sec"], float(total) / maxf(res["elapsed_sec"], 0.001)]
		)
	)
	print("Side A (First) Wins : %d (%.2f%% ± %.2f%%)" % [a_wins, a_rate, ci_a])
	print("Side B (Second) Wins: %d (%.2f%%)" % [b_wins, b_rate])
	print("Draws (Stalemate)   : %d (%.2f%%)" % [draws, draw_rate])
	print(
		(
			"Turns Distribution  : Avg=%.1f | Med=%.0f | P10=%.0f | P90=%.0f | Max=%d"
			% [avg_turns, med_turns, p10_turns, p90_turns, max_turns]
		)
	)

	print("\n--- Action Breakdown ---")
	var atypes: Dictionary = res["action_types"]
	var total_acts := 0
	for k in atypes:
		total_acts += atypes[k]
	for k in atypes:
		print(
			"  %-8s: %6d (%5.2f%%)" % [k, atypes[k], float(atypes[k]) / float(total_acts) * 100.0]
		)
	var flips: Dictionary = res["flip_targets"]
	var total_flips: int = flips["own"] + flips["opponent"]
	if total_flips > 0:
		print(
			(
				"  Flip Targets -> Own: %d (%.1f%%) | Opponent: %d (%.1f%%)"
				% [
					flips["own"],
					float(flips["own"]) / float(total_flips) * 100.0,
					flips["opponent"],
					float(flips["opponent"]) / float(total_flips) * 100.0
				]
			)
		)

	print("\n--- Card Performance ---")
	print(
		(
			"%-12s | PickRate | WinRate | Falls/G | FlipsRec/G | Swaps/G | (L / C / R / Bench)"
			% ["Card ID"]
		)
	)
	print(
		"-----------------------------------------------------------------------------------------"
	)
	var cstats: Dictionary = res["card_stats"]
	for cid in cstats:
		var st: Dictionary = cstats[cid]
		var picks: int = st["picks"]
		var wr := float(st["wins"]) / float(maxi(picks, 1)) * 100.0
		var pick_rate := float(picks) / float(total * 2) * 100.0  # 1試合に2プレイヤー
		var falls_g := float(st["falls"]) / float(maxi(picks, 1))
		var flips_g := float(st["flips_received"]) / float(maxi(picks, 1))
		var swaps_g := float(st["swaps"]) / float(maxi(picks, 1))
		print(
			(
				"%-12s |   %5.1f%% |  %5.1f%% |    %4.2f |       %4.2f |    %4.2f | (%d / %d / %d / %d)"
				% [
					cid,
					pick_rate,
					wr,
					falls_g,
					flips_g,
					swaps_g,
					st["pos_left"],
					st["pos_center"],
					st["pos_right"],
					st["pos_bench"]
				]
			)
		)


func _export_results(res: Dictionary, mode: String, out_dir: String) -> void:
	var dir := DirAccess.open("res://")
	if not dir.dir_exists(out_dir):
		dir.make_dir_recursive(out_dir)

	var file_path := "%s/sim_%s.json" % [out_dir, mode]
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(res, "\t"))
		print("\nExported JSON: %s" % file_path)


func _calc_avg(arr: Array[int]) -> float:
	if arr.is_empty():
		return 0.0
	var sum := 0
	for v in arr:
		sum += v
	return float(sum) / float(arr.size())


func _calc_percentile(sorted_arr: Array[int], p: float) -> float:
	if sorted_arr.is_empty():
		return 0.0
	var idx := int(round(p * float(sorted_arr.size() - 1)))
	return float(sorted_arr[clamp(idx, 0, sorted_arr.size() - 1)])


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
				if key == "games" or key == "seed":
					result[key] = int(val)
				else:
					result[key] = val
	return result
