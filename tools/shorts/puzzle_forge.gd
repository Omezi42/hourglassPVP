extends SceneTree
## とどめ問題ショート用の「しっかり考えないと解けない」問題を探し、--out= のJSONへ足す。
## 盤面をランダムに組み、総当たり(puzzle_solver.gd)で最大打点を測って相手HPをそれに合わせ
## (=最善手順でしか届かず、届けばぴったり0になる)、難しさの基準を満たすものだけを残す。
##
## ふだんは make_short.py forge <問数> から並列で回し、結果を tools/shorts/puzzles.json へまとめる。
##   godot --headless --path . --script res://tools/shorts/puzzle_forge.gd --
##     --count=3 --seed=1 --out=<json>

const Solver := preload("res://tools/shorts/puzzle_solver.gd")
const BOOK_PATH := "res://tools/shorts/puzzles.json"
const MAX_TRIES := 4000

## 難しさの基準。でたらめに指して勝てる確率・勝ちに繋がる初手の割合が小さく、手数が多いこと。
const MAX_P_RANDOM := 0.02
const MAX_GOOD_FIRST_RATIO := 0.3
const MIN_LEN := 4
## 正解の再生が長くなりすぎない手数と、考える時間に出す効果の説明の行数の上限。
const MAX_LEN := 7
const MAX_LEGEND := 4
## 見て数えられる規模に収める(動画の5秒で盤面を読めること)。
const MIN_DAMAGE := 5
const MAX_DAMAGE := 20
const OWN_UNITS := Vector2i(2, 4)
const FOE_UNITS := Vector2i(1, 3)
const HAND_CARDS := Vector2i(1, 3)
const MANA := Vector2i(1, 5)
const GUARD_CHANCE := 0.5
const MAX_WOUND := 2
## `CardData.describe()` が効果の無いカードに返す文。
const NO_EFFECT_TEXT := "効果なし"
const HINT := "このターンで相手の体力をちょうど0にしよう"

var _rng := RandomNumberGenerator.new()
var _units: Array[CardData] = []
var _guards: Array[CardData] = []
var _hand_pool: Array[CardData] = []


func _init() -> void:
	var count := 5
	var seed_value := 1
	var verbose := false
	var out_path := BOOK_PATH
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--count="):
			count = int(arg.trim_prefix("--count="))
		elif arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
		elif arg == "--verbose":
			verbose = true
	_rng.seed = seed_value
	_build_pools()
	var saved: Array = _load(out_path)
	var known := {}
	for entry in saved + _load(BOOK_PATH):
		known[_signature(entry["stage"])] = true
	var solver := Solver.new()
	var added := 0
	for attempt in MAX_TRIES:
		if added >= count:
			break
		var stage := _random_stage()
		if known.has(_signature(_stage_dict(stage))) or legend_size(stage) > MAX_LEGEND:
			continue
		var started := Time.get_ticks_msec()
		var damage := solver.max_damage(stage)
		var report := {}
		if damage >= MIN_DAMAGE and damage <= MAX_DAMAGE:
			stage.foe_hp = damage
			report = solver.analyze(stage)
		if verbose:
			print(
				(
					"試行%d  打点%d  局面%d  %dms  %s"
					% [
						attempt,
						damage,
						solver.nodes,
						Time.get_ticks_msec() - started,
						JSON.stringify(_metrics(report)) if not report.is_empty() else ""
					]
				)
			)
		if report.is_empty() or not _hard_enough(report):
			continue
		var entry := {
			"stage": _stage_dict(stage), "solution": report["solution"], "metrics": _metrics(report)
		}
		saved.append(entry)
		known[_signature(entry["stage"])] = true
		added += 1
		print("#%d  hp=%d  %s" % [saved.size(), damage, JSON.stringify(entry["metrics"])])
		_save(out_path, saved)
	print("追加 %d 問(試行 %d)" % [added, MAX_TRIES])
	quit()


func _hard_enough(report: Dictionary) -> bool:
	var ratio := float(report["good_first"]) / maxf(float(report["first"]), 1.0)
	return (
		float(report["p_random"]) <= MAX_P_RANDOM
		and ratio <= MAX_GOOD_FIRST_RATIO
		and int(report["min_len"]) >= MIN_LEN
		and int(report["min_len"]) <= MAX_LEN
	)


