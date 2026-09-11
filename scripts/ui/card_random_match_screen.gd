class_name CardRandomMatchScreen
extends Control
## ランダムマッチの専用画面(GameDesign.md 11章)。デッキ選択画面でデッキを確定した直後に
## 開き、マッチングキューへの参加からマッチ成立までをここで完結させる。
##
## 以前は `BattleTab` の「だれかと」の枠の見出し行に待機中の文言・巡回ドット・キャンセル・
## 募集通知の印を重ねており、たたかうタブが「入口」と「待機画面」を兼ねていた。
## `MatchmakingQueue` を持つのはこの画面であり、`BattleTab` からはキューへ参加する
## コードをすべて外した(ルームマッチが `CardRoomScreen` へ `RoomMatch` を持たせたのと同じ形)。

signal back_pressed
## 対戦が成立した。`Main._on_online_match_found()` がそのまま受け取れる形にしてある。
signal matched(match_id: String, my_side: int, opponent_uid: String)

const HEADER_SCENE := "res://scenes/screen_header.tscn"
## 通信待ち中の「...」演出。他の待機画面と同じ間隔・同じ打ち方に揃える。
const BUSY_DOTS_MAX := EmptyState.DOTS_MAX
## 印にカーソルを乗せたときだけ出す説明(GameDesign.md 11章)。
const ANNOUNCE_NOTE := "公式Discordサーバーへ「対戦相手をさがしている人がいる」と通知を送りました"
## 印は待機中の文言のすぐ右へ置く(GameDesign.md 11章)。
const ANNOUNCE_BADGE_GAP := 10.0
const CANCEL_SIZE := Vector2(220, 64)
## 文言の行とキャンセルボタンの間隔。
const CANCEL_GAP := 40.0

var _queue: MatchmakingQueue
var _busy := false
var _status_base_text := ""
var _content_rect: Rect2
var _empty_state: EmptyState
var _announce_badge: StatusBadge
var _cancel_button: Button


func _ready() -> void:
	_build()


func _build() -> void:
	var backdrop := ScreenBackdrop.new()
	backdrop.room = ScreenBackdrop.Room.HALL
	add_child(backdrop)
	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	header.set_title("ランダムマッチ")
	header.back_pressed.connect(_on_back_pressed)

	_content_rect = Rect2(
		ScreenHeader.OUTER_MARGIN,
		ScreenHeader.CONTENT_TOP,
		1280.0 - ScreenHeader.OUTER_MARGIN * 2.0,
		ScreenHeader.CONTENT_HEIGHT
	)
	_empty_state = EmptyState.new()
	_empty_state.position = _content_rect.position
	_empty_state.size = _content_rect.size
	add_child(_empty_state)

	_announce_badge = StatusBadge.new()
	add_child(_announce_badge)

	_cancel_button = CodedButton.make("キャンセル", CANCEL_SIZE)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	add_child(_cancel_button)
	_cancel_button.position = Vector2(
		_content_rect.get_center().x - CANCEL_SIZE.x * 0.5, _cancel_button_top()
	)


## デッキ選択画面から開く。開いた時点でマッチングキューへ参加する。
func begin_match() -> void:
	if _busy:
		return
	_set_busy(true)
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


## 対局から戻ってきたときに、成立時の状態(キューのノード)を解く。
func reset_after_match() -> void:
	_discard_session()
	_set_busy(false)


func _discard_session() -> void:
	if is_instance_valid(_queue):
		_queue.queue_free()
	_queue = null


func _set_busy(busy: bool) -> void:
	_busy = busy
	_cancel_button.visible = busy
	if not busy:
		_discard_session()


func _set_status(text: String) -> void:
	_status_base_text = text
	if _announce_badge != null:
		_announce_badge.clear_note()
	_refresh_status_display()


func _refresh_status_display() -> void:
	_empty_state.show_message(_status_base_text, "", _busy)
	_place_announce_badge()


## `EmptyState` は情報だけを置き、押せるものを持たない(GameDesign.md 9章)。
## そのため印(`StatusBadge`)は `EmptyState` の外側から、その公開定数を使って
## 内部の中央寄せと同じ位置を計算し直して重ねる。ヒントは常に空文字なので
## ブロックの高さは一定であり、固定の一度きりの計算で済む。
func _title_baseline_y() -> float:
	var emblem_height := EmptyState.EMBLEM_SIZE * EmptyState.EMBLEM_VISUAL_RATIO
	var block := emblem_height + EmptyState.EMBLEM_GAP + EmptyState.TITLE_FONT_SIZE
	var top := _content_rect.position.y + (_content_rect.size.y - block) * 0.5
	return top + emblem_height + EmptyState.EMBLEM_GAP


func _cancel_button_top() -> float:
	return _title_baseline_y() + CANCEL_GAP


## **巡回ドットぶんの幅をあらかじめ確保する**(バトルタブの印の置き方と同じ考え方)。
## そうしないと、印が0.5秒ごとに文言の伸び縮みへ合わせて跳ねる。
func _place_announce_badge() -> void:
	if _announce_badge == null:
		return
	var font := get_theme_default_font()
	var font_size := EmptyState.TITLE_FONT_SIZE
	if font == null:
		return
	var text := _status_base_text + ".".repeat(BUSY_DOTS_MAX)
	var half_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5
	var baseline := _title_baseline_y()
	_announce_badge.position = Vector2(
		_content_rect.get_center().x + half_width + ANNOUNCE_BADGE_GAP,
		baseline - font_size * 0.72 - StatusBadge.DIAMETER * 0.5
	)


func _sign_in_or_fail() -> bool:
	var ok: bool = await NetSession.sign_in()
	if not ok:
		_fail("通信に失敗しました。もう一度お試しください")
	return ok


func _fail(message: String) -> void:
	_set_busy(false)
	_set_status(message)


func _on_back_pressed() -> void:
	if _busy:
		_on_cancel_pressed()
	back_pressed.emit()


## **キャンセルは押した瞬間に効かせ、後片付け(通信)の完了は待たない**
## (ルームマッチ画面と同じ理由。応答が遅いと「押しても何も起きない」ように見えるため)。
func _on_cancel_pressed() -> void:
	var queue := _queue
	_queue = null
	_set_busy(false)
	_set_status("キャンセルしました")
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


## 自分のuidがplayer_a/player_bのどちらとも一致しない場合はやり直させる。双方が後手に
## なると互いのデッキを待ち続けて対局が始まらないため(Architecture.md 6.1節)。
func _on_matched(match_id: String, opponent_uid: String) -> void:
	_busy = false
	_cancel_button.visible = false
	var match_doc: Dictionary = await NetSession.client.get_document("matches/%s" % match_id)
	var my_side: int
	if match_doc.get("player_a", "") == NetSession.auth.uid:
		my_side = MatchState.Side.A
	elif match_doc.get("player_b", "") == NetSession.auth.uid:
		my_side = MatchState.Side.B
	else:
		_fail("対戦相手との同期に失敗しました。もう一度お試しください")
		return
	_set_status("対戦相手が見つかりました!")
	matched.emit(match_id, my_side, opponent_uid)
