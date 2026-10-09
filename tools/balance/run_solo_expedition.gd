extends SceneTree
## 遠征(GameDesign.md 27章)の通し測定。CPU(上級)に遠征を丸ごと指させ、深さごとの踏破率・
## 段ごとの脱落・関門/主ごとの勝率・恩恵ごとの成績を出す。対局の規則は本番と同じ
## `SoloBattleRules`で当てる。
##
## 使い方:
##   Godot --headless --path . --script tools/balance/run_solo_expedition.gd -- \
##       runs=200 depths=0,1,2,3,4,5 seed=42 player=normal isolated=300 \
##       out=tools/balance/out/solo.md
##
## 序盤の難しさの試行: `start_deck=20` で初期の山札を作戦の15種+重ねる数枚にし、
## `floor1_foe_hp=-6` で1段目の相手のHPを増減する(どちらも本番の規則には無い)。
##
## `only=survive,empty_board` を与えると、`isolated` で測る関門・主をそのidだけに絞る(調整の試行用)。
##
## 通しでは主まで届く遠征が少なく、主・関門ごとの試行数が偏る。`isolated=N` を与えると、
## 関門・主それぞれと通常の対局を同じ条件(作戦の15種×2の30枚・HP満タン・相手は上級)で
## N局ずつ直接指させ、難しさを通常の対局と並べて比べる表を足す。
##
## 遊び手の方針(単純に固定する。読むのは関門・主・恩恵どうしの差):
## - 作戦・主は出発の候補から乱数で選ぶ(本番と同じ引き方)
## - 行き先は、HPが最大の`SPRING_BELOW`未満なら泉、それ以外は対局・関門から等確率。工房は選ばない
## - 束は選んだ作戦の束を足す(無ければ先頭)。恩恵は候補から等確率(恩恵どうしを偏りなく比べるため)
## - マリガンは双方CPUの判断。自分側のCPUの思考レベルは `player=beginner|normal|expert`(既定は上級)

const SPRING_BELOW := 0.6
const PLAYER_LEVELS := {
	"beginner": CardCpuStrategy.Difficulty.BEGINNER,
	"normal": CardCpuStrategy.Difficulty.NORMAL,
	"expert": CardCpuStrategy.Difficulty.EXPERT,
}

var _rng := RandomNumberGenerator.new()
var _lines: Array[String] = []
var _player_level := "expert"
var _start_deck := 0
var _floor1_foe_hp := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var runs: int = int(args.get("runs", "100"))
	_rng.seed = int(args.get("seed", "42"))
	_player_level = str(args.get("player", _player_level))
	if not PLAYER_LEVELS.has(_player_level):
		printerr("player は beginner か normal か expert")
		quit(1)
		return
	_start_deck = int(args.get("start_deck", "0"))
	_floor1_foe_hp = int(args.get("floor1_foe_hp", "0"))
	var depths: Array[int] = []
	for token in str(args.get("depths", "0,1,2,3,4,5")).split(","):
		depths.append(clampi(int(token), 0, SoloRun.DEPTH_MAX))
	var stats := {}
	for depth in depths:
		stats[depth] = _new_stats()
		for i in runs:
			_play_run(depth, stats[depth])
		printerr("depth %d done" % depth)
	_report(stats, depths, runs)
	var isolated := int(args.get("isolated", "0"))
	if isolated > 0:
		var only := PackedStringArray()
		if not str(args.get("only", "")).is_empty():
			only = str(args["only"]).split(",")
		_report_isolated(isolated, only)
	var out: String = args.get("out", "")
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var file := FileAccess.open(out, FileAccess.WRITE)
		file.store_string("\n".join(_lines) + "\n")
	quit()


func _new_stats() -> Dictionary:
	return {
		"clears": 0,
		"wins_total": 0,
		"lost_at": [0, 0, 0, 0, 0, 0],
		"floor_battles": [[0, 0], [0, 0], [0, 0], [0, 0], [0, 0], [0, 0]],
		"gates": {},
		"bosses": {},
		"boon_runs": {},
		"boon_after": {},
		"themes": {},
	}


