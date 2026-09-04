class_name BattleTab
extends Control

## ここで成立するのはランダムマッチだけ(ルームマッチは専用画面が持つ。
## GameDesign.md 11章)。対局種別は受け取った側が「ランダム」として扱う。
signal online_match_found(match_id: String, my_side: int, opponent_uid: String)
signal resume_requested(record: Dictionary)
signal stats_requested
signal puzzle_requested
signal mission_requested
signal replay_list_requested
signal cpu_match_requested
signal random_match_deck_requested
## ルームマッチの専用画面を開く。デッキ選択もその画面の中で行うため、
## 他の導線と違ってここでデッキ選択画面を挟まない(GameDesign.md 9章)。
signal room_match_requested

## 通信待ち中の「...」演出。3個目まで打ってから空に戻る(対局画面の待機表現と統一)。
const BUSY_DOTS_MAX := 3
const BUSY_DOTS_INTERVAL := 0.5
## 待機中の文言と、募集を知らせたことを示す丸い印との間隔。
const ANNOUNCE_BADGE_GAP := 8.0
## 印にカーソルを乗せたときだけ出す説明(GameDesign.md 11章)。
const ANNOUNCE_NOTE := "公式Discordサーバーへ「対戦相手をさがしている人がいる」と通知を送りました"

var _queue: MatchmakingQueue
var _busy := false
var _busy_dots_timer: Timer
var _busy_dot_count := 0
var _status_base_text := ""
## 切断した対局へ戻る導線(GameDesign.md 11章)。`.tscn` を書き換えずに済ませるため
## コードで生成し、戻れる対局があるときだけ出す。
var _resume_button: Button
## 戦績(GameDesign.md 19章)。`.tscn` を書き換えずに済ませるためコードで生成する。
var _stats_button: Button
var _puzzle_button: Button
var _mission_button: Button
## 募集をDiscordへ知らせられたときに、待機中の文言の横へ出す丸い印
## (GameDesign.md 11章)。`.tscn` を書き換えずに済ませるためコードで生成する。
var _announce_badge: StatusBadge

@onready var status_label: Label = $Margin/VBox/StatusLabel
@onready var random_match_button: Button = $Margin/VBox/MainRow/RandomMatchButton
@onready var room_match_button: Button = $Margin/VBox/MainRow/RoomMatchButton
@onready var replay_button: Button = $Margin/VBox/SecondaryRow/ReplayButton
@onready var cpu_match_button: Button = $Margin/VBox/SecondaryRow/CpuMatchButton
@onready var cancel_button: Button = $CancelButton


func _ready() -> void:
	_busy_dots_timer = Timer.new()
	_busy_dots_timer.wait_time = BUSY_DOTS_INTERVAL
	_busy_dots_timer.timeout.connect(_on_busy_dots_timeout)
	add_child(_busy_dots_timer)
	# **入口は `HomeTile` にする**(GameDesign.md 9章)。`.tscn` を書き換えずに済ませるため、
	# 置いてある `Button` を同じ場所・同じ大きさの札へ差し替える。
	random_match_button = _to_tile(random_match_button, "ランダムマッチ", "誰かと当たるまで待ちます", "burst", 27)
	room_match_button = _to_tile(room_match_button, "ルームマッチ", "合言葉で友達と対戦します", "shield", 27)
	replay_button = _to_tile(replay_button, "リプレイ", "", "eye", 20)
	cpu_match_button = _to_tile(cpu_match_button, "CPU戦", "", "hour", 20)
	random_match_button.pressed.connect(func() -> void: random_match_deck_requested.emit())
	room_match_button.pressed.connect(func() -> void: room_match_requested.emit())
	replay_button.pressed.connect(func() -> void: replay_list_requested.emit())
	cpu_match_button.pressed.connect(func() -> void: cpu_match_requested.emit())
	cancel_button.pressed.connect(_on_cancel_pressed)
	_build_resume_button()
	_build_stats_button()
	_build_side_buttons()
	_build_announce_badge()
	refresh()


func refresh() -> void:
	if _busy:
		return
	_refresh_resume()
	# 未保存でもプリセットの「基本」が返るため、常に対戦できる(GameDesign.md 18章)。
	var ready_to_battle: bool = CardDeckSave.selected_deck().size() == MatchState.DECK_SIZE
	random_match_button.disabled = not ready_to_battle
	room_match_button.disabled = not ready_to_battle
	cpu_match_button.disabled = not ready_to_battle
	_set_status("対戦できます" if ready_to_battle else "デッキを%d枚にしてください" % MatchState.DECK_SIZE)


func _build_resume_button() -> void:
	_resume_button = HomeTile.make("前回の対局へ戻る", "途中の対局が残っています", "hour", Vector2(320, 68), 21)
	_resume_button.visible = false
	_resume_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_resume_button.pressed.connect(_on_resume_pressed)
	var column: Control = status_label.get_parent()
	column.add_child(_resume_button)
	column.move_child(_resume_button, 0)


func _build_announce_badge() -> void:
	_announce_badge = StatusBadge.new()
	status_label.add_child(_announce_badge)


## 「戦績」はリプレイ・CPU戦と同じ「対局そのものではない導線」のため、専用の行を作らず
## 同じ行へ並べる。行を1つ増やすと、タブの高さ(下部タブに挟まれた領域)を超える。
func _build_stats_button() -> void:
	_stats_button = HomeTile.make("戦績", "", "crown", Vector2(200, 64), 20)
	_stats_button.pressed.connect(func() -> void: stats_requested.emit())
	replay_button.get_parent().add_child(_stats_button)


