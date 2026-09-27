class_name SoloRun
extends RefCounted
## 遠征(ソロモード)1回ぶんの状態と規則(GameDesign.md 27章、Architecture.md 10.15節)。
## 対局画面から切り離した純粋なロジックで、乱数は呼び出し側から受け取る。
## `to_dict()` / `from_dict()` はそのままJSONへ通せる形(enumは整数)。

## 行き先の種類。泉は `cpu_deck` / `gate` を空文字のまま持つ。
enum Kind { BATTLE, GATE, SPRING }

const FLOOR_COUNT := 6
const SPRING_HEAL := 8
const OFFER_SIZE := 3
const GATE_OFFER_SIZE := 4
const THEME_CHOICES := 3
const EXPERT_FROM_FLOOR := 2
const GOLD_PER_WIN := 20
const CLEAR_GOLD := 100
## 同名カードは山札に2枚まで(GameDesign.md 27章「山札を育てる」)。
const MAX_DECK_COPIES := 2

## 遠征をまたいで残る限定カード・アイコンの節目(GameDesign.md 27章)。
## `wins` を持つ行は初めてその勝利数に届いたとき、`cleared` を持つ行は
## 初めて踏破したときに解放する。
const MILESTONES: Array[Dictionary] = [
	{"id": "solo_wins_2", "wins": 2, "card_set": "solo_chime", "icon": ""},
	{"id": "solo_wins_4", "wins": 4, "card_set": "solo_ward", "icon": ""},
	{"id": "solo_cleared", "cleared": true, "card_set": "solo_goad", "icon": "glow"},
]

var theme_id := ""
var deck_ids: Array[String] = []
var hp := MatchState.INITIAL_HP
## いま選ぶ段(0始まり)。`FLOOR_COUNT` に達したら踏破。
var floor := 0
var wins := 0
## 段ごとの行き先の配列。`route[floor]` が、その段で選べる行き先(2〜3個)の配列。
## 行き先は `{"kind": Kind, "cpu_deck": id, "gate": id}`(泉は空文字)。
var route: Array = []
## 勝った直後に選べる候補。空なら候補待ちではない。
var offer: Array[String] = []
## 行き先の対局を始めてから決着するまで true。
var in_battle := false
var over := false
var cleared := false

## いま挑んでいる行き先(`in_battle` の間だけ有効。保存はしない——
## 中断は負けとして扱うため、復元する必要がない)。
var _active: Dictionary = {}


## 出発で示す作戦(`CardCpuDecks` のid)を3つ。
static func theme_choices(rng: RandomNumberGenerator) -> Array[String]:
	var ids: Array[String] = []
	for id in _shuffled(CardCpuDecks.deck_ids(), rng):
		ids.append(str(id))
	return ids.slice(0, THEME_CHOICES)


## 作戦の15種を1枚ずつ山札にし、道を作る(GameDesign.md 27章「遠征の流れ」)。
static func create(theme_id: String, rng: RandomNumberGenerator) -> SoloRun:
	var run := SoloRun.new()
	run.theme_id = theme_id
	run.deck_ids = _unique_ids(CardCpuDecks.deck_of(theme_id))
	run.hp = MatchState.INITIAL_HP
	run.route = _build_route(rng)
	return run


## 段で決まる思考レベル(GameDesign.md 27章「道」)。
func difficulty() -> int:
	if floor >= EXPERT_FROM_FLOOR:
		return CardCpuStrategy.Difficulty.EXPERT
	return CardCpuStrategy.Difficulty.NORMAL


## いまの段で選べる行き先。候補待ち・決着後は空。
func current_destinations() -> Array:
	if over or in_battle or not offer.is_empty() or floor >= route.size():
		return []
	return route[floor]


func active_destination() -> Dictionary:
	return _active


## いまの段の行き先を選ぶ。泉なら回復して次の段へ進む。対局・関門なら `in_battle` を立てる。
func choose(index: int, _rng: RandomNumberGenerator) -> void:
	var options := current_destinations()
	if index < 0 or index >= options.size():
		return
	var dest: Dictionary = options[index]
	if int(dest.get("kind", Kind.BATTLE)) == Kind.SPRING:
		hp = mini(hp + SPRING_HEAL, MatchState.INITIAL_HP)
		floor += 1
		return
	_active = dest
	in_battle = true


## 行き先の対局の決着を返す。勝ちなら`wins`と`floor`を進め、`hp`を控え、候補を作る
## (最終段なら踏破)。負けなら遠征を終える。
func finish_battle(won: bool, hp_left: int, rng: RandomNumberGenerator) -> void:
	var was_gate := int(_active.get("kind", Kind.BATTLE)) == Kind.GATE
	in_battle = false
	hp = maxi(hp_left, 0)
	_active = {}
	if not won:
		over = true
		return
	wins += 1
	floor += 1
	if floor >= FLOOR_COUNT:
		cleared = true
		over = true
		return
	offer = _build_offer(rng, was_gate)


## 候補から1枚を山札へ足す。
func take(card_id: String) -> void:
	if not offer.has(card_id):
		return
	deck_ids.append(card_id)
	offer = []


## 候補を足さずに見送る。
func pass_offer() -> void:
	offer = []


func to_dict() -> Dictionary:
	return {
		"theme_id": theme_id,
		"deck_ids": deck_ids,
		"hp": hp,
		"floor": floor,
		"wins": wins,
		"route": route,
		"offer": offer,
		"in_battle": in_battle,
		"over": over,
		"cleared": cleared,
	}


