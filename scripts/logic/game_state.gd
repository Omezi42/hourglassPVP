class_name GameState
extends Node

signal hp_changed(side: PlayerSide, new_hp: int)
signal hourglass_state_changed(side: PlayerSide, position: BoardPosition, new_state: int)
signal hourglass_moved(side: PlayerSide, from_position: BoardPosition, to_position: BoardPosition)
signal hourglass_swapped(side: PlayerSide, bench_index: int, board_position: BoardPosition)
signal turn_started(side: PlayerSide)
## ターン終了時の解決で、1マス分の解決を始める直前に発行する(GameDesign.md 4.4)。
## kindは "advance"(進行する) / "idle"(既に落ちきりで何も起きない) / "flip" / "move" / "swap_in"。
## positionsは対象マス(移動のみ2個)。UI層はこれを区切りとしてズーム演出を組み立てる。
signal resolution_step_started(side: PlayerSide, positions: Array, kind: String)
signal match_ended(winner: PlayerSide)

enum PlayerSide { A, B }
enum BoardPosition { LEFT, CENTER, RIGHT }
## 決着の要因(GameDesign.md 3章)。結果パネル・対局ログの文言をUI層が出し分けるために使う。
enum EndReason { HP_DEPLETED, TIMEOUT, SURRENDER }

const BOARD_SIZE := 3
const BENCH_SIZE := 2
const INITIAL_HP := 30

## 対局開始時、場の各マスが取る初期状態(GameDesign.md 2章・5章)。BoardPosition順。
const START_STATES: Array[int] = [
	GameEnums.HourglassState.UPRIGHT,
	GameEnums.HourglassState.FALLING,
	GameEnums.HourglassState.FALLEN,
]

var hp: Dictionary = {}
var board: Dictionary = {}
var bench: Dictionary = {}
var current_turn: PlayerSide = PlayerSide.A
var effect_resolver: EffectResolver
## この手番に設定された行動(GameDesign.md 4.3)。空のときはパス(全マスが進行する)。
var pending_action: Dictionary = {}
## 直前の対局がどう決着したか。match_ended発火の直前に確定する。
var end_reason: EndReason = EndReason.HP_DEPLETED
var _match_over := false


func start_match(
	board_a: Array[HourglassData],
	bench_a: Array[HourglassData],
	board_b: Array[HourglassData],
	bench_b: Array[HourglassData]
) -> void:
	hp = {PlayerSide.A: INITIAL_HP, PlayerSide.B: INITIAL_HP}
	board = {
		PlayerSide.A: _build_board_instances(board_a),
		PlayerSide.B: _build_board_instances(board_b),
	}
	bench = {PlayerSide.A: _build_instances(bench_a), PlayerSide.B: _build_instances(bench_b)}
	current_turn = PlayerSide.A
	pending_action = {}
	_match_over = false
	end_reason = EndReason.HP_DEPLETED


func other_side(side: PlayerSide) -> PlayerSide:
	return PlayerSide.B if side == PlayerSide.A else PlayerSide.A


func is_match_over() -> bool:
	return _match_over


## 持ち時間切れなど、ダメージ以外の要因で対局を即座に終了させる。reasonは決着の要因で、
## 既定は持ち時間切れ(投了はsurrender()から明示的に渡す)。
func force_match_end(winner: PlayerSide, reason: EndReason = EndReason.TIMEOUT) -> void:
	if _match_over:
		return
	_match_over = true
	end_reason = reason
	match_ended.emit(winner)


## 投了。sideが即座に敗北する(GameDesign.md 3章)。持ち時間切れと同じ即時終了経路を使う。
func surrender(side: PlayerSide) -> void:
	force_match_end(other_side(side), EndReason.SURRENDER)


## この手番の行動を設定する(GameDesign.md 4.3)。設定しただけでは盤面は動かず、
## advance_and_end_turn()の解決で初めて適用される。押す前なら何度でも設定し直せる。
func set_pending_action(action: Dictionary) -> void:
	if _match_over:
		return
	pending_action = action.duplicate(true)