# --- 遠征1回 ------------------------------------------------------------


func _play_run(depth: int, stats: Dictionary) -> void:
	var themes := SoloRun.theme_choices(_rng)
	var theme: String = themes[_rng.randi_range(0, themes.size() - 1)]
	var run := SoloRun.create(theme, depth, _rng, SoloRun.boss_choice(_rng))
	_thicken_deck(run)
	while not run.over:
		if run.workshop_open:
			run.workshop_skip()
			continue
		if not run.boon_offer.is_empty():
			run.take_boon(run.boon_offer[_rng.randi_range(0, run.boon_offer.size() - 1)])
			continue
		if not run.offer.is_empty():
			run.take_bundle(_theme_bundle(run))
			continue
		run.choose(_pick_destination(run), _rng)
		if run.in_battle:
			_play_battle(run, stats)
	_tally(stats["themes"], theme, run.cleared)
	for id in run.boons:
		_tally(stats["boon_runs"], id, run.cleared)
	stats["wins_total"] += run.wins
	if run.cleared:
		stats["clears"] += 1
	else:
		stats["lost_at"][run.floor] += 1


## 初期の山札を`_start_deck`枚まで、作戦の15種から重ならないように2枚目を足して増やす。
func _thicken_deck(run: SoloRun) -> void:
	var extras := run.deck_ids.duplicate()
	while run.deck_ids.size() < _start_deck and not extras.is_empty():
		run.deck_ids.append(extras.pop_at(_rng.randi_range(0, extras.size() - 1)))


func _pick_destination(run: SoloRun) -> int:
	var options := run.current_destinations()
	var open_rows := SoloRun.open_rows(run.route, run.floor, run.chosen)
	var fights: Array[int] = []
	for i in open_rows:
		var kind := int(options[i].get("kind", SoloRun.Kind.BATTLE))
		if kind == SoloRun.Kind.SPRING and run.hp < run.max_hp * SPRING_BELOW:
			return i
		if kind == SoloRun.Kind.BATTLE or kind == SoloRun.Kind.GATE:
			fights.append(i)
	if fights.is_empty():
		return open_rows[0]
	return fights[_rng.randi_range(0, fights.size() - 1)]


func _theme_bundle(run: SoloRun) -> int:
	for i in run.offer.size():
		if str(run.offer[i].get("theme", "")) == run.theme_id:
			return i
	return 0


func _play_battle(run: SoloRun, stats: Dictionary) -> void:
	var dest := run.active_destination()
	var gate := SoloGateLibrary.find_by_id(str(dest.get("gate", "")))
	var floor_played := run.floor
	var held_boons := run.boons.duplicate()
	var result := _fight(run, dest, gate, run.difficulty())
	var won: bool = result[0]
	run.finish_battle(won, result[1], _rng)
	var cell: Array = stats["floor_battles"][floor_played]
	cell[0] += 1
	cell[1] += int(won)
	if gate != null:
		var bucket: Dictionary = (
			stats["bosses"] if floor_played == SoloRun.FLOOR_COUNT - 1 else stats["gates"]
		)
		_tally(bucket, gate.id, won)
	for id in held_boons:
		_tally(stats["boon_after"], id, won)


