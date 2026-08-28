class_name BattleTab
extends Control

## is_roomは成立した経路の区別(ルームマッチかランダムマッチか)。
## 砂金の獲得量が経路ごとに異なるため伝える必要がある(GameDesign.md 15章)。
signal online_match_found(match_id: String, my_side: int, opponent_uid: String, is_room: bool)
signal resume_requested(record: Dictionary)
signal stats_requested
signal replay_list_requested
signal spectate_requested(match_id: String)
signal cpu_match_requested
signal random_match_deck_requested
signal create_room_deck_requested

## 通信待ち中の「...」演出。3個目まで打ってから空に戻る(対局画面の待機表現と統一)。
const BUSY_DOTS_MAX := 3
const BUSY_DOTS_INTERVAL := 0.5

var _queue: MatchmakingQueue
var _room: RoomMatch
var _busy := false
var _busy_dots_timer: Timer
var _busy_dot_count := 0
var _status_base_text := ""
## 切断した対局へ戻る導線(GameDesign.md 11章)。`.tscn` を書き換えずに済ませるため
## コードで生成し、戻れる対局があるときだけ出す。
var _resume_button: Button
## 戦績(GameDesign.md 19章)。`.tscn` を書き換えずに済ませるためコードで生成する。
var _stats_button: Button

@onready var status_label: Label = $Margin/VBox/StatusLabel
@onready var random_match_button: Button = $Margin/VBox/MainRow/RandomMatchButton
@onready var create_room_button: Button = $Margin/VBox/MainRow/CreateRoomButton
@onready var room_code_label: Label = $Margin/VBox/RoomCodeLabel
@onready var join_code_input: LineEdit = $Margin/VBox/JoinRow/JoinCodeInput
@onready var join_room_button: Button = $Margin/VBox/JoinRow/JoinRoomButton
@onready var spectate_button: Button = $Margin/VBox/JoinRow/SpectateButton
@onready var replay_button: Button = $Margin/VBox/SecondaryRow/ReplayButton
@onready var cpu_match_button: Button = $Margin/VBox/SecondaryRow/CpuMatchButton
@onready var cancel_button: Button = $CancelButton


func _ready() -> void:
	_busy_dots_timer = Timer.new()
	_busy_dots_timer.wait_time = BUSY_DOTS_INTERVAL
	_busy_dots_timer.timeout.connect(_on_busy_dots_timeout)
	add_child(_busy_dots_timer)
	random_match_button.pressed.connect(func() -> void: random_match_deck_requested.emit())
	create_room_button.pressed.connect(func() -> void: create_room_deck_requested.emit())
	join_room_button.pressed.connect(_on_join_room_pressed)
	spectate_button.pressed.connect(_on_spectate_pressed)
	replay_button.pressed.connect(func() -> void: replay_list_requested.emit())
	cpu_match_button.pressed.connect(func() -> void: cpu_match_requested.emit())
	cancel_button.pressed.connect(_on_cancel_pressed)
	_build_resume_button()
	_build_stats_button()
	refresh()


func refresh() -> void:
	if _busy:
		return
	_refresh_resume()
	# v5.0はデッキを1つだけ持ち、未保存でも既定のデッキが返るため、常に対戦できる。
	var ready_to_battle: bool = CardDeckSave.load_deck().size() == MatchState.DECK_SIZE
	random_match_button.disabled = not ready_to_battle
	create_room_button.disabled = not ready_to_battle
	cpu_match_button.disabled = not ready_to_battle
	join_room_button.disabled = not ready_to_battle
	status_label.text = "対戦できます" if ready_to_battle else "デッキを20枚にしてください"


func _build_resume_button() -> void:
	_resume_button = CodedButton.make("前回の対局へ戻る", Vector2(300, 68))
	_resume_button.visible = false
	_resume_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_resume_button.pressed.connect(_on_resume_pressed)
	var column: Control = status_label.get_parent()
	column.add_child(_resume_button)
	column.move_child(_resume_button, 0)


func _build_stats_button() -> void:
	_stats_button = CodedButton.make("戦績", Vector2(220, 60))
	_stats_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stats_button.pressed.connect(func() -> void: stats_requested.emit())
	var column: Control = status_label.get_parent()
	column.add_child(_stats_button)


## 覚えている対局があるときだけ出す。終わっているかどうかは押した時点で確かめる
## (毎回ホームで通信すると、オフラインでも遊べるという前提を崩すため)。
func _refresh_resume() -> void:
	if _resume_button == null:
		return
	_resume_button.visible = not OnlineResume.pending().is_empty()


func _on_resume_pressed() -> void:
	var record := OnlineResume.pending()
	if record.is_empty():
		_refresh_resume()
		return
	_set_busy(true)
	_set_status("前回の対局を確認しています")
	if not await _sign_in_or_fail():
		return
	_busy = false
	_stop_busy_dots()
	resume_requested.emit(record)


## cancellable: マッチングキュー参加中・ルーム作成後の相手待ちなど、待機を中断できる操作の間だけtrueにする。
## 通信の完了を待つだけの短い処理(参加・観戦の問い合わせ等)では出さない。
func _set_busy(busy: bool, cancellable: bool = false) -> void:
	_busy = busy
	random_match_button.disabled = busy
	create_room_button.disabled = busy
	join_room_button.disabled = busy
	spectate_button.disabled = busy
	join_code_input.editable = not busy
	cancel_button.visible = busy and cancellable
	if busy:
		_busy_dot_count = 0
		_busy_dots_timer.start()
	else:
		_queue = null
		_room = null
		_stop_busy_dots()
		refresh()


