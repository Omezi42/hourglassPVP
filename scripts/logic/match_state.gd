class_name MatchState
extends Node
## v5.0の対局そのもの(GameDesign.md 2〜5章)。UIに依存しない唯一の真実を保持する。
## 旧ルール(位相制)の GameState とは別物であり、混ぜて使わない。

signal hp_changed(side: int, new_hp: int)
signal mana_changed(side: int, current: int, maximum: int)
signal hand_changed(side: int)
signal board_changed(side: int)
## 砂時計が場に出たとき。
signal unit_played(side: int, slot: int)
## 砂時計がダメージを受けたとき(amount は実際に消えた砂の量)。
signal unit_damaged(side: int, slot: int, amount: int)
## 硝子が最初のダメージを1度だけ無効にした(GameDesign.md 9章)。膜が割れたことを
## その場で示さないと、次の攻撃が通るかどうかを判断できない。
signal unit_shielded(side: int, slot: int)
## 砂時計が破壊されたとき。
signal unit_destroyed(side: int, slot: int, card: CardData)
signal unit_flipped(side: int, slot: int)
## ターン終了時に砂が1粒落ちたとき。**ダメージ(砂が消える)とは別のシグナルにする**。
## UI側でこの2つを別の演出として描き分けるため(GameDesign.md 9章)。
signal unit_ticked(side: int, slot: int)
## 攻撃が行われたとき。target_slot が -1 なら相手プレイヤーへの攻撃。
signal attack_performed(side: int, slot: int, target_slot: int)
signal mulligan_finished
signal turn_started(side: int)
## 山札から手札へ引いた枚数。ドローの動きを見せるために持つ。
signal cards_drawn(side: int, count: int)
## 山札が尽きた側が受ける疲労ダメージ。**発生源が駒ではなく山札にある**ため、
## 通常の被ダメージとは別の経路で知らせる(GameDesign.md 9章)。
signal fatigue_damage(side: int, amount: int)
## 効果が対象を取った(GameDesign.md 9章)。`target_slot` が -1 なら相手プレイヤー。
## 出した駒から対象へ光の筋を伸ばすために、適用の直前に発行する。
signal effect_targeted(source_side: int, source_slot: int, target_side: int, target_slot: int)
signal match_ended(winner: int)
## 持ち時間が尽きて手番を強制的に終えた(GameDesign.md 5章)。`count` は連続回数。
signal turn_forfeited(side: int, count: int)

enum Side { A, B }
## 決着の要因(GameDesign.md 5章)。
enum EndReason { HP_DEPLETED, SURRENDER, TIMEOUT, DRAW }

const INITIAL_HP := 30
const BOARD_SIZE := 6
const DECK_SIZE := 20
const MAX_MANA := 10
const FIRST_PLAYER_HAND := 3
const SECOND_PLAYER_HAND := 4
const FATIGUE_DAMAGE := 1
## コイン(後手が1度だけ使える+1マナ)。GameDesign.md 2章の手番補正。
const COIN_MANA := 1
## コインを配るかどうか(GameDesign.md 2章)。
const COIN_ENABLED := true
## 引き分けを避けるための保険。両者が延々とパスし続けた場合に打ち切る。
const MAX_TURNS := 200
## 連続してこの回数だけ手番を時間切れで渡したら敗北(GameDesign.md 5章)。
## 何もしない相手を待ち続ける状態を終わらせるための線で、1手でも指せば数え直す。
const TURN_FORFEIT_LIMIT := 3

var hp: Dictionary = {}
var mana: Dictionary = {}
var max_mana: Dictionary = {}
## 山札(先頭が次に引くカード)。
var deck: Dictionary = {}
var hand: Dictionary = {}
## 場の6枠。空き枠は null。
var board: Dictionary = {}
var graveyard: Dictionary = {}
var current_turn: int = Side.A
## 先手側。手番の補正は「後手が1枚多い」と「後手はコインを持つ」の2つだけで、
## 先手のドローを止める補正は持たない(GameDesign.md 2章)。
var first_side: int = Side.A
var turn_count: int = 0
var end_reason: int = EndReason.HP_DEPLETED
var winner: int = -1
## まだコインを持っているか(Side をキーにした bool)。対局開始時に後手だけ true になる。
var coin_available: Dictionary = {}
## 側ごとの、連続した時間切れの回数。持ち時間を短くする段(GameDesign.md 5章)と
## 敗北の判定の両方がこれを見る。**手として送り合うため両者で同じ値になる。**
var turn_forfeits: Dictionary = {}