## 1局を指させ、`[勝ったか, 残りHP]` を返す。規則は本番と同じ`SoloBattleRules`で当てる。
func _fight(run: SoloRun, dest: Dictionary, gate: SoloGateData, foe_level: int) -> Array:
	var mine := MatchState.Side.A
	var foe := MatchState.other_side(mine)
	var state := MatchState.new()
	state.start_match(
		SoloBattleRules.own_deck(run),
		SoloBattleRules.foe_deck(run, dest, gate),
		mine,
		_rng.randi_range(1, 1 << 30),
		MatchState.COIN_ENABLED,
		true
	)
	var rules := SoloBattleRules.new()
	rules.apply(state, mine, run, gate)
	if run.floor == 0 and _floor1_foe_hp != 0:
		state.hp[foe] = maxi(state.hp[foe] + _floor1_foe_hp, 1)
	var own_cpu := CardCpuStrategy.new()
	own_cpu.difficulty = PLAYER_LEVELS[_player_level]
	var foe_cpu := CardCpuStrategy.new()
	foe_cpu.difficulty = foe_level
	if state.mulligan_pending:
		state.mulligan(mine, own_cpu.choose_mulligan(state, mine))
		state.mulligan(foe, foe_cpu.choose_mulligan(state, foe))
	while not state.is_match_over():
		var side := state.current_turn
		(own_cpu if side == mine else foe_cpu).take_turn(state, side)
	var result := [state.winner == mine, int(state.hp[mine])]
	state.free()
	return result


# --- 関門・主を単独で ---------------------------------------------------


## 関門・主を1つ(空なら通常の対局)同じ条件で`games`局指させ、`[回数, 勝ち]`を返す。
func _isolated(gate_id: String, games: int) -> Array:
	var gate := SoloGateLibrary.find_by_id(gate_id)
	var ids := CardCpuDecks.deck_ids()
	var cell := [0, 0]
	for i in games:
		var theme: String = ids[_rng.randi_range(0, ids.size() - 1)]
		var run := SoloRun.create(theme, 0, _rng)
		run.deck_ids = run.deck_ids + run.deck_ids
		var foe_deck: String = (
			gate.cpu_deck if gate != null and not gate.cpu_deck.is_empty() else theme
		)
		while foe_deck == theme:
			foe_deck = ids[_rng.randi_range(0, ids.size() - 1)]
		var kind := SoloRun.Kind.GATE if gate != null else SoloRun.Kind.BATTLE
		var dest := {"kind": kind, "cpu_deck": foe_deck, "gate": gate_id}
		var result := _fight(run, dest, gate, CardCpuStrategy.Difficulty.EXPERT)
		cell[0] += 1
		cell[1] += int(result[0])
	return cell


func _report_isolated(games: int, only: PackedStringArray) -> void:
	_out("")
	_out("### 関門・主を単独で(各%d局・30枚・HP満タン・相手は上級)" % games)
	_out("")
	_out("| 相手 | 勝率 |")
	_out("|---|---|")
	_out("| 通常の対局 | %s |" % _rate(_isolated("", games)))
	for gate in SoloGateLibrary.all_gates():
		if only.is_empty() or gate.id in only:
			_out("| 関門 %s | %s |" % [gate.display_name, _rate(_isolated(gate.id, games))])
	for boss in SoloGateLibrary.all_bosses():
		if not only.is_empty() and boss.id not in only:
			continue
		_out("| 主 %s | %s |" % [boss.display_name, _rate(_isolated(boss.id, games))])


## `{id: [回数, 成功]}` へ1件足す。
func _tally(bucket: Dictionary, id: String, ok: bool) -> void:
	var cell: Array = bucket.get(id, [0, 0])
	cell[0] += 1
	cell[1] += int(ok)
	bucket[id] = cell


# --- 報告 ---------------------------------------------------------------


