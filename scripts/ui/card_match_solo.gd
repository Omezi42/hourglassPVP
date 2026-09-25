class_name CardMatchSolo
extends RefCounted
## ソロモードの進行(GameDesign.md 27章)。
##
## パズル型は既存の`CardMatchPuzzle`(`_screen.puzzle`)をそのまま使う。ここが扱うのは
## 残り4種(CPU対戦型・特殊ルール型・連戦型・縛り型)で、いずれも「固定デッキ・上級CPU・
## 特殊ルールを適用した対局」という共通の骨格を持つ。`card_match_screen.gd`が1000行の
## 上限に近いため、`CardMatchPuzzle`と同じ`_screen`参照を持つ切り出しにしている
## (Architecture.md 4.0節・10.15節)。

signal finished(cleared: bool)

var _screen: CardMatchScreen
var _panel: CardChallengeResult
var _stage: SoloStageData = null
var _config: SoloMatchConfig = null
## 連戦型(GAUNTLET)でいま何戦目か(0始まり)。
var _gauntlet_index := 0
## 連戦型で次の対局へ持ち越すHP。-1なら未設定(初戦)。
var _carried_hp := -1
var _settled := false
var _cleared := false


func _init(screen: CardMatchScreen) -> void:
	_screen = screen
	_panel = CardChallengeResult.new()
	_panel.retry_pressed.connect(func() -> void: start(_stage))
	_panel.next_pressed.connect(func() -> void: start_any(next_stage_of(_stage)))
	_panel.quit_pressed.connect(func() -> void: finished.emit(_settled and _cleared))
	_panel.log_pressed.connect(func() -> void: _screen._log.set_open(true))
	add_result_panel(screen, _panel)


## 結果パネルを対局画面へ置く。**ログより奥に差し込む**——結果パネルの「ログ」で開いたログが
## パネルの下へ隠れないように(閉じると結果パネルへ戻る。GameDesign.md 27章)。
static func add_result_panel(screen: CardMatchScreen, panel: CardChallengeResult) -> void:
	screen.add_child(panel)
	screen.move_child(panel, screen._log.get_index())


## 種別に応じてパズル・対局を振り分けて始める(一覧から選んだときも「次のステージへ」も同じ)。
func start_any(target: SoloStageData) -> void:
	if target == null:
		return
	if target.stage_type == SoloStageData.Kind.PUZZLE:
		_screen.puzzle.start(target.puzzle, false, target)
	else:
		start(target)


## 並び順で次のステージ。まだ開いていなければ null。
static func next_stage_of(current: SoloStageData) -> SoloStageData:
	var stages := SoloLibrary.all_stages()
	var index := stages.find(current)
	if index < 0 or index + 1 >= stages.size():
		return null
	var candidate: SoloStageData = stages[index + 1]
	if not SoloLibrary.is_unlocked(candidate, StageReward.current_uid()):
		return null
	return candidate


static func eyebrow_of(target: SoloStageData) -> String:
	return "ソロモード ・ ステージ%d ・ %s" % [target.order, target.kind_label()]


## いま挑戦中か。終局の受け口が結果パネルを出し分けるのに使う。
func active() -> bool:
	return _stage != null


func stage() -> SoloStageData:
	return _stage


## 1ステージを始める(パズル型以外)。連戦型は複数戦をまたいで内部で回す。
func start(target: SoloStageData) -> void:
	if target == null or target.match_config == null:
		return
	_stage = target
	_config = target.match_config
	_gauntlet_index = 0
	_carried_hp = -1
	_settled = false
	_panel.visible = false
	_begin_battle()


func close() -> void:
	_stage = null
	_config = null
	_settled = false
	_panel.visible = false


## 相手のHPが0になった等、`MatchState.match_ended` から呼ばれる。
func on_match_ended() -> void:
	if _stage == null or _settled:
		return
	var state: MatchState = _screen.state
	var won: bool = state != null and state.winner == _screen.my_side
	if won and _stage.stage_type == SoloStageData.Kind.GAUNTLET:
		_gauntlet_index += 1
		if _gauntlet_index < _config.opponent_count:
			_carried_hp = int(state.hp[_screen.my_side])
			_begin_battle()
			return
	_settle(won)


