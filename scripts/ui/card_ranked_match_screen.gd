class_name CardRankedMatchScreen
extends Control
## ランクマッチの専用画面(GameDesign.md 28章)。`CardRandomMatchScreen`と同じ形で、
## デッキ選択画面を終えた直後に開き、`RankedMatchmakingQueue`への参加から
## マッチ成立までをここで完結させる。見知らぬ人との対戦はこの1つだけ(11章)。

signal back_pressed
## 対戦が成立した。`Main._on_ranked_match_found()` がそのまま受け取れる形にしてある。
signal matched(match_id: String, my_side: int, opponent_uid: String)
## 待っている間のCPU戦(GameDesign.md 11章。自動で始まる場合とボタンの場合)。`Main` がCPU戦を始める。
signal cpu_requested
## 「ほかの画面を見る」(GameDesign.md 11章)。キューは残したまま `Main` がホームへ戻す。
signal browse_requested
## 失敗・キャンセルで待機が終わった。`message` は失敗の文言(キャンセルは空)。
signal waiting_ended(message: String)

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const BUSY_DOTS_MAX := EmptyState.DOTS_MAX
## 印にカーソルを乗せたときだけ出す説明(GameDesign.md 11章)。
const ANNOUNCE_NOTE := "公式Discordサーバーへ「対戦相手をさがしている人がいる」と通知を送りました"
## 印は待機中の文言のすぐ右へ置く(GameDesign.md 11章)。
const ANNOUNCE_BADGE_GAP := 10.0
const CANCEL_SIZE := Vector2(220, 64)
## 見出しの下の1行(なければ見出し)から、すぐ下のCPUボタンまでの間隔。
const CANCEL_GAP := 40.0
## 待機中、印を返す間隔(GameDesign.md 11章)。
const EMBLEM_FLIP_SECONDS := 6.0
const TIER_FONT_SIZE := UiPalette.T_LEAD
## 縦画面(GameDesign.md 9章「縦画面」)。中央の待機の文言は `EmptyState` が拡大して描くため、印とボタンもそれに合わせる。
const PORTRAIT_CANCEL_SIZE := Vector2(300, 76)
const PORTRAIT_TIER_FONT_SIZE := 26
## 待機の一群を縦の中央より上へ寄せる(下にCPU戦の入口と予告が続くため)。
const PORTRAIT_CONTENT_HEIGHT := 760.0
const BROWSE_SIZE := Vector2(220, 56)
## 見出しと「次にすることの1行」の2段(GameDesign.md 9章の空状態)。
const FAILED_TITLE := "通信に失敗しました"
const FAILED_HINT := "もう一度お試しください"
const NEWER_VERSION_TITLE := "新しい版が公開されています"
const NEWER_VERSION_HINT := "再読み込みしてください"

## 待っている間のCPU戦のキュー。`WaitingCpuMatch` がCPU戦の印を立て、相手の知らせを受ける。
var queue: MatchmakingQueue:
	get:
		return _queue if is_instance_valid(_queue) else null

## 待機を始めた時点のデッキの複製。待機中に編集・保存しても、この対局には反映しない(GameDesign.md 11章)。
var deck: Array = []
## 待機を始めた時刻(`Time.get_ticks_msec()`)。待機の帯が経過時間を数える。
var started_msec := 0

var _queue: RankedMatchmakingQueue
var _cpu_offer: WaitingCpuOffer
var _wait_funnel := RankedWaitFunnel.new(self)
var _busy := false
## 見つかって見出しを替え、対局へ移るまでとどまっている間(押すものは出さない)。
var _found_hold := false
## 見出しの下の1行が経過時間(と待機人数)のとき真。
var _clock_hint := false
## 自分を除く待機人数。読めていないときは負。
var _others_waiting := -1
var _status_base_text := ""
var _status_hint := ""
var _content_rect: Rect2
var _empty_state: EmptyState
var _tier_label: Label
var _announce_badge: StatusBadge
var _cancel_button: Button
var _browse_button: Button
var _ceremony: CardSeasonCeremonyPanel
var _header: ScreenHeader
var _portrait := false
var _poll_timer: Timer


func _ready() -> void:
	_build()
	visibility_changed.connect(_on_visibility_changed)


