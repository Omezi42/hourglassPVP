class_name SoloBattleRules
extends RefCounted
## 遠征の対局1つぶんに重ねる規則(GameDesign.md 27章、Architecture.md 10.15節)。
##
## 山札の組み立て・HPの持ち越し・関門/主の特殊ルールと初期盤面・恩恵・特殊勝利条件の監視を、
## 画面を持たない `MatchState` へ当てる。対局画面(`CardMatchSolo`)と通し測定
## (`tools/balance/run_solo_expedition.gd`)が同じ規則で対局を作るため、ここへ1か所にまとめる。

## 特殊勝利条件の残りの数が変わりうる瞬間(遠征の札の更新用)。
signal progressed

var _state: MatchState
var _mine := MatchState.Side.A
var _gate: SoloGateData = null
var _boon_effects: SoloBoonEffects = null


## 自分の山札(恩恵で書き換えた写し)。
static func own_deck(run: SoloRun) -> Array:
	return SoloBoonEffects.modded_deck(CardLibrary.deck_from_ids(run.deck_ids), run)


## 相手の山札。鏡写し・鏡の主は恩恵で書き換える前の自分の山札の写しを使い、
## 急ぎの主は速落を足す(GameDesign.md 27章「関門」「主」)。
static func foe_deck(run: SoloRun, dest: Dictionary, gate: SoloGateData) -> Array:
	var cards: Array = (
		CardLibrary.deck_from_ids(run.deck_ids)
		if SoloRun.uses_player_deck(dest)
		else CardCpuDecks.deck_of(str(dest.get("cpu_deck", "")))
	)
	if gate != null and gate.foe_quick:
		cards = SoloBoonEffects.quick_deck(cards)
	return cards


## `start_match()`(マリガン待ち)の直後、マリガンより前に呼ぶ。
## 恩恵「用意周到」の追加ドローはマリガンで見せる手札へ入れるためここで足す。
## 効果音を鳴らさないため信号を出す`draw()`ではなく`_draw_one()`を使う。
## **`hp_changed` は出さない。**画面はHPを直接読み、音とログがこの信号を被弾と誤読するため。
func apply(state: MatchState, mine: int, run: SoloRun, gate: SoloGateData) -> void:
	_state = state
	_mine = mine
	_gate = gate
	var foe := MatchState.other_side(mine)
	for _i in run.extra_opening_draw():
		state._draw_one(mine)
	state.hp[mine] = run.hp
	var foe_delta := run.foe_hp_delta() + (gate.foe_hp_bonus if gate != null else 0)
	if foe_delta != 0:
		state.hp[foe] = maxi(state.hp[foe] + foe_delta, 1)
	if gate != null:
		state.sand_drop_count = gate.sand_drop_count
		state.flip_disabled = gate.flip_disabled
		state.clash_damage_multiplier = gate.clash_damage_multiplier
		if gate.flip_rights != 0:
			state.flip_right_remaining[mine] = gate.flip_rights
			state.flip_right_remaining[foe] = gate.flip_rights
		_place(state, mine, gate.own_board_units)
		_place(state, foe, gate.foe_board_units)
	state.board_changed.emit(mine)
	state.board_changed.emit(foe)
	_boon_effects = SoloBoonEffects.new()
	_boon_effects.attach(state, mine, run)
	if gate == null:
		return
	match gate.win_condition:
		SoloGateData.WinCondition.SURVIVE_TURNS:
			state.turn_started.connect(_on_turn_started_for_survival)
		SoloGateData.WinCondition.WIN_WITHIN_TURNS:
			state.turn_started.connect(_on_turn_started_for_deadline)
		SoloGateData.WinCondition.DESTROY_ALL_ENEMY_UNITS:
			state.unit_destroyed.connect(_on_unit_destroyed_for_wipe)


## 特殊勝利条件の関門が持つ残りの数(遠征の札・結果パネル)。持たない関門・関門でないときは-1。
static func remaining_for(state: MatchState, mine: int, gate: SoloGateData) -> int:
	if gate == null or state == null:
		return -1
	match gate.win_condition:
		SoloGateData.WinCondition.SURVIVE_TURNS, SoloGateData.WinCondition.WIN_WITHIN_TURNS:
			return own_turns_left(state, gate)
		SoloGateData.WinCondition.DESTROY_ALL_ENEMY_UNITS:
			return state.units(MatchState.other_side(mine)).size()
		_:
			return -1


## 目標の手番までの自分の手番の数。`turn_count`は両者の手番を通しで数えるため半分(切り上げ)。
static func own_turns_left(state: MatchState, gate: SoloGateData) -> int:
	var turns_left := gate.survive_turns + 1 - state.turn_count
	return maxi(ceili(turns_left / 2.0), 1)


## 盤面の初期配置。`PuzzleStageData`と同じ`"id:体力:攻撃力"`の表現を読む。
func _place(state: MatchState, side: int, rows: Array[String]) -> void:
	var slots: Array = state.board[side]
	for i in mini(rows.size(), MatchState.BOARD_SIZE):
		var parsed := PuzzleStageData.parse_unit(rows[i])
		if parsed.is_empty():
			continue
		var unit := CardInstance.new(parsed["card"])
		unit.health = int(parsed["health"])
		unit.attack = int(parsed["attack"])
		unit.summoned_this_turn = false
		slots[i] = unit


## 指定ターン数を生き延びた。通常のHP0での敗北判定はそのまま生かしておく。
func _on_turn_started_for_survival(side: int) -> void:
	if _state.is_match_over() or side != _mine:
		return
	if _state.turn_count > _gate.survive_turns:
		_state.surrender(MatchState.other_side(_mine))
	progressed.emit()


## 期限の手番までに倒せなかった(速攻勝負)。期限を超えた相手の手番の始まりで自分を投了させる。
func _on_turn_started_for_deadline(side: int) -> void:
	if _state.is_match_over():
		return
	if side != _mine and _state.turn_count > _gate.survive_turns:
		_state.surrender(_mine)
	progressed.emit()


## 相手の場の砂時計をすべて破壊した(空にする)。
func _on_unit_destroyed_for_wipe(side: int, _slot: int, _card: CardData) -> void:
	if _state.is_match_over() or side == _mine:
		return
	if _state.units(side).is_empty():
		_state.surrender(side)
	progressed.emit()