## `.tscn` に置いてある `Button` を、同じ場所・同じ大きさの `HomeTile` へ置き換える。
func _to_tile(
	button: Button, title: String, subtitle: String, emblem_id: String, font_size: int
) -> HomeTile:
	var parent := button.get_parent()
	var tile := HomeTile.make(title, subtitle, emblem_id, button.custom_minimum_size, font_size)
	tile.size_flags_horizontal = button.size_flags_horizontal
	tile.size_flags_vertical = button.size_flags_vertical
	parent.add_child(tile)
	parent.move_child(tile, button.get_index())
	parent.remove_child(button)
	button.queue_free()
	return tile


## リーサルパズル(GameDesign.md 24章)とデイリーミッション(同23章)も、
## 対局そのものではない導線として「戦績」と同じ行に並べる。
func _build_side_buttons() -> void:
	_puzzle_button = HomeTile.make("パズル", "", "sword", Vector2(200, 64), 20)
	_puzzle_button.pressed.connect(func() -> void: puzzle_requested.emit())
	replay_button.get_parent().add_child(_puzzle_button)
	_mission_button = HomeTile.make("ミッション", "", "halo", Vector2(200, 64), 20)
	_mission_button.pressed.connect(func() -> void: mission_requested.emit())
	replay_button.get_parent().add_child(_mission_button)


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


## cancellable: マッチングキュー参加中など、待機を中断できる操作の間だけtrueにする。
## 通信の完了を待つだけの短い処理では出さない。
func _set_busy(busy: bool, cancellable: bool = false) -> void:
	_busy = busy
	random_match_button.disabled = busy
	room_match_button.disabled = busy
	cancel_button.visible = busy and cancellable
	if busy:
		_busy_dot_count = 0
		_busy_dots_timer.start()
	else:
		_queue = null
		_stop_busy_dots()
		refresh()


## 対局から戻ってきたときに、マッチング成立時の状態(ボタンの無効化・成立の文言・
## キューのノード)を解く。**`_on_matched()` は待機を止めるだけで `_set_busy(false)` を
## 通らない**ため、これが無いとホームへ戻った後も「対戦相手が見つかりました!」のまま
## ボタンが押せない状態が残る。
func reset_after_match() -> void:
	_discard_session()
	# ボタンの再有効化・キャンセルボタンを隠す・文言の戻しは _set_busy(false) が全て行う。
	_set_busy(false)


## キューのノードを片付ける。`_set_busy(false)` は参照を外すだけで
## ノードを残していたため、対戦のたびに子が積み上がっていた。
func _discard_session() -> void:
	if is_instance_valid(_queue):
		_queue.queue_free()
	_queue = null


## 待機中テキストの土台(base)を更新し、末尾のドットと合わせて表示し直す。
## 文言を差し替えたら印は消す。印は「いま出ている文言に添えるもの」であり、
## 別の知らせへ変わった後も残っていると、何に付いた印なのか読めなくなる。
func _set_status(text: String) -> void:
	_status_base_text = text
	if _announce_badge != null:
		_announce_badge.clear_note()
	_refresh_status_display()


func _refresh_status_display() -> void:
	var text := _status_base_text
	if _busy:
		text += ".".repeat(_busy_dot_count)
	status_label.text = text
	_place_announce_badge()


## 印は文言のすぐ右へ置く。**位置は巡回ドットを含まない幅から決める**
## (ドットに合わせて動かすと0.5秒ごとに印が跳ねる)。
func _place_announce_badge() -> void:
	if _announce_badge == null:
		return
	var font := status_label.get_theme_font("font")
	var font_size := status_label.get_theme_font_size("font_size")
	if font == null:
		return
	var text := _status_base_text + ".".repeat(BUSY_DOTS_MAX)
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_announce_badge.position = Vector2(
		(status_label.size.x + text_width) * 0.5 + ANNOUNCE_BADGE_GAP,
		(status_label.size.y - StatusBadge.DIAMETER) * 0.5
	)


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
	_queue.failed.connect(_fail)
	_queue.version_mismatch.connect(_on_version_mismatch)
	_queue.announce_result.connect(_on_announce_result)
	_queue.join()


## マッチングキューの待機を、対戦成立を待たずに取りやめる。
## **キャンセルは押した瞬間に効かせ、後片付け(通信)の完了は待たない。**
## 待っていると、応答が遅い・返らない場合に「押しても何も起きない」ように見えるため。
func _on_cancel_pressed() -> void:
	var queue := _queue
	_set_busy(false)
	status_label.text = "キャンセルしました"
	if queue != null:
		await queue.cancel()
		queue.queue_free()


## 募集をDiscordへ知らせられた(GameDesign.md 11章)。**文言としては出さない。**
## 待っている人にできることは無いため、丸い印だけを添え、知りたい人がカーソルを
## 乗せたときにその説明を出す。届かなかった場合は何も出さない。
func _on_announce_result(ok: bool) -> void:
	if ok and _announce_badge != null:
		_announce_badge.show_note(ANNOUNCE_NOTE)


## 待機者はいたが全員バージョンが違った(GameDesign.md 11章)。待機自体は続けるので、
## `_fail()` ではなく待機中の文言だけを差し替える(末尾に巡回ドットが付く)。
func _on_version_mismatch(newer_exists: bool) -> void:
	if newer_exists:
		_set_status("新しい版が公開されています。再読み込みしてください")
	else:
		_set_status("古い版の相手が待っています。マッチング中")


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
	online_match_found.emit(match_id, my_side, opponent_uid)