func _process(_delta: float) -> void:
	if _clock_hint and is_visible_in_tree():
		_empty_state.set_hint(_wait_line())


func _build() -> void:
	var backdrop := ScreenBackdrop.new()
	backdrop.room = ScreenBackdrop.Room.HALL
	add_child(backdrop)
	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	header.set_title("ランクマッチ")
	header.back_pressed.connect(_on_back_pressed)
	_header = header
	# 縦でヘッダーの下の行が出たり消えたりしないよう、待機していない間も置いたまま押せなくする。
	_browse_button = CodedButton.make("ほかの画面を見る", BROWSE_SIZE)
	_browse_button.disabled = true
	_browse_button.pressed.connect(func() -> void: browse_requested.emit())
	header.add_action(_browse_button)

	_content_rect = _landscape_content_rect()
	_tier_label = Label.new()
	_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tier_label.add_theme_color_override("font_color", UiPalette.MUTED)
	_tier_label.add_theme_font_size_override("font_size", TIER_FONT_SIZE)
	add_child(_tier_label)

	_empty_state = EmptyState.new()
	_empty_state.position = _content_rect.position
	_empty_state.size = _content_rect.size
	_empty_state.flip_interval = EMBLEM_FLIP_SECONDS
	add_child(_empty_state)

	_poll_timer = Timer.new()
	_poll_timer.wait_time = RankedMatchmakingQueue.WAITING_POLL_SECONDS
	_poll_timer.timeout.connect(_refresh_others_waiting)
	add_child(_poll_timer)

	_announce_badge = StatusBadge.new()
	add_child(_announce_badge)

	_cancel_button = CodedButton.make("キャンセル", CANCEL_SIZE)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	add_child(_cancel_button)
	_cpu_offer = WaitingCpuOffer.new(self)
	_place_action_buttons()
	_cpu_offer.requested.connect(
		func() -> void:
			_wait_funnel.switched_to_cpu()
			cpu_requested.emit()
	)

	# 表彰式は結果パネルより手前に描かれる必要があるため最後の子にする
	# (Godotは後の子ほど手前に描く。Architecture.md 11章)。
	_ceremony = CardSeasonCeremonyPanel.new()
	add_child(_ceremony)


func _landscape_content_rect() -> Rect2:
	return Rect2(
		ScreenHeader.OUTER_MARGIN,
		ScreenHeader.CONTENT_TOP,
		ScreenOrientation.LANDSCAPE_SIZE.x - ScreenHeader.OUTER_MARGIN * 2.0,
		ScreenHeader.CONTENT_HEIGHT
	)


## 縦横が変わったときに `Main` から呼ばれる(Architecture.md 4.7節)。待機(キュー)は保つ。
func apply_orientation(portrait: bool) -> void:
	_portrait = portrait
	if _header == null:
		return
	_header.apply_orientation(portrait)
	_content_rect = _landscape_content_rect()
	if portrait:
		var content := _header.portrait_content_rect()
		_content_rect = Rect2(content.position, Vector2(content.size.x, PORTRAIT_CONTENT_HEIGHT))
	_empty_state.position = _content_rect.position
	_empty_state.size = _content_rect.size
	_tier_label.add_theme_font_size_override(
		"font_size", PORTRAIT_TIER_FONT_SIZE if portrait else TIER_FONT_SIZE
	)
	var cancel_size := PORTRAIT_CANCEL_SIZE if portrait else CANCEL_SIZE
	_cancel_button.custom_minimum_size = cancel_size
	_cancel_button.size = cancel_size
	if portrait:
		_cancel_button.add_theme_font_size_override("font_size", ScreenHeader.PORTRAIT_BUTTON_FONT)
	else:
		_cancel_button.remove_theme_font_size_override("font_size")
	_place_action_buttons()
	if not _tier_label.text.is_empty():
		_refresh_tier_label()
	_place_announce_badge()