## 対局を1戦ぶん作る。中身はCPU戦と同じ経路(`_begin_state()`)で、固定デッキ・
## 上級CPU・特殊ルールをそのあとで重ねる(GameDesign.md 27章)。
func _begin_battle() -> void:
	# **`_reset_for_new_match()` は画面の後始末として `close()` を呼び、`_stage`/`_config`
	# を消す。**先に控えて、戻してから使う(`CardMatchPuzzle` が `_begin_state()` のあとで
	# 問題を覚えているのと同じ穴。Architecture.md 10.12節)。
	var stage_kept := _stage
	var config_kept := _config
	_screen._reset_for_new_match()
	_stage = stage_kept
	_config = config_kept
	_screen._cpu = CardCpuStrategy.new()
	_screen._cpu.difficulty = CardCpuStrategy.Difficulty.EXPERT
	_screen._interactive = true
	_screen._match_kind = CurrencyRules.MatchKind.NONE
	_screen.my_side = MatchState.Side.A
	_screen.bar_for(MatchState.Side.A).display_name = AccountService.display_name()
	_screen.bar_for(MatchState.Side.A).icon_id = AccountService.icon_id()
	_screen.bar_for(MatchState.Side.A).title_id = AccountService.title_id()
	_screen.foe_bar.display_name = "CPU"
	_screen.foe_bar.icon_id = UserProfileLibrary.CPU_ICON_ID
	_screen.foe_bar.title_id = UserProfileLibrary.CPU_TITLE_ID
	_screen._set_playmats(AccountService.playmat_id(), PlaymatLibrary.CPU_ID)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_screen._begin_state(
		_deck_of(_config.player_deck_ids),
		_deck_of(_config.opponent_deck_ids),
		rng.randi_range(1, 1 << 30)
	)
	_apply_config()
	# `_begin_state()` は自分の呼び出しの中で一度 `refresh()` しているが、その後の
	# `_apply_config()` がHP・盤面を上書きするため、これが無いと差し替え後の
	# 局面(HPの上書き・連戦の持ち越し・初期配置)が次の操作まで画面へ反映されない
	# (`CardMatchPuzzle.start()` が `_apply()` の後で `refresh()` するのと同じ理由)。
	_screen.refresh()


func _deck_of(ids: Array[String]) -> Array:
	var cards: Array = []
	for id in ids:
		var card := CardLibrary.find_by_id(id)
		if card != null:
			cards.append(card)
	return cards


## 対局設定を反映する。**HP・盤面の上書きは新しいAPIを作らず、ルール画面
## (Architecture.md 4.2節)と同じ「差し替え」で行う。**
func _apply_config() -> void:
	var state: MatchState = _screen.state
	var mine: int = _screen.my_side
	var foe: int = MatchState.other_side(mine)
	state.sand_drop_count = _config.sand_drop_count
	state.flip_disabled = _config.flip_disabled
	state.clash_damage_multiplier = _config.clash_damage_multiplier
	state.mana_frozen = _config.mana_frozen
	# **凍結は「常に1のまま」を意味する**(GameDesign.md 27章)。この設定は最初の手番が
	# 始まったあとに掛かるため、まだ手番の来ていない側は最大マナ0のまま凍りつく。
	# 両者へ1を保証して、片側だけ何も出せない対局にならないようにする。
	if _config.mana_frozen:
		for target_side in [mine, foe]:
			state.max_mana[target_side] = maxi(int(state.max_mana[target_side]), 1)
			state.mana[target_side] = int(state.max_mana[target_side])
			state.mana_changed.emit(
				target_side, state.mana[target_side], state.max_mana[target_side]
			)
	if _config.hp_override > 0:
		state.hp[mine] = _config.hp_override
		state.hp[foe] = _config.hp_override
	# 連戦型(GAUNTLET)はHPだけを次の対局へ持ち越す(GameDesign.md 27章)。
	if _carried_hp >= 0:
		state.hp[mine] = _carried_hp
	_place(state, mine, _config.own_board_units)
	_place(state, foe, _config.foe_board_units)
	# **`hp_changed` は出さない。**`_screen.refresh()`(呼び出し元 `_begin_battle()`)が
	# `state.hp` を直接読んで情報帯を更新するため不要な上、`CardMatchSound`/`CardMatchLog`
	# がこの信号を「初期HP24 → 上書き後のHP」の被弾/回復として解釈し、開始直後に
	# 誤った演出とログを出す(連戦型の持ち越しでは実際のHP変化のためなおさら誤読を招く)。
	state.board_changed.emit(mine)
	state.board_changed.emit(foe)
	match _config.win_condition:
		SoloMatchConfig.WinCondition.SURVIVE_TURNS:
			state.turn_started.connect(_on_turn_started_for_survival)
		SoloMatchConfig.WinCondition.DESTROY_ALL_ENEMY_UNITS:
			state.unit_destroyed.connect(_on_unit_destroyed_for_wipe)


## 盤面の初期配置。`PuzzleStageData`と同じ`"id:体力:攻撃力"`の表現を読む。
func _place(state: MatchState, side: int, rows: Array[String]) -> void:
	if rows.is_empty():
		return
	var slots: Array = state.board[side]
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


