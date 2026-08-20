class_name GameBoard
## 横長のテーブル(BoardTableがコード描画)に合わせて各行・位置ラベルを絶対座標で
## 配置するため、VBoxContainerではなくControlを使う。控え表示はGameBoardの外
## (MatchScreenが直接持つHourglassSlotStrip)へ撤去済みで、ここは場の3+3マスのみを扱う。
extends Control

signal opponent_position_pressed(position: int)
signal own_position_pressed(position: int)
## 対局中の効果詳細表示(GameDesign.md 9章)用。既存の選択操作系シグナルとは独立して発火する。
signal opponent_info_requested(position: int)
signal own_info_requested(position: int)

var _state: GameState
var _self_side: GameState.PlayerSide
var _board_interactive := true
var _reject_feedback := false

@onready var opponent_row: BoardRow = $OpponentRow
@onready var own_row: BoardRow = $OwnRow
@onready var flip_reach_overlay: FlipReachOverlay = $FlipReachOverlay


func _ready() -> void:
	opponent_row.position_pressed.connect(func(p: int) -> void: opponent_position_pressed.emit(p))
	own_row.position_pressed.connect(func(p: int) -> void: own_position_pressed.emit(p))
	opponent_row.info_requested.connect(func(p: int) -> void: opponent_info_requested.emit(p))
	own_row.info_requested.connect(func(p: int) -> void: own_info_requested.emit(p))

	# テーブル面はコード描画の無地パネル(台座イラストなし)のため、駒側の自前台座光を
	# 既定(表示)のまま使う(HourglassSlotの_show_pedestalは既定でtrue)。


func show_state(state: GameState, self_side: GameState.PlayerSide) -> void:
	_state = state
	_self_side = self_side
	var opponent_side: GameState.PlayerSide = state.other_side(self_side)
	opponent_row.show_board(state.board[opponent_side])
	own_row.show_board(state.board[self_side])
	opponent_row.refresh_falling_warnings(state.board[opponent_side], true)
	own_row.refresh_falling_warnings(state.board[self_side], false)
	_apply_interactive()


## この手番に設定された行動(GameState.pending_action)を、対象マスの予約マークとして表示する
## (GameDesign.md 4.3・9章)。行動は指した瞬間には適用されず、ターン終了時の解決で初めて
## 盤面が動くため、それまでの唯一の手がかりになる。actionが空なら全マスのマークを消す。
func show_reservations(self_side: GameState.PlayerSide, action: Dictionary) -> void:
	var own: Dictionary = {}
	var opponent: Dictionary = {}
	match action.get("type", ""):
		"flip":
			var target: GameState.PlayerSide = action["side"]
			if target == self_side:
				own[action["position"]] = "flip"
			else:
				opponent[action["position"]] = "flip"
		"move":
			var bucket := own if action["side"] == self_side else opponent
			bucket[action["from"]] = "move"
			bucket[action["to"]] = "move"
		"swap_in":
			var bucket_swap := own if action["side"] == self_side else opponent
			bucket_swap[GameState.BoardPosition.LEFT] = "swap_in"
	own_row.set_reservations(own)
	opponent_row.set_reservations(opponent)


## 配置フェーズ用。相手の場は配置内容が非公開のため常に空表示にする。
func show_own_placement(placed: Array) -> void:
	own_row.show_placement(placed)
	opponent_row.show_board([])


func set_own_placement_interactive(interactive: bool) -> void:
	own_row.set_interactive(interactive)
	opponent_row.set_interactive(false)


## 選択中の駒が画面上で占める矩形を返す。アクションメニューをその駒の直下へ
## 出すために使う。該当する駒がない場合は空の矩形を返す。
func get_slot_rect(selection_type: ActionMenu.SelectionType, position: int) -> Rect2:
	var slot := _slot_at(selection_type, position)
	if slot == null:
		return Rect2()
	# 解決演出中は盤面(BoardCamera)がズームしている。get_global_rect()は親のscaleを
	# 反映しないため、変換込みの矩形を返して呼び出し側(実況テキスト・浮遊ダメージ・
	# 光の筋)がそのままズームへ追従できるようにする(フェーズ17 V-3)。
	return slot.get_global_transform() * Rect2(Vector2.ZERO, slot.size)