## マリガン(初手の引き直し)を待っている間だけ true。
var mulligan_pending := false
## 決着が疲労(デッキ切れ)によるものだったか。バランス検証の必須指標
## 「本体ダメージで決着した割合」(GameDesign.md 7章)を測るために持つ。
var finished_by_fatigue := false

var _effects: CardEffectResolver
var _rng := RandomNumberGenerator.new()
var _match_over := false
var _deck_exhausted: Dictionary = {}
var _mulligan_choice: Dictionary = {}


func _init() -> void:
	_effects = CardEffectResolver.new(self)


## 対局を開始する。deck_a/deck_b は CardData を DECK_SIZE 枚並べた配列。
func start_match(
	deck_a: Array,
	deck_b: Array,
	p_first_side: int = Side.A,
	seed_value: int = 0,
	use_coin_rule: bool = COIN_ENABLED,
	use_mulligan: bool = false
) -> void:
	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	_match_over = false
	winner = -1
	end_reason = EndReason.HP_DEPLETED
	turn_count = 0
	finished_by_fatigue = false
	first_side = p_first_side
	current_turn = p_first_side
	for side in [Side.A, Side.B]:
		hp[side] = INITIAL_HP
		mana[side] = 0
		max_mana[side] = 0
		hand[side] = []
		graveyard[side] = []
		_deck_exhausted[side] = false
		coin_available[side] = false
		turn_forfeits[side] = 0
		var slots: Array = []
		slots.resize(BOARD_SIZE)
		board[side] = slots
	deck[Side.A] = _shuffled(deck_a)
	deck[Side.B] = _shuffled(deck_b)
	var second_side := other_side(p_first_side)
	coin_available[second_side] = use_coin_rule
	for i in FIRST_PLAYER_HAND:
		_draw_one(p_first_side)
	for i in SECOND_PLAYER_HAND:
		_draw_one(second_side)
	mulligan_pending = use_mulligan
	_mulligan_choice = {}
	if mulligan_pending:
		return
	_begin_turn()


## 初手の引き直しの選択を受け取る(GameDesign.md 2章)。indices は手札の位置。
## **両者ぶんが揃うまで適用しない**。適用は山札を切り直して乱数を消費するため、
## 届いた順ではなく A → B の固定順で行わないと、同じ種から始めた対局が食い違う。
func mulligan(side: int, indices: Array) -> bool:
	if not mulligan_pending or _mulligan_choice.has(side):
		return false
	_mulligan_choice[side] = indices.duplicate()
	if _mulligan_choice.size() < 2:
		return true
	_apply_mulligan(Side.A)
	_apply_mulligan(Side.B)
	mulligan_pending = false
	mulligan_finished.emit()
	_begin_turn()
	return true


## 手札から外す → 同じ枚数を引く → 外したカードを山札へ混ぜて切り直す、の順。
## 先に山札へ戻すと、引き直したカードがその場で返ってくる。
func _apply_mulligan(side: int) -> void:
	var indices: Array = _mulligan_choice.get(side, [])
	if indices.is_empty():
		return
	var cards: Array = hand[side]
	var picked: Array = []
	var sorted_indices := indices.duplicate()
	sorted_indices.sort()
	sorted_indices.reverse()
	for index in sorted_indices:
		if index < 0 or index >= cards.size():
			continue
		picked.append(cards[index])
		cards.remove_at(index)
	for i in picked.size():
		_draw_one(side)
	deck[side] = _shuffled(deck[side] + picked)
	_deck_exhausted[side] = deck[side].is_empty()
	hand_changed.emit(side)


static func other_side(side: int) -> int:
	return Side.B if side == Side.A else Side.A


func is_match_over() -> bool:
	return _match_over


func units(side: int) -> Array:
	var found: Array = []
	for unit in board[side]:
		if unit != null:
			found.append(unit)
	return found


func empty_slots(side: int) -> Array:
	var found: Array = []
	var slots: Array = board[side]
	for i in slots.size():
		if slots[i] == null:
			found.append(i)
	return found


# --- 手番 ---------------------------------------------------------------


func _begin_turn() -> void:
	turn_count += 1
	var side := current_turn
	max_mana[side] = mini(max_mana[side] + 1, MAX_MANA)
	mana[side] = max_mana[side]
	mana_changed.emit(side, mana[side], max_mana[side])
	for unit in units(side):
		unit.begin_turn()
	draw(side, 1)
	board_changed.emit(side)
	turn_started.emit(side)


