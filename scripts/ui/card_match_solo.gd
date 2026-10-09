class_name CardMatchSolo
extends RefCounted
## 遠征(ソロモード)の対局(GameDesign.md 27章)。
##
## 遠征の規則(道・山札・HP・候補)は `SoloRun` に切り出してあり、ここは対局そのものを
## 既存のCPU戦の経路(`_begin_state()`)へ薄く重ねるだけを持つ(Architecture.md 10.15節)。
## `card_match_screen.gd`が1000行の上限に近いため、`CardMatchPuzzle`と同じ`_screen`参照を
## 持つ切り出しにしている(Architecture.md 4.0節)。

signal finished

var _screen: CardMatchScreen
var _panel: CardChallengeResult
var _plaque: SoloMatchPlaque
var _run: SoloRun = null
var _gate: SoloGateData = null
var _rules: SoloBattleRules = null
var _settled := false


func _init(screen: CardMatchScreen) -> void:
	_screen = screen
	_panel = CardChallengeResult.new()
	_panel.quit_pressed.connect(func() -> void: finished.emit())
	_panel.log_pressed.connect(func() -> void: _screen._log.set_open(true))
	add_result_panel(screen, _panel)
	# 遠征の札(GameDesign.md 27章)も結果パネル・ログより背面に置く(`add_result_panel`と同じ理由)。
	_plaque = SoloMatchPlaque.new(screen, self)
	screen.add_child(_plaque)
	screen.move_child(_plaque, screen._result.get_index())


## 結果パネルを対局画面へ置く。**ログより奥に差し込む**——結果パネルの「ログ」で開いたログが
## パネルの下へ隠れないように(閉じると結果パネルへ戻る。GameDesign.md 27章)。
static func add_result_panel(screen: CardMatchScreen, panel: CardChallengeResult) -> void:
	screen.add_child(panel)
	screen.move_child(panel, screen._log.get_index())


## いま挑戦中か。終局の受け口が結果パネルを出し分けるのに使う。
func active() -> bool:
	return _run != null


## いまの遠征の最大HP(恩恵「丈夫な体」で伸びる。情報帯のHPの器・GameDesign.md 27章)。
func max_hp() -> int:
	return _run.max_hp if _run != null else MatchState.INITIAL_HP


## `run.choose()` で `in_battle` を立てた行き先を始める。
func start(run: SoloRun) -> void:
	if run == null or not run.in_battle:
		return
	_run = run
	_gate = SoloGateLibrary.find_by_id(str(run.active_destination().get("gate", "")))
	_settled = false
	_panel.visible = false
	_begin_battle()
	_plaque.start(_run, _gate)
	FunnelService.reach_first_solo_battle(FunnelService.SOLO_B1_START, _run.floor)


func close() -> void:
	_run = null
	_gate = null
	_rules = null
	_settled = false
	_panel.visible = false
	_plaque.close()


## 相手のHPが0になった等、`MatchState.match_ended` から呼ばれる。
func on_match_ended() -> void:
	if _run == null or _settled:
		return
	var state: MatchState = _screen.state
	var won: bool = state != null and state.winner == _screen.my_side
	_settle(won)


