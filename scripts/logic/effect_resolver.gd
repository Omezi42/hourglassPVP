class_name EffectResolver
extends RefCounted


func resolve_on_flip(game_state: GameState, actor: int, side: int, position: int) -> void:
	var instance: HourglassInstance = game_state.board[side][position]
	for effect in instance.data.effects:
		if effect.trigger != GameEnums.Trigger.ON_FLIP:
			continue
		match effect.effect_type:
			GameEnums.EffectType.DAMAGE:
				game_state.deal_damage(_resolve_player_target(effect.target, side), effect.value)
			GameEnums.EffectType.COUNTER:
				if actor != side:
					game_state.deal_damage(
						_resolve_player_target(effect.target, side), effect.value
					)
			GameEnums.EffectType.FORCE_ADVANCE:
				if effect.target == GameEnums.Target.SELF:
					game_state.advance_slot(side, position)
			GameEnums.EffectType.SYNC_STATE:
				_sync_state(game_state, side, position, instance, effect.target)


func resolve_on_fallen(game_state: GameState, side: int, position: int) -> void:
	var instance: HourglassInstance = game_state.board[side][position]
	for effect in instance.data.effects:
		if effect.trigger != GameEnums.Trigger.ON_FALLEN:
			continue
		match effect.effect_type:
			GameEnums.EffectType.DAMAGE:
				game_state.deal_damage(_resolve_player_target(effect.target, side), effect.value)
			GameEnums.EffectType.RECOVER:
				if effect.target == GameEnums.Target.RANDOM_ALLY:
					_recover_random_ally(game_state, side, position)


func resolve_turn_tick(game_state: GameState) -> void:
	for side in [GameState.PlayerSide.A, GameState.PlayerSide.B]:
		for position in range(GameState.BOARD_SIZE):
			var instance: HourglassInstance = game_state.board[side][position]
			if instance.state != GameEnums.HourglassState.FALLEN:
				continue
			for effect in instance.data.effects:
				if effect.trigger != GameEnums.Trigger.WHILE_FALLEN:
					continue
				if effect.effect_type == GameEnums.EffectType.DAMAGE:
					game_state.deal_damage(
						_resolve_player_target(effect.target, side), effect.value
					)


func get_damage_reduction(game_state: GameState, side: int) -> int:
	var total := 0
	for position in range(GameState.BOARD_SIZE):
		var instance: HourglassInstance = game_state.board[side][position]
		for effect in instance.data.effects:
			if effect.effect_type != GameEnums.EffectType.DAMAGE_REDUCTION:
				continue
			if (
				effect.trigger == GameEnums.Trigger.WHILE_FALLING
				and instance.state == GameEnums.HourglassState.FALLING
			):
				total += effect.value
			elif (
				effect.trigger == GameEnums.Trigger.WHILE_FALLEN
				and instance.state == GameEnums.HourglassState.FALLEN
			):
				total += effect.value
	return total


func is_locked(game_state: GameState, side: int, position: int) -> bool:
	var opponent_side: int = game_state.other_side(side)
	var opponent_instance: HourglassInstance = game_state.board[opponent_side][position]
	for effect in opponent_instance.data.effects:
		if effect.effect_type != GameEnums.EffectType.LOCK:
			continue
		if effect.target != GameEnums.Target.OPPONENT_MIRROR:
			continue
		if (
			effect.trigger == GameEnums.Trigger.WHILE_FALLING
			and opponent_instance.state == GameEnums.HourglassState.FALLING
		):
			return true
		if (
			effect.trigger == GameEnums.Trigger.WHILE_FALLEN
			and opponent_instance.state == GameEnums.HourglassState.FALLEN
		):
			return true
	return false


## そのマスでスキルを発動しても意味があるかどうか。位置交換は隣が無いマス(右向きなら右端)
## では対象が存在せず、選んでも手番を無駄にするだけなので合法手にもUIにも出さない。
static func can_activate_skill(game_state: GameState, side: int, position: int) -> bool:
	var skill := game_state.skill_at(side, position)
	if skill == null:
		return false
	if skill.effect_type != GameEnums.EffectType.SWAP_POSITION:
		return true
	return game_state.skill_positions(side, {"position": position}).size() >= 2


## スキル(GameDesign.md 4.3・7章)を解決する。受動効果と同じEffectType/Targetの語彙を使うため、
## SWAP_BENCH/SWAP_POSITION以外は受動側と同じ処理をそのまま呼ぶ。
func resolve_skill(game_state: GameState, side: int, position: int, bench_index: int) -> void:
	var instance: HourglassInstance = game_state.board[side][position]
	var skill: SkillData = instance.data.skill
	if skill == null:
		return
	match skill.effect_type:
		GameEnums.EffectType.SWAP_BENCH:
			game_state.swap_bench(side, position, bench_index)
		GameEnums.EffectType.SWAP_POSITION:
			var partner := _adjacent_position(position, skill.target)
			if partner >= 0:
				game_state.move(side, position, partner)
		GameEnums.EffectType.FORCE_ADVANCE:
			game_state.advance_slot(side, position)
		GameEnums.EffectType.RECOVER:
			_recover_random_ally(game_state, side, position, skill.value)
		GameEnums.EffectType.SYNC_STATE:
			_sync_state(game_state, side, position, instance, skill.target)
		GameEnums.EffectType.DAMAGE:
			game_state.deal_damage(_resolve_player_target(skill.target, side), skill.value)


func _resolve_player_target(target: int, owner_side: int) -> int:
	if target == GameEnums.Target.OWN_PLAYER:
		return owner_side
	return _other_player(owner_side)


func _other_player(owner_side: int) -> int:
	return (
		GameState.PlayerSide.B if owner_side == GameState.PlayerSide.A else GameState.PlayerSide.A
	)


func _sync_state(
	game_state: GameState, side: int, position: int, instance: HourglassInstance, target: int
) -> void:
	var adjacent_position := _adjacent_position(position, target)
	if adjacent_position == -1:
		return
	var adjacent_instance: HourglassInstance = game_state.board[side][adjacent_position]
	adjacent_instance.state = instance.state
	game_state.hourglass_state_changed.emit(side, adjacent_position, adjacent_instance.state)


func _adjacent_position(position: int, target: int) -> int:
	if target == GameEnums.Target.ADJACENT_LEFT and position > GameState.BoardPosition.LEFT:
		return position - 1
	if target == GameEnums.Target.ADJACENT_RIGHT and position < GameState.BoardPosition.RIGHT:
		return position + 1
	return -1


## countは上向きに戻す味方の個数。1なら従来どおりランダムに1個、2以上なら
## その個数だけランダムに(重複なく)戻す(GameDesign.md 7章のスキル「目覚め」)。
func _recover_random_ally(
	game_state: GameState, side: int, exclude_position: int, count: int = 1
) -> void:
	var candidates: Array[int] = []
	for position in range(GameState.BOARD_SIZE):
		if position == exclude_position:
			continue
		# 落ちきった駒だけを対象にする。落下中の駒を上向きへ戻すと、その駒が落ちきるのを
		# 自分で遅らせることになり、起こす側の得にならないため(GameDesign.md 7章)。
		var instance: HourglassInstance = game_state.board[side][position]
		if instance.state != GameEnums.HourglassState.FALLEN:
			continue
		candidates.append(position)
	candidates.shuffle()
	for i in range(mini(maxi(count, 1), candidates.size())):
		var chosen_position: int = candidates[i]
		var chosen: HourglassInstance = game_state.board[side][chosen_position]
		chosen.flip()
		game_state.hourglass_state_changed.emit(side, chosen_position, chosen.state)