## デッキ選択画面から開く。開いた時点でシーズンを確認してからキューへ参加する。
func begin_match() -> void:
	if _busy:
		return
	_set_busy(true)
	started_msec = Time.get_ticks_msec()
	_others_waiting = -1
	_set_status("マッチング中", "", true)
	deck = CardDeckSave.selected_deck().duplicate()
	if not await _sign_in_or_fail():
		return
	var season_result := await RankProgress.ensure_current_season(
		NetSession.client, NetSession.auth.uid
	)
	_refresh_tier_label()
	if bool(season_result.get("transitioned", false)):
		_ceremony.open(season_result)
	_queue = RankedMatchmakingQueue.new(NetSession.client, NetSession.auth)
	add_child(_queue)
	_queue.matched.connect(_on_matched)
	_queue.failed.connect(_fail)
	_queue.version_mismatch.connect(_on_version_mismatch)
	_queue.announce_result.connect(_on_announce_result)
	_queue.join()
	_poll_timer.start()
	_refresh_others_waiting()
	_wait_funnel.begin()
	_browse_button.disabled = false
	# 表彰式を読んでいる間にボタンが出ないよう、閉じてから数え始める
	if _ceremony.visible:
		await _ceremony.closed
		if not _busy or queue == null:
			return
	_cpu_offer.arm(WaitingCpuOffer.FIRST_DELAY_SECONDS)


func _refresh_tier_label() -> void:
	_tier_label.text = "いまの段位: %s" % RankRules.display_name(AccountService.rank_tier())
	var font_size := _tier_label.get_theme_font_size("font_size")
	var half_width := (
		_tier_label.get_theme_default_font().get_string_size(_tier_label.text, 0, -1, font_size).x
		* 0.5
	)
	_tier_label.position = Vector2(
		_content_rect.get_center().x - half_width, _content_rect.position.y - 6.0
	)


## キューに入って相手を待っている(他の画面にいる間も真)。
func is_waiting() -> bool:
	return _busy and queue != null


## 待機の帯の「やめる」。待機画面の外からキャンセルする。
func cancel_waiting() -> void:
	if is_waiting():
		_on_cancel_pressed()


## 待っている間のCPU戦から戻ってきた。キューは残したまま、通常の待機に復帰する。
## 待機が既に失敗で終わっていれば(`_queue` が無い)、その文言のまま何もしない。
func resume_waiting() -> void:
	if queue == null:
		return
	_queue.set_cpu_playing(false)
	_cpu_offer.arm(0.0)


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
	_found_hold = false
	if not busy:
		_poll_timer.stop()
	_cancel_button.visible = busy
	_browse_button.disabled = true
	_cpu_offer.hide()
	if not busy:
		_discard_session()


## `hint` は見出しの下へ出す「次にすることの1行」。呼ぶたびに前の状態の1行を引き継がない。
## `clock` が真のときは、1行を経過時間(と待機人数)にして毎秒差し替える。
func _set_status(text: String, hint := "", clock := false) -> void:
	_status_base_text = text
	_clock_hint = clock
	_status_hint = _wait_line() if clock else hint
	if _announce_badge != null:
		_announce_badge.clear_note()
	_empty_state.show_message(_status_base_text, _status_hint, _busy)
	_place_announce_badge()
	if _cancel_button != null and _cpu_offer != null:
		_place_action_buttons()


## 見出しの下の1行(「0:42」「0:42 ・ ほかに 2人が待っています」)。
func _wait_line() -> String:
	return RankedWaitLine.line(RankedWaitLine.elapsed_seconds(started_msec), _others_waiting)


## 待機人数を読む。待機画面が見えている間だけ読み、CPU戦などで隠れている間は読まない。
func _refresh_others_waiting() -> void:
	if not is_waiting() or not is_visible_in_tree():
		return
	var count := await RankedMatchmakingQueue.count_waiting(NetSession.client, NetSession.auth.uid)
	if not is_waiting():
		return
	_others_waiting = count
	if _clock_hint:
		_empty_state.set_hint(_wait_line())


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_refresh_others_waiting()


## `EmptyState` は押せるものを持たないため、印は外側から同じ中央寄せを計算し直して重ねる。
func _place_announce_badge() -> void:
	var font := get_theme_default_font()
	if _announce_badge == null or font == null:
		return
	var font_size := EmptyState.TITLE_FONT_SIZE
	var text := _status_base_text + ".".repeat(BUSY_DOTS_MAX)
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_announce_badge.position = Vector2(
		_content_rect.get_center().x + text_width * 0.5 * _zoom() + ANNOUNCE_BADGE_GAP,
		_title_baseline_y() - font_size * 0.72 * _zoom() - StatusBadge.DIAMETER * 0.5
	)


