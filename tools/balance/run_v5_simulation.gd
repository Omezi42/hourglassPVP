extends SceneTree
## v5.0の自己対戦シミュレーション。GameDesign.md 7章の5指標を測る。
##
## 使い方:
##   Godot --headless --path . --script tools/balance/run_v5_simulation.gd -- \
##       games=2000 seed=42 out=tools/balance/out/v5.json
##
## **必ず「本体ダメージで決着した割合」を見ること。**この値が低い場合、対局が
## デッキ切れ(疲労)で決まっており、カードゲームとして成立していない。
##
## バランス測定は**ランダムに生成した混成デッキ同士**で行う。単色デッキ同士は
## 勝敗が決定的になって勝率が0%/100%へ量子化し、単色と混成の比較は
## マナカーブが組めないぶん単色が構造的に不利になるため、どちらも信号にならない。

const COPY_LIMIT := 2
## 中盤の優劣を記録する手数。ここで劣勢だった側が勝った割合を逆転率とする。
const MIDGAME_TURN := 12

var _rng := RandomNumberGenerator.new()
var _cards: Array[CardData] = []
var _coin := true
var _mulligan := true
## 反転権(GameDesign.md 2章)の総回数の検証用オーバーライド。既定は仕様どおりの値で、
## flip_right_first=0 flip_right_second=0 とすれば「反転権が無い場合」と比較できる。
var _flip_right_first := MatchState.FLIP_RIGHT_FIRST
var _flip_right_second := MatchState.FLIP_RIGHT_SECOND


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var games: int = int(args.get("games", "1000"))
	# 既定は仕様どおりコインあり。coin=0 で外した場合と比べられる。
	_coin = args.get("coin", "1") == "1"
	# 既定は仕様どおりマリガンあり。mulligan=0 で外した場合と比べられる。
	_mulligan = args.get("mulligan", "1") == "1"
	_flip_right_first = int(args.get("flip_right_first", str(MatchState.FLIP_RIGHT_FIRST)))
	_flip_right_second = int(args.get("flip_right_second", str(MatchState.FLIP_RIGHT_SECOND)))
	_rng.seed = int(args.get("seed", "42"))
	_cards = CardLibrary.all_cards()
	if _cards.is_empty():
		printerr("no cards found")
		quit(1)
		return

	var totals := _new_totals()
	var per_card: Dictionary = {}
	for card in _cards:
		per_card[card.id] = {"games": 0, "wins": 0}

	for game in games:
		var deck_a := _random_deck()
		var deck_b := _random_deck()
		# 先手・後手の偏りを消すため、同じ組を入れ替えて2回は回さず、
		# 代わりにデッキそのものを毎回引き直して独立試行にしている。
		var result := _play_one(deck_a, deck_b)
		_accumulate(totals, result)
		_accumulate_cards(per_card, deck_a, deck_b, result)

	_report(totals, per_card, games)
	var out: String = args.get("out", "")
	if not out.is_empty():
		_save(out, totals, per_card, games)
	quit()


func _new_totals() -> Dictionary:
	return {
		"decisive": 0,
		"first_wins": 0,
		"draws": 0,
		"turns": 0,
		"face_finish": 0,
		"fatigue_finish": 0,
		"surrender_finish": 0,
		"unit_attacks": 0,
		"face_attacks": 0,
		"comeback_chances": 0,
		"comebacks": 0,
	}


# --- 1対局 --------------------------------------------------------------


func _play_one(deck_a: Array, deck_b: Array) -> Dictionary:
	var state := MatchState.new()
	var cpu_a := CardCpuStrategy.new()
	var cpu_b := CardCpuStrategy.new()
	var stats := {"unit_attacks": 0, "face_attacks": 0, "behind_at_midgame": -1}
	state.attack_performed.connect(
		func(_side: int, _slot: int, target_slot: int) -> void:
			if target_slot < 0:
				stats["face_attacks"] += 1
			else:
				stats["unit_attacks"] += 1
	)
	state.start_match(
		deck_a, deck_b, MatchState.Side.A, _rng.randi_range(1, 1 << 30), _coin, _mulligan
	)
	# 反転権の総回数を検証用に上書きする(既定は仕様どおりの値のまま何もしない)。
	state.flip_right_remaining[MatchState.Side.A] = _flip_right_first
	state.flip_right_remaining[MatchState.Side.B] = _flip_right_second
	if state.mulligan_pending:
		state.mulligan(MatchState.Side.A, cpu_a.choose_mulligan(state, MatchState.Side.A))
		state.mulligan(MatchState.Side.B, cpu_b.choose_mulligan(state, MatchState.Side.B))
	while not state.is_match_over():
		if state.turn_count == MIDGAME_TURN and stats["behind_at_midgame"] < 0:
			stats["behind_at_midgame"] = _behind_side(state)
		var side := state.current_turn
		var cpu: CardCpuStrategy = cpu_a if side == MatchState.Side.A else cpu_b
		cpu.take_turn(state, side)
	return {
		"winner": state.winner,
		"turns": state.turn_count,
		"end_reason": state.end_reason,
		"fatigue": state.finished_by_fatigue,
		"unit_attacks": stats["unit_attacks"],
		"face_attacks": stats["face_attacks"],
		"behind": stats["behind_at_midgame"],
	}


