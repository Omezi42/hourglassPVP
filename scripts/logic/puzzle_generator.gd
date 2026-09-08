class_name PuzzleGenerator
extends RefCounted
## エンドレスモード(GameDesign.md 24章)の問題をその場で組み立てる。
## `CardLibrary` と同じ「Autoloadを使わずstaticで持つ」流儀。
##
## **盤面を丸ごとランダムに振って総当たりで解を探す方式は採らない**(Architecture.md
## 10.12.1節)。代わりに「先に正解の部品(kit)を決め、相手のHPをその合計へ逆算し、
## 紛らわしい選択肢(distractor)を足してから、実際に `MatchState` で解けることを
## 検証する」方式にする。検証に落ちたら黙って作り直す——プレイヤーには常に
## 検証済みの1問だけを渡す。

const MAX_ATTEMPTS := 80
## 1手目に選べる行動の数がこれ未満だと「択が多い」狙いに届かないため作り直す。
const MIN_BRANCHING := 6
const MIN_KIT_SIZE := 2
const MAX_KIT_SIZE := 4
const SPELL_PIECE_CHANCE := 0.35
const FLIP_PIECE_CHANCE := 0.45
const GUARD_CHANCE := 0.5
const PIECE_VALUE_MIN := 2
const PIECE_VALUE_MAX := 6
const MAX_OWN_DISTRACTORS := 2
const MAX_FOE_DISTRACTORS := 2
const MAX_HAND_DISTRACTORS := 2

## 正解の部品(kit)に使う自陣の駒から除くキーワード。貫通・連撃・毒砂・吸命は
## 「面へ攻撃したときの合計ダメージ」を静かに変えてしまい、組み立てた数値の
## つじつまが合わなくなるため。
const UNSAFE_OWN_KEYWORDS: Array[int] = [
	CardEnums.Keyword.PIERCE,
	CardEnums.Keyword.DOUBLE_STRIKE,
	CardEnums.Keyword.POISON,
	CardEnums.Keyword.LIFESTEAL,
]

const HINT_LINES := [
	"このターンだけで仕留めきる一手を探そう",
	"手札と盤面、両方から使う駒を選び抜こう",
	"数を合わせるだけでなく、順番も大事",
]
const HINT_LINES_GUARD := [
	"立ちはだかるものを先に片づけよう",
]


## 新しい問題を1つ作って返す。**同じ問題を保存しないため、id は仮の値**。
static func generate(seed_value: int = 0) -> PuzzleStageData:
	return _generate_full(seed_value)["stage"]


## テスト専用。生成した問題に加え、意図した解答手順(`{"type":..., ...}` の配列)と
## 分岐の数を返す。`_verify()` が実際に解けることを確かめた手順そのものであり、
## テスト側で改めて正解を用意し直さずに独立した検証ができる
## (`tools/tests/puzzle_generator_tests.gd`)。
static func generate_for_test(seed_value: int) -> Dictionary:
	return _generate_full(seed_value)


