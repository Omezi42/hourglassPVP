class_name MatchScreen
extends Control

signal back_pressed

const CPU_THINK_SECONDS := 0.6
## 相手・CPUが設定した行動の予約マークを見せてから、ターン終了の解決演出へ移るまでの間
## (GameDesign.md 9章)。「何を設定されたか」と「その結果どうなったか」を区別させるため。
const RESERVATION_HOLD_SECONDS := 0.7
const ACTION_MENU_GAP := 8.0
const ACTION_MENU_MARGIN := 8.0
## 相手を待っている間の「...」演出。3個目まで打ってから空に戻る。

var state: GameState
## 解決演出で盤面だけをズーム/パンさせる(GameDesign.md 9章)。上下バーは対象外。
var board_camera_controller: MatchBoardCamera
var _selected_type: ActionMenu.SelectionType = ActionMenu.SelectionType.NONE
var _selected_position: int = -1
## 交代スキルの対象(控え)を選んでいる最中かどうか。
var _pending_bench_skill := false
var _is_online := false
var _online_match: OnlineMatch = null
var _my_side: GameState.PlayerSide = GameState.PlayerSide.A
var _clock: MatchClock = null
var _last_hp: Dictionary = {}
## hourglass_state_changedでFALLENになった駒を、直後に同期発火するhp_changedと対応付ける
## ためのキュー。target_side(与えたダメージの相手側) -> Array[{"side","position"}]。
## GameState.advance_slot()はFALLEN発火の直後に同期でdeal_damage()を呼ぶ実装のため、
## 1件のhp_changedに対して先頭の1件を取り出せば発生源の駒を特定できる。
var _pending_fall_source: Dictionary = {}
## 結果表示で「何手で決着したか」を出すための手数。GameStateは盤面の状態のみを扱うため、
## 手数の集計は表示側のこちらで持つ。
var _move_count := 0

var _is_cpu_match := false
## 砂金の獲得量を決める対局の種別(GameDesign.md 15章)。NONEは報酬の対象外。
var _match_kind: CurrencyRules.MatchKind = CurrencyRules.MatchKind.NONE
var _cpu_strategy: CpuStrategy = null
## CPU戦のローカルリプレイ保存(K-2)はMatchCpuReplayRecorderへ切り出している。
var _cpu_replay_recorder: MatchCpuReplayRecorder

## ターン進行の逐次演出・対局ログ・被弾演出はMatchPlacementControllerと同様に
## 専用クラスへ切り出している。
var _turn_resolver: MatchTurnResolver
var _battle_log: MatchBattleLog
var _damage_presenter: MatchDamagePresenter
var _result_presenter: MatchResultPresenter
## 実況フロート(P-3)・自分の手番バナー(P-5)も同様に切り出している。
var _event_caption: MatchEventCaption
var _turn_banner: MatchTurnBanner
## オンライン対戦の通信状態の表示・持ち時間の同期・時間切れの申告(GameDesign.md 11章)。
var _net: MatchNetController
## 行動(反転/移動/交代)そのものの演出(フェーズ14)。ターン進行の演出(_turn_resolver)と
## 対になる位置づけで、「指した手」と「その結果」を見た目の上で切り分ける。
var _action_presenter: MatchActionPresenter
var _detail_presenter: MatchDetailPresenter

## 配置フェーズの状態・操作はMatchPlacementControllerへ切り出している(責務分離)。
var _placement: MatchPlacementController

var _is_replay := false
var _is_spectate := false
## 棋譜の保持と再生制御(再生コントロールの操作・指定手数までの再現)はMatchReplayControllerへ
## 切り出している。モードフラグ(_is_replay)とHUDの出し分けはこちらに残す。
var _replay: MatchReplayController