func _metrics(report: Dictionary) -> Dictionary:
	return {
		"p_random": snappedf(float(report["p_random"]), 0.0001),
		"good_first": report["good_first"],
		"first": report["first"],
		"min_len": report["min_len"],
	}


## 撮影に向く(読める・結果が決まる)カードだけを使う。
## 引く効果は山札の並びで結果が変わり、ターン終了時の効果はこの1手番では働かず、回復は打点に関わらない。
func _build_pools() -> void:
	for card in CardLibrary.all_cards():
		if not _usable(card):
			continue
		if card.is_spell:
			_hand_pool.append(card)
			continue
		_units.append(card)
		if card.has_keyword(CardEnums.Keyword.GUARD):
			_guards.append(card)
		_hand_pool.append(card)


func _usable(card: CardData) -> bool:
	for effect in card.effects:
		if effect.trigger == CardEnums.Trigger.ON_TURN_END:
			return false
		if (
			effect.effect_type
			in [
				CardEnums.EffectType.DRAW,
				CardEnums.EffectType.HEAL_PLAYER,
				CardEnums.EffectType.INVERT_PLAYER_HP,
			]
		):
			return false
	return true


func _random_stage() -> PuzzleStageData:
	var stage := PuzzleStageData.new()
	stage.id = "forge"
	stage.title = "とどめ問題"
	stage.hint = HINT
	stage.own_hp = MatchState.INITIAL_HP
	stage.mana = _rng.randi_range(MANA.x, MANA.y)
	stage.own_units = _random_rows(_rng.randi_range(OWN_UNITS.x, OWN_UNITS.y), false)
	stage.foe_units = _random_rows(_rng.randi_range(FOE_UNITS.x, FOE_UNITS.y), true)
	# 手札は払えるカードだけにする(出せないカードは迷わせる役にも立たない)。
	var affordable: Array[CardData] = []
	for card in _hand_pool:
		if card.cost <= stage.mana:
			affordable.append(card)
	var hand: Array[String] = []
	for i in _rng.randi_range(HAND_CARDS.x, HAND_CARDS.y):
		hand.append(_pick(affordable).id)
	stage.hand_ids = hand
	return stage


## 盤面の行。空き枠は "-"(`PuzzleStageData.parse_unit` が読めずに飛ばす)で表し、駒の位置を散らす。
func _random_rows(count: int, foe: bool) -> Array[String]:
	var rows: Array[String] = []
	for i in MatchState.BOARD_SIZE:
		rows.append("-")
	var slots := range(MatchState.BOARD_SIZE)
	for i in count:
		var slot: int = slots.pop_at(_rng.randi_range(0, slots.size() - 1))
		var card: CardData
		if foe and i == 0 and not _guards.is_empty() and _rng.randf() < GUARD_CHANCE:
			card = _pick(_guards)
		else:
			card = _pick(_units)
		var total := maxi(card.total_sand - _rng.randi_range(0, MAX_WOUND), 1)
		var health := _rng.randi_range(1, total)
		rows[slot] = "%s:%d:%d" % [card.id, health, total - health]
	return rows


func _pick(pool: Array[CardData]) -> CardData:
	return pool[_rng.randi_range(0, pool.size() - 1)]


func _stage_dict(stage: PuzzleStageData) -> Dictionary:
	return {
		"title": stage.title,
		"hint": stage.hint,
		"foe_hp": stage.foe_hp,
		"own_hp": stage.own_hp,
		"mana": stage.mana,
		"hand_ids": stage.hand_ids,
		"own_units": stage.own_units,
		"foe_units": stage.foe_units,
	}


func _signature(stage: Dictionary) -> String:
	return JSON.stringify(
		[stage["mana"], stage["hand_ids"], stage["own_units"], stage["foe_units"]]
	)


## 盤面と手札に出てくるカードのうち、効果の説明が要る(「効果なし」でない)ものの数。
static func legend_size(stage: PuzzleStageData) -> int:
	var ids := {}
	for row in stage.own_units + stage.foe_units:
		var parsed := PuzzleStageData.parse_unit(row)
		if not parsed.is_empty():
			ids[(parsed["card"] as CardData).id] = parsed["card"]
	for id in stage.hand_ids:
		ids[id] = CardLibrary.find_by_id(id)
	var count := 0
	for card in ids.values():
		if (card as CardData).describe() != NO_EFFECT_TEXT:
			count += 1
	return count


func _load(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Array else []


func _save(path: String, entries: Array) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(entries, "\t") + "\n")
	file.close()