func _on_announce_result(ok: bool) -> void:
	if ok and _announce_badge != null:
		_announce_badge.show_note(ANNOUNCE_NOTE)


## `EmptyState` の描く倍率(縦は中身ごと拡大する)。
func _zoom() -> float:
	return EmptyState.PORTRAIT_ZOOM if _portrait else 1.0


func _title_baseline_y() -> float:
	var emblem_height := EmptyState.EMBLEM_SIZE * EmptyState.EMBLEM_VISUAL_RATIO
	var block := emblem_height + EmptyState.EMBLEM_GAP + EmptyState.TITLE_FONT_SIZE
	if not _status_hint.is_empty():
		block += EmptyState.HINT_GAP
	var top := (_content_rect.size.y / _zoom() - block) * 0.5
	return _content_rect.position.y + (top + emblem_height + EmptyState.EMBLEM_GAP) * _zoom()


## 1行があるときは、その下端からCPUボタンまで `CANCEL_GAP` を保つ。
func _action_buttons_top() -> float:
	var hint_gap := EmptyState.HINT_GAP if not _status_hint.is_empty() else 0.0
	return _title_baseline_y() + (CANCEL_GAP + hint_gap) * _zoom()


## 文言のすぐ下にCPUボタン、その下にキャンセル(GameDesign.md 11章)。CPUボタンが出る前も場所を空けておき、
## 出たときにキャンセルが動いて押し間違えさせない。
func _place_action_buttons() -> void:
	var center_x := _content_rect.get_center().x
	var cancel_top := _cpu_offer.place(center_x, _action_buttons_top(), _portrait)
	_cancel_button.position = Vector2(center_x - _cancel_button.size.x * 0.5, cancel_top)


func _sign_in_or_fail() -> bool:
	var ok: bool = await NetSession.sign_in()
	if not ok:
		_fail(FAILED_TITLE, FAILED_HINT)
	return ok


func _fail(message: String, hint := "") -> void:
	_wait_funnel.end()
	_set_busy(false)
	_set_status(message, hint)
	waiting_ended.emit(message if hint.is_empty() else "%s。%s" % [message, hint])


func _on_back_pressed() -> void:
	if _found_hold:
		return
	if _busy:
		_on_cancel_pressed()
	back_pressed.emit()


## キャンセルは押した瞬間に効かせ、後片付け(通信)の完了は待たない(GameDesign.md 11章)。
func _on_cancel_pressed() -> void:
	var queue := _queue
	_queue = null
	_wait_funnel.end(FunnelService.RANKED_CANCEL)
	_set_busy(false)
	_set_status("キャンセルしました")
	if queue != null:
		waiting_ended.emit("")
		await queue.cancel()
		queue.queue_free()


func _on_version_mismatch(newer_exists: bool) -> void:
	if newer_exists:
		_set_status(NEWER_VERSION_TITLE, NEWER_VERSION_HINT)
	else:
		_set_status("古い版の相手が待っています。マッチング中", "", true)


## 自分のuidがplayer_a/player_bのどちらとも一致しない場合はやり直させる
## (Architecture.md 6.1節)。
func _on_matched(match_id: String, opponent_uid: String) -> void:
	_wait_funnel.end(FunnelService.RANKED_MATCHED)
	_busy = false
	_found_hold = true
	_poll_timer.stop()
	_cancel_button.visible = false
	_browse_button.disabled = true
	_cpu_offer.hide()
	var match_doc: Dictionary = await NetSession.client.get_document("matches/%s" % match_id)
	var my_side: int
	if match_doc.get("player_a", "") == NetSession.auth.uid:
		my_side = MatchState.Side.A
	elif match_doc.get("player_b", "") == NetSession.auth.uid:
		my_side = MatchState.Side.B
	else:
		_fail("対戦相手との同期に失敗しました。もう一度お試しください")
		return
	# 経過時間の行は止めたまま残し、見出しだけ替える(行が消えて見出しが動かないように)。
	_set_status("対戦相手が見つかりました!", _status_hint)
	# 他の画面にいる間は帯が同じ間を取る(`Main`)ため、ここでは待たない。
	if is_visible_in_tree():
		await get_tree().create_timer(RankedWaitBanner.FOUND_NOTICE_SECONDS).timeout
	matched.emit(match_id, my_side, opponent_uid)