func clear_pending_action() -> void:
	pending_action = {}


## 自分の手番を終える。ここまで指していた側(current_turn)の場3マスを左→中央→右の順に
## 1マスずつ解決し、相手の駒への反転が設定されていればそれを最後に解決してから、
## ターンチック効果を解決して手番を交代する(GameDesign.md 4.4)。
## 1マスの解決は「そのマスに設定された行動を適用する→続けて必ず1段階進行する」の2段で、
## 行動を設定したかどうかで進行の有無は変わらない(GameDesign.md 2章)。
## 対局開始直後はこの関数が一度も呼ばれないため、
## 全ての砂時計はSTART_STATESで与えた初期状態のまま保たれる。
func advance_and_end_turn() -> void:
	if _match_over:
		return
	var action := pending_action
	pending_action = {}
	var own_kinds := _own_slot_kinds(action)

	for position in range(BOARD_SIZE):
		match own_kinds.get(position, ""):
			"flip":
				resolution_step_started.emit(current_turn, [position], "flip")
				flip(action["actor"], action["side"], action["position"])
			"move":
				var from_position: int = action["from"]
				var to_position: int = action["to"]
				resolution_step_started.emit(current_turn, [from_position, to_position], "move")
				move(current_turn, from_position, to_position)
			"swap_in":
				resolution_step_started.emit(current_turn, [position], "swap_in")
				swap_in(current_turn, action["bench_index"])
			"skill":
				resolution_step_started.emit(current_turn, _skill_step_positions(action), "skill")
				activate_skill(current_turn, action["position"], action.get("bench_index", 0))
			_:
				var instance: HourglassInstance = board[current_turn][position]
				var idle := instance.state == GameEnums.HourglassState.FALLEN
				resolution_step_started.emit(
					current_turn, [position], "idle" if idle else "advance"
				)
		advance_slot(current_turn, position)

	if _is_opponent_flip(action):
		var opponent: PlayerSide = other_side(current_turn)
		resolution_step_started.emit(opponent, [action["position"]], "flip")
		flip(action["actor"], action["side"], action["position"])

	if effect_resolver != null:
		effect_resolver.resolve_turn_tick(self)
	current_turn = other_side(current_turn)
	turn_started.emit(current_turn)


## 設定された行動から「自分の場のどのマスがどの行動で解決されるか」を求める。
## 相手の駒への反転・パスの場合は空になり、3マスとも進行するだけになる。
## 移動は関与する2マスのうち番号の若い方にだけ登録する。入れ替え自体をそこで1度だけ行い、
## もう一方のマスは自分の解決順が来たときに通常どおり進行させるため(GameDesign.md 4.4)。
func _own_slot_kinds(action: Dictionary) -> Dictionary:
	var kinds: Dictionary = {}
	match action.get("type", ""):
		"flip":
			if action["side"] == current_turn:
				kinds[action["position"]] = "flip"
		"move":
			kinds[mini(action["from"], action["to"])] = "move"
		"swap_in":
			kinds[BoardPosition.LEFT] = "swap_in"
		"skill":
			kinds[_skill_slot(action)] = "skill"
	return kinds


## スキルを解決するマス。位置交換は2マスに関わるため、移動と同じく番号の若い方で1度だけ
## 実行する(GameDesign.md 4.4)。そうしないと入れ替わった駒の一方が2回進行してしまう。
func _skill_slot(action: Dictionary) -> int:
	var positions := _skill_step_positions(action)
	return positions.min()


func _skill_step_positions(action: Dictionary) -> Array:
	return skill_positions(current_turn, action)


