extends SceneTree
## 砂術の1手読み(`CardCpuStrategy.spell_lookahead`)の新旧を、同じデッキどうしで戦わせる
## (docs/BalanceReport_v5.md 17章)。毎局デッキを1つ作り両者に持たせ、先後を交互にする。
##
## 使い方:
##   Godot --headless --path . --script tools/balance/run_cpu_spell_ab.gd -- \
##       games=800 seed=42 spells=6 level=normal
##
## `spells` はデッキに入れる砂術の種類数(各2枚、残りは砂時計)。-1 なら砂術を絞らない混成デッキ。
## `old_level` を与えると旧来側の思考レベルを別にできる(思考レベルの差の確認用)。

const COPY_LIMIT := 2
const KINDS := 15
const LEVELS := {
	"beginner": CardCpuStrategy.Difficulty.BEGINNER,
	"normal": CardCpuStrategy.Difficulty.NORMAL,
	"expert": CardCpuStrategy.Difficulty.EXPERT,
}

var _rng := RandomNumberGenerator.new()
var _spells: Array[CardData] = []
var _units: Array[CardData] = []
var _stats := {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var games := int(args.get("games", "800"))
	var spell_kinds := int(args.get("spells", "6"))
	var level: CardCpuStrategy.Difficulty = LEVELS[args.get("level", "normal")]
	var old_level: CardCpuStrategy.Difficulty = LEVELS[args.get(
		"old_level", args.get("level", "normal")
	)]
	_rng.seed = int(args.get("seed", "42"))
	for card in CardLibrary.all_cards():
		if not card.set_id.is_empty() and CardSetLibrary.price(card.set_id) <= 0:
			continue
		(_spells if card.is_spell else _units).append(card)
	for key in ["new", "old"]:
		_stats[key] = {"wins": 0, "cast": 0, "held": 0, "think_us": 0, "calls": 0, "max_us": 0}
	var decisive := 0
	for g in games:
		var deck := _deck(spell_kinds)
		var new_cpu := CardCpuStrategy.new()
		new_cpu.difficulty = level
		var old_cpu := CardCpuStrategy.new()
		old_cpu.difficulty = old_level
		old_cpu.spell_lookahead = false
		var winner := _play(deck, new_cpu, old_cpu, g % 2 == 0)
		if winner == "":
			continue
		decisive += 1
		_stats[winner]["wins"] += 1
	print("=== 砂術の1手読み 新旧 (%d局・seed %d・砂術%d種) ===" % [decisive, _rng.seed, spell_kinds])
	print("新の勝率 %5.1f%%" % (float(_stats["new"]["wins"]) / maxf(decisive, 1) * 100.0))
	for key in ["new", "old"]:
		var s: Dictionary = _stats[key]
		print(
			(
				"%s: 撃った %d / 引いた砂術 %d (%5.1f%%)・1手の思考 平均 %.2fms 最大 %.1fms"
				% [
					key,
					s["cast"],
					s["cast"] + s["held"],
					float(s["cast"]) / maxf(s["cast"] + s["held"], 1) * 100.0,
					float(s["think_us"]) / maxf(s["calls"], 1) / 1000.0,
					float(s["max_us"]) / 1000.0
				]
			)
		)
	quit()


## 勝った側の "new" / "old"、引き分けは空。
func _play(
	deck: Array, new_cpu: CardCpuStrategy, old_cpu: CardCpuStrategy, new_first: bool
) -> String:
	var state := MatchState.new()
	state.start_match(deck, deck.duplicate(), MatchState.Side.A, _rng.randi_range(1, 1 << 30))
	var names := {
		MatchState.Side.A: "new" if new_first else "old",
		MatchState.Side.B: "old" if new_first else "new",
	}
	var cpus := {
		MatchState.Side.A: new_cpu if new_first else old_cpu,
		MatchState.Side.B: old_cpu if new_first else new_cpu,
	}
	state.spell_cast.connect(
		func(side: int, _card: CardData) -> void: _stats[names[side]]["cast"] += 1
	)
	if state.mulligan_pending:
		for side in cpus:
			state.mulligan(side, cpus[side].choose_mulligan(state, side))
	var guard := 0
	while not state.is_match_over() and guard < 2000:
		guard += 1
		var side := state.current_turn
		var cpu: CardCpuStrategy = cpus[side]
		var started := Time.get_ticks_usec()
		var action := cpu.choose_action(state, side)
		var spent := Time.get_ticks_usec() - started
		var s: Dictionary = _stats[names[side]]
		s["think_us"] += spent
		s["calls"] += 1
		s["max_us"] = maxi(s["max_us"], spent)
		MatchAction.apply(state, action)
	for side in cpus:
		_stats[names[side]]["held"] += (
			state.hand[side].filter(func(card: CardData) -> bool: return card.is_spell).size()
		)
	if state.winner < 0:
		return ""
	return names[state.winner]


## 砂術 `spell_kinds` 種と砂時計の残りを各2枚で30枚。負なら全プールから混成。
func _deck(spell_kinds: int) -> Array:
	var picked: Array = []
	if spell_kinds < 0:
		var pool: Array = _spells + _units
		_shuffle(pool)
		picked = pool.slice(0, KINDS)
	else:
		var spells := _spells.duplicate()
		var units := _units.duplicate()
		_shuffle(spells)
		_shuffle(units)
		picked = spells.slice(0, spell_kinds) + units.slice(0, KINDS - spell_kinds)
	var deck: Array = []
	for card in picked:
		for i in COPY_LIMIT:
			deck.append(card)
	return deck


func _shuffle(cards: Array) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = cards[i]
		cards[i] = cards[j]
		cards[j] = tmp


func _parse_args() -> Dictionary:
	var parsed: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			parsed[pair[0]] = pair[1]
	return parsed
