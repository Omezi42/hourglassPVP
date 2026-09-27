class_name SoloRun
extends RefCounted
## 遠征(ソロモード)1回ぶんの状態と規則(GameDesign.md 27章、Architecture.md 10.15節)。
## 対局画面から切り離した純粋なロジックで、乱数は呼び出し側から受け取る。
## `to_dict()` / `from_dict()` はそのままJSONへ通せる形(enumは整数)。

## 行き先の種類。泉・工房は `cpu_deck` / `gate` を空文字のまま持つ。
## `WORKSHOP` は保存データ(`route`)の一部のため末尾へ足す(Pitfalls.md)。
enum Kind { BATTLE, GATE, SPRING, WORKSHOP }

const FLOOR_COUNT := 6
const SPRING_HEAL := 8
const THEME_CHOICES := 3
const EXPERT_FROM_FLOOR := 2
const GOLD_PER_WIN := 20
const CLEAR_GOLD := 100
## 同名カードは山札に2枚まで(GameDesign.md 27章「山札を育てる」)。
const MAX_DECK_COPIES := 2
## 束の数(既定)。恩恵「目利き」の`extra_bundles`だけ増える。
const BUNDLE_COUNT := 3
## 1つの束の中のカード枚数。
const BUNDLE_CARDS := 3
## 恩恵の候補数。
const BOON_OFFER_SIZE := 3
## 相手が自分の山札の写しを使うときの相手の名前(GameDesign.md 27章「画面」)。
const MIRROR_FOE_NAME := "あなたの山札"
## 踏破の砂金は深さに応じて増える(GameDesign.md 27章「遠征をまたいで残るもの」)。
const CLEAR_GOLD_PER_DEPTH := 50

## 砂の深さ(難度)の上限(GameDesign.md 27章「砂の深さ」)。
const DEPTH_MAX := 5
const DEPTH_EXPERT_FROM := 1
const DEPTH_SPRING_FROM := 2
const DEPTH_SPRING_HEAL := 5
const DEPTH_FOE_HP_FROM := 3
const DEPTH_FOE_HP_BONUS := 4
const DEPTH_BUNDLE_FROM := 4
const DEPTH_BUNDLE_PENALTY := 1
const DEPTH_MAX_HP_FROM := 5
const DEPTH_START_MAX_HP := 20

## 深さで加わる条件(出発の画面の一覧に使う。GameDesign.md 27章「砂の深さ」)。
## 条件は積み重なる——`depth_condition_lines()`は`depth`以下のものをすべて返す。
const DEPTH_CONDITIONS: Array[Dictionary] = [
	{"depth": 1, "text": "CPUが1段目から上級"},
	{"depth": 2, "text": "泉の回復が5になる"},
	{"depth": 3, "text": "相手のHPが4多い状態で対局を始める"},
	{"depth": 4, "text": "束の候補が1つ減る"},
	{"depth": 5, "text": "遠征の開始時の最大HPが20"},
]

## 遠征をまたいで残る限定カード・アイコンの節目(GameDesign.md 27章)。
## `wins` を持つ行は初めてその勝利数に届いたとき、`cleared` を持つ行は
## 初めて踏破したときに解放する。
const MILESTONES: Array[Dictionary] = [
	{"id": "solo_wins_2", "wins": 2, "card_set": "solo_chime", "icon": ""},
	{"id": "solo_wins_4", "wins": 4, "card_set": "solo_ward", "icon": ""},
	{"id": "solo_cleared", "cleared": true, "card_set": "solo_goad", "icon": "glow"},
]

var theme_id := ""
## 最終戦の主(`data/solo_bosses/`のid。GameDesign.md 27章「主」)。出発の画面で決まる。
## 主が無かった頃の保存データは空で、最終戦は通常の対局になる。
var boss_id := ""
var deck_ids: Array[String] = []
## 砂の深さ(難度。0〜`DEPTH_MAX`)。踏破したあとも条件を重ねて挑み直せる
## (GameDesign.md 27章「砂の深さ」)。遠征の間は変わらない。
var depth := 0
var hp := MatchState.INITIAL_HP
## 恩恵「丈夫な体」で伸びる最大HP(GameDesign.md 27章「恩恵」)。
var max_hp := MatchState.INITIAL_HP
## いま選ぶ段(0始まり)。`FLOOR_COUNT` に達したら踏破。
var floor := 0
var wins := 0
## 段ごとの行き先の配列。`route[floor]` が、その段で選べる行き先(2〜3個)の配列。
## 行き先は `{"kind": Kind, "cpu_deck": id, "gate": id}`(泉・工房は空文字)。
var route: Array = []
## 勝った直後に選べる束の候補。空なら候補待ちではない。
## 束は `{"theme": id, "cards": [id, id, id]}`。
var offer: Array[Dictionary] = []
## 関門に勝った直後に選べる恩恵の候補。空なら候補待ちではない。
var boon_offer: Array[String] = []
## `boon_offer`を作った関門のid(恩恵の画面の小見出し「関門『名前』を越えた」用)。
var last_gate_id := ""
## 得た恩恵のid(GameDesign.md 27章「恩恵」。同じ恩恵は1回の遠征で1度だけ)。
var boons: Array[String] = []
## 工房を開いている間 true(GameDesign.md 27章「画面」)。
var workshop_open := false
## 段ごとに選んだ行き先のindex(`route[i]`の中の位置)。道の描画で、選び終えた段の
## どの駒を真鍮で明るくするかに使う(画面・27章)。`choose()`のたびに足す。
var chosen: Array[int] = []
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