## スキルの解決で注目すべきマス(UI層のズーム・予約マーク・滑り込みの対象)。
## 位置交換のみ2マスになり、それ以外はその駒のマス1つ。
func skill_positions(side: PlayerSide, action: Dictionary) -> Array:
	var position: int = action["position"]
	var skill := skill_at(side, position)
	if skill == null or skill.effect_type != GameEnums.EffectType.SWAP_POSITION:
		return [position]
	var partner := _adjacent_position(position, skill.target)
	if partner < 0:
		return [position]
	return [position, partner]


## 指定したマスの駒が持つスキル(無ければnull)。
func skill_at(side: PlayerSide, position: int) -> SkillData:
	var instance: HourglassInstance = board[side][position]
	return instance.data.skill


## スキルを発動する(GameDesign.md 4.3)。実際の効果はEffectResolverが解決する。
func activate_skill(side: PlayerSide, position: int, bench_index: int = 0) -> void:
	if _match_over or effect_resolver == null:
		return
	effect_resolver.resolve_skill(self, side, position, bench_index)


## 隣接マスの位置を返す(隣が無い場合は-1)。
func _adjacent_position(position: int, target: int) -> int:
	var offset := 0
	if target == GameEnums.Target.ADJACENT_LEFT:
		offset = -1
	elif target == GameEnums.Target.ADJACENT_RIGHT:
		offset = 1
	if offset == 0:
		return -1
	var result := position + offset
	if result < 0 or result >= BOARD_SIZE:
		return -1
	return result


func _is_opponent_flip(action: Dictionary) -> bool:
	if action.get("type", "") != "flip":
		return false
	return action["side"] != current_turn


func flip(actor: PlayerSide, side: PlayerSide, position: int) -> void:
	if _match_over:
		return
	if effect_resolver != null and effect_resolver.is_locked(self, side, position):
		return
	var instance: HourglassInstance = board[side][position]
	instance.flip()
	hourglass_state_changed.emit(side, position, instance.state)
	if effect_resolver != null:
		effect_resolver.resolve_on_flip(self, actor, side, position)


func move(side: PlayerSide, from_position: int, to_position: int) -> void:
	if _match_over or from_position == to_position:
		return
	var slots: Array = board[side]
	var tmp: HourglassInstance = slots[from_position]
	slots[from_position] = slots[to_position]
	slots[to_position] = tmp
	hourglass_moved.emit(side, from_position, to_position)


## 旧「交代」アクション(基本行動としては廃止済み)。過去のリプレイを再生できるよう残している。
func swap_in(side: PlayerSide, bench_index: int) -> void:
	swap_bench(side, BoardPosition.LEFT, bench_index)


## 交代スキル(GameDesign.md 7章)。指定したマスの駒と控えの1個を入れ替える。
## 出てきた駒は上向きから始まる。
func swap_bench(side: PlayerSide, position: int, bench_index: int) -> void:
	if _match_over:
		return
	var bench_slots: Array = bench[side]
	var board_slots: Array = board[side]
	if bench_index < 0 or bench_index >= bench_slots.size():
		return
	var incoming: HourglassInstance = bench_slots[bench_index]
	var outgoing: HourglassInstance = board_slots[position]
	incoming.state = GameEnums.HourglassState.UPRIGHT
	board_slots[position] = incoming
	bench_slots[bench_index] = outgoing
	hourglass_swapped.emit(side, bench_index, position)


## 場に出す砂時計を作る。マスごとに異なる初期状態を与えるが、これは生成時の代入であり
## advance_slot()を経由しないため、右マスがFALLENで始まっても落下ダメージは発生しない
## (落下ダメージはFALLENへ到達した瞬間に入るものであるため)。
func _build_board_instances(defs: Array[HourglassData]) -> Array[HourglassInstance]:
	var result := _build_instances(defs)
	for position in range(mini(result.size(), START_STATES.size())):
		result[position].state = START_STATES[position]
	return result


func _build_instances(defs: Array[HourglassData]) -> Array[HourglassInstance]:
	var result: Array[HourglassInstance] = []
	for data in defs:
		result.append(HourglassInstance.new(data))
	return result


