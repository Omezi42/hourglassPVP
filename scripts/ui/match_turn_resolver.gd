class_name MatchTurnResolver
extends RefCounted
## ターン終了時の解決演出(GameDesign.md 4.4・9章)。state.advance_and_end_turn()の呼び出し中に
## 発火するresolution_step_started/hourglass_state_changed/hp_changedを即座に反映せず、まず
## キューへ積む。積み終えたらplay()が、GameStateが実際に処理した順(左のマス→中央→右→
## 相手への反転)のまま1件ずつ間隔を空けて再生する。GameState自体の処理順序・タイミングは
## 変更しない。MatchPlacementControllerと同様、MatchScreenの責務を分離するために切り出している。

## 状態変化・ダメージ1件あたりの間。
const STEP_DELAY := 0.55
## ズームが寄りきってから中身を見せ始めるまでの間。
const ZOOM_SETTLE := 0.3
## 何も起きないマス(既に落ちきり)をズームしたまま見せる時間。「何も起きなかったこと」自体を
## 見せるため、進行するマスと同様に必ず区切りを取る(GameDesign.md 9章)。
const IDLE_HOLD := 0.4
## 反転/移動/交代を見せてから次のマスへ移るまでの間。
const ACTION_HOLD := 0.6

var resolving := false

var _screen: MatchScreen
var _capturing := false
var _queue: Array[Dictionary] = []
## 解決対象の行動(GameState.pending_action)。ステップ再生時に反転/移動/交代の見た目を
## 組み立てるため、キャプチャ開始時にMatchScreenから受け取っておく。
var _action: Dictionary = {}
## 反転のステップは行動の実況(「…を反転」)と状態変化の実況(「…が上向きへ進行」)が
## 同時に出て重なって読めなくなるため、直後の状態変化1件分だけ実況を抑制する。
## 反転させたこと自体は行動の実況が伝えており、ログには両方とも従来どおり残る。
var _suppress_state_caption := false


func _init(screen: MatchScreen) -> void:
	_screen = screen


func reset() -> void:
	_capturing = false
	resolving = false
	_queue.clear()
	_action = {}
	_suppress_state_caption = false


func begin_capture(action: Dictionary = {}) -> void:
	_queue.clear()
	_action = action
	_capturing = true


func end_capture() -> void:
	_capturing = false


func is_capturing() -> bool:
	return _capturing


func has_events() -> bool:
	return not _queue.is_empty()


func clear() -> void:
	_queue.clear()


## 1マス分の解決の区切り(GameState.resolution_step_started)。以降に積まれる状態変化・
## ダメージは、この区切りが指すマスの結果として扱う。
func push_step_event(side: int, positions: Array, step_kind: String) -> void:
	if not _capturing:
		return
	var typed: Array[int] = []
	for position in positions:
		typed.append(position)
	_queue.append({"kind": "step", "side": side, "positions": typed, "step_kind": step_kind})


func push_state_event(side: int, position: int, new_state: int) -> void:
	if not _capturing:
		return
	_queue.append({"kind": "state", "side": side, "position": position, "new_state": new_state})


func push_hp_event(side: int, new_hp: int, previous_hp: int, source: Variant) -> void:
	if not _capturing:
		return
	_queue.append(
		{"kind": "hp", "side": side, "new_hp": new_hp, "previous_hp": previous_hp, "source": source}
	)


## 演出中はresolving=trueとなり、MatchScreen側(_can_act()/_process())が盤面操作・
## 持ち時間の消費を止める。完了後の後始末(持ち時間の再開・全体再描画・CPU着手)は
## MatchScreen.on_turn_resolution_finished()へ委譲する。
func play() -> void:
	var events := _queue.duplicate()
	_queue.clear()
	resolving = true
	for event in events:
		if event["kind"] == "step":
			await _play_step(event)
			continue
		_apply(event)
		# HPを0にしたダメージが出た時点で打ち切る。決着した瞬間より後のマスの解決は勝敗に
		# 影響しないため演出せず、原因の駒を照らしたまま「決着」を見せてから結果パネルへ
		# 移る(GameDesign.md 3章、フェーズ18 W-2)。
		if event["kind"] == "hp" and event["new_hp"] <= 0:
			await _screen._result_presenter.play_finishing_blow()
			resolving = false
			_action = {}
			_screen.on_turn_resolution_finished()
			return
		await _screen.get_tree().create_timer(STEP_DELAY).timeout
	_screen.board_camera_controller.reset()
	await _screen.get_tree().create_timer(MatchBoardCamera.RESET_DURATION).timeout
	_screen.game_board.clear_spotlight_all()
	resolving = false
	_action = {}
	_screen.on_turn_resolution_finished()


## 1マス分の解決。対象マスへズームとスポットライトを当ててから、そのマスで起きることを見せる。
## 進行するマス("advance")は続けて積まれている状態変化イベントが本体になるため、ここでは
## 寄せるだけで待たずに次のイベントへ進む。
func _play_step(event: Dictionary) -> void:
	var side: int = event["side"]
	var positions: Array[int] = event["positions"]
	_screen.game_board.focus_slots(_screen.perspective_side(), side, positions)
	_screen.board_camera_controller.focus(_slot_rects(side, positions))
	await _screen.get_tree().create_timer(ZOOM_SETTLE).timeout
	match event["step_kind"]:
		"flip":
			# 反転だけは間を置かずに次のイベント(状態変化=アイコンの回転)へ進む。
			# 駒が持ち上がっている最中に回転が始まり、着地までが一続きの動きになる。
			_screen.play_action_sound(_action)
			_suppress_state_caption = true
			_screen.game_board.clear_reservations()
			await _screen._action_presenter.play_step(_action)
		"move", "swap_in":
			_screen.play_action_sound(_action)
			_screen.game_board.clear_reservations()
			await _screen._action_presenter.play_step(_action)
			await _screen.get_tree().create_timer(ACTION_HOLD).timeout
		"idle":
			_screen._event_caption.show_idle_step(_screen.state, side, positions[0])
			await _screen.get_tree().create_timer(IDLE_HOLD).timeout


func _slot_rects(side: int, positions: Array[int]) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for position in positions:
		var rect := _screen.game_board.get_board_slot_rect(
			_screen.perspective_side(), side, position
		)
		if rect.size != Vector2.ZERO:
			rects.append(rect)
	return rects


func _apply(event: Dictionary) -> void:
	match event["kind"]:
		"state":
			_screen.game_board.play_state_step(
				_screen.perspective_side(), event["side"], event["position"], event["new_state"]
			)
			_screen._battle_log.record_state_event(_screen.state, event)
			if _suppress_state_caption:
				_suppress_state_caption = false
			else:
				_screen._event_caption.show_state_event(_screen.state, event)
		"hp":
			var amount: int = event["previous_hp"] - event["new_hp"]
			if amount > 0:
				var source: Variant = event["source"]
				_screen._damage_presenter.spawn_floating_damage(event["side"], amount, source)
				_screen._damage_presenter.play_damage_feedback(event["side"])
				if source != null:
					_screen.game_board.flash_fall_damage(
						_screen.perspective_side(), source["side"], source["position"]
					)
				_screen._battle_log.record_damage_event(event["side"], amount, event["new_hp"])
				_screen._event_caption.show_damage_event(
					event["side"], amount, event["new_hp"], source
				)
			_screen.apply_hp_bar(event["side"], event["new_hp"], true)