## 出発で示す最終戦の主(GameDesign.md 27章「主」)。主が1体も無ければ空。
static func boss_choice(rng: RandomNumberGenerator) -> String:
	var ids := SoloGateLibrary.boss_ids()
	if ids.is_empty():
		return ""
	return ids[rng.randi_range(0, ids.size() - 1)]


## 作戦の15種を1枚ずつ山札にし、道を作る(GameDesign.md 27章「遠征の流れ」)。
static func create(
	theme_id: String, depth: int, rng: RandomNumberGenerator, boss_id: String = ""
) -> SoloRun:
	var run := SoloRun.new()
	run.theme_id = theme_id
	run.boss_id = boss_id
	run.depth = clampi(depth, 0, DEPTH_MAX)
	run.deck_ids = _unique_ids(CardCpuDecks.deck_of(theme_id))
	run.max_hp = starting_max_hp(run.depth)
	run.hp = run.max_hp
	run.route = _build_route(rng, boss_id)
	return run


## 行き先の相手の名前(「CPU ・ 速攻」)。相手が自分の山札の写しを使う関門・主では
## 「CPU ・ あなたの山札」(GameDesign.md 27章「画面」)。
static func foe_name_of(dest: Dictionary) -> String:
	if uses_player_deck(dest):
		return CardCpuDecks.FOE_NAME_PREFIX + MIRROR_FOE_NAME
	return CardCpuDecks.foe_name_of(str(dest.get("cpu_deck", "")))


static func uses_player_deck(dest: Dictionary) -> bool:
	var gate := SoloGateLibrary.find_by_id(str(dest.get("gate", "")))
	return gate != null and gate.foe_uses_player_deck


## 遠征開始時の最大HP(GameDesign.md 27章「砂の深さ」)。深さ5で20になる。
static func starting_max_hp(depth: int) -> int:
	return DEPTH_START_MAX_HP if depth >= DEPTH_MAX_HP_FROM else MatchState.INITIAL_HP


## 深さで加わる条件の説明。積み重なるため`depth`以下のものをすべて返す
## (GameDesign.md 27章「砂の深さ」)。深さ0は空(呼び出し側が「条件なし」を出す)。
static func depth_condition_lines(depth: int) -> Array[String]:
	var lines: Array[String] = []
	for entry in DEPTH_CONDITIONS:
		if int(entry["depth"]) <= depth:
			lines.append(str(entry["text"]))
	return lines


## 段で決まる思考レベルの閾値。深さ1以上はCPUが1段目から上級になる
## (GameDesign.md 27章「道」「砂の深さ」)。
func expert_from_floor() -> int:
	return 0 if depth >= DEPTH_EXPERT_FROM else EXPERT_FROM_FLOOR


## 段で決まる思考レベル(GameDesign.md 27章「道」)。
func difficulty() -> int:
	if floor >= expert_from_floor():
		return CardCpuStrategy.Difficulty.EXPERT
	return CardCpuStrategy.Difficulty.NORMAL


## 踏破の砂金(GameDesign.md 27章「遠征をまたいで残るもの」)。深さに応じて増える。
func clear_gold() -> int:
	return CLEAR_GOLD + depth * CLEAR_GOLD_PER_DEPTH


## いまの段で選べる行き先。候補待ち・工房を開いている間・決着後は空。
func current_destinations() -> Array:
	if (
		over
		or in_battle
		or workshop_open
		or not offer.is_empty()
		or not boon_offer.is_empty()
		or floor >= route.size()
	):
		return []
	return route[floor]


func active_destination() -> Dictionary:
	return _active


