class_name CardRankedMatchScreen
extends Control
## ランクマッチの専用画面(GameDesign.md 28章)。`CardRandomMatchScreen`と同じ形で、
## デッキ選択画面を終えた直後に開き、`RankedMatchmakingQueue`への参加から
## マッチ成立までをここで完結させる。募集をDiscordへ知らせる仕組み(11章)は
## フリーマッチだけのものであり、ここでは使わない。

signal back_pressed
## 対戦が成立した。`Main._on_ranked_match_found()` がそのまま受け取れる形にしてある。
signal matched(match_id: String, my_side: int, opponent_uid: String)
## ヘッダーの「ランキング」から、段位・ランキング一覧の画面(`CardRankScreen`)を開く。
signal ranking_requested

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const CANCEL_SIZE := Vector2(220, 64)
const CANCEL_GAP := 40.0
const RANKING_BUTTON_SIZE := Vector2(168, 48)

var _queue: RankedMatchmakingQueue
var _busy := false
var _status_base_text := ""
var _content_rect: Rect2
var _empty_state: EmptyState
var _tier_label: Label
var _cancel_button: Button
var _ranking_button: Button


func _ready() -> void:
	_build()


func _build() -> void:
	var backdrop := ScreenBackdrop.new()
	backdrop.room = ScreenBackdrop.Room.HALL
	add_child(backdrop)
	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	header.set_title("ランクマッチ")
	header.back_pressed.connect(_on_back_pressed)
	_ranking_button = CodedButton.make("ランキング", RANKING_BUTTON_SIZE)
	_ranking_button.pressed.connect(func() -> void: ranking_requested.emit())
	header.add_action(_ranking_button)

	_content_rect = Rect2(
		ScreenHeader.OUTER_MARGIN,
		ScreenHeader.CONTENT_TOP,
		1280.0 - ScreenHeader.OUTER_MARGIN * 2.0,
		ScreenHeader.CONTENT_HEIGHT
	)
	_tier_label = Label.new()
	_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tier_label.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	_tier_label.add_theme_font_size_override("font_size", 18)
	add_child(_tier_label)

	_empty_state = EmptyState.new()
	_empty_state.position = _content_rect.position
	_empty_state.size = _content_rect.size
	add_child(_empty_state)

	_cancel_button = CodedButton.make("キャンセル", CANCEL_SIZE)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	add_child(_cancel_button)
	_cancel_button.position = Vector2(
		_content_rect.get_center().x - CANCEL_SIZE.x * 0.5, _cancel_button_top()
	)


## デッキ選択画面から開く。開いた時点でシーズンを確認してからキューへ参加する。
func begin_match() -> void:
	if _busy:
		return
	_set_busy(true)
	_set_status("マッチング中")
	if not await _sign_in_or_fail():
		return
	await RankProgress.ensure_current_season(NetSession.client, NetSession.auth.uid)
	_refresh_tier_label()
	_queue = RankedMatchmakingQueue.new(NetSession.client, NetSession.auth)
	add_child(_queue)
	_queue.matched.connect(_on_matched)
	_queue.failed.connect(_fail)
	_queue.version_mismatch.connect(_on_version_mismatch)
	_queue.join()


func _refresh_tier_label() -> void:
	_tier_label.text = "いまの段位: %s" % RankRules.display_name(AccountService.rank_tier())
	var font_size := 18
	var half_width := (
		_tier_label.get_theme_default_font().get_string_size(_tier_label.text, 0, -1, font_size).x
		* 0.5
	)
	_tier_label.position = Vector2(
		_content_rect.get_center().x - half_width, _content_rect.position.y - 6.0
	)


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
	# キューに参加している間にランキングへ移ると、そのまま待機が残ったまま画面だけ
	# 離れてしまう(キャンセルされない)。押せなくして、その状態を作らせない。
	_ranking_button.disabled = busy
	if not busy:
		_discard_session()


func _set_status(text: String) -> void:
	_status_base_text = text
	_empty_state.show_message(_status_base_text, "", _busy)


func _title_baseline_y() -> float:
	var emblem_height := EmptyState.EMBLEM_SIZE * EmptyState.EMBLEM_VISUAL_RATIO
	var block := emblem_height + EmptyState.EMBLEM_GAP + EmptyState.TITLE_FONT_SIZE
	var top := _content_rect.position.y + (_content_rect.size.y - block) * 0.5
	return top + emblem_height + EmptyState.EMBLEM_GAP


func _cancel_button_top() -> float:
	return _title_baseline_y() + CANCEL_GAP


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


## キャンセルは押した瞬間に効かせ、後片付け(通信)の完了は待たない(GameDesign.md 11章)。
func _on_cancel_pressed() -> void:
	var queue := _queue
	_queue = null
	_set_busy(false)
	_set_status("キャンセルしました")
	if queue != null:
		await queue.cancel()
		queue.queue_free()


func _on_version_mismatch(newer_exists: bool) -> void:
	if newer_exists:
		_set_status("新しい版が公開されています。再読み込みしてください")
	else:
		_set_status("古い版の相手が待っています。マッチング中")


## 自分のuidがplayer_a/player_bのどちらとも一致しない場合はやり直させる
## (Architecture.md 6.1節)。
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