## 中盤に劣勢だった側。HPと盤面の生涯ダメージの合計で比べる。
func _behind_side(state: MatchState) -> int:
	var score_a := _side_score(state, MatchState.Side.A)
	var score_b := _side_score(state, MatchState.Side.B)
	if absf(score_a - score_b) < 1.0:
		return -1
	return MatchState.Side.A if score_a < score_b else MatchState.Side.B


func _side_score(state: MatchState, side: int) -> float:
	var score := float(state.hp[side])
	for unit in state.units(side):
		score += float(unit.lifetime_damage()) * 0.5
	return score


# --- 集計 ---------------------------------------------------------------


func _accumulate(totals: Dictionary, result: Dictionary) -> void:
	totals["unit_attacks"] += result["unit_attacks"]
	totals["face_attacks"] += result["face_attacks"]
	if result["winner"] < 0:
		totals["draws"] += 1
		return
	totals["decisive"] += 1
	totals["turns"] += result["turns"]
	if result["winner"] == MatchState.Side.A:
		totals["first_wins"] += 1
	if result["end_reason"] == MatchState.EndReason.SURRENDER:
		totals["surrender_finish"] += 1
	elif result["fatigue"]:
		totals["fatigue_finish"] += 1
	else:
		totals["face_finish"] += 1
	var behind: int = result["behind"]
	if behind >= 0:
		totals["comeback_chances"] += 1
		if behind == result["winner"]:
			totals["comebacks"] += 1


func _accumulate_cards(
	per_card: Dictionary, deck_a: Array, deck_b: Array, result: Dictionary
) -> void:
	if result["winner"] < 0:
		return
	_mark_deck(per_card, deck_a, result["winner"] == MatchState.Side.A)
	_mark_deck(per_card, deck_b, result["winner"] == MatchState.Side.B)


func _mark_deck(per_card: Dictionary, deck: Array, won: bool) -> void:
	var seen: Dictionary = {}
	for card in deck:
		if seen.has(card.id):
			continue
		seen[card.id] = true
		per_card[card.id]["games"] += 1
		if won:
			per_card[card.id]["wins"] += 1


# --- デッキ生成 ---------------------------------------------------------


## 同名2枚までの制限を守ってランダムな混成デッキを1つ作る。
func _random_deck() -> Array:
	var pool: Array = []
	for card in _cards:
		for i in COPY_LIMIT:
			pool.append(card)
	for i in range(pool.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, MatchState.DECK_SIZE)


# --- 出力 ---------------------------------------------------------------


func _report(totals: Dictionary, per_card: Dictionary, games: int) -> void:
	var decisive: int = totals["decisive"]
	var attacks: int = totals["unit_attacks"] + totals["face_attacks"]
	print("=== v5.0 balance (%d games) ===" % games)
	print("先手勝率            : %s" % _pct(totals["first_wins"], decisive))
	print("決着手数(平均)      : %.1f" % (float(totals["turns"]) / maxf(decisive, 1)))
	print("本体ダメージで決着  : %s" % _pct(totals["face_finish"], decisive))
	print("  うち疲労で決着    : %s" % _pct(totals["fatigue_finish"], decisive))
	print("ユニットへの攻撃    : %s" % _pct(totals["unit_attacks"], attacks))
	print("逆転率              : %s" % _pct(totals["comebacks"], totals["comeback_chances"]))
	print("引き分け            : %s" % _pct(totals["draws"], games))
	print("")
	print("--- カード別勝率 ---")
	var rows: Array = []
	for card in _cards:
		var entry: Dictionary = per_card[card.id]
		var rate := float(entry["wins"]) / maxf(entry["games"], 1)
		rows.append({"card": card, "rate": rate, "games": entry["games"]})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["rate"] > b["rate"])
	for row in rows:
		var card: CardData = row["card"]
		print(
			(
				"%-10s コスト%d 総量%d  %5.1f%%  (%d戦)"
				% [card.display_name, card.cost, card.total_sand, row["rate"] * 100.0, row["games"]]
			)
		)


func _pct(part: int, whole: int) -> String:
	if whole <= 0:
		return "n/a"
	return "%.1f%% (%d/%d)" % [float(part) / float(whole) * 100.0, part, whole]


func _save(path: String, totals: Dictionary, per_card: Dictionary, games: int) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("cannot write ", path)
		return
	file.store_string(JSON.stringify({"games": games, "totals": totals, "cards": per_card}, "\t"))


func _parse_args() -> Dictionary:
	var parsed: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			parsed[pair[0]] = pair[1]
	return parsed
