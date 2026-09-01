class_name CardRoomScreen
extends Control
## ルームマッチの専用画面(GameDesign.md 11章)。部屋を作る・コードで参加する・観戦する
## の3つと、その待機をここで完結させる。使用デッキと持ち時間(5章)の設定も併せて持つ。
##
## `RoomMatch` を持つのはこの画面であり、`BattleTab` からは同じ経路をすべて外してある。

signal back_pressed
## 使用デッキを選び直す。デッキ一覧(選択モード)を開くのは `Main` の役目。
signal deck_change_requested
## 対戦が成立した。time_limit は部屋の設定(GameDesign.md 5章)で、対局画面まで運ぶ。
signal matched(match_id: String, my_side: int, opponent_uid: String, time_limit: bool)
signal spectate_requested(match_id: String)

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const SETTINGS_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 1232, 108)
const CREATE_RECT := Rect2(24, 268, 604, 284)
const JOIN_RECT := Rect2(652, 268, 604, 284)
const STATUS_RECT := Rect2(24, 568, 1232, 88)
## 通信待ち中の「...」演出。バトルタブと同じ間隔・同じ打ち方に揃える。
const BUSY_DOTS_MAX := 3
const BUSY_DOTS_INTERVAL := 0.5

var _room: RoomMatch
var _busy := false
var _code := ""
var _time_limit := true
var _status_base_text := ""
var _busy_dot_count := 0
var _busy_dots_timer: Timer
var _deck_label: Label
var _deck_button: Button
var _time_button: Button
var _time_note: Label
var _create_button: Button
var _code_label: Label
var _copy_button: Button
var _join_input: LineEdit
var _join_button: Button
var _spectate_button: Button
var _status_label: Label
var _cancel_button: Button


func _ready() -> void:
	_busy_dots_timer = Timer.new()
	_busy_dots_timer.wait_time = BUSY_DOTS_INTERVAL
	_busy_dots_timer.timeout.connect(_on_busy_dots_timeout)
	add_child(_busy_dots_timer)
	_build()
	_refresh_settings()


## 画面を開く。待機中に開き直した場合(デッキを選び直して戻ってきた場合)は、
## 進行中の待機を壊さないよう設定の表示だけを描き直す。
func open() -> void:
	_refresh_settings()
	if not _busy:
		_set_status("部屋を作るか、コードで参加してください")


## 対局から戻ってきたときに、成立時の状態(ボタンの無効化・部屋のノード)を解く。
func reset_after_match() -> void:
	_code = ""
	_set_busy(false)


func _build() -> void:
	add_child(ScreenBackdrop.new())
	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	header.set_title("ルームマッチ")
	header.back_pressed.connect(_on_back_pressed)
	_build_settings()
	_build_create()
	_build_join()
	_build_status()


## 上段。使用デッキと持ち時間は、部屋を作る側にも参加する側にも関わるため1行へ並べる。
func _build_settings() -> void:
	var row := _make_panel(SETTINGS_RECT)
	var deck_row := HBoxContainer.new()
	deck_row.add_theme_constant_override("separation", 16)
	row.add_child(deck_row)
	_deck_label = _make_label("", 22)
	_deck_label.custom_minimum_size = Vector2(540, 0)
	deck_row.add_child(_deck_label)
	_deck_button = CodedButton.make("変更", Vector2(140, 52))
	_deck_button.pressed.connect(func() -> void: deck_change_requested.emit())
	deck_row.add_child(_deck_button)
	_time_button = CodedButton.make("", Vector2(300, 52))
	_time_button.pressed.connect(_on_time_pressed)
	deck_row.add_child(_time_button)
	_time_note = _make_label("", 17)
	row.add_child(_time_note)


func _build_create() -> void:
	var column := _make_panel(CREATE_RECT)
	column.add_child(_make_label("部屋を作る", 26))
	column.add_child(_make_label("作ったコードを友達へ渡してください", 17))
	_create_button = CodedButton.make("部屋を作る", Vector2(300, 68))
	_create_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_create_button.pressed.connect(_on_create_pressed)
	column.add_child(_create_button)
	_code_label = _make_label("", 40)
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_label.visible = false
	column.add_child(_code_label)
	_copy_button = CodedButton.make("コードをコピー", Vector2(240, 56))
	_copy_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_copy_button.visible = false
	_copy_button.pressed.connect(_on_copy_pressed)
	column.add_child(_copy_button)