## いまの段の行き先を選ぶ。泉なら回復して次の段へ進み、工房なら開く。対局・関門なら
## `in_battle` を立てる。
func choose(index: int, _rng: RandomNumberGenerator) -> void:
	var options := current_destinations()
	if index < 0 or index >= options.size():
		return
	chosen.append(index)
	var dest: Dictionary = options[index]
	var kind := int(dest.get("kind", Kind.BATTLE))
	if kind == Kind.SPRING:
		hp = mini(hp + spring_heal() + spring_bonus(), max_hp)
		floor += 1
		return
	if kind == Kind.WORKSHOP:
		workshop_open = true
		return
	_active = dest
	in_battle = true


## 行き先の対局の決着を返す。勝ちなら`wins`と`floor`を進め、`hp`を控え、関門なら恩恵の
## 候補を、それ以外は束の候補を作る(最終段なら踏破)。負けなら遠征を終える。
func finish_battle(won: bool, hp_left: int, rng: RandomNumberGenerator) -> void:
	var was_gate := int(_active.get("kind", Kind.BATTLE)) == Kind.GATE
	var gate_id := str(_active.get("gate", ""))
	in_battle = false
	hp = maxi(hp_left, 0)
	_active = {}
	if not won:
		over = true
		return
	hp = mini(hp + win_heal(), max_hp)
	wins += 1
	floor += 1
	if floor >= FLOOR_COUNT:
		cleared = true
		over = true
		return
	if was_gate:
		last_gate_id = gate_id
		boon_offer = _build_boon_offer(rng)
	else:
		offer = _build_bundle_offer(rng)


## 恩恵の候補から1つ得る。丈夫な体は即座にHPも回復する。束の候補はこのあとに作る
## (GameDesign.md 27章「恩恵」)。
func take_boon(id: String) -> void:
	if not boon_offer.has(id):
		return
	boons.append(id)
	boon_offer = []
	var boon := SoloBoonLibrary.find_by_id(id)
	if boon != null and boon.max_hp_bonus != 0:
		max_hp = maxi(max_hp + boon.max_hp_bonus, 1)
		hp = clampi(hp + maxi(boon.max_hp_bonus, 0), 1, max_hp)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	offer = _build_bundle_offer(rng)


## 束を1つ選び、その3枚をまとめて山札へ足す。
func take_bundle(index: int) -> void:
	if index < 0 or index >= offer.size():
		return
	var bundle: Dictionary = offer[index]
	for id in bundle.get("cards", []):
		deck_ids.append(str(id))
	offer = []


## 束を足さずに見送る。
func pass_offer() -> void:
	offer = []


## 山札から1枚を抜く。工房を閉じ、次の段へ進む。
func workshop_remove(card_id: String) -> void:
	if not workshop_open:
		return
	var index := deck_ids.find(card_id)
	if index == -1:
		return
	deck_ids.remove_at(index)
	_close_workshop()


## 山札の1枚を複製する(同名は2枚まで)。工房を閉じ、次の段へ進む。
func workshop_duplicate(card_id: String) -> void:
	if not workshop_open:
		return
	if not deck_ids.has(card_id):
		return
	if deck_ids.count(card_id) >= MAX_DECK_COPIES:
		return
	deck_ids.append(card_id)
	_close_workshop()


## 何もせず工房を閉じ、次の段へ進む。
func workshop_skip() -> void:
	if not workshop_open:
		return
	_close_workshop()


func _close_workshop() -> void:
	workshop_open = false
	floor += 1


## 泉で回復する基礎量。深さ2以上では基礎量そのものが5になる(GameDesign.md 27章
## 「砂の深さ」)。恩恵「深い泉」の`spring_bonus()`はこの上に足す。
func spring_heal() -> int:
	return DEPTH_SPRING_HEAL if depth >= DEPTH_SPRING_FROM else SPRING_HEAL


## 対局開始時に相手のHPへ足す増減。深さ3以上の+4と恩恵「先制の砂」の-3を合算する
## (GameDesign.md 27章「砂の深さ」「恩恵」)。下限1は呼び出し側(`CardMatchSolo`)が当てる。
func foe_hp_delta() -> int:
	var bonus := DEPTH_FOE_HP_BONUS if depth >= DEPTH_FOE_HP_FROM else 0
	return bonus - foe_hp_penalty()


## 束の候補数。恩恵「目利き」の`extra_bundles()`と深さ4以上の-1を合算し、最低1つは残す
## (GameDesign.md 27章「山札を育てる」「砂の深さ」)。
func bundle_target() -> int:
	var penalty := DEPTH_BUNDLE_PENALTY if depth >= DEPTH_BUNDLE_FROM else 0
	return maxi(BUNDLE_COUNT + extra_bundles() - penalty, 1)