## side(GameState.PlayerSide)基準で駒の矩形を返す。ダメージ演出の発生源(落ちきった駒)は
## 選択操作を経由しないため、get_slot_rect()のSelectionTypeベースAPIとは別に用意する。
## self_sideは呼び出し側(MatchScreen)の現在の視点を毎回明示的に渡す。GameState.advance_and_end_turn()
## がターン経過による落ちきりダメージを同期的に発火するのは、ローカル対戦で視点が入れ替わる
## show_state()の再描画より前(current_turnは既に切り替わっている)であり、内部の_self_side
## フィールドを参照すると1手分古い視点のまま解決してしまうため。
func get_board_slot_rect(
	self_side: GameState.PlayerSide, side: GameState.PlayerSide, position: int
) -> Rect2:
	return get_slot_rect(_selection_type_for_side(self_side, side), position)


## 落ちきった駒(側・位置)を一瞬光らせ、ダメージの発生源であることを示す。
## self_sideの扱いはget_board_slot_rect()と同じ。
func flash_fall_damage(
	self_side: GameState.PlayerSide, side: GameState.PlayerSide, position: int
) -> void:
	var slot := _slot_at(_selection_type_for_side(self_side, side), position)
	if slot != null:
		slot.flash_fall_damage()


## ターン進行の逐次演出(C-1)用。指定したマスの駒だけを、記録済みのnew_stateへ
## 個別にアニメーションさせる(show_state()のような全マス一括の再描画はしない)。
## self_sideの扱いはget_board_slot_rect()と同じ。
func play_state_step(
	self_side: GameState.PlayerSide, side: GameState.PlayerSide, position: int, new_state: int
) -> void:
	if _state == null:
		return
	var slot := _slot_at(_selection_type_for_side(self_side, side), position)
	if slot == null:
		return
	var data: HourglassData = _state.board[side][position].data
	slot.show_state_step(data, new_state)
	slot.set_falling_warning(new_state == GameEnums.HourglassState.FALLING, side != self_side)


## ターン進行の逐次演出中、解決中のマスへ視線誘導する(P-2)。self_sideの扱いは
## get_board_slot_rect()と同じ。
func focus_slot(self_side: GameState.PlayerSide, side: GameState.PlayerSide, position: int) -> void:
	if side == self_side:
		own_row.apply_spotlight(position)
		opponent_row.apply_spotlight(-1)
	else:
		opponent_row.apply_spotlight(position)
		own_row.apply_spotlight(-1)


## 行動演出(フェーズ14 S-1)用。指定した側の行のうち複数マスを同時に注目させ、反対側の行は
## 暗く沈める(移動は入れ替わる2マスが対象になるため、focus_slot()とは別に用意する)。
## self_sideの扱いはget_board_slot_rect()と同じ。
func focus_slots(
	self_side: GameState.PlayerSide, side: GameState.PlayerSide, positions: Array[int]
) -> void:
	var none: Array[int] = []
	if side == self_side:
		own_row.apply_spotlight_positions(positions)
		opponent_row.apply_spotlight_positions(none)
	else:
		opponent_row.apply_spotlight_positions(positions)
		own_row.apply_spotlight_positions(none)


## 行動演出(移動/交代)用。指定したマスの駒を、offsetぶんずらした位置から定位置へ
## 滑り込ませる(フェーズ14 S-2)。self_sideの扱いはget_board_slot_rect()と同じ。
func play_slide_in(
	self_side: GameState.PlayerSide,
	side: GameState.PlayerSide,
	position: int,
	offset: Vector2,
	arc_height: float = 0.0
) -> void:
	if side == self_side:
		own_row.play_slide_in(position, offset, arc_height)
	else:
		opponent_row.play_slide_in(position, offset, arc_height)


func clear_spotlight_all() -> void:
	own_row.clear_spotlight()
	opponent_row.clear_spotlight()


## 反転(GameDesign.md 9章、T-1)。actor(行動した側)の陣地からside(駒の持ち主)/positionの
## 駒へ光の筋を伸ばす。始点は行動した側の陣地の代表点として、その側の場の中央マスの矩形を
## 使う(get_board_slot_rect()をplay_slide_in()と同じ考え方で流用する)。矩形が取得できない
## 場合は何もせずfalseを返す。self_sideの扱いはget_board_slot_rect()と同じ。
func play_flip_reach(
	self_side: GameState.PlayerSide,
	actor: GameState.PlayerSide,
	side: GameState.PlayerSide,
	position: int
) -> bool:
	var source_rect := get_board_slot_rect(self_side, actor, GameState.BoardPosition.CENTER)
	var target_rect := get_board_slot_rect(self_side, side, position)
	if source_rect.size == Vector2.ZERO or target_rect.size == Vector2.ZERO:
		return false
	flip_reach_overlay.play_reach(source_rect.get_center(), target_rect.get_center())
	return true