func _build_join() -> void:
	var column := _make_panel(JOIN_RECT)
	column.add_child(_make_label("コードで参加する", 26))
	column.add_child(_make_label("友達から受け取ったコードを入力してください", 17))
	_join_input = LineEdit.new()
	_join_input.placeholder_text = "%d桁の数字" % RoomMatch.CODE_LENGTH
	_join_input.max_length = RoomMatch.CODE_LENGTH
	_join_input.custom_minimum_size = Vector2(300, 56)
	column.add_child(_join_input)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	_join_button = CodedButton.make("参加する", Vector2(200, 64))
	_join_button.pressed.connect(_on_join_pressed)
	buttons.add_child(_join_button)
	_spectate_button = CodedButton.make("観戦する", Vector2(200, 64))
	_spectate_button.pressed.connect(_on_spectate_pressed)
	buttons.add_child(_spectate_button)


func _build_status() -> void:
	var row := _make_panel(STATUS_RECT)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 24)
	row.add_child(line)
	_status_label = _make_label("", 22)
	_status_label.custom_minimum_size = Vector2(920, 0)
	line.add_child(_status_label)
	_cancel_button = CodedButton.make("キャンセル", Vector2(200, 56))
	_cancel_button.visible = false
	_cancel_button.pressed.connect(_on_cancel_pressed)
	line.add_child(_cancel_button)