func advance_slot(side: PlayerSide, position: int) -> void:
	var instance: HourglassInstance = board[side][position]
	if instance.state == GameEnums.HourglassState.FALLEN:
		return
	instance.advance()
	hourglass_state_changed.emit(side, position, instance.state)
	if instance.state == GameEnums.HourglassState.FALLEN:
		_apply_fall_damage(side, position)
		if effect_resolver != null:
			effect_resolver.resolve_on_fallen(self, side, position)


func _apply_fall_damage(side: PlayerSide, position: int) -> void:
	var instance: HourglassInstance = board[side][position]
	var damage: int = instance.data.fall_damage
	if damage <= 0:
		return
	deal_damage(other_side(side), damage)


func deal_damage(target_side: PlayerSide, amount: int) -> void:
	if _match_over or amount <= 0:
		return
	var final_amount := amount
	if effect_resolver != null:
		final_amount -= effect_resolver.get_damage_reduction(self, target_side)
	final_amount = max(final_amount, 0)
	if final_amount <= 0:
		return
	hp[target_side] = max(hp[target_side] - final_amount, 0)
	hp_changed.emit(target_side, hp[target_side])
	if hp[target_side] <= 0:
		_match_over = true
		end_reason = EndReason.HP_DEPLETED
		match_ended.emit(other_side(target_side))


## 探索・シミュレーション用の軽量スナップショットを取得する。
func save_snapshot() -> Dictionary:
	var board_snap := {
		PlayerSide.A: [],
		PlayerSide.B: [],
	}
	for side in [PlayerSide.A, PlayerSide.B]:
		for instance: HourglassInstance in board[side]:
			board_snap[side].append({"data": instance.data, "state": instance.state})

	var bench_snap := {
		PlayerSide.A: [],
		PlayerSide.B: [],
	}
	for side in [PlayerSide.A, PlayerSide.B]:
		for instance: HourglassInstance in bench[side]:
			bench_snap[side].append({"data": instance.data, "state": instance.state})

	return {
		"hp": hp.duplicate(),
		"current_turn": current_turn,
		"pending_action": pending_action.duplicate(true),
		"match_over": _match_over,
		"end_reason": end_reason,
		"board": board_snap,
		"bench": bench_snap,
	}


## スナップショットから盤面・HP・状態を復元する。
func restore_snapshot(snapshot: Dictionary) -> void:
	hp = snapshot["hp"].duplicate()
	current_turn = snapshot["current_turn"]
	pending_action = snapshot["pending_action"].duplicate(true)
	_match_over = snapshot["match_over"]
	end_reason = snapshot["end_reason"]

	for side in [PlayerSide.A, PlayerSide.B]:
		var snap_board: Array = snapshot["board"][side]
		for i in range(snap_board.size()):
			var item: Dictionary = snap_board[i]
			var inst: HourglassInstance = board[side][i]
			inst.data = item["data"]
			inst.state = item["state"]

		var snap_bench: Array = snapshot["bench"][side]
		for i in range(snap_bench.size()):
			var item: Dictionary = snap_bench[i]
			var inst: HourglassInstance = bench[side][i]
			inst.data = item["data"]
			inst.state = item["state"]


## UI等へのシグナル購読を持たない、探索・シミュレーション専用の複製GameStateを生成する。
func clone_state() -> GameState:
	var cloned := GameState.new()
	cloned.effect_resolver = EffectResolver.new()
	var empty_cards: Array[HourglassData] = []
	cloned.start_match(empty_cards, empty_cards, empty_cards, empty_cards)
	for side in [PlayerSide.A, PlayerSide.B]:
		cloned.board[side] = []
		for inst in board[side]:
			cloned.board[side].append(HourglassInstance.new(inst.data))
		cloned.bench[side] = []
		for inst in bench[side]:
			cloned.bench[side].append(HourglassInstance.new(inst.data))
	cloned.restore_snapshot(save_snapshot())
	return cloned