## 対局を1つ作る。中身はCPU戦と同じ経路(`_begin_state()`)で、HP・関門の特殊ルールを
## `SoloBattleRules`で重ねる(GameDesign.md 27章)。
func _begin_battle() -> void:
	# **`_reset_for_new_match()` は画面の後始末として `close()` を呼び、`_run`/`_gate`
	# を消す。**先に控えて、戻してから使う(`CardMatchPuzzle`と同じ穴。Architecture.md 10.12節)。
	var run_kept := _run
	var gate_kept := _gate
	_screen._reset_for_new_match()
	_run = run_kept
	_gate = gate_kept
	_screen._cpu = CardCpuStrategy.new()
	_screen._cpu.difficulty = _run.difficulty()
	_screen._interactive = true
	_screen._match_kind = CurrencyRules.MatchKind.NONE
	_screen.my_side = MatchState.Side.A
	_screen.bar_for(MatchState.Side.A).display_name = AccountService.display_name()
	_screen.bar_for(MatchState.Side.A).icon_id = AccountService.icon_id()
	_screen.bar_for(MatchState.Side.A).title_id = AccountService.title_id()
	var dest := _run.active_destination()
	_screen.foe_bar.display_name = SoloRun.foe_name_of(dest)
	_screen.foe_bar.icon_id = UserProfileLibrary.CPU_ICON_ID
	_screen.foe_bar.title_id = UserProfileLibrary.CPU_TITLE_ID
	_screen._set_playmats(AccountService.playmat_id(), PlaymatLibrary.CPU_ID)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_screen._begin_state(
		SoloBattleRules.own_deck(_run),
		SoloBattleRules.foe_deck(_run, dest, _gate),
		rng.randi_range(1, 1 << 30),
		true
	)
	# HP・特殊ルール・恩恵は通し測定と同じ`SoloBattleRules`で当てる(Architecture.md 10.15節)。
	_rules = SoloBattleRules.new()
	_rules.progressed.connect(_plaque.refresh)
	_rules.apply(_screen.state, _screen.my_side, _run, _gate)
	_screen._cpu_ctl.begin_mulligan()
	# `_begin_state()` は自分の呼び出しの中で一度 `refresh()` しているが、その後の
	# `apply()` がHP・盤面を上書きするため、これが無いと差し替え後の
	# 局面が次の操作まで画面へ反映されない(`CardMatchPuzzle.start()`と同じ理由)。
	_screen.refresh()


func _settle(won: bool) -> void:
	_settled = true
	var state: MatchState = _screen.state
	var mine: int = _screen.my_side
	var foe: int = MatchState.other_side(mine)
	var hp_left := int(state.hp[mine])
	var foe_hp_left := int(state.hp[foe])
	var floor_played := _run.floor
	var foe_name := SoloRun.foe_name_of(_run.active_destination())
	var gate := _gate
	var uid := StageReward.current_uid()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	FunnelService.reach_first_solo_battle(_first_battle_step(won, state), floor_played)
	_run.finish_battle(won, hp_left, rng)
	if won:
		FunnelService.reach(FunnelService.SOLO_WIN)
	if _run.cleared:
		FunnelService.reach(FunnelService.SOLO_CLEAR)
	var reached := SoloProgress.record(uid, _run)
	if _run.over:
		SoloProgress.save_finished(uid, _run, "")
		SoloProgress.clear_run(uid)
	else:
		SoloProgress.save_run(uid, _run)
	var reward := _grant_rewards(uid, won, reached)
	_panel.show_for(
		_outcome(won, floor_played, gate, foe_name, hp_left, foe_hp_left, state, reward)
	)


## 砂金(対局・関門に勝つたびに20、踏破で100)と節目の限定カード・アイコンを渡す。
## **通信は待たない**——結果の表示を通信で止めない扱いは、対局の砂金と同じ。
## **複数の節目が同時に届いたときは、すべてを結果パネルの札として並べる**(4勝目の
## 「ウォード」と踏破の「揺さぶりの一手」が同時に届く場合など。GameDesign.md 27章)。
func _grant_rewards(uid: String, won: bool, reached: Array[Dictionary]) -> StageReward:
	var reward := StageReward.new()
	if won:
		var amount := SoloRun.GOLD_PER_WIN + (_run.clear_gold() if _run.cleared else 0)
		reward.grant_gold(uid, amount)
	for milestone in reached:
		var card_set_id := str(milestone.get("card_set", ""))
		if not card_set_id.is_empty():
			AccountService.unlock_card_set(NetSession.client, uid, card_set_id)
			reward.card_set_ids.append(card_set_id)
		var icon_id := str(milestone.get("icon", ""))
		if not icon_id.is_empty():
			AccountService.unlock_icon(NetSession.client, uid, icon_id)
			reward.icon_ids.append(icon_id)
	if not reward.card_set_ids.is_empty():
		reward.card_set_id = reward.card_set_ids[0]
	if not reward.icon_ids.is_empty():
		reward.icon_id = reward.icon_ids[0]
	return reward