## 恩恵「深い泉」の合計(GameDesign.md 27章「恩恵」)。
func spring_bonus() -> int:
	return boon_total("spring_bonus")


## 恩恵「目利き」の合計。束の数は `BUNDLE_COUNT + extra_bundles()`。
func extra_bundles() -> int:
	return boon_total("extra_bundles")


## 恩恵「先制の砂」の合計。対局開始時に相手のHPから引く(`CardMatchSolo`)。
func foe_hp_penalty() -> int:
	return boon_total("foe_hp_penalty")


## 対局の最初の手札に足す枚数(`CardMatchSolo`)。恩恵「用意周到」の合計に、山札が
## 閾値以下のときの「身軽」を足す(GameDesign.md 27章「恩恵」)。
func extra_opening_draw() -> int:
	var total := boon_total("extra_opening_draw")
	for boon in owned_boons():
		if boon.light_deck_max > 0 and deck_ids.size() <= boon.light_deck_max:
			total += boon.light_deck_draw
	return total


func owned_boons() -> Array[SoloBoonData]:
	var found: Array[SoloBoonData] = []
	for id in boons:
		var boon := SoloBoonLibrary.find_by_id(id)
		if boon != null:
			found.append(boon)
	return found


## 恩恵「勝ち癖」の合計。勝利時にHPへ足す(上限は`max_hp`)。
func win_heal() -> int:
	return boon_total("win_heal")


func boon_total(field: String) -> int:
	var total := 0
	for boon in owned_boons():
		total += int(boon.get(field))
	return total


func to_dict() -> Dictionary:
	return {
		"theme_id": theme_id,
		"boss_id": boss_id,
		"deck_ids": deck_ids,
		"depth": depth,
		"hp": hp,
		"max_hp": max_hp,
		"floor": floor,
		"wins": wins,
		"route": route,
		"offer": offer,
		"boon_offer": boon_offer,
		"last_gate_id": last_gate_id,
		"boons": boons,
		"workshop_open": workshop_open,
		"chosen": chosen,
		"in_battle": in_battle,
		"over": over,
		"cleared": cleared,
	}


static func from_dict(data: Dictionary) -> SoloRun:
	var run := SoloRun.new()
	run.theme_id = str(data.get("theme_id", ""))
	run.boss_id = str(data.get("boss_id", ""))
	for id in data.get("deck_ids", []):
		run.deck_ids.append(str(id))
	# 旧データ(深さ無し)は深さ0として読む(Pitfalls.md「データとコードの境目」)。
	run.depth = clampi(int(data.get("depth", 0)), 0, DEPTH_MAX)
	run.max_hp = int(data.get("max_hp", MatchState.INITIAL_HP))
	run.hp = int(data.get("hp", run.max_hp))
	run.floor = int(data.get("floor", 0))
	run.wins = int(data.get("wins", 0))
	run.route = _route_from_variant(data.get("route", []))
	# 以前の形式(束ではなくカードidの配列)を読んだときは、offerを捨てて候補待ちを解く
	# (CLAUDE.md「仕様変更フロー」ではなくPitfalls.mdの保存データの互換の話)。
	run.offer = _offer_from_variant(data.get("offer", []))
	for id in data.get("boon_offer", []):
		run.boon_offer.append(str(id))
	run.last_gate_id = str(data.get("last_gate_id", ""))
	for id in data.get("boons", []):
		run.boons.append(str(id))
	run.workshop_open = bool(data.get("workshop_open", false))
	for index in data.get("chosen", []):
		run.chosen.append(int(index))
	run.in_battle = bool(data.get("in_battle", false))
	run.over = bool(data.get("over", false))
	run.cleared = bool(data.get("cleared", false))
	return run


static func _offer_from_variant(raw: Variant) -> Array[Dictionary]:
	var offer: Array[Dictionary] = []
	if not (raw is Array):
		return offer
	for entry in raw:
		if not (entry is Dictionary):
			continue
		var cards: Array[String] = []
		for id in (entry as Dictionary).get("cards", []):
			cards.append(str(id))
		offer.append({"theme": str((entry as Dictionary).get("theme", "")), "cards": cards})
	return offer


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