## 光の筋が届いた瞬間、対象の駒を持ち上げて着地させる(T-1)。self_sideの扱いは
## get_board_slot_rect()と同じ。
func play_flip_lift(
	self_side: GameState.PlayerSide, side: GameState.PlayerSide, position: int
) -> void:
	var slot := _slot_at(_selection_type_for_side(self_side, side), position)
	if slot != null:
		slot.play_flip_lift()


func _selection_type_for_side(
	self_side: GameState.PlayerSide, side: GameState.PlayerSide
) -> ActionMenu.SelectionType:
	if side == self_side:
		return ActionMenu.SelectionType.OWN_BOARD
	return ActionMenu.SelectionType.OPPONENT_BOARD


## BENCH(控え)は場に含まれないため、ここでは扱わない。控えのActionMenu位置決めは
## MatchScreenがHourglassSlotStrip.get_bench_slot_rect()を直接呼んで解決する。
func _slot_at(selection_type: ActionMenu.SelectionType, position: int) -> HourglassSlot:
	var row_slots: Array[HourglassSlot] = []
	match selection_type:
		ActionMenu.SelectionType.OPPONENT_BOARD:
			row_slots = opponent_row.slots
		ActionMenu.SelectionType.OWN_BOARD:
			row_slots = own_row.slots
		_:
			return null
	if position < 0 or position >= row_slots.size():
		return null
	return row_slots[position]


## 選択中の駒だけをハイライトする。選択なし(NONE)の場合は全解除になる。
func show_selection(selection_type: ActionMenu.SelectionType, position: int) -> void:
	opponent_row.set_selected_position(
		position if selection_type == ActionMenu.SelectionType.OPPONENT_BOARD else -1
	)
	own_row.set_selected_position(
		position if selection_type == ActionMenu.SelectionType.OWN_BOARD else -1
	)


## 移動先候補のマスを示す(自分の場のみ)。どのマスが候補かはルールに関わるため、
## 呼び出し側(MatchScreen)が判断し、GameBoardは渡された結果を表示するだけに留める。
func show_move_targets(positions: Array[int]) -> void:
	own_row.set_move_targets(positions)


func clear_move_targets() -> void:
	own_row.set_move_targets([])


## 操作できない間(相手の手番待ち・観戦・リプレイ再生中など)は盤面全体のホバー表現を止める。
## reject_feedbackは「対局中で自分の手番でない」場合のみtrueにする想定(観戦・リプレイでは
## falseのまま渡し、そもそも操作対象でないことを示す)。
func set_interactive(interactive: bool, reject_feedback: bool = false) -> void:
	_board_interactive = interactive
	_reject_feedback = reject_feedback
	_apply_interactive()


func _apply_interactive() -> void:
	own_row.set_interactive(_board_interactive, _reject_feedback)
	opponent_row.set_interactive(_board_interactive, _reject_feedback)
	_refresh_locks()


## ロック中の砂時計にロックアイコンを表示する(ロックは盤面同士でのみ発生し、控えには発生しない)。
## 相手の駒がロック中の場合、選べる行動(反転のみ)が実際には存在しないため、盤面全体の
## 操作可否とは別に個別で非活性化する(GameState.flip()がロック中は何もしないことをコードで
## 確認済み。自分の駒側は移動が引き続き行えるため、この個別非活性化の対象外とする)。
func _refresh_locks() -> void:
	if _state == null or _state.effect_resolver == null:
		return
	var opponent_side: GameState.PlayerSide = _state.other_side(_self_side)
	for position in range(GameState.BOARD_SIZE):
		var own_locked: bool = _state.effect_resolver.is_locked(_state, _self_side, position)
		var opponent_locked: bool = _state.effect_resolver.is_locked(
			_state, opponent_side, position
		)
		own_row.slots[position].set_locked(own_locked)
		opponent_row.slots[position].set_locked(opponent_locked)
		if opponent_locked:
			opponent_row.slots[position].set_interactive(false)