## 自分の手番を終える。自分の砂時計の砂が1粒ずつ落ち、手番が相手へ移る。
func end_turn() -> void:
	if _match_over:
		return
	var side := current_turn
	# 自分でターンを終えたなら席にいる。連続の時間切れは数え直す(GameDesign.md 5章)。
	# **`time_up()` はこの後でカウントを書き戻す**ため、ここで消えても矛盾しない。
	turn_forfeits[side] = 0
	for slot in BOARD_SIZE:
		var unit: CardInstance = board[side][slot]
		if unit == null:
			continue
		unit.tick()
		unit_ticked.emit(side, slot)
		if unit.is_dead():
			_destroy_unit(side, slot)
	board_changed.emit(side)
	if _deck_exhausted[side]:
		fatigue_damage.emit(side, FATIGUE_DAMAGE)
		damage_player(side, FATIGUE_DAMAGE)
		finished_by_fatigue = _match_over
	if _match_over:
		return
	if turn_count >= MAX_TURNS:
		_finish(-1, EndReason.DRAW)
		return
	current_turn = other_side(side)
	_begin_turn()


## 持ち時間が尽きた。**敗北ではなく、その手番を強制的に終えて相手へ渡す**
## (GameDesign.md 5章)。ただし連続 `TURN_FORFEIT_LIMIT` 回で敗北とする。
## 何か1手でも指していれば `end_turn()` がカウントを0へ戻しているため、
## ここへ来るのは「その手番に何もできなかった」場合に限られる。
func time_up(side: int) -> bool:
	if _match_over or current_turn != side:
		return false
	var count: int = int(turn_forfeits.get(side, 0)) + 1
	turn_forfeited.emit(side, count)
	if count >= TURN_FORFEIT_LIMIT:
		_finish(other_side(side), EndReason.TIMEOUT)
		return true
	end_turn()
	# `end_turn()` が0へ戻した後に書き戻す。順序を逆にすると連続を数えられない。
	turn_forfeits[side] = count
	return true


## 投了・切断による時間切れ。どちらも盤面を変えずに相手の勝ちで終局する。
func surrender(side: int, reason: int = EndReason.SURRENDER) -> void:
	if _match_over:
		return
	_finish(other_side(side), reason)


## コインを使う。使えたときだけ true を返す(1対局に1度・自分の手番のみ)。
func use_coin(side: int) -> bool:
	if _match_over or current_turn != side or not coin_available.get(side, false):
		return false
	coin_available[side] = false
	mana[side] += COIN_MANA
	mana_changed.emit(side, mana[side], max_mana[side])
	return true


# --- ドロー -------------------------------------------------------------


func draw(side: int, amount: int) -> void:
	var before: int = hand[side].size()
	for i in amount:
		_draw_one(side)
	hand_changed.emit(side)
	var drawn: int = hand[side].size() - before
	if drawn > 0:
		cards_drawn.emit(side, drawn)


func _draw_one(side: int) -> void:
	var pile: Array = deck[side]
	if pile.is_empty():
		_deck_exhausted[side] = true
		return
	hand[side].append(pile.pop_front())
	if pile.is_empty():
		_deck_exhausted[side] = true


