class_name SmartCpuStrategy
extends CpuStrategy

## 盤面評価と探索に基づく強化CPU思考ロジック。
## 局面評価関数とスナップショットを用いた高速展開により、有利な手番・初期配置を選択する。

const WIN_SCORE := 100000.0
const LOSE_SCORE := -100000.0

## スキル持ちを場へ置くことの価値。スキルは場に出ている駒しか使えないため。
const SKILL_ON_BOARD_BONUS := 25.0

@export var search_depth: int = 2
var _sim_state: GameState


func _init(p_depth: int = 2) -> void:
	search_depth = p_depth


## 初期配置(場3個・控え2個)を駒の特性と初期状態に合わせて決定する。
func choose_placement(deck: Array[HourglassData]) -> Dictionary:
	if deck.size() < GameState.BOARD_SIZE + GameState.BENCH_SIZE:
		return super.choose_placement(deck)

	var best_board: Array[HourglassData] = []
	var best_bench: Array[HourglassData] = []
	var best_score := -INF

	# 5枚から場3枚を選ぶ順列(60通り)を全探索して最高スコアの配置を選ぶ
	var indices := [0, 1, 2, 3, 4]
	for i in range(5):
		for j in range(5):
			if j == i:
				continue
			for k in range(5):
				if k == i or k == j:
					continue
				var board_cand: Array[HourglassData] = [deck[i], deck[j], deck[k]]
				var bench_cand: Array[HourglassData] = []
				for idx in indices:
					if idx != i and idx != j and idx != k:
						bench_cand.append(deck[idx])

				var score := _evaluate_placement(board_cand, bench_cand)
				if score > best_score:
					best_score = score
					best_board = board_cand
					best_bench = bench_cand

	return {
		"board": best_board,
		"bench": best_bench,
	}


func _evaluate_placement(board: Array[HourglassData], _bench: Array[HourglassData]) -> float:
	var score := 0.0

	# 左マス (LEFT): 初期状態 UPRIGHT (2手かけて落ちる)
	var left := board[GameState.BoardPosition.LEFT]
	score += _score_left_slot(left) + _score_skill(left, GameState.BoardPosition.LEFT)

	# 中央マス (CENTER): 初期状態 FALLING (1手目に何もしなければ即落ちきる)
	var center := board[GameState.BoardPosition.CENTER]
	score += _score_center_slot(center) + _score_skill(center, GameState.BoardPosition.CENTER)

	# 右マス (RIGHT): 初期状態 FALLEN (落ちきりスタート、反転しないと動かない)
	var right := board[GameState.BoardPosition.RIGHT]
	score += _score_right_slot(right) + _score_skill(right, GameState.BoardPosition.RIGHT)

	return score


## スキルは場に出ていないと使えないため、スキル持ちは場へ置く価値がある(GameDesign.md 4.3)。
## 位置交換だけは右隣が必要なため、右マスに置くと死に札になる。
func _score_skill(data: HourglassData, position: int) -> float:
	if not data.has_skill():
		return 0.0
	if (
		data.skill.effect_type == GameEnums.EffectType.SWAP_POSITION
		and position == GameState.BoardPosition.RIGHT
	):
		return 0.0
	return SKILL_ON_BOARD_BONUS


func _score_left_slot(data: HourglassData) -> float:
	var s := float(data.fall_damage) * 10.0
	for effect in data.effects:
		if effect.trigger == GameEnums.Trigger.WHILE_FALLING:
			s += 20.0  # 落下中効果(シールド・キング・アイ)は2ターン維持できる左と相性が良い
	return s


func _score_center_slot(data: HourglassData) -> float:
	# 即座に落ちきるため、落下ダメージが高い駒が非常に強力
	var s := float(data.fall_damage) * 25.0
	for effect in data.effects:
		if effect.trigger == GameEnums.Trigger.ON_FLIP:
			s -= 15.0  # 反転させないと効果が出ない駒は中央に置くメリットが薄い
		elif effect.trigger == GameEnums.Trigger.WHILE_FALLING:
			s -= 10.0  # 1手で落ちきるため落下中効果の恩恵が短い
	return s


func _score_right_slot(data: HourglassData) -> float:
	var s := 0.0
	# 落ちきりスタートなので、初手に反転させる価値が高い駒、または落ちきり中効果が活きる駒
	for effect in data.effects:
		if effect.trigger == GameEnums.Trigger.ON_FLIP:
			s += 30.0  # 反転時効果持ち(ソード、ダッシュ、ミラー等)に最適
		elif effect.trigger == GameEnums.Trigger.WHILE_FALLEN:
			s += 35.0  # ジャッジなど落ちきり中効果持ち
	if data.fall_damage >= 4 and data.effects.is_empty():
		# バニラ駒は反転すれば2手後に大ダメージだが、最初は寝ている
		s += 10.0
	return s


## 局面から最善手を1手選択する。
func choose_action(state: GameState, side: GameState.PlayerSide) -> Dictionary:
	var actions := legal_actions(state, side)
	if actions.is_empty():
		return {"type": "pass", "side": side}

	_ensure_sim_state(state)

	var best_action: Dictionary = actions[0]
	var best_score := -INF

	# 各合法手を試す
	for action in actions:
		var score := _search_action(state, action, side, search_depth)
		# 同点ならランダムに少し揺らす(tie-breaker)
		var tie_breaker: float = randf() * 0.01
		if score + tie_breaker > best_score:
			best_score = score + tie_breaker
			best_action = action

	return best_action