func _report(stats: Dictionary, depths: Array[int], runs: int) -> void:
	var level_name := "上級" if _player_level == "expert" else "中級"
	_out("## 遠征の通し測定(深さごと%d回・自分側CPUは%s)" % [runs, level_name])
	_out("")
	_out("| 深さ | 踏破率 | 平均勝利数 | 脱落 1段 | 2段 | 3段 | 4段 | 5段 | 6段(主) |")
	_out("|---|---|---|---|---|---|---|---|---|")
	for depth in depths:
		var s: Dictionary = stats[depth]
		var row := (
			"| %d | %s | %.2f |" % [depth, _pct(s["clears"], runs), float(s["wins_total"]) / runs]
		)
		for f in SoloRun.FLOOR_COUNT:
			row += " %s |" % _pct(s["lost_at"][f], runs)
		_out(row)
	_out("")
	_out("### 段ごとの対局の勝率")
	_out("")
	_out(_header("段", depths))
	for f in SoloRun.FLOOR_COUNT:
		var row := "| %d段 |" % (f + 1)
		for depth in depths:
			var cell: Array = stats[depth]["floor_battles"][f]
			row += " %s |" % _rate(cell)
		_out(row)
	_report_table("関門ごとの勝率", SoloGateLibrary.all_gates(), "gates", stats, depths)
	_report_table("主ごとの勝率", SoloGateLibrary.all_bosses(), "bosses", stats, depths)
	_report_boons(stats, depths)
	_out("")
	_out("### 作戦ごとの踏破率")
	_out("")
	_out(_header("作戦", depths))
	for id in CardCpuDecks.deck_ids():
		var row := "| %s |" % CardCpuDecks.name_of(id)
		for depth in depths:
			row += " %s |" % _rate(stats[depth]["themes"].get(id, [0, 0]))
		_out(row)


func _report_table(
	title: String, rows: Array[SoloGateData], key: String, stats: Dictionary, depths: Array[int]
) -> void:
	_out("")
	_out("### %s" % title)
	_out("")
	_out(_header("名前", depths, ["全体"]))
	for gate in rows:
		var row := "| %s |" % gate.display_name
		var total := [0, 0]
		for depth in depths:
			var cell: Array = stats[depth][key].get(gate.id, [0, 0])
			total[0] += cell[0]
			total[1] += cell[1]
			row += " %s |" % _rate(cell)
		_out(row + " %s |" % _rate(total))


## 恩恵は深さをまとめて出す。「得た遠征の踏破率」は関門を越えた遠征ほど高く出るため、
## 恩恵どうしの比較には「得たあとの対局の勝率」を使う。
func _report_boons(stats: Dictionary, depths: Array[int]) -> void:
	_out("")
	_out("### 恩恵ごとの成績(深さをまとめる)")
	_out("")
	_out("| 恩恵 | 得た遠征の踏破率 | 得たあとの対局の勝率 |")
	_out("|---|---|---|")
	for boon in SoloBoonLibrary.all_boons():
		var runs_cell := [0, 0]
		var after_cell := [0, 0]
		for depth in depths:
			var r: Array = stats[depth]["boon_runs"].get(boon.id, [0, 0])
			var a: Array = stats[depth]["boon_after"].get(boon.id, [0, 0])
			runs_cell = [runs_cell[0] + r[0], runs_cell[1] + r[1]]
			after_cell = [after_cell[0] + a[0], after_cell[1] + a[1]]
		_out("| %s | %s | %s |" % [boon.display_name, _rate(runs_cell), _rate(after_cell)])


## 見出しの行と区切りの行。列は深さごと(+ `tail` の列)。
func _header(first: String, depths: Array[int], tail: Array[String] = []) -> String:
	var head := "| %s |" % first
	var rule := "|---|"
	for depth in depths:
		head += " 深さ%d |" % depth
		rule += "---|"
	for title in tail:
		head += " %s |" % title
		rule += "---|"
	return head + "\n" + rule


func _out(text: String) -> void:
	print(text)
	_lines.append(text)


func _pct(count: int, total: int) -> String:
	return "%.0f%%" % (float(count) / maxf(total, 1) * 100.0)


## `[回数, 成功]` を「勝率 (回数)」に。
func _rate(cell: Array) -> String:
	if int(cell[0]) == 0:
		return "─"
	return "%s (%d)" % [_pct(cell[1], cell[0]), cell[0]]


func _parse_args() -> Dictionary:
	var parsed: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			parsed[pair[0]] = pair[1]
	return parsed