func _shuffled(cards: Array) -> Array:
	var copy := cards.duplicate()
	for i in range(copy.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = copy[i]
		copy[i] = copy[j]
		copy[j] = tmp
	return copy


# --- 場に出す -----------------------------------------------------------


func can_play(side: int, hand_index: int) -> bool:
	if _match_over or current_turn != side:
		return false
	if hand_index < 0 or hand_index >= hand[side].size():
		return false
	if empty_slots(side).is_empty():
		return false
	var card: CardData = hand[side][hand_index]
	return mana[side] >= card.cost


## 手札の1枚を場の空き枠へ出す。埋まっている枠へは出せない(上書き設置は行わない)。
## target は ENEMY_UNIT を対象に取る設置効果のための指定 {"side":..., "slot":...}。
func play_card(side: int, hand_index: int, slot: int, target: Dictionary = {}) -> bool:
	if not can_play(side, hand_index):
		return false
	if slot < 0 or slot >= BOARD_SIZE:
		return false
	if board[side][slot] != null:
		return false
	var card: CardData = hand[side][hand_index]
	mana[side] -= card.cost
	hand[side].remove_at(hand_index)
	hand_changed.emit(side)
	mana_changed.emit(side, mana[side], max_mana[side])
	var unit := CardInstance.new(card)
	if unit.has_keyword(CardEnums.Keyword.QUICK):
		unit.drop_sand(2)
		unit.summoned_this_turn = false
	board[side][slot] = unit
	unit_played.emit(side, slot)
	board_changed.emit(side)
	_effects.resolve(side, unit, CardEnums.Trigger.ON_PLAY, target)
	_cleanup_dead()
	return true


# --- 反転 ---------------------------------------------------------------


func can_flip(side: int, slot: int) -> bool:
	if _match_over or current_turn != side:
		return false
	var unit: CardInstance = board[side][slot]
	return unit != null and unit.can_flip()


## 反転する。マナは不要。1体につき1ターン1回、出したターンは反転できない。
func flip(side: int, slot: int) -> bool:
	if not can_flip(side, slot):
		return false
	var unit: CardInstance = board[side][slot]
	unit.flip()
	unit.flipped_this_turn = true
	unit_flipped.emit(side, slot)
	_effects.resolve(side, unit, CardEnums.Trigger.ON_FLIP, {})
	if unit.is_dead():
		_destroy_unit(side, slot)
	board_changed.emit(side)
	return true


# --- 戦闘 ---------------------------------------------------------------


## 守護を持つ砂時計がいる間は、その砂時計しか攻撃できない(GameDesign.md 6章)。
func attackable_slots(defender_side: int) -> Array:
	var guards: Array = []
	var others: Array = []
	var slots: Array = board[defender_side]
	for i in slots.size():
		var unit: CardInstance = slots[i]
		if unit == null:
			continue
		if unit.has_keyword(CardEnums.Keyword.GUARD):
			guards.append(i)
		else:
			others.append(i)
	return guards if not guards.is_empty() else others


## まだ出せるカードか、攻撃できる駒が残っているか。
## 対局画面がターン終了ボタンの色を決めるのに使う(GameDesign.md 9章)。
func has_moves_left(side: int) -> bool:
	for index in hand[side].size():
		if can_play(side, index):
			return true
	for slot in BOARD_SIZE:
		var unit: CardInstance = board[side][slot]
		if unit != null and unit.can_attack():
			return true
	return false


func can_attack_player(side: int) -> bool:
	for unit in units(other_side(side)):
		if unit.has_keyword(CardEnums.Keyword.GUARD):
			return false
	return true


func can_attack(side: int, slot: int, target_slot: int) -> bool:
	if _match_over or current_turn != side:
		return false
	var unit: CardInstance = board[side][slot]
	if unit == null or not unit.can_attack():
		return false
	if target_slot < 0:
		return can_attack_player(side)
	return attackable_slots(other_side(side)).has(target_slot)


## 攻撃する。target_slot が -1 なら相手プレイヤーへの攻撃。
func attack(side: int, slot: int, target_slot: int) -> bool:
	if not can_attack(side, slot, target_slot):
		return false
	var attacker: CardInstance = board[side][slot]
	attacker.attacks_this_turn += 1
	attack_performed.emit(side, slot, target_slot)
	if target_slot < 0:
		var power := attacker.attack
		damage_player(other_side(side), power)
		_lifesteal(side, attacker, power)
		return true
	_resolve_unit_combat(side, slot, target_slot)
	_cleanup_dead()
	return true


## 攻撃した場合に双方がどうなるかを、盤面を変えずに計算する(GameDesign.md 9章)。
## **戦闘は相打ちで、攻撃側も必ず削れる**ため、UIはこれを対象選択の間ずっと出す。
## 判定の順序は `_resolve_unit_combat()` と同じにすること(硝子→毒砂の順)。
func combat_preview(side: int, slot: int, target_slot: int) -> Dictionary:
	var foe_side := other_side(side)
	var attacker: CardInstance = board[side][slot]
	if attacker == null:
		return {}
	if target_slot < 0:
		return {
			"attacker_health": attacker.health,
			"attacker_dead": false,
			"target_health": hp[foe_side] - attacker.attack,
			"target_dead": hp[foe_side] - attacker.attack <= 0,
			"pierce": 0,
		}
	var defender: CardInstance = board[foe_side][target_slot]
	if defender == null:
		return {}
	var to_defender := _preview_damage(defender, attacker.attack)
	var to_attacker := _preview_damage(attacker, defender.attack)
	var defender_health := defender.health - to_defender
	var attacker_health := attacker.health - to_attacker
	if to_defender > 0 and attacker.has_keyword(CardEnums.Keyword.POISON):
		defender_health = 0
	if to_attacker > 0 and defender.has_keyword(CardEnums.Keyword.POISON):
		attacker_health = 0
	var pierce := 0
	if to_defender > 0 and attacker.has_keyword(CardEnums.Keyword.PIERCE):
		pierce = maxi(attacker.attack - defender.health, 0)
	return {
		"attacker_health": maxi(attacker_health, 0),
		"attacker_dead": attacker_health <= 0,
		"target_health": maxi(defender_health, 0),
		"target_dead": defender_health <= 0,
		"pierce": pierce,
	}


## 硝子が残っていれば最初の1回は通らない(`CardInstance.take_damage()` と同じ判定)。
func _preview_damage(unit: CardInstance, amount: int) -> int:
	if amount <= 0:
		return 0
	return 0 if unit.glass_intact else amount


func _resolve_unit_combat(side: int, slot: int, target_slot: int) -> void:
	var foe_side := other_side(side)
	var attacker: CardInstance = board[side][slot]
	var defender: CardInstance = board[foe_side][target_slot]
	var attacker_power := attacker.attack
	var defender_power := defender.attack
	var defender_health := defender.health
	var attacker_health := attacker.health
	# 硝子が割れたかどうかは、削られたかどうかでは分からない(どちらも与ダメージ0)。
	# 受ける前の状態を控えておき、消えていたら膜が吸ったものとして知らせる。
	var defender_glass := defender.glass_intact
	var attacker_glass := attacker.glass_intact
	var dealt_to_defender := defender.take_damage(attacker_power)
	var dealt_to_attacker := attacker.take_damage(defender_power)
	if dealt_to_defender > 0:
		unit_damaged.emit(foe_side, target_slot, dealt_to_defender)
	elif defender_glass and not defender.glass_intact:
		unit_shielded.emit(foe_side, target_slot)
	if dealt_to_attacker > 0:
		unit_damaged.emit(side, slot, dealt_to_attacker)
	elif attacker_glass and not attacker.glass_intact:
		unit_shielded.emit(side, slot)
	_apply_pierce(attacker, foe_side, attacker_power, defender_health, dealt_to_defender)
	_apply_pierce(defender, side, defender_power, attacker_health, dealt_to_attacker)
	_lifesteal(side, attacker, dealt_to_defender)
	_lifesteal(foe_side, defender, dealt_to_attacker)
	if dealt_to_defender > 0 and attacker.has_keyword(CardEnums.Keyword.POISON):
		defender.health = 0
	if dealt_to_attacker > 0 and defender.has_keyword(CardEnums.Keyword.POISON):
		attacker.health = 0


## 貫通:砂時計の体力を超えた分が相手プレイヤーへ抜ける。
func _apply_pierce(
	unit: CardInstance, foe_side: int, power: int, target_health: int, dealt: int
) -> void:
	if dealt <= 0 or not unit.has_keyword(CardEnums.Keyword.PIERCE):
		return
	var excess: int = power - target_health
	if excess > 0:
		damage_player(foe_side, excess)


func _lifesteal(side: int, unit: CardInstance, amount: int) -> void:
	if amount <= 0 or not unit.has_keyword(CardEnums.Keyword.LIFESTEAL):
		return
	heal_player(side, amount)


# --- ダメージ・破壊 -----------------------------------------------------


func damage_player(side: int, amount: int) -> void:
	if amount <= 0 or _match_over:
		return
	hp[side] = maxi(hp[side] - amount, 0)
	hp_changed.emit(side, hp[side])
	if hp[side] <= 0:
		_finish(other_side(side), EndReason.HP_DEPLETED)


func heal_player(side: int, amount: int) -> void:
	if amount <= 0:
		return
	hp[side] = mini(hp[side] + amount, INITIAL_HP)
	hp_changed.emit(side, hp[side])


## 砂時計へダメージを与える(設置効果などから使う)。
func damage_unit(side: int, slot: int, amount: int) -> void:
	var unit: CardInstance = board[side][slot]
	if unit == null:
		return
	var had_glass := unit.glass_intact
	var dealt := unit.take_damage(amount)
	if dealt > 0:
		unit_damaged.emit(side, slot, dealt)
	elif had_glass and not unit.glass_intact:
		unit_shielded.emit(side, slot)


func destroy_unit(side: int, slot: int) -> void:
	var unit: CardInstance = board[side][slot]
	if unit == null:
		return
	unit.health = 0
	_destroy_unit(side, slot)


func _destroy_unit(side: int, slot: int) -> void:
	var unit: CardInstance = board[side][slot]
	if unit == null:
		return
	board[side][slot] = null
	graveyard[side].append(unit.data)
	_effects.resolve(side, unit, CardEnums.Trigger.ON_DEATH, {})
	unit_destroyed.emit(side, slot, unit.data)


func _cleanup_dead() -> void:
	for side in [Side.A, Side.B]:
		for slot in BOARD_SIZE:
			var unit: CardInstance = board[side][slot]
			if unit != null and unit.is_dead():
				_destroy_unit(side, slot)
		board_changed.emit(side)


func _finish(p_winner: int, reason: int) -> void:
	if _match_over:
		return
	_match_over = true
	winner = p_winner
	end_reason = reason
	match_ended.emit(p_winner)