## 8つのCPUデッキ(floors 0〜4で7つ・最終戦で1つ)・関門を切り混ぜて重複なく割り当てる。
## 1〜5段目は2〜3個、6段目は主との対局1つだけ(GameDesign.md 27章「道」「主」)。
## 主が作戦を持つときは、その作戦を最終戦に回して1〜5段目の相手と重ねない。
static func _build_route(rng: RandomNumberGenerator, boss_id: String = "") -> Array:
	var deck_pool := _string_array(_shuffled(CardCpuDecks.deck_ids(), rng))
	var boss := SoloGateLibrary.find_by_id(boss_id)
	var final_deck: String = deck_pool.pop_back()
	if boss != null and deck_pool.has(boss.cpu_deck):
		deck_pool[deck_pool.find(boss.cpu_deck)] = final_deck
		final_deck = boss.cpu_deck
	var gate_pool := _string_array(_shuffled(SoloGateLibrary.all_ids(), rng))
	# 8つのうち7つをfloors 0〜4へ配る。1段目は泉・工房が出せないため必ず2つ受け取る。
	# 残る1つは1〜4段目のうちどれか1段へ(その段は行き先が3個になり得る)。
	var extra_floor := 1 + rng.randi_range(0, 3)
	var route: Array = []
	for floor_i in range(FLOOR_COUNT - 1):
		var non_spring_count := 2 if (floor_i == 0 or floor_i == extra_floor) else 1
		var destinations: Array = []
		for _n in non_spring_count:
			destinations.append(_next_destination(deck_pool, gate_pool, rng))
		# 泉と工房は合わせて1段に1つまで・1段目には出さない(GameDesign.md 27章「道」)。
		var allow_extra := floor_i > 0
		var add_extra := allow_extra and (non_spring_count == 1 or rng.randf() < 0.5)
		if add_extra:
			var extra_kind := Kind.WORKSHOP if rng.randf() < 0.5 else Kind.SPRING
			destinations.append({"kind": extra_kind, "cpu_deck": "", "gate": ""})
		route.append(_shuffled(destinations, rng))
	var final_gate := boss.id if boss != null else ""
	route.append([{"kind": Kind.BATTLE, "cpu_deck": final_deck, "gate": final_gate}])
	return route


static func _next_destination(
	deck_pool: Array[String], gate_pool: Array[String], rng: RandomNumberGenerator
) -> Dictionary:
	var deck_id: String = deck_pool.pop_back()
	if not gate_pool.is_empty() and rng.randf() < 0.5:
		var gate_id: String = gate_pool.pop_back()
		return {"kind": Kind.GATE, "cpu_deck": deck_id, "gate": gate_id}
	return {"kind": Kind.BATTLE, "cpu_deck": deck_id, "gate": ""}


## 恩恵の候補(GameDesign.md 27章「恩恵」)。まだ持っていない恩恵から3つ。
## 戦い方を変える恩恵(◆)が残っていれば、1つは必ずそこから選ぶ。
func _build_boon_offer(rng: RandomNumberGenerator) -> Array[String]:
	var play_pool: Array[String] = []
	var pool: Array[String] = []
	for boon in SoloBoonLibrary.all_boons():
		if boons.has(boon.id):
			continue
		pool.append(boon.id)
		if boon.changes_play:
			play_pool.append(boon.id)
	var picked: Array[String] = []
	if not play_pool.is_empty():
		picked.append(play_pool[rng.randi_range(0, play_pool.size() - 1)])
	for id in _string_array(_shuffled(pool, rng)):
		if picked.size() >= BOON_OFFER_SIZE:
			break
		if not picked.has(id):
			picked.append(id)
	return _string_array(_shuffled(picked, rng))


## 束の候補(GameDesign.md 27章「山札を育てる」)。1つは選んだ作戦の束、残りは他の作戦から
## 重ならないように選ぶ。3枚そろわない作戦は束にしない。数は`BUNDLE_COUNT + extra_bundles()`。
func _build_bundle_offer(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var counts := _deck_counts()
	var target := bundle_target()
	var themes: Array[String] = []
	if _theme_pool(theme_id, counts).size() >= BUNDLE_CARDS:
		themes.append(theme_id)
	for id in _string_array(_shuffled(CardCpuDecks.deck_ids(), rng)):
		if themes.size() >= target:
			break
		if themes.has(id):
			continue
		if _theme_pool(id, counts).size() >= BUNDLE_CARDS:
			themes.append(id)
	var bundles: Array[Dictionary] = []
	for t in themes:
		var pool := _string_array(_shuffled(_theme_pool(t, counts), rng))
		bundles.append({"theme": t, "cards": pool.slice(0, BUNDLE_CARDS)})
	return bundles


## 作戦の15種のうち、山札に既に2枚あるカードを除いたもの。
func _theme_pool(id: String, counts: Dictionary) -> Array[String]:
	var pool: Array[String] = []
	for card_id in CardCpuDecks.card_ids_of(id):
		if int(counts.get(card_id, 0)) < MAX_DECK_COPIES:
			pool.append(card_id)
	return pool


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