static func from_dict(data: Dictionary) -> SoloRun:
	var run := SoloRun.new()
	run.theme_id = str(data.get("theme_id", ""))
	for id in data.get("deck_ids", []):
		run.deck_ids.append(str(id))
	run.hp = int(data.get("hp", MatchState.INITIAL_HP))
	run.floor = int(data.get("floor", 0))
	run.wins = int(data.get("wins", 0))
	run.route = _route_from_variant(data.get("route", []))
	for id in data.get("offer", []):
		run.offer.append(str(id))
	run.in_battle = bool(data.get("in_battle", false))
	run.over = bool(data.get("over", false))
	run.cleared = bool(data.get("cleared", false))
	return run


static func _route_from_variant(raw: Variant) -> Array:
	var route: Array = []
	if not (raw is Array):
		return route
	for floor_options in raw:
		var options: Array = []
		if floor_options is Array:
			for entry in floor_options:
				if entry is Dictionary:
					(
						options
						. append(
							{
								"kind": int(entry.get("kind", Kind.BATTLE)),
								"cpu_deck": str(entry.get("cpu_deck", "")),
								"gate": str(entry.get("gate", "")),
							}
						)
					)
		route.append(options)
	return route


## 8つのCPUデッキ(floors 0〜4で7つ・最終戦で1つ)・7つの関門を切り混ぜて重複なく割り当てる。
## 1〜5段目は2〜3個、6段目は対局1つだけ(GameDesign.md 27章「道」)。
static func _build_route(rng: RandomNumberGenerator) -> Array:
	var deck_pool := _string_array(_shuffled(CardCpuDecks.deck_ids(), rng))
	var final_deck: String = deck_pool.pop_back()
	var gate_pool := _string_array(_shuffled(SoloGateLibrary.all_ids(), rng))
	# 8つのうち7つをfloors 0〜4へ配る。1段目は泉が出せないため必ず2つ受け取る。
	# 残る1つは1〜4段目のうちどれか1段へ(その段は行き先が3個になり得る)。
	var extra_floor := 1 + rng.randi_range(0, 3)
	var route: Array = []
	for floor_i in range(FLOOR_COUNT - 1):
		var non_spring_count := 2 if (floor_i == 0 or floor_i == extra_floor) else 1
		var destinations: Array = []
		for _n in non_spring_count:
			destinations.append(_next_destination(deck_pool, gate_pool, rng))
		var allow_spring := floor_i > 0
		var add_spring := allow_spring and (non_spring_count == 1 or rng.randf() < 0.5)
		if add_spring:
			destinations.append({"kind": Kind.SPRING, "cpu_deck": "", "gate": ""})
		route.append(_shuffled(destinations, rng))
	route.append([{"kind": Kind.BATTLE, "cpu_deck": final_deck, "gate": ""}])
	return route


static func _next_destination(
	deck_pool: Array[String], gate_pool: Array[String], rng: RandomNumberGenerator
) -> Dictionary:
	var deck_id: String = deck_pool.pop_back()
	if not gate_pool.is_empty() and rng.randf() < 0.5:
		var gate_id: String = gate_pool.pop_back()
		return {"kind": Kind.GATE, "cpu_deck": deck_id, "gate": gate_id}
	return {"kind": Kind.BATTLE, "cpu_deck": deck_id, "gate": ""}


## 勝った候補(27章「山札を育てる」)。1枚は作戦のCPUデッキの15種から、残りは
## 「基本セット + `price > 0` のカードセット」のうちトークンでないカードから。
## 山札に既に2枚あるカード・同じ候補の中の重複は除く。
func _build_offer(rng: RandomNumberGenerator, is_gate: bool) -> Array[String]:
	var size := GATE_OFFER_SIZE if is_gate else OFFER_SIZE
	var counts := _deck_counts()
	var result: Array[String] = []
	var theme_pool: Array[String] = []
	for id in _unique_ids(CardCpuDecks.deck_of(theme_id)):
		if int(counts.get(id, 0)) < MAX_DECK_COPIES:
			theme_pool.append(id)
	theme_pool = _string_array(_shuffled(theme_pool, rng))
	if not theme_pool.is_empty():
		result.append(theme_pool[0])
	var general_pool: Array[String] = []
	for card in CardLibrary.all_cards():
		if result.has(card.id):
			continue
		if int(counts.get(card.id, 0)) >= MAX_DECK_COPIES:
			continue
		if not (card.set_id.is_empty() or CardSetLibrary.price(card.set_id) > 0):
			continue
		general_pool.append(card.id)
	general_pool = _string_array(_shuffled(general_pool, rng))
	for id in general_pool:
		if result.size() >= size:
			break
		if result.has(id):
			continue
		result.append(id)
	return result


func _deck_counts() -> Dictionary:
	var counts := {}
	for id in deck_ids:
		counts[id] = int(counts.get(id, 0)) + 1
	return counts


static func _unique_ids(cards: Array) -> Array[String]:
	var ids: Array[String] = []
	for card: CardData in cards:
		if not ids.has(card.id):
			ids.append(card.id)
	return ids


static func _string_array(items: Array) -> Array[String]:
	var found: Array[String] = []
	for item in items:
		found.append(str(item))
	return found


static func _shuffled(items: Array, rng: RandomNumberGenerator) -> Array:
	var copy := items.duplicate()
	for i in range(copy.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = copy[i]
		copy[i] = copy[j]
		copy[j] = tmp
	return copy