## 待機中テキストの土台(base)を更新し、末尾のドットと合わせて表示し直す。
func _set_status(text: String) -> void:
	_status_base_text = text
	_refresh_status_display()


func _refresh_status_display() -> void:
	var text := _status_base_text
	if _busy:
		text += ".".repeat(_busy_dot_count)
	status_label.text = text


func _on_busy_dots_timeout() -> void:
	_busy_dot_count = (_busy_dot_count % BUSY_DOTS_MAX) + 1
	_refresh_status_display()


func _stop_busy_dots() -> void:
	_busy_dots_timer.stop()
	_busy_dot_count = 0


func _sign_in_or_fail() -> bool:
	var ok: bool = await NetSession.sign_in()
	if not ok:
		_fail("通信に失敗しました。もう一度お試しください")
	return ok


## 失敗の理由を表示して待機状態を解く。_set_busy(false)は最後にrefresh()を呼んで
## 定型文でstatus_labelを上書きするため、文言はその後に入れないと表示されない。
func _fail(message: String) -> void:
	_set_busy(false)
	status_label.text = message


## デッキ選択画面での確定後にMainから呼ばれる。ランダムマッチのキューへ参加する。
func begin_random_match() -> void:
	if _busy:
		return
	_set_busy(true, true)
	_set_status("マッチング中")
	if not await _sign_in_or_fail():
		return
	_queue = MatchmakingQueue.new(NetSession.client, NetSession.auth)
	add_child(_queue)
	_queue.matched.connect(_on_matched)
	_queue.join()


## デッキ選択画面での確定後にMainから呼ばれる。ルームを作成する。
func begin_create_room() -> void:
	if _busy:
		return
	_set_busy(true, true)
	_set_status("部屋を作成中")
	room_code_label.text = ""
	if not await _sign_in_or_fail():
		return
	_room = RoomMatch.new(NetSession.client, NetSession.auth)
	add_child(_room)
	_room.room_created.connect(_on_room_created)
	_room.matched.connect(_on_matched)
	_room.create_room()


func _on_join_room_pressed() -> void:
	if _busy:
		return
	var code := join_code_input.text.strip_edges().to_upper()
	if code == "":
		status_label.text = "ルームコードを入力してください"
		return
	_set_busy(true)
	_set_status("参加中")
	if not await _sign_in_or_fail():
		return
	_room = RoomMatch.new(NetSession.client, NetSession.auth)
	add_child(_room)
	_room.matched.connect(_on_matched)
	_room.join_failed.connect(_on_join_failed)
	_room.join_room(code)


func _on_spectate_pressed() -> void:
	if _busy:
		return
	var code := join_code_input.text.strip_edges().to_upper()
	if code == "":
		status_label.text = "ルームコードを入力してください"
		return
	_set_busy(true)
	_set_status("観戦先を確認中")
	if not await _sign_in_or_fail():
		return
	_room = RoomMatch.new(NetSession.client, NetSession.auth)
	add_child(_room)
	_room.spectate_ready.connect(_on_spectate_ready)
	_room.spectate_failed.connect(_on_spectate_failed)
	_room.spectate(code)


## マッチングキュー参加中・ルーム作成後の相手待ちを、対戦成立を待たずに取りやめる。
func _on_cancel_pressed() -> void:
	if _queue != null:
		await _queue.cancel()
	if _room != null:
		await _room.cancel()
	_set_busy(false)
	status_label.text = "キャンセルしました"


func _on_spectate_ready(match_id: String) -> void:
	_busy = false
	cancel_button.visible = false
	_stop_busy_dots()
	status_label.text = "観戦を開始します"
	spectate_requested.emit(match_id)


func _on_spectate_failed(reason: String) -> void:
	var message := "コードが見つかりません" if reason == "not_found" else "対局がまだ始まっていません"
	_fail("観戦できませんでした(%s)" % message)


func _on_room_created(code: String) -> void:
	room_code_label.text = "ルームコード: %s(相手の参加を待っています)" % code


func _on_join_failed(reason: String) -> void:
	_fail("参加に失敗しました(%s)" % _join_failure_message(reason))


func _join_failure_message(reason: String) -> String:
	match reason:
		"not_found":
			return "コードが見つかりません"
		"full":
			return "その部屋は既に埋まっています"
		"race_lost":
			return "ほぼ同時に別の人が参加しました"
		"room_create_failed":
			return "部屋を作成できませんでした"
		_:
			return reason


func _on_matched(match_id: String, opponent_uid: String) -> void:
	_busy = false
	cancel_button.visible = false
	_stop_busy_dots()
	var match_doc: Dictionary = await NetSession.client.get_document("matches/%s" % match_id)
	# 自分のuidがplayer_a/player_bのどちらとも一致しない場合、以前は黙って後手として
	# 扱っていた。双方が後手になると互いのデッキを待ち続けて対局が始まらないため、
	# ここで止めてやり直させる(マッチ成立の書き込みは原子的になったので通常は起きない)。
	var my_side: int
	if match_doc.get("player_a", "") == NetSession.auth.uid:
		my_side = MatchState.Side.A
	elif match_doc.get("player_b", "") == NetSession.auth.uid:
		my_side = MatchState.Side.B
	else:
		_fail("対戦相手との同期に失敗しました。もう一度お試しください")
		return
	status_label.text = "対戦相手が見つかりました!"
	# ランダムマッチは_queue、ルームコード対戦は_roomが成立させる
	online_match_found.emit(match_id, my_side, opponent_uid, _room != null)