func _search_action(
	state: GameState, action: Dictionary, side: GameState.PlayerSide, depth: int
) -> float:
	_sim_state.restore_snapshot(state.save_snapshot())
	OnlineMatch.apply(action, _sim_state)
	_sim_state.advance_and_end_turn()

	if _sim_state.is_match_over():
		return evaluate_state(_sim_state, side)

	if depth <= 1:
		return evaluate_state(_sim_state, side)

	# 相手の応手を読む(相手視点での最善手に対するミニマックス)
	var opp_side: GameState.PlayerSide = _sim_state.other_side(side)
	var opp_actions := legal_actions(_sim_state, opp_side)
	if opp_actions.is_empty():
		return evaluate_state(_sim_state, side)

	var snap := _sim_state.save_snapshot()
	var worst_score_for_me := INF

	for opp_action in opp_actions:
		_sim_state.restore_snapshot(snap)
		OnlineMatch.apply(opp_action, _sim_state)
		_sim_state.advance_and_end_turn()

		var score := evaluate_state(_sim_state, side)
		if score < worst_score_for_me:
			worst_score_for_me = score

	return worst_score_for_me


## 局面評価関数(sideから見たスコア)
func evaluate_state(state: GameState, side: GameState.PlayerSide) -> float:
	if state.is_match_over():
		var opp: GameState.PlayerSide = state.other_side(side)
		if state.hp[opp] <= 0 and state.hp[side] > 0:
			return WIN_SCORE
		if state.hp[side] <= 0:
			return LOSE_SCORE
		return 0.0

	var opp_side: GameState.PlayerSide = state.other_side(side)
	var my_hp: int = state.hp[side]
	var opp_hp: int = state.hp[opp_side]

	# 1. HP差の評価
	var score: float = float(my_hp - opp_hp) * 100.0

	# 自分のHPが危険水域(<=6)なら生存重視
	if my_hp <= 6:
		score -= float(6 - my_hp) * 50.0

	# 相手のHPが危険水域(<=6)なら詰み重視
	if opp_hp <= 6:
		score += float(6 - opp_hp) * 50.0

	# 2. 自陣の駒の評価 (前進・ダメージ期待値・効果)
	for pos in range(GameState.BOARD_SIZE):
		var inst: HourglassInstance = state.board[side][pos]
		score += _evaluate_own_piece(inst, state, side, pos)

	# 3. 相手陣の駒の評価 (脅威度・遅延価値)
	for pos in range(GameState.BOARD_SIZE):
		var opp_inst: HourglassInstance = state.board[opp_side][pos]
		score -= _evaluate_opp_piece(opp_inst, state, opp_side, pos)

	return score


func _evaluate_own_piece(
	inst: HourglassInstance, state: GameState, side: GameState.PlayerSide, pos: int
) -> float:
	var s := 0.0
	var damage := float(inst.data.fall_damage)

	match inst.state:
		GameEnums.HourglassState.FALLING:
			# 次手番終了で落ちきる期待値(高い価値)
			s += damage * 30.0
			for effect in inst.data.effects:
				if effect.trigger == GameEnums.Trigger.WHILE_FALLING:
					s += 25.0  # 被ダメ軽減やロックなどの維持
				elif effect.trigger == GameEnums.Trigger.ON_FALLEN:
					s += 15.0  # 落ちきり時効果期待値
		GameEnums.HourglassState.UPRIGHT:
			# 2手後に落ちきる期待値
			s += damage * 15.0
		GameEnums.HourglassState.FALLEN:
			# 落ちきり中効果(ジャッジ等)
			for effect in inst.data.effects:
				if effect.trigger == GameEnums.Trigger.WHILE_FALLEN:
					s += 45.0  # 毎ターン継続ダメージの価値
			# バニラ駒で落ちきったまま放置されているのは寝ている状態
			if inst.data.effects.is_empty():
				s -= 5.0

	# ロックされている場合のマイナス
	if state.effect_resolver != null and state.effect_resolver.is_locked(state, side, pos):
		s -= 15.0

	return s


func _evaluate_opp_piece(
	inst: HourglassInstance, state: GameState, opp_side: GameState.PlayerSide, pos: int
) -> float:
	var s := 0.0
	var damage := float(inst.data.fall_damage)

	match inst.state:
		GameEnums.HourglassState.FALLING:
			# 相手が次に落ちきる高打点駒は脅威
			s += damage * 32.0
			for effect in inst.data.effects:
				if effect.trigger == GameEnums.Trigger.WHILE_FALLING:
					s += 20.0
		GameEnums.HourglassState.UPRIGHT:
			s += damage * 14.0
		GameEnums.HourglassState.FALLEN:
			for effect in inst.data.effects:
				if effect.trigger == GameEnums.Trigger.WHILE_FALLEN:
					s += 50.0  # 相手のジャッジ放置は大脅威

	if state.effect_resolver != null and state.effect_resolver.is_locked(state, opp_side, pos):
		s -= 15.0  # ロックして封じているなら脅威度低下

	return s


func _ensure_sim_state(base_state: GameState) -> void:
	if _sim_state == null:
		_sim_state = base_state.clone_state()
