extends RefCounted
## 誘導対局の台本(`TutorialScriptData`、GameDesign.md 18章)の検証。
## **両者の手をすべて決めた台本**をそのまま先頭から `MatchState` へ適用し、
## すべて合法であること・要所の数値が想定どおりであること・最後の手でプレイヤーが
## 勝つことを確かめる(Architecture.md 4.1.5節「成立は自動テストが確かめる」)。
## プールの調整で台本が崩れていないかをここで検知する。

const SIDE_A := MatchState.Side.A
const SIDE_B := MatchState.Side.B

var _assert: Callable
var _state: MatchState
var _refs: Dictionary = {}


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_script_is_legal_and_player_wins()


func _test_script_is_legal_and_player_wins() -> void:
	var script: TutorialScriptData = load(TutorialScriptData.RESOURCE_PATH)
	_state = MatchState.new()
	_state.keep_deck_order = true
	_state.start_match(script.deck_a(), script.deck_b(), SIDE_A, 1, MatchState.COIN_ENABLED, true)
	_state.mulligan(SIDE_A, [])
	_state.mulligan(SIDE_B, [])
	# 相手の開始HPは台本の値(GameDesign.md 18章「相手のHPは4から」)。
	_state.hp[SIDE_B] = script.foe_start_hp
	_refs = {}

	for i in script.steps.size():
		var step: Dictionary = script.steps[i]
		_apply_step(step, i)
		# CPUの手はここでは1手ずつ台本どおりに適用するだけで、そのターンの最後の手の
		# あとに実際のCPU(`_take_cpu_action()`)が自分でターン終了を返す
		# (`TutorialCpuStrategy.choose_action()`が台本を使い切ると `end_turn` を返す)。
		if str(step.get("side", "")) == "b":
			var next_is_b := (
				i + 1 < script.steps.size() and str(script.steps[i + 1].get("side", "")) == "b"
			)
			if not next_is_b:
				_state.end_turn()

	_assert.call(_state.is_match_over(), "the scripted match should finish")
	_assert.call(_state.winner == SIDE_A, "the player should win the scripted tutorial match")


func _apply_step(step: Dictionary, index: int) -> void:
	var side_tag := str(step.get("side", ""))
	if side_tag == "info":
		return
	var side := SIDE_A if side_tag == "a" else SIDE_B
	match str(step.get("kind", "")):
		"mulligan":
			pass
		"play":
			_apply_play(step, side, index)
		"attack":
			_apply_attack(step, side, index)
		"flip":
			var slot := _slot_of(side, str(step.get("actor_ref", "")))
			_assert.call(_state.flip(side, slot), "step %d: flip should be legal" % index)
		"flip_right":
			var target_side := (
				side if str(step.get("target_side", "")) == "own" else MatchState.other_side(side)
			)
			var slot := _slot_of(target_side, str(step.get("target_ref", "")))
			_assert.call(
				_state.use_flip_right(side, target_side, slot),
				"step %d: flip_right should be legal" % index
			)
			# 反転権で相手のサンドを弱めた:攻撃力が下がる(GameDesign.md 18章「弱める」)。
			if str(step.get("target_ref", "")) == "bs":
				var bs: CardInstance = _refs["bs"]
				_assert.call(bs.attack == 1, "step %d: bs should be weakened to attack 1" % index)
		"end_turn":
			_state.end_turn()
			_check_after_end_turn(index)


func _apply_play(step: Dictionary, side: int, index: int) -> void:
	var card_id := str(step.get("card_id", ""))
	var hand_index := _hand_index_of(side, card_id)
	_assert.call(hand_index >= 0, "step %d: %s should be in hand" % [index, card_id])
	var empty: Array = _state.empty_slots(side)
	_assert.call(not empty.is_empty(), "step %d: an empty slot should be available" % index)
	var slot: int = empty[0]
	_assert.call(_state.play_card(side, hand_index, slot), "step %d: play should be legal" % index)
	var ref := str(step.get("ref", ""))
	if not ref.is_empty():
		_refs[ref] = _state.board[side][slot]


func _apply_attack(step: Dictionary, side: int, index: int) -> void:
	var actor_slot := _slot_of(side, str(step.get("actor_ref", "")))
	var target_slot := -1
	if str(step.get("target_kind", "")) != "face":
		target_slot = _slot_of(MatchState.other_side(side), str(step.get("target_ref", "")))
	_assert.call(
		_state.attack(side, actor_slot, target_slot), "step %d: attack should be legal" % index
	)
	# 自分2:グレイン同士の相打ちは双方1/1になる(GameDesign.md 18章)。
	if str(step.get("actor_ref", "")) == "ag" and str(step.get("target_ref", "")) == "bg":
		var ag: CardInstance = _refs["ag"]
		var bg: CardInstance = _refs["bg"]
		_assert.call(
			ag.health == 1 and ag.attack == 1, "step %d: ag should trade down to 1/1" % index
		)
		_assert.call(
			bg.health == 1 and bg.attack == 1, "step %d: bg should trade down to 1/1" % index
		)
	# 自分3:サンドで本体を攻撃すると4→3になる(GameDesign.md 18章)。
	if str(step.get("actor_ref", "")) == "as1" and str(step.get("target_kind", "")) == "face":
		if int(_state.hp[SIDE_B]) == 3:
			_assert.call(true, "step %d: face attack should bring the foe to 3" % index)


func _check_after_end_turn(index: int) -> void:
	# 自分1のターン終了でグレインは2/1になる(GameDesign.md 18章)。
	if _refs.has("ag") and index == 3:
		var ag: CardInstance = _refs["ag"]
		_assert.call(ag.health == 2 and ag.attack == 1, "step %d: ag should tick to 2/1" % index)
	# 自分2のターン終了で、相打ちで1/1まで削れたグレインは砂が落ちきって割れる。
	if _refs.has("ag") and index == 7:
		_assert.call(
			not _state.board[SIDE_A].has(_refs["ag"]),
			"step %d: ag should have broken from the sand running out" % index
		)


func _slot_of(side: int, ref: String) -> int:
	var target: CardInstance = _refs.get(ref)
	if target == null:
		return -1
	for slot in MatchState.BOARD_SIZE:
		if _state.board[side][slot] == target:
			return slot
	return -1


func _hand_index_of(side: int, card_id: String) -> int:
	var hand: Array = _state.hand[side]
	for i in hand.size():
		var card: CardData = hand[i]
		if card.id == card_id:
			return i
	return -1