@onready var board_area: Control = $Layout/BoardArea
@onready var board_camera: Control = $Layout/BoardArea/BoardCamera
@onready var game_board: GameBoard = $Layout/BoardArea/BoardCamera/GameBoard
@onready var action_menu: ActionMenu = $ActionMenu
@onready var top_bar_row: HBoxContainer = $Layout/TopBar/TopBarMargin/TopBarRow
@onready var bottom_bar_row: HBoxContainer = $Layout/BottomBar/BottomBarMargin/BottomRow
@onready var opponent_status: PlayerStatusBar = top_bar_row.get_node("OpponentStatus")
@onready var own_status: PlayerStatusBar = bottom_bar_row.get_node("OwnStatus")
@onready var opponent_slot_strip: HourglassSlotStrip = top_bar_row.get_node("OpponentSlotStrip")
@onready var own_slot_strip: HourglassSlotStrip = bottom_bar_row.get_node("OwnSlotStrip")
@onready var turn_label: Label = top_bar_row.get_node("TurnLabel")
@onready var damage_flash: ColorRect = $DamageFlash
@onready var result_overlay: Control = $ResultOverlay
@onready var result_panel: PanelContainer = $ResultOverlay/CenterBox/Panel
@onready var result_title: Label = $ResultOverlay/CenterBox/Panel/Margin/VBox/TitleLabel
@onready var result_detail: Label = $ResultOverlay/CenterBox/Panel/Margin/VBox/DetailLabel
@onready var result_button_row: HBoxContainer = $ResultOverlay/CenterBox/Panel/Margin/VBox/ButtonRow
@onready var result_home_button: Button = result_button_row.get_node("HomeButton")
@onready var result_log_button: Button = result_button_row.get_node("LogButton")
@onready var back_button: Button = top_bar_row.get_node("BackButton")
@onready
var match_menu_controls: HBoxContainer = bottom_bar_row.get_node("BottomMiddle/MatchMenuControls")
@onready var surrender_button: Button = match_menu_controls.get_node("SurrenderButton")
@onready var end_turn_button: Button = match_menu_controls.get_node("EndTurnButton")
@onready var detail_panel: HourglassDetailPanel = $MatchDetailPanel
@onready var detail_close_button: Button = $MatchDetailCloseButton
@onready var surrender_confirm: Control = $SurrenderConfirm
@onready var surrender_confirm_button: Button = surrender_confirm.get_node(
	"CenterBox/Panel/Margin/VBox/ButtonRow/ConfirmButton"
)
@onready var surrender_cancel_button: Button = surrender_confirm.get_node(
	"CenterBox/Panel/Margin/VBox/ButtonRow/CancelButton"
)
@onready var replay_controls: HBoxContainer = bottom_bar_row.get_node("BottomMiddle/ReplayControls")
@onready var replay_to_start_button: Button = replay_controls.get_node("ReplayToStartButton")
@onready var replay_back_button: Button = replay_controls.get_node("ReplayStepBackButton")
@onready var replay_play_button: Button = replay_controls.get_node("ReplayPlayButton")
@onready var replay_forward_button: Button = replay_controls.get_node("ReplayStepForwardButton")
@onready var replay_to_end_button: Button = replay_controls.get_node("ReplayToEndButton")
@onready var replay_step_label: Label = replay_controls.get_node("ReplayStepLabel")
@onready var replay_timer: Timer = $ReplayTimer
@onready var spectate_label: Label = top_bar_row.get_node("SpectateLabel")
@onready var wait_dots_timer: Timer = $WaitDotsTimer
@onready var log_button: Button = match_menu_controls.get_node("LogButton")
@onready var log_panel: Control = $LogPanel
@onready var log_dim: ColorRect = log_panel.get_node("Dim")
@onready var log_content: PanelContainer = log_panel.get_node("CenterBox/LogContent")
@onready
var log_close_button: Button = log_content.get_node("LogMargin/LogVBox/LogHeaderRow/LogCloseButton")
@onready var log_list: VBoxContainer = log_content.get_node("LogMargin/LogVBox/LogScroll/LogList")
@onready
var placement_controls: HBoxContainer = bottom_bar_row.get_node("BottomMiddle/PlacementControls")
@onready var placement_start_button: Button = placement_controls.get_node("PlacementStartButton")