static func _generate_full(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	var fallback: Dictionary = {}
	for attempt in MAX_ATTEMPTS:
		var result := _try_build(rng)
		if result.is_empty():
			continue
		if int(result["branching"]) >= MIN_BRANCHING:
			return result
		if fallback.is_empty():
			fallback = result
	if not fallback.is_empty():
		return fallback
	return {
		"stage": _trivial_fallback(),
		"branching": 0,
		"solution": [{"type": "attack", "slot": 0, "target_slot": -1}],
	}


## 検証にすら1度も通らなかった場合の最終手段。`sand` は基本セット固定のカードで
## 必ず存在するため、この1問だけは pool を経由せず直接組む。
static func _trivial_fallback() -> PuzzleStageData:
	var stage := PuzzleStageData.new()
	stage.id = "endless"
	stage.title = "エンドレス"
	stage.hint = HINT_LINES[0]
	stage.order = 0
	stage.foe_hp = 5
	stage.own_hp = MatchState.INITIAL_HP
	stage.mana = 0
	stage.hand_ids = []
	stage.own_units = ["sand:1:5"]
	stage.foe_units = []
	return stage


## 1回ぶんの生成の試み。作れない・検証に落ちた場合は空の Dictionary を返す。
static func _try_build(rng: RandomNumberGenerator) -> Dictionary:
	var own_pool := _safe_own_pool()
	if own_pool.is_empty():
		return {}
	var spell_pool := _face_spell_pool()
	var guard_pool := _guard_pool(own_pool)
	var inert_pool := _inert_distractor_pool()
	var foe_pool := _foe_distractor_pool()
	var has_spell := not spell_pool.is_empty()

	var kit_size := rng.randi_range(MIN_KIT_SIZE, MAX_KIT_SIZE)
	var board_pieces: Array[Dictionary] = []
	var spell_pieces: Array[Dictionary] = []
	for i in kit_size:
		if has_spell and rng.randf() < SPELL_PIECE_CHANCE:
			var spell_card: CardData = spell_pool[rng.randi_range(0, spell_pool.size() - 1)]
			(
				spell_pieces
				. append(
					{
						"card": spell_card,
						"value": int(spell_card.effects[0].value),
						"cost": spell_card.cost,
					}
				)
			)
		else:
			board_pieces.append(_random_board_piece(rng, own_pool))
	if board_pieces.is_empty():
		board_pieces.append(_random_board_piece(rng, own_pool))

	# **守護の壁は、部品のうち1つを「まず割るためだけ」の役へ回す。**
	# その分は相手HPの合計へ数えない(6章の守護がそのまま手順の縛りになる)。
	var clearer_index := -1
	var guard: Dictionary = {}
	if board_pieces.size() >= 2 and not guard_pool.is_empty() and rng.randf() < GUARD_CHANCE:
		clearer_index = rng.randi_range(0, board_pieces.size() - 1)
		var guard_card: CardData = guard_pool[rng.randi_range(0, guard_pool.size() - 1)]
		guard = {
			"card": guard_card,
			"health": int(board_pieces[clearer_index]["value"]),
			"attack": 1,
		}

	var contrib_values: Array[int] = []
	for i in board_pieces.size():
		if i != clearer_index:
			contrib_values.append(int(board_pieces[i]["value"]))
	for piece in spell_pieces:
		contrib_values.append(int(piece["value"]))
	if contrib_values.is_empty():
		return {}
	var foe_hp := 0
	var min_contrib: int = contrib_values[0]
	for value in contrib_values:
		foe_hp += value
		min_contrib = mini(min_contrib, value)
	if foe_hp <= 0:
		return {}

	var mana := 0
	for piece in spell_pieces:
		mana += int(piece["cost"])

	# **紛らわしい駒の攻撃力はごく小さく保つ。**正解の部品を1つ欠いた不足分より
	# 必ず小さくすることで、「本来要らない駒を足せば帳尻が合う」抜け道を作らない。
	var distractor_own_count := clampi(min_contrib - 1, 0, MAX_OWN_DISTRACTORS)
	var own_rows: Array[String] = []
	for piece in board_pieces:
		var health: int
		var attack: int
		if bool(piece["flip"]):
			health = int(piece["value"])
			attack = 1
		else:
			health = 1
			attack = int(piece["value"])
		own_rows.append("%s:%d:%d" % [String(piece["card"].id), health, attack])
	for i in distractor_own_count:
		var distractor_card: CardData = own_pool[rng.randi_range(0, own_pool.size() - 1)]
		own_rows.append("%s:1:1" % String(distractor_card.id))

	var foe_rows: Array[String] = []
	var guard_slot := -1
	if not guard.is_empty():
		guard_slot = foe_rows.size()
		foe_rows.append(
			"%s:%d:%d" % [String(guard["card"].id), int(guard["health"]), int(guard["attack"])]
		)
	if not foe_pool.is_empty():
		var foe_distractor_count := rng.randi_range(0, MAX_FOE_DISTRACTORS)
		for i in foe_distractor_count:
			var foe_card: CardData = foe_pool[rng.randi_range(0, foe_pool.size() - 1)]
			foe_rows.append(
				"%s:%d:%d" % [String(foe_card.id), rng.randi_range(2, 6), rng.randi_range(0, 2)]
			)

	var hand_ids: Array[String] = []
	for piece in spell_pieces:
		hand_ids.append(String(piece["card"].id))
	if not inert_pool.is_empty():
		var distractor_hand_count := rng.randi_range(1, MAX_HAND_DISTRACTORS)
		for i in distractor_hand_count:
			var hand_card: CardData = inert_pool[rng.randi_range(0, inert_pool.size() - 1)]
			hand_ids.append(String(hand_card.id))

	var stage := PuzzleStageData.new()
	stage.id = "endless"
	stage.title = "エンドレス"
	stage.hint = _pick_hint(rng, not guard.is_empty())
	stage.order = 0
	stage.foe_hp = foe_hp
	stage.own_hp = MatchState.INITIAL_HP
	stage.mana = mana
	stage.hand_ids = hand_ids
	stage.own_units = own_rows
	stage.foe_units = foe_rows

	var check := _verify(stage, board_pieces, spell_pieces, clearer_index, guard_slot)
	if check.is_empty():
		return {}
	return {"stage": stage, "branching": check["branching"], "solution": check["solution"]}


static func _random_board_piece(
	rng: RandomNumberGenerator, own_pool: Array[CardData]
) -> Dictionary:
	var card: CardData = own_pool[rng.randi_range(0, own_pool.size() - 1)]
	return {
		"card": card,
		"value": rng.randi_range(PIECE_VALUE_MIN, PIECE_VALUE_MAX),
		"flip": rng.randf() < FLIP_PIECE_CHANCE,
	}


## 意図した手順(反転 → 守護を割る → 残りの駒で本体を殴る → 砂術を撃つ)を
## 実際の `MatchState` へ適用し、相手のHPが0以下になることを確かめる。
## `tools/tests/puzzle_mission_tests.gd` の `_build()`/`_solve()` と同じやり方。
static func _verify(
	stage: PuzzleStageData,
	board_pieces: Array[Dictionary],
	spell_pieces: Array[Dictionary],
	clearer_index: int,
	guard_slot: int
) -> Dictionary:
	var state := _build_state(stage)
	var mine: int = MatchState.Side.A
	var foe: int = MatchState.other_side(mine)
	var branching := _count_root_options(state, mine)
	var solution: Array[Dictionary] = []
	for i in board_pieces.size():
		if bool(board_pieces[i]["flip"]):
			if not state.flip(mine, i):
				state.free()
				return {}
			solution.append({"type": "flip", "slot": i})
	if guard_slot >= 0:
		if not state.attack(mine, clearer_index, guard_slot):
			state.free()
			return {}
		solution.append({"type": "attack", "slot": clearer_index, "target_slot": guard_slot})
	for i in board_pieces.size():
		if i == clearer_index:
			continue
		if not state.attack(mine, i, -1):
			state.free()
			return {}
		solution.append({"type": "attack", "slot": i, "target_slot": -1})
	for piece in spell_pieces:
		var card_id := String(piece["card"].id)
		if not _cast_by_id(state, mine, card_id):
			state.free()
			return {}
		solution.append({"type": "cast_id", "card_id": card_id})
	var cleared: bool = int(state.hp[foe]) <= 0
	state.free()
	if not cleared:
		return {}
	return {"branching": branching, "solution": solution}


static func _cast_by_id(state: MatchState, side: int, card_id: String) -> bool:
	var hand: Array = state.hand[side]
	for i in hand.size():
		var card: CardData = hand[i]
		if card.id == card_id:
			return state.cast_spell(side, i)
	return false


## いまの盤面で選べる1手目の数(GameDesign.md 24章「択が多く」の指標)。
## 深い探索はせず、この局面だけを数える。
static func _count_root_options(state: MatchState, side: int) -> int:
	var count := 0
	var hand: Array = state.hand[side]
	for i in hand.size():
		var card: CardData = hand[i]
		if card.is_spell:
			if state.can_cast(side, i):
				count += 1
		elif state.can_play(side, i):
			count += 1
	var foe_side := MatchState.other_side(side)
	for slot in MatchState.BOARD_SIZE:
		var unit: CardInstance = state.board[side][slot]
		if unit == null:
			continue
		if unit.can_flip():
			count += 1
		if unit.can_attack():
			var targets := state.attackable_slots(foe_side).size()
			if state.can_attack_player(side):
				targets += 1
			count += targets
	if int(state.flip_right_remaining.get(side, 0)) > 0:
		count += state.units(side).size() + state.units(foe_side).size()
	return count


## `CardMatchPuzzle._apply()` と同じ形の局面を、UIを起こさずに作る。
static func _build_state(stage: PuzzleStageData) -> MatchState:
	var state := MatchState.new()
	var deck := CardPresetDecks.basic()
	state.start_match(deck, deck, MatchState.Side.A, 1, false, false)
	var mine: int = MatchState.Side.A
	var foe: int = MatchState.other_side(mine)
	state.hp[mine] = stage.own_hp
	state.hp[foe] = stage.foe_hp
	state.max_mana[mine] = stage.mana
	state.mana[mine] = stage.mana
	state.hand[mine] = []
	for id in stage.hand_ids:
		var card := CardLibrary.find_by_id(id)
		if card != null:
			state.hand[mine].append(card)
	_place(state, mine, stage.own_units)
	_place(state, foe, stage.foe_units)
	return state


static func _place(state: MatchState, side: int, rows: Array[String]) -> void:
	var slots: Array = []
	slots.resize(MatchState.BOARD_SIZE)
	for i in rows.size():
		if i >= MatchState.BOARD_SIZE:
			break
		var parsed := PuzzleStageData.parse_unit(rows[i])
		if parsed.is_empty():
			continue
		var unit := CardInstance.new(parsed["card"])
		unit.health = int(parsed["health"])
		unit.attack = int(parsed["attack"])
		unit.summoned_this_turn = false
		slots[i] = unit
	state.board[side] = slots


static func _pick_hint(rng: RandomNumberGenerator, has_guard: bool) -> String:
	if has_guard and rng.randf() < 0.6:
		return HINT_LINES_GUARD[rng.randi_range(0, HINT_LINES_GUARD.size() - 1)]
	return HINT_LINES[rng.randi_range(0, HINT_LINES.size() - 1)]


## 正解の部品(kit)・紛らわしい自陣の駒に使ってよいカード。貫通・連撃・毒砂・吸命を
## 持たず、固有効果(`effects`)も持たないものに限る(Architecture.md 10.12.1節)。
static func _safe_own_pool() -> Array[CardData]:
	var found: Array[CardData] = []
	for card in CardLibrary.all_cards():
		if card.is_spell or card.cannot_attack:
			continue
		if not card.effects.is_empty():
			continue
		if _has_unsafe_keyword(card):
			continue
		found.append(card)
	return found


static func _has_unsafe_keyword(card: CardData) -> bool:
	for keyword in UNSAFE_OWN_KEYWORDS:
		if card.has_keyword(keyword):
			return true
	return false


static func _guard_pool(own_pool: Array[CardData]) -> Array[CardData]:
	var found: Array[CardData] = []
	for card in own_pool:
		if card.has_keyword(CardEnums.Keyword.GUARD):
			found.append(card)
	return found


## 相手プレイヤーへ固定ダメージだけを与える砂術(サンドショット等)。
## 効果が複数絡む・値が盤面で変わるカードは対象にしない(次に対象を広げる拡張点)。
static func _face_spell_pool() -> Array[CardData]:
	var found: Array[CardData] = []
	for card in CardLibrary.all_cards():
		if not card.is_spell or card.effects.size() != 1:
			continue
		var effect: CardEffectData = card.effects[0]
		if (
			effect.trigger == CardEnums.Trigger.ON_PLAY
			and effect.effect_type == CardEnums.EffectType.DAMAGE_PLAYER
			and effect.target == CardEnums.EffectTarget.OPPONENT_PLAYER
			and effect.value > 0
		):
			found.append(card)
	return found


## 手札の紛らわしい1枚。固有効果を持たないため、出しても盤面へ何も起こさない。
static func _inert_distractor_pool() -> Array[CardData]:
	var found: Array[CardData] = []
	for card in CardLibrary.all_cards():
		if card.is_spell:
			continue
		if card.effects.is_empty():
			found.append(card)
	return found


## 敵陣の紛らわしい駒。攻撃してしまった場合の見た目上の危うさのために、
## 自陣の部品ほど厳しくは絞らない。
static func _foe_distractor_pool() -> Array[CardData]:
	var found: Array[CardData] = []
	for card in CardLibrary.all_cards():
		if not card.is_spell:
			found.append(card)
	return found