## 指定ターン数を生き残った(GameDesign.md 27章)。**通常のHP0での敗北判定は
## そのまま生かしておく**——生き残る前に自分が倒されたら、既存の経路で普通に負ける。
func _on_turn_started_for_survival(side: int) -> void:
	var state: MatchState = _screen.state
	if state == null or state.is_match_over() or side != _screen.my_side:
		return
	if state.turn_count > _config.survive_turns:
		state.surrender(MatchState.other_side(_screen.my_side))


## 相手の場の砂時計をすべて破壊した(GameDesign.md 27章)。
func _on_unit_destroyed_for_wipe(side: int, _slot: int, _card: CardData) -> void:
	var state: MatchState = _screen.state
	if state == null or state.is_match_over() or side == _screen.my_side:
		return
	if state.units(side).is_empty():
		state.surrender(side)


func _settle(cleared: bool) -> void:
	_settled = true
	_cleared = cleared
	var reward: StageReward = null
	if cleared:
		reward = grant_stage_rewards(_stage)
	_panel.show_for(_outcome(cleared, reward))


## 結果パネルの中身(GameDesign.md 27章「結果パネル」)。負けは勝利条件までの残りを数字で出す。
func _outcome(cleared: bool, reward: StageReward) -> CardChallengeResult.Outcome:
	var outcome := CardChallengeResult.Outcome.new()
	outcome.cleared = cleared
	outcome.reward = reward
	outcome.eyebrow = eyebrow_of(_stage)
	outcome.stage_name = _stage.display_name
	outcome.show_log = true
	var state: MatchState = _screen.state
	var mine: int = _screen.my_side
	var foe: int = MatchState.other_side(mine)
	if cleared:
		if _config.opponent_count > 1:
			outcome.summary_value = _config.opponent_count
			outcome.summary_tail = "連戦を突破"
		else:
			match _config.win_condition:
				SoloMatchConfig.WinCondition.SURVIVE_TURNS:
					outcome.summary_lead = "最後まで生き延びた"
				SoloMatchConfig.WinCondition.DESTROY_ALL_ENEMY_UNITS:
					outcome.summary_lead = "相手の場を空にした"
				_:
					outcome.summary_lead = "自分のHP"
					outcome.summary_value = int(state.hp[mine])
					outcome.summary_tail = "を残して勝利"
		outcome.next_label = "次のステージへ" if next_stage_of(_stage) != null else ""
		return outcome
	var prefix := "%d戦目で倒れた ・ " % (_gauntlet_index + 1) if _config.opponent_count > 1 else ""
	match _config.win_condition:
		SoloMatchConfig.WinCondition.SURVIVE_TURNS:
			outcome.summary_lead = prefix + "生き延びるまで あと"
			outcome.summary_value = _own_turns_left(state)
			outcome.summary_tail = "手番"
		SoloMatchConfig.WinCondition.DESTROY_ALL_ENEMY_UNITS:
			outcome.summary_lead = prefix + "相手の場に あと"
			outcome.summary_value = state.units(foe).size()
			outcome.summary_tail = "体"
		_:
			outcome.summary_lead = prefix + "相手のHP あと"
			outcome.summary_value = maxi(int(state.hp[foe]), 0)
	outcome.tray_title = "ステージの条件"
	outcome.tray_text = _stage.description
	return outcome


## 生存の達成は `turn_count` が `survive_turns` を超えた自分の手番(`_on_turn_started_for_survival`)。
## `turn_count` は両者の手番を通しで数えるため、残りの手番のうち自分のものは半分(切り上げ)になる。
func _own_turns_left(state: MatchState) -> int:
	var turns_left := _config.survive_turns + 1 - state.turn_count
	return maxi(ceili(turns_left / 2.0), 1)


## ステージの報酬を渡す(初回クリアだけ。GameDesign.md 27章)。**通信は待たない**——結果の
## 表示を通信で止めない扱いは、対局の砂金(`CardMatchOutcome`)・パズルの砂金と同じ。
## **パズル型のステージも同じ経路を通す**——パズル型は進行が `CardMatchPuzzle` 側にあるが、
## 進捗を `SoloProgress` へ書かないと次のステージが永久に開かない(Architecture.md 10.15節)。
## そのため static にして両者で共有する。
static func grant_stage_rewards(target: SoloStageData) -> StageReward:
	var reward := StageReward.new()
	var uid := StageReward.current_uid()
	if not SoloProgress.mark_cleared(uid, target.id):
		reward.already_cleared = true
		return reward
	reward.grant_gold(uid, target.reward_gold)
	if not target.reward_icon_id.is_empty():
		AccountService.unlock_icon(NetSession.client, uid, target.reward_icon_id)
		reward.icon_id = target.reward_icon_id
	if not target.reward_card_set_id.is_empty():
		AccountService.unlock_card_set(NetSession.client, uid, target.reward_card_set_id)
		reward.card_set_id = target.reward_card_set_id
	return reward