func _ready() -> void:
	action_menu.flip_pressed.connect(_on_flip_pressed)
	action_menu.skill_pressed.connect(_on_skill_pressed)
	game_board.opponent_position_pressed.connect(_on_opponent_position_pressed)
	game_board.own_position_pressed.connect(_on_own_position_pressed)
	own_slot_strip.bench_pressed.connect(_on_own_bench_pressed)
	# 相手のスロットは参照専用(操作を受け付ける導線が存在しない)ため、ホバー表現も出さない
	opponent_slot_strip.set_interactive(false)
	action_menu.show_for_selection(ActionMenu.SelectionType.NONE)
	_apply_player_names("")
	result_overlay.visible = false
	surrender_button.visible = false
	surrender_confirm.visible = false
	detail_panel.visible = false
	detail_close_button.visible = false
	back_button.pressed.connect(_on_leave_pressed)
	result_home_button.pressed.connect(_on_leave_pressed)
	# 終局後は結果パネルの暗幕が下部のログボタンを塞ぐため、パネル側からログを開く(W-3)
	result_log_button.pressed.connect(func() -> void: _battle_log.set_open(true))
	surrender_button.pressed.connect(_on_surrender_button_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	surrender_cancel_button.pressed.connect(func() -> void: surrender_confirm.visible = false)
	surrender_confirm_button.pressed.connect(_on_surrender_confirmed)

	_placement = MatchPlacementController.new(self)
	add_child(_placement)
	_placement.setup()

	_turn_resolver = MatchTurnResolver.new(self)
	_battle_log = MatchBattleLog.new(self)
	_battle_log.setup()
	_damage_presenter = MatchDamagePresenter.new(self)
	_result_presenter = MatchResultPresenter.new(self)
	_cpu_replay_recorder = MatchCpuReplayRecorder.new(self)
	_event_caption = MatchEventCaption.new(self)
	_turn_banner = MatchTurnBanner.new(self)
	_turn_banner.setup()
	_net = MatchNetController.new(self)
	_net.setup()
	_action_presenter = MatchActionPresenter.new(self)
	_detail_presenter = MatchDetailPresenter.new(self)
	_detail_presenter.setup()
	board_camera_controller = MatchBoardCamera.new(self)
	board_area.resized.connect(func() -> void: board_camera_controller.reset(true))
	_replay = MatchReplayController.new(self)
	_replay.setup()


func start_match(
	board_a: Array[HourglassData],
	bench_a: Array[HourglassData],
	board_b: Array[HourglassData],
	bench_b: Array[HourglassData]
) -> void:
	_reset_mode(CurrencyRules.MatchKind.NONE)
	_my_side = GameState.PlayerSide.A
	back_button.visible = false
	surrender_button.visible = true
	log_button.visible = true
	end_turn_button.visible = true
	action_menu.visible = false
	replay_controls.visible = false
	spectate_label.visible = false
	_start_common(board_a, bench_a, board_b, bench_b)


## オンライン対戦用の開始。my_sideは固定の自視点(手番が変わっても表示は切り替わらない)。
func start_online_match(
	board_a: Array[HourglassData],
	bench_a: Array[HourglassData],
	board_b: Array[HourglassData],
	bench_b: Array[HourglassData],
	online_match: OnlineMatch,
	my_side: GameState.PlayerSide
) -> void:
	# 種別は配置フェーズへ入る時点で決まっているため、ここでは引き継ぐ
	_reset_mode(_match_kind)
	_is_online = true
	_online_match = online_match
	_my_side = my_side
	back_button.visible = false
	surrender_button.visible = true
	log_button.visible = true
	end_turn_button.visible = true
	action_menu.visible = false
	replay_controls.visible = false
	spectate_label.visible = false
	_online_match.action_received.connect(_on_action_received)
	_net.attach(_online_match)
	_start_common(board_a, bench_a, board_b, bench_b)


## CPU戦の開始。プレイヤーは常に先手(PlayerSide.A)、CPUは後手を担当する。
## strategyを省略した場合はSmartCpuStrategy(盤面評価と探索を行う賢いCPU)を使う。
func start_cpu_match(
	board_a: Array[HourglassData],
	bench_a: Array[HourglassData],
	board_b: Array[HourglassData],
	bench_b: Array[HourglassData],
	strategy: CpuStrategy = null
) -> void:
	_reset_mode(CurrencyRules.MatchKind.CPU)
	_is_cpu_match = true
	_my_side = GameState.PlayerSide.A
	_cpu_strategy = strategy if strategy != null else SmartCpuStrategy.new()
	_cpu_replay_recorder.begin(board_a, bench_a, board_b, bench_b)
	back_button.visible = false
	surrender_button.visible = true
	log_button.visible = true
	end_turn_button.visible = true
	action_menu.visible = false
	replay_controls.visible = false
	spectate_label.visible = false
	_start_common(board_a, bench_a, board_b, bench_b)
	_maybe_trigger_cpu_turn()


## ローカル対戦(同一端末での交互操作)の入り口。配置フェーズはMatchPlacementControllerへ
## 委譲し、確定後にstart_match()を呼び出す(引数・挙動は既存のstart_match()を変更しない)。
func start_placement_then_match(
	own_deck: Array[HourglassData],
	opponent_board: Array[HourglassData],
	opponent_bench: Array[HourglassData],
	is_first: bool
) -> void:
	_reset_mode(CurrencyRules.MatchKind.NONE)
	_placement.begin_match(own_deck, opponent_board, opponent_bench, is_first)


## CPU戦の入り口。CPUの場・控えはMainが対局開始前にランダム生成済み(GameDesign.md 13章)。
## 配置フェーズ確定後、既存のstart_cpu_match()を呼び出す。
func start_placement_then_cpu(
	own_deck: Array[HourglassData], cpu_board: Array[HourglassData], cpu_bench: Array[HourglassData]
) -> void:
	_reset_mode(CurrencyRules.MatchKind.CPU)
	_placement.begin_cpu(own_deck, cpu_board, cpu_bench)


## オンライン対戦の入り口。相手のデッキ取得・自分の配置送信・相手の配置待ちの手順は、
## MatchPlacementController側で旧DeckSelectScreenの手順をそのまま踏襲している。
## is_roomは成立した経路。ルームマッチは自分たちで繰り返せるため報酬が少ない(15章)。
func start_placement_then_online(
	own_deck: Array[HourglassData],
	match_id: String,
	my_side: GameState.PlayerSide,
	is_room: bool = false,
	opponent_uid: String = ""
) -> void:
	_reset_mode(CurrencyRules.MatchKind.ROOM if is_room else CurrencyRules.MatchKind.RANDOM)
	_placement.begin_online(own_deck, match_id, my_side)
	_apply_player_names(opponent_uid)


## 保存済みのmatches/{match_id}を読み込み、再生モードで開始する。
func start_replay(match_id: String, client: FirestoreClient) -> void:
	await _replay.start_from_firestore(match_id, client)


## LocalReplayService.get_replay()が返すCPU戦のローカルリプレイ記録を、再生モードで開始する
## (K-2)。doc/recordの形はいずれもフラットなDictionary(deck_a/deck_b/placement_a/
## placement_b/actions)で共通のため、start_replay()と同じ経路で再生できる。
func start_local_replay(record: Dictionary) -> void:
	_replay.start_from_doc(record)


## リプレイ再生モードとして対局を開始する。棋譜の読み込み・再生制御はMatchReplayControllerが
## 持ち、モードフラグとHUDの出し分けはこちらで行う(他のstart_*()と同じ並び)。
func begin_replay_mode(
	board_a: Array[HourglassData],
	bench_a: Array[HourglassData],
	board_b: Array[HourglassData],
	bench_b: Array[HourglassData]
) -> void:
	_reset_mode(CurrencyRules.MatchKind.NONE)
	_is_replay = true
	_is_spectate = false
	_is_cpu_match = false
	_my_side = GameState.PlayerSide.A
	back_button.visible = true
	surrender_button.visible = false
	log_button.visible = false
	end_turn_button.visible = false
	action_menu.visible = false
	replay_controls.visible = true
	spectate_label.visible = false
	_start_common(board_a, bench_a, board_b, bench_b)


## ルームコードから解決したmatch_idのオンライン対局を、観戦(閲覧専用)として開始する。
func start_spectate(match_id: String, client: FirestoreClient) -> void:
	var doc: Dictionary = await client.get_document("matches/%s" % match_id)
	var deck_a_ids: Array = doc.get("deck_a", [])
	var deck_b_ids: Array = doc.get("deck_b", [])
	var placement_a_ids: Array = doc.get("placement_a", [])
	var placement_b_ids: Array = doc.get("placement_b", [])
	var existing_actions: Array = doc.get("actions", [])

	var board_a := MatchReplayController.ids_to_data(placement_a_ids)
	var bench_a := MatchReplayController.ids_to_data(
		MatchReplayController.ids_minus(deck_a_ids, placement_a_ids)
	)
	var board_b := MatchReplayController.ids_to_data(placement_b_ids)
	var bench_b := MatchReplayController.ids_to_data(
		MatchReplayController.ids_minus(deck_b_ids, placement_b_ids)
	)

	_reset_mode(CurrencyRules.MatchKind.NONE)
	_is_spectate = true
	_my_side = GameState.PlayerSide.A
	back_button.visible = true
	surrender_button.visible = false
	log_button.visible = false
	end_turn_button.visible = false
	action_menu.visible = false
	replay_controls.visible = false
	spectate_label.visible = true

	_start_common(board_a, bench_a, board_b, bench_b)

	_replay.catching_up = true
	for action in existing_actions:
		OnlineMatch.apply(action, state)
		if not state.is_match_over():
			state.advance_and_end_turn()
	_replay.catching_up = false
	refresh_view()

	_online_match = OnlineMatch.new(client)
	add_child(_online_match)
	_online_match.action_received.connect(_on_action_received)
	_online_match.start(match_id, existing_actions.size())


## 各start_*の冒頭で、モードのフラグをまとめて既定(ローカル対戦)へ戻す。
## 呼び出し側は自分のモードにあたる1行だけを上書きする。
## HPバーの名前を、アカウントの表示名(GameDesign.md 14章)で置き換える。
## 未設定・取得できない場合は従来どおり「自分」「相手」のままにする。
## 相手の表示名は通信を伴うため、待っている間も既定の呼び方で成立させる。
func _apply_player_names(opponent_uid: String) -> void:
	var own_name := AccountService.display_name()
	own_status.setup(own_name if own_name != "" else "自分")
	opponent_status.setup("相手")
	if opponent_uid == "" or NetSession.client == null:
		return
	var name: String = await AccountService.fetch_display_name(NetSession.client, opponent_uid)
	if name != "":
		opponent_status.setup(name)


func _reset_mode(kind: CurrencyRules.MatchKind) -> void:
	_stop_online_match()
	_is_online = false
	_is_replay = false
	_is_spectate = false
	_is_cpu_match = false
	_match_kind = kind
	_online_match = null


func _stop_online_match() -> void:
	if _online_match != null:
		_online_match.stop()


## 戻る/ホームへ。画面を離れるときは通信を必ず止め、対局開始前の相手待ちであれば
## 中断したことを相手へ伝える(GameDesign.md 11章)。
func _on_leave_pressed() -> void:
	_stop_online_match()
	_net.reset()
	_placement.cancel_wait()
	back_pressed.emit()


func _start_common(
	board_a: Array[HourglassData],
	bench_a: Array[HourglassData],
	board_b: Array[HourglassData],
	bench_b: Array[HourglassData]
) -> void:
	state = GameState.new()
	state.effect_resolver = EffectResolver.new()
	state.hp_changed.connect(_on_hp_changed)
	state.hourglass_state_changed.connect(_on_hourglass_state_changed)
	state.resolution_step_started.connect(_on_resolution_step_started)
	state.match_ended.connect(_on_match_ended)
	result_overlay.visible = false
	_detail_presenter.hide()
	surrender_confirm.visible = false
	# 配置フェーズを抜けずに別モードへ入った場合(オンラインの配置待ちからの離脱など)、
	# 配置用のHUDが残ったまま盤面が始まってしまうため、ここで必ず対局用の表示へ戻す
	if _placement.active:
		_placement.exit()
	_move_count = 0
	_pending_fall_source.clear()
	_turn_resolver.reset()
	_action_presenter.reset()
	board_camera_controller.reset(true)
	_battle_log.reset()
	_result_presenter.reset()
	_turn_banner.reset()
	if not _is_online:
		_net.reset()
	state.start_match(board_a, bench_a, board_b, bench_b)
	_last_hp = state.hp.duplicate()

	_clock = MatchClock.new()
	_clock.time_out.connect(_on_clock_time_out)
	_clock.start_turn(state.current_turn)
	opponent_status.set_clock_visible(not _is_cpu_match and not _is_replay)
	own_status.set_clock_visible(not _is_cpu_match and not _is_replay)

	refresh_view()


func _process(delta: float) -> void:
	# 通信状態の表示と、相手の時間切れの猶予は解決演出中も進める必要があるため先に呼ぶ
	_net.process(delta)
	if (
		_is_replay
		or _is_spectate
		or _is_cpu_match
		or _turn_resolver.resolving
		or _action_presenter.presenting
		or _clock == null
		or state == null
		or state.is_match_over()
	):
		return
	_clock.tick(delta)
	_refresh_clock()


func _on_opponent_position_pressed(position: int) -> void:
	if not _can_act() or _pending_bench_skill:
		return
	_select(ActionMenu.SelectionType.OPPONENT_BOARD, position)


func _on_own_position_pressed(position: int) -> void:
	if _placement.active:
		_placement.on_board_pressed(position)
		return
	if not _can_act():
		return
	if _pending_bench_skill:
		if position == _selected_position:
			_cancel_pending_skill()
		return
	_select(ActionMenu.SelectionType.OWN_BOARD, position)


## 控えは直接選んで行動できない(GameDesign.md 9章)。交代スキルの対象選択中だけ押せる。
func _on_own_bench_pressed(index: int) -> void:
	if not _can_act() or not _pending_bench_skill:
		return
	var action := {"type": "skill", "side": state.current_turn, "position": _selected_position}
	action["bench_index"] = index
	_set_action(action)


func _on_flip_pressed() -> void:
	if _selected_type == ActionMenu.SelectionType.NONE:
		return
	var target_side: GameState.PlayerSide = state.current_turn
	if _selected_type == ActionMenu.SelectionType.OPPONENT_BOARD:
		target_side = state.other_side(state.current_turn)
	_set_action(
		{
			"type": "flip",
			"actor": state.current_turn,
			"side": target_side,
			"position": _selected_position
		}
	)


## スキルの発動(GameDesign.md 4.3)。対象を選ぶ必要があるのは交代スキルだけで、
## その場合は控え2枠をハイライトして選ばせる。それ以外はその場で行動を設定する。
func _on_skill_pressed() -> void:
	if _selected_type != ActionMenu.SelectionType.OWN_BOARD:
		return
	var skill := _selected_skill()
	if skill == null:
		return
	if not skill.needs_bench_target():
		_set_action({"type": "skill", "side": state.current_turn, "position": _selected_position})
		return
	_pending_bench_skill = true
	# 控えを選ぶ間はメニューを畳み、盤面の選択ハイライトは残しておく
	action_menu.show_for_selection(ActionMenu.SelectionType.NONE)
	action_menu.visible = false
	own_slot_strip.show_swap_targets(true)


## 交代スキルの対象選択をキャンセルし、選択直後の状態(ActionMenu表示)に戻す(O-5)。
func _cancel_pending_skill() -> void:
	_pending_bench_skill = false
	own_slot_strip.show_swap_targets(false)
	action_menu.visible = true
	action_menu.show_for_selection(
		_selected_type, _is_flip_locked(_selected_type, _selected_position), _selected_skill()
	)
	_place_action_menu(_selected_type, _selected_position)


## 選択中の自分の駒が持つスキル(無ければnull)。
func _selected_skill() -> SkillData:
	if _selected_type != ActionMenu.SelectionType.OWN_BOARD or state == null:
		return null
	if not EffectResolver.can_activate_skill(state, state.current_turn, _selected_position):
		return null
	return state.skill_at(state.current_turn, _selected_position)


func _can_act() -> bool:
	if (
		_turn_resolver.resolving
		or _action_presenter.presenting
		or _is_replay
		or _is_spectate
		or state == null
		or state.is_match_over()
	):
		return false
	if (_is_online or _is_cpu_match) and state.current_turn != _my_side:
		return false
	return true


func _select(selection_type: ActionMenu.SelectionType, position: int) -> void:
	_selected_type = selection_type
	_selected_position = position
	game_board.show_selection(selection_type, position)
	own_slot_strip.set_selected_bench_index(-1)
	own_slot_strip.show_swap_targets(false)
	game_board.clear_move_targets()
	action_menu.show_for_selection(
		selection_type, _is_flip_locked(selection_type, position), _selected_skill()
	)
	_place_action_menu(selection_type, position)


## 選択中の駒がロック中で反転できないかどうか(GameState.flip()の判定と一致させる)。
func _is_flip_locked(selection_type: ActionMenu.SelectionType, position: int) -> bool:
	if state.effect_resolver == null:
		return false
	match selection_type:
		ActionMenu.SelectionType.OWN_BOARD:
			return state.effect_resolver.is_locked(state, state.current_turn, position)
		ActionMenu.SelectionType.OPPONENT_BOARD:
			return state.effect_resolver.is_locked(
				state, state.other_side(state.current_turn), position
			)
		_:
			return false


## アクションメニューを、選択した駒の近くに中央揃えで置く。画面外へはみ出す場合は画面内に
## 収まるよう寄せる。控え(BENCH)はHourglassSlotStrip側から矩形を取得する。自分の場・控えは
## 画面下寄りにあるためメニューは選択駒の上に出す(下に出すと画面外へはみ出すため)。
func _place_action_menu(selection_type: ActionMenu.SelectionType, position: int) -> void:
	if not action_menu.visible:
		return
	var slot_rect := (
		own_slot_strip.get_bench_slot_rect(position)
		if selection_type == ActionMenu.SelectionType.BENCH
		else game_board.get_slot_rect(selection_type, position)
	)
	if slot_rect.size == Vector2.ZERO:
		action_menu.visible = false
		return

	var menu_size := action_menu.get_combined_minimum_size()
	var show_above := (
		selection_type == ActionMenu.SelectionType.OWN_BOARD
		or selection_type == ActionMenu.SelectionType.BENCH
	)
	var target_y: float
	if show_above:
		target_y = slot_rect.position.y - ACTION_MENU_GAP - menu_size.y
	else:
		target_y = slot_rect.end.y + ACTION_MENU_GAP
	var target := Vector2(slot_rect.position.x + (slot_rect.size.x - menu_size.x) * 0.5, target_y)
	target.x = clampf(target.x, ACTION_MENU_MARGIN, size.x - menu_size.x - ACTION_MENU_MARGIN)
	target.y = clampf(target.y, ACTION_MENU_MARGIN, size.y - menu_size.y - ACTION_MENU_MARGIN)
	action_menu.global_position = target


## この手番の行動を設定する(GameDesign.md 4.3)。盤面はまだ動かず、対象マスに予約マークが
## 付くだけで、実際の適用は「ターン終了」を押したときの解決で行われる。押す前なら何度でも
## 設定し直せるため、ここでは送信・記録も行わない(送信は_on_end_turn_pressed()に集約する)。
func _set_action(action: Dictionary) -> void:
	state.set_pending_action(action)
	_clear_selection()
	refresh_view()


## 手番を終える。設定済みの行動(未設定ならパス)を相手・CPUリプレイへ送ったうえで、
## ターン終了時の解決(GameDesign.md 4.4)へ進む。
func _on_end_turn_pressed() -> void:
	if not _can_act():
		return
	var action: Dictionary = state.pending_action.duplicate(true)
	if action.is_empty():
		action = {"type": "pass", "side": state.current_turn}
	_clear_selection()
	if _is_online:
		# 送信の完了は待たない。数秒の通信で盤面を止めると指した手応えが失われるため、
		# 届かなかった場合はMatchNetControllerが「接続できません」を出す(GameDesign.md 11章)。
		_online_match.send_and_apply(_net.stamp(action), state)
	else:
		OnlineMatch.apply(action, state)
	if _is_cpu_match:
		_cpu_replay_recorder.record_action(action)
	_battle_log.record_action(state, action)
	refresh_view()
	_advance_turn_and_refresh()


## 相手(オンライン)の手を受け取る。届いた時点では盤面は動かず行動が設定されるだけなので、
## まず予約マークだけを見せて短い間を置き、それからターン終了の解決演出へ進む。これにより
## 待っている側でも「相手が何を設定したか」→「その結果どうなったか」の順で追える。
func _on_action_received(action: Dictionary) -> void:
	_net.apply_incoming(action)
	# 投了・持ち時間切れは盤面を変えずに即終局するため、予約・演出・ターン交代のいずれも
	# 行わない(T-3、およびフェーズ26の時間切れの申告)。
	if action.get("type", "") in ["surrender", "timeout"]:
		_move_count += 1
		_battle_log.record_action(state, action)
		OnlineMatch.apply(action, state)
		return
	OnlineMatch.apply(action, state)
	_battle_log.record_action(state, action)
	refresh_view()
	if not _replay.catching_up:
		await get_tree().create_timer(RESERVATION_HOLD_SECONDS).timeout
	_advance_turn_and_refresh()


func _clear_selection() -> void:
	_selected_type = ActionMenu.SelectionType.NONE
	_selected_position = -1
	_pending_bench_skill = false
	action_menu.show_for_selection(ActionMenu.SelectionType.NONE)
	game_board.show_selection(ActionMenu.SelectionType.NONE, -1)
	own_slot_strip.set_selected_bench_index(-1)
	own_slot_strip.show_swap_targets(false)
	game_board.clear_move_targets()


## ターン交代を反映する。advance_and_end_turn()中のイベントは_turn_resolverへ積み、
## MatchTurnResolver.play()が間隔を空けて再生する(GameDesign.md 9章)。ターン進行より前に
## 一度refresh_view()を挟み、直前の直接操作(反転/移動/交代)による見た目の変化を演出の
## 開始前に即座に反映する(O-6: これが無いと反転の見た目が演出完了まで遅延して見える)。
func _advance_turn_and_refresh() -> void:
	_move_count += 1
	if state.is_match_over():
		refresh_view()
		_maybe_trigger_cpu_turn()
		return

	refresh_view()
	_turn_resolver.begin_capture(state.pending_action.duplicate(true))
	state.advance_and_end_turn()
	_turn_resolver.end_capture()
	_refresh_turn_label()

	if not _turn_resolver.has_events():
		_turn_resolver.clear()
		if not state.is_match_over():
			_clock.finish_turn(state.current_turn)
		refresh_view()
		_result_presenter.flush_pending()
		_maybe_trigger_cpu_turn()
		return

	game_board.set_interactive(false, _should_show_reject_feedback())
	own_slot_strip.set_interactive(false, _should_show_reject_feedback())
	_turn_resolver.play()


## 演出再生後の後始末。持ち時間を再開し、盤面を同期し、CPUの手番なら着手させる。
func on_turn_resolution_finished() -> void:
	if not state.is_match_over():
		_clock.finish_turn(state.current_turn)
	refresh_view()
	_result_presenter.flush_pending()
	_maybe_trigger_cpu_turn()


## HPバーの値・色のみを更新する(浮遊ダメージ・被弾演出は呼び出し側が個別に扱う)。
func apply_hp_bar(side: GameState.PlayerSide, hp: int, animate: bool) -> void:
	if side == perspective_side():
		own_status.show_hp(hp, animate)
	else:
		opponent_status.show_hp(hp, animate)


## CPUの手番であれば、思考時間分だけ待ってから合法手を1つ選んで着手する。
func _maybe_trigger_cpu_turn() -> void:
	if not _is_cpu_match or state.is_match_over():
		return
	if state.current_turn == _my_side:
		return
	await get_tree().create_timer(CPU_THINK_SECONDS).timeout
	if state == null or state.is_match_over() or state.current_turn == _my_side:
		return
	var cpu_side: GameState.PlayerSide = state.other_side(_my_side)
	var action: Dictionary = _cpu_strategy.choose_action(state, cpu_side)
	OnlineMatch.apply(action, state)
	_cpu_replay_recorder.record_action(action)
	_battle_log.record_action(state, action)
	refresh_view()
	await get_tree().create_timer(RESERVATION_HOLD_SECONDS).timeout
	if state == null or state.is_match_over():
		return
	_advance_turn_and_refresh()


## ターン終了時の解決で、1マス分の解決が始まる区切り(GameDesign.md 4.4)。
## MatchTurnResolverがこれを区切りとして、どのマスへズームし何を見せるかを組み立てる。
func _on_resolution_step_started(
	side: GameState.PlayerSide, positions: Array, step_kind: String
) -> void:
	_turn_resolver.push_step_event(side, positions, step_kind)


## 反転/移動/交代の手応え音。行動が実際に適用される解決のタイミング(MatchTurnResolver)から
## 呼ぶことで、音と見た目が一致する。リプレイの巻き戻し・観戦の追いつきでは鳴らさない。
func play_action_sound(action: Dictionary) -> void:
	if _replay.catching_up:
		return
	match action.get("type", ""):
		"flip":
			SoundBank.play(SoundBank.Sfx.FLIP)
		"move":
			SoundBank.play(SoundBank.Sfx.MOVE)
		"swap_in":
			SoundBank.play(SoundBank.Sfx.SWAP)
		"skill":
			var skill := state.skill_at(action["side"], action["position"])
			var bench := skill != null and skill.needs_bench_target()
			SoundBank.play(SoundBank.Sfx.SWAP if bench else SoundBank.Sfx.MOVE)


## 駒が落ちきった(FALLENに到達した)瞬間を記録する。GameState.advance_slot()はこの発火の
## 直後、同期的にdeal_damage()経由でhp_changedを発火するため、_on_hp_changed側でキューの
## 先頭を1件取り出せば「どの駒が原因か」対応付けられる(対応しない場合はフォールバックする)。
func _on_hourglass_state_changed(side: GameState.PlayerSide, position: int, new_state: int) -> void:
	if new_state == GameEnums.HourglassState.FALLEN:
		var target_side: GameState.PlayerSide = state.other_side(side)
		if not _pending_fall_source.has(target_side):
			_pending_fall_source[target_side] = []
		_pending_fall_source[target_side].append({"side": side, "position": position})

	# ターン進行中(advance_and_end_turn()呼び出し中)は即座に反映せず_turn_resolverへ積む。
	# 反転/移動/交代の直接操作による状態変化は、既存どおりshow_state()で即時反映する。
	_turn_resolver.push_state_event(side, position, new_state)


## targetが受けたダメージの発生源(落ちきった駒)をキューから取り出す。対応する記録が
## ない場合はnullを返し、呼び出し側はHPバー付近からのフォールバック演出にする。
func _pop_fall_source(target_side: GameState.PlayerSide) -> Variant:
	var queue: Array = _pending_fall_source.get(target_side, [])
	if queue.is_empty():
		return null
	return queue.pop_front()


func _on_hp_changed(side: GameState.PlayerSide, new_hp: int) -> void:
	var previous_hp: int = _last_hp.get(side, new_hp)
	_last_hp[side] = new_hp
	if _turn_resolver.is_capturing():
		var source: Variant = null
		if new_hp < previous_hp:
			source = _pop_fall_source(side)
		_result_presenter.note_hp_change(side, previous_hp, new_hp, source)
		_turn_resolver.push_hp_event(side, new_hp, previous_hp, source)
		return
	if new_hp < previous_hp and not _replay.catching_up:
		var source: Variant = _pop_fall_source(side)
		_result_presenter.note_hp_change(side, previous_hp, new_hp, source)
		_damage_presenter.spawn_floating_damage(side, previous_hp - new_hp, source)
		_damage_presenter.play_damage_feedback(side)
		if source != null:
			game_board.flash_fall_damage(perspective_side(), source["side"], source["position"])
	_refresh_hud()


## リプレイの1コマを再現するために、GameStateを初期配置から作り直す。GameStateは巻き戻し
## 操作を持たないため、MatchReplayControllerは手を戻すたびにここから作り直して目的の手数まで
## 再適用する。再生中に何度も呼ばれるため、_start_common()と違いモード判定・持ち時間・
## 各演出クラスのリセットには触れない。
func reset_state_for_replay(
	board_a: Array[HourglassData],
	bench_a: Array[HourglassData],
	board_b: Array[HourglassData],
	bench_b: Array[HourglassData]
) -> void:
	state = GameState.new()
	state.effect_resolver = EffectResolver.new()
	state.hp_changed.connect(_on_hp_changed)
	state.hourglass_state_changed.connect(_on_hourglass_state_changed)
	state.resolution_step_started.connect(_on_resolution_step_started)
	state.match_ended.connect(_on_match_ended)
	result_overlay.visible = false
	_pending_fall_source.clear()
	state.start_match(board_a, bench_a, board_b, bench_b)
	_last_hp = state.hp.duplicate()


## 持ち時間が0になったとき。オンライン対戦は「切れた本人が申告する/相手の申告が来ない
## 場合は猶予を置いてから終局させる」という扱いのため、MatchNetControllerが引き受ける。
func _on_clock_time_out(side: GameState.PlayerSide) -> void:
	if _net.handle_timeout(side):
		return
	state.force_match_end(state.other_side(side))


func _on_match_ended(winner: GameState.PlayerSide) -> void:
	_clock.stop()
	_refresh_turn_label()
	surrender_button.visible = false
	end_turn_button.visible = false
	surrender_confirm.visible = false
	if _is_online and not _is_replay:
		var winner_str := "a" if winner == GameState.PlayerSide.A else "b"
		ReplayService.mark_finished(
			_online_match.client, _online_match.match_id, winner_str, NetSession.auth.uid
		)
	if _is_cpu_match and not _is_replay:
		_cpu_replay_recorder.save_finished(winner)
	# 終局したらポーリングを止める(以前は次の対局を始めるまでFirestoreを読み続けていた)
	_stop_online_match()
	_net.reset()
	# リプレイの巻き戻し・観戦の追いつき中は一気に手が再現されるため、決着音は鳴らさない
	if not _replay.catching_up:
		SoundBank.play(_result_jingle(winner))
	# リプレイ再生中は手を自由に前後できることが目的のため、結果パネルで操作を塞がない
	if _is_replay:
		return
	# 結果画面ではBGMを止める。数分あるクラシックの曲は冒頭しか聞かれず、
	# 短いジングルへ譲ったほうが決着が伝わるため(GameDesign.md 9章)。
	MusicPlayer.stop()
	# 決着した手番の解決演出がまだ残っている場合は、最後まで見せ切ってから結果を出す(W-2)。
	# 表示はMatchResultPresenter.flush_pending()が演出の完了後に行う。
	if _turn_resolver.is_capturing() or _turn_resolver.resolving:
		_result_presenter.hold_result(winner)
		return
	_show_result(winner)


## 決着ジングルを勝敗で鳴り分ける。同一端末で交互に操作するローカル対戦と観戦は
## 「自分」が定まらないため、決着そのものを示す勝利側のジングルを鳴らす。
func _result_jingle(winner: GameState.PlayerSide) -> SoundBank.Sfx:
	if is_self_view_fixed():
		return SoundBank.Sfx.RESULT_WIN if winner == _my_side else SoundBank.Sfx.RESULT_LOSE
	return SoundBank.Sfx.RESULT_WIN


## 勝敗テキストの組み立てと結果パネルの表示はMatchResultPresenterが持つ。決め手の1行(W-3)が
## 加わり、視点の書き分けと合わせて結果表示の判断がそちらへ寄ったため。
func _show_result(winner: GameState.PlayerSide) -> void:
	_result_presenter.show_for(winner)


## リプレイの巻き戻し・観戦の追いつきで手を一気に再現している最中かどうか。この間は
## 1手ごとの演出を出さない(MatchActionPresenterが参照する)。
func is_catching_up() -> bool:
	return _replay.catching_up


## 自視点が固定される対局(オンライン/CPU戦)かどうか。同一端末で交互に操作するローカル対戦と
## 観戦は「自分」が定まらないため、勝敗・決め手・決着ジングルを先手/後手の視点で扱う。
func is_self_view_fixed() -> bool:
	return _is_online or _is_cpu_match


## 自視点が固定される対局における「自分」の側。
func self_side() -> GameState.PlayerSide:
	return _my_side


## その対局の総手数(結果パネルの表示用)。
func move_count() -> int:
	return _move_count


func perspective_side() -> GameState.PlayerSide:
	return _my_side if (_is_online or _is_spectate or _is_cpu_match) else state.current_turn


func refresh_view() -> void:
	var self_side := perspective_side()
	var opponent_side: GameState.PlayerSide = state.other_side(self_side)
	game_board.show_state(state, self_side)
	game_board.show_reservations(self_side, state.pending_action)
	game_board.set_interactive(_can_act(), _should_show_reject_feedback())
	opponent_slot_strip.show_state(state.board[opponent_side], state.bench[opponent_side])
	own_slot_strip.show_state(state.board[self_side], state.bench[self_side])
	own_slot_strip.set_interactive(_can_act(), _should_show_reject_feedback())
	end_turn_button.disabled = not _can_act()
	_refresh_hud()
	_refresh_turn_label()


## 「今は押せない」揺れ演出を出してよいかどうか。対局中(観戦・リプレイではない)に限る。
## ローカル対戦(自視点が固定されない)は_can_act()が常にtrueのため、この演出は
## オンライン対戦・CPU戦で相手の手番になっている間だけ実際に発生する。
func _should_show_reject_feedback() -> bool:
	return not (_is_replay or _is_spectate) and state != null and not state.is_match_over()


func _refresh_hud() -> void:
	var self_side := perspective_side()
	# リプレイの手戻し中はHPが飛び飛びに変わるため、バーのアニメーションは止める
	var animate := not _replay.catching_up
	opponent_status.show_hp(state.hp[state.other_side(self_side)], animate)
	own_status.show_hp(state.hp[self_side], animate)
	_refresh_clock()


func _refresh_clock() -> void:
	var self_side := perspective_side()
	opponent_status.show_clock(_clock.get_remaining(state.other_side(self_side)))
	own_status.show_clock(_clock.get_remaining(self_side))


## 手番表示(テキスト・巡回ドット・バナー)はMatchTurnBannerがまとめて持つ。
func _refresh_turn_label() -> void:
	var self_locked := is_self_view_fixed()
	_turn_banner.refresh_label(
		self_locked, not self_locked or state.current_turn == _my_side, state.is_match_over()
	)


## 詳細パネルを開いたまま盤面の駒以外(背景・マス間の余白等)をクリックした場合に自動で閉じる(N-2)。
## 駒や閉じるボタン自体のクリックは各Controlの_gui_inputで消費されここへは届かないため競合しない。
## 交代スキルの対象選択中はEscキー、または同様に何も無い場所のクリックでキャンセルできる(O-5)。
func _unhandled_input(event: InputEvent) -> void:
	if _pending_bench_skill and event.is_action_pressed("ui_cancel"):
		_cancel_pending_skill()
		get_viewport().set_input_as_handled()
		return
	if not detail_panel.visible and not _pending_bench_skill:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if detail_panel.visible:
			_detail_presenter.hide()
		if _pending_bench_skill:
			_cancel_pending_skill()


## 投了ボタン。誤操作防止のため確認ダイアログ(SurrenderConfirm)を挟む(GameDesign.md 3章)。
func _on_surrender_button_pressed() -> void:
	if state == null or state.is_match_over():
		return
	surrender_confirm.visible = true


## 投了を指し手と同じactions配列の1件として扱う(GameDesign.md 3章・Architecture.md 6章)。
## オンラインはOnlineMatch.send_and_apply()経由で送信、ローカル/CPU戦はローカルのGameStateへ
## 適用する。記録はapply()が同期的にmatch_endedを発火させるより前に済ませる必要があるため先に
## 行う。盤面を変えず即終局する点が反転/移動/交代と異なるため、演出とターン交代は呼ばない。
func _on_surrender_confirmed() -> void:
	surrender_confirm.visible = false
	if state == null or state.is_match_over():
		return
	var action := {"type": "surrender", "side": perspective_side()}
	_move_count += 1
	if _is_cpu_match:
		_cpu_replay_recorder.record_action(action)
	_battle_log.record_action(state, action)
	if _is_online:
		await _online_match.send_and_apply(action, state)
	else:
		OnlineMatch.apply(action, state)