func _make_panel(rect: Rect2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.custom_minimum_size = rect.size
	panel.size = rect.size
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	return column


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	# 折り返しは size より先に立てる(Architecture.md 11章)。
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## 使用デッキと持ち時間の表示を描き直す。**持ち時間を変えられるのは部屋を作る前だけ**
## (GameDesign.md 5章)。参加する側と、既に作った後は表示だけになる。
func _refresh_settings() -> void:
	var decks := CardDeckSave.list_decks()
	if decks.is_empty():
		_deck_label.text = "使用デッキ: 基本(プリセット)"
		_deck_button.disabled = true
	else:
		var index := clampi(CardDeckSave.selected_index(), 0, decks.size() - 1)
		_deck_label.text = "使用デッキ: %s" % decks[index]["name"]
		_deck_button.disabled = _busy
	_time_button.text = "持ち時間: あり" if _time_limit else "持ち時間: なし"
	_time_button.disabled = _busy
	_time_note.text = ("1手番につき60秒。手番が移るたびに戻ります" if _time_limit else "持ち時間なし。放置した相手を時間切れで倒せなくなります")


func _on_time_pressed() -> void:
	if _busy:
		return
	_time_limit = not _time_limit
	_refresh_settings()


## コピーはブラウザに拒否されることがあるが、**失敗しても画面には何も出さない**
## (GameDesign.md 11章)。コード自体が大きく出ており、手入力で足りるため。
func _on_copy_pressed() -> void:
	if _code != "":
		DisplayServer.clipboard_set(_code)


## cancellable: 相手の参加待ち・観戦の開始待ちなど、待機を中断できる間だけtrueにする。
func _set_busy(busy: bool, cancellable: bool = false) -> void:
	_busy = busy
	_create_button.disabled = busy
	_join_button.disabled = busy
	_spectate_button.disabled = busy
	_join_input.editable = not busy
	_cancel_button.visible = busy and cancellable
	if busy:
		_busy_dot_count = 0
		_busy_dots_timer.start()
	else:
		_discard_session()
		_stop_busy_dots()
		_code_label.visible = false
		_copy_button.visible = false
		_create_button.visible = true
	_refresh_settings()


## 部屋のノードを片付ける。参照を外すだけだと、待機のたびに子が積み上がる。
func _discard_session() -> void:
	if is_instance_valid(_room):
		_room.queue_free()
	_room = null


func _set_status(text: String) -> void:
	_status_base_text = text
	_refresh_status_display()


func _refresh_status_display() -> void:
	var text := _status_base_text
	if _busy:
		text += ".".repeat(_busy_dot_count)
	_status_label.text = text


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


func _fail(message: String) -> void:
	_set_busy(false)
	_code = ""
	_set_status(message)


## 入力欄のコードを取り出す。桁数の合わない入力は空文字にして呼び出し側で弾く
## (4桁しかないため、打ち間違いをそのまま通信させる意味がない)。
func _room_code_input() -> String:
	var code := _join_input.text.strip_edges()
	if code.length() != RoomMatch.CODE_LENGTH:
		return ""
	for i in code.length():
		if code[i] < "0" or code[i] > "9":
			return ""
	return code


func _on_back_pressed() -> void:
	if _busy:
		_on_cancel_pressed()
	back_pressed.emit()


func _on_create_pressed() -> void:
	if _busy:
		return
	_set_busy(true, true)
	_set_status("部屋を作成中")
	if not await _sign_in_or_fail():
		return
	_room = RoomMatch.new(NetSession.client, NetSession.auth)
	add_child(_room)
	_room.room_created.connect(_on_room_created)
	_room.matched.connect(_on_matched)
	_room.join_failed.connect(_on_join_failed)
	_room.create_room(_time_limit)


func _on_join_pressed() -> void:
	if _busy:
		return
	var code := _room_code_input()
	if code == "":
		_set_status("ルームコードは%d桁の数字です" % RoomMatch.CODE_LENGTH)
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


## 観戦は、対局がまだ始まっていなければ同じ画面で待つ(GameDesign.md 11章)。
## 待つ以上は中断できる必要があるため、キャンセルを出す。
func _on_spectate_pressed() -> void:
	if _busy:
		return
	var code := _room_code_input()
	if code == "":
		_set_status("ルームコードは%d桁の数字です" % RoomMatch.CODE_LENGTH)
		return
	_set_busy(true, true)
	_set_status("観戦先を確認中")
	if not await _sign_in_or_fail():
		return
	_room = RoomMatch.new(NetSession.client, NetSession.auth)
	add_child(_room)
	_room.spectate_ready.connect(_on_spectate_ready)
	_room.spectate_waiting.connect(_on_spectate_waiting)
	_room.spectate_failed.connect(_on_spectate_failed)
	_room.spectate(code)


## **キャンセルは押した瞬間に効かせ、後片付け(通信)の完了は待たない**
## (バトルタブと同じ理由。応答が遅いと「押しても何も起きない」ように見えるため)。
func _on_cancel_pressed() -> void:
	var room := _room
	_room = null
	_code = ""
	_set_busy(false)
	_set_status("キャンセルしました")
	if room != null:
		await room.cancel()
		room.queue_free()


## 作った後は「部屋を作る」を隠す。押せない状態のまま置いておくと、コードとコピーを
## 足したぶんだけパネルの中身が縦にあふれる(実際に描画して確認した)。
func _on_room_created(code: String) -> void:
	_code = code
	_code_label.text = code
	_code_label.visible = true
	_copy_button.visible = true
	_create_button.visible = false
	_set_status("相手の参加を待っています")


func _on_spectate_waiting() -> void:
	_set_status("対局の開始を待っています")


func _on_spectate_ready(match_id: String) -> void:
	_busy = false
	_cancel_button.visible = false
	_stop_busy_dots()
	_set_status("観戦を開始します")
	spectate_requested.emit(match_id)


func _on_spectate_failed(reason: String) -> void:
	var message := _version_message(reason)
	if message == "":
		message = "コードが見つかりません"
	_fail("観戦できませんでした(%s)" % message)


func _on_join_failed(reason: String) -> void:
	_fail("参加に失敗しました(%s)" % _join_failure_message(reason))


## バージョン違いで弾いたときの文言。ビルドIDは時刻順に比較できるため、
## どちらが古いかまで示せる(GameDesign.md 11章)。該当しなければ空文字を返す。
func _version_message(reason: String) -> String:
	match reason:
		"version_older":
			return "新しい版が公開されています。再読み込みしてください"
		"version_newer":
			return "相手が古い版です。相手に再読み込みしてもらってください"
		_:
			return ""


func _join_failure_message(reason: String) -> String:
	var version_message := _version_message(reason)
	if version_message != "":
		return version_message
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


## 自分のuidがplayer_a/player_bのどちらとも一致しない場合はやり直させる。双方が後手に
## なると互いのデッキを待ち続けて対局が始まらないため(Architecture.md 6.1節)。
func _on_matched(match_id: String, opponent_uid: String) -> void:
	_busy = false
	_cancel_button.visible = false
	_stop_busy_dots()
	var time_limit: bool = _room != null and _room.time_limit
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
	matched.emit(match_id, my_side, opponent_uid, time_limit)