## 結果パネルの中身(GameDesign.md 27章「結果パネル」)。
func _outcome(
	won: bool,
	floor_played: int,
	gate: SoloGateData,
	foe_name: String,
	hp_left: int,
	foe_hp_left: int,
	state: MatchState,
	reward: StageReward
) -> CardChallengeResult.Outcome:
	var outcome := CardChallengeResult.Outcome.new()
	outcome.cleared = won
	outcome.reward = reward
	outcome.show_log = true
	var kind_label := "対局"
	if floor_played == SoloRun.FLOOR_COUNT - 1:
		kind_label = "最終戦"
	elif gate != null:
		kind_label = "関門"
	var depth_lead := "深さ%d ・ " % _run.depth if _run.depth > 0 else ""
	outcome.eyebrow = "ソロモード ・ %s%d段目 ・ %s" % [depth_lead, floor_played + 1, kind_label]
	outcome.stage_name = ("%s ・ " % gate.display_name) + foe_name if gate != null else foe_name
	outcome.single_action_label = "遠征を終える" if _run.over else "道へ戻る"
	if won:
		_fill_win_summary(outcome, gate, hp_left)
		return outcome
	var foe: int = MatchState.other_side(_screen.my_side)
	if gate != null and gate.win_condition == SoloGateData.WinCondition.SURVIVE_TURNS:
		outcome.summary_lead = "生き延びるまで あと"
		outcome.summary_value = SoloBattleRules.own_turns_left(state, gate)
		outcome.summary_tail = "手番"
	elif gate != null and gate.win_condition == SoloGateData.WinCondition.DESTROY_ALL_ENEMY_UNITS:
		outcome.summary_lead = "相手の場に あと"
		outcome.summary_value = state.units(foe).size()
		outcome.summary_tail = "体"
	else:
		outcome.summary_lead = "相手のHP あと"
		outcome.summary_value = maxi(foe_hp_left, 0)
	var lines: Array[String] = []
	if gate != null:
		lines.append(gate.description)
	lines.append("%d段目まで進み、%d勝" % [floor_played + 1, _run.wins])
	outcome.tray_title = "遠征の結果"
	outcome.tray_text = "\n".join(lines)
	return outcome


func _fill_win_summary(
	outcome: CardChallengeResult.Outcome, gate: SoloGateData, hp_left: int
) -> void:
	if gate != null and gate.win_condition == SoloGateData.WinCondition.SURVIVE_TURNS:
		outcome.summary_lead = "最後まで生き延びた"
	elif gate != null and gate.win_condition == SoloGateData.WinCondition.DESTROY_ALL_ENEMY_UNITS:
		outcome.summary_lead = "相手の場を空にした"
	else:
		outcome.summary_lead = "自分のHP"
		outcome.summary_value = hp_left
		outcome.summary_tail = "を残して勝利"


## 特殊勝利条件の関門が持つ残りの数(GameDesign.md 27章「遠征の札」)。関門でない・
## 特殊勝利条件を持たない関門のときは-1。対局中の遠征の札(`SoloMatchPlaque`)から呼ぶ。
func remaining_for(gate: SoloGateData) -> int:
	return SoloBattleRules.remaining_for(_screen.state, _screen.my_side, gate)


## 通過数の1戦目の段階。プレイヤーの投了は負けではなく「途中で抜けた」に数える(GameDesign.md 22章)。
func _first_battle_step(won: bool, state: MatchState) -> String:
	if won:
		return FunnelService.SOLO_B1_WIN
	if state.end_reason == MatchState.EndReason.SURRENDER and not _rules.decided:
		return FunnelService.SOLO_B1_QUIT
	return FunnelService.SOLO_B1_LOSE
