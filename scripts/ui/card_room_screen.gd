class_name CardRoomScreen
extends Control
## ルームマッチの専用画面(GameDesign.md 11章)。部屋を作る・コードで参加する・観戦する
## の3つと、その待機をここで完結させる。画面は「入口」と「部屋の中」の2つの段を持つ。
##
## `RoomMatch` を持つのはこの画面であり、`BattleTab` からは同じ経路をすべて外してある。

signal back_pressed
## 使用デッキを選び直す。デッキ一覧(選択モード)を開くのは `Main` の役目。
signal deck_change_requested
## 対戦が成立した。time_limit は部屋の設定(GameDesign.md 5章)で、対局画面まで運ぶ。
signal matched(match_id: String, my_side: int, opponent_uid: String, time_limit: bool)
signal spectate_requested(match_id: String)

enum Role { NONE, HOST, GUEST, SPECTATOR }

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const PANEL_STYLE := "res://resources/theme/content_panel.tres"

const CREATE_RECT := Rect2(24, 136, 604, 400)
const JOIN_RECT := Rect2(652, 136, 604, 400)
const MESSAGE_RECT := Rect2(24, 544, 1232, 32)
const DECK_RECT := Rect2(24, 584, 1232, 112)
const CARD_TITLE_POS := Vector2(32, 24)
const CARD_SUB_POS := Vector2(32, 68)
const TIME_LABEL_POS := Vector2(32, 116)
const TIME_ON_RECT := Rect2(32, 152, 160, 56)
const TIME_OFF_RECT := Rect2(204, 152, 160, 56)
const TIME_NOTE_POS := Vector2(32, 222)
const CREATE_BUTTON_RECT := Rect2(152, 300, 300, 72)
const ENTRY_TILES_RECT := Rect2(32, 120, 300, 80)
const JOIN_BUTTON_RECT := Rect2(32, 220, 300, 64)
const SPECTATE_BUTTON_RECT := Rect2(32, 296, 300, 64)
const PAD_POS := Vector2(364, 120)
const PAD_KEY_SIZE := Vector2(64, 54)
const DECK_CAPTION_POS := Vector2(32, 18)
const DECK_NAME_POS := Vector2(32, 44)
const DECK_BUTTON_RECT := Rect2(1000, 26, 200, 60)

const CODE_RECT := Rect2(24, 136, 1232, 128)
const CODE_CAPTION_POS := Vector2(40, 34)
const CODE_HINT_POS := Vector2(40, 68)
const ROOM_TILES_RECT := Rect2(452, 18, 331, 92)
const COPY_BUTTON_RECT := Rect2(832, 34, 150, 60)
const MINE_RECT := Rect2(24, 288, 540, 272)
const FOE_RECT := Rect2(716, 288, 540, 272)
const SEATS_RECT := Rect2(24, 288, 1232, 272)
const VS_CENTER := Vector2(640, 424)
const VS_RADIUS := 42.0
const VS_RING := 4.0
const VS_FONT_SIZE := 32
const TIME_INFO_POS := Vector2(40, 606)
const STATUS_POS := Vector2(40, 640)
const STATUS_WIDTH := 720.0
const LEAVE_RECT := Rect2(772, 612, 220, 72)
const LEAVE_ALONE_RECT := Rect2(1036, 612, 220, 72)
const START_RECT := Rect2(1012, 612, 244, 72)

const TITLE_FONT_SIZE := 28
const SUB_FONT_SIZE := 17
const BODY_FONT_SIZE := 20
const NOTE_FONT_SIZE := 16
const DECK_NAME_FONT_SIZE := 28
const STATUS_FONT_SIZE := 18

const TIME_ON_NOTE := "1手番につき60秒。手番が移るたびに戻ります"
const TIME_OFF_NOTE := "持ち時間なし。放置した相手を時間切れで倒せなくなります"
const WAIT_FOE_TEXT := "相手の参加を待っています"
const WAIT_FOE_HINT := "コードを入力すると、ここに座ります"
const LOADING_FOE_NAME := "読み込み中"
## 表示名を付けていない相手。自分の名札の既定(`AccountService.display_name_or_default()`)と揃える。
const FOE_FALLBACK_NAME := "ゲスト"

var _room: RoomMatch
var _role := Role.NONE
var _busy := false
var _in_lobby := false
## ホストが「対局を開始」を押してから成立するまで。デッキも変えられなくする。
var _starting := false
var _code := ""
var _time_limit := true
var _status_base_text := ""
var _status_waiting := false
var _busy_dot_count := 0
var _busy_dots_timer: Timer

var _entrance: Control
var _time_on_button: Button
var _time_off_button: Button
var _time_note: Label
var _create_button: Button
var _join_tiles: CodeTiles
var _join_pad: NumberPad
var _join_button: Button
var _spectate_button: Button
var _message_label: Label
var _deck_name_label: Label
var _deck_button: Button

var _room_view: Control
var _code_caption: Label
var _code_hint: Label
var _room_tiles: CodeTiles
var _copy_button: Button
var _my_seat: RoomSeat
var _foe_seat: RoomSeat
var _seat_deck_button: Button
var _vs_mark: Control
var _spectate_state: EmptyState
var _time_info: Label
var _status_label: Label
var _leave_button: Button
var _start_button: Button


func _ready() -> void:
	_busy_dots_timer = Timer.new()
	_busy_dots_timer.wait_time = EmptyState.DOTS_INTERVAL
	_busy_dots_timer.timeout.connect(_on_busy_dots_timeout)
	add_child(_busy_dots_timer)
	_build()
	_show_entrance("")


## 画面を開く。待機中に開き直した場合(デッキを選び直して戻ってきた場合)は、
## 進行中の待機を壊さないよう設定の表示だけを描き直す。
func open() -> void:
	_refresh_settings()


## 対局から戻ってきたときに、成立時の状態(ボタンの無効化・部屋のノード)を解く。
func reset_after_match() -> void:
	_discard_session()
	_show_entrance("")


func _build() -> void:
	var backdrop := ScreenBackdrop.new()
	backdrop.room = ScreenBackdrop.Room.HALL
	add_child(backdrop)
	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	header.set_title("ルームマッチ")
	header.back_pressed.connect(_on_back_pressed)
	_entrance = _make_layer()
	_build_create_card()
	_build_join_card()
	_message_label = _make_label(_entrance, "", BODY_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	_message_label.position = MESSAGE_RECT.position
	_message_label.size = MESSAGE_RECT.size
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_deck_strip()
	_room_view = _make_layer()
	_build_code_plate()
	_build_seats()
	_build_footer()


func _make_layer() -> Control:
	var layer := Control.new()
	layer.anchor_right = 1.0
	layer.anchor_bottom = 1.0
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	return layer


func _make_panel(parent: Control, rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


func _make_label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _place_label(
	parent: Control, text: String, at: Vector2, font_size: int, color: Color
) -> Label:
	var label := _make_label(parent, text, font_size, color)
	label.position = at
	return label


## primary: 主要な操作は塗りつぶした真鍮、副次的な操作は凹んだパネル(GameDesign.md 11章)。
func _make_button(parent: Control, text: String, rect: Rect2, primary: bool) -> Button:
	var button: Button
	if primary:
		button = CodedButton.make_in_group(text, rect.size, CodedButton.PRIMARY_ACTION_GROUP)
	else:
		button = CodedButton.make(text, rect.size)
	button.position = rect.position
	parent.add_child(button)
	return button


func _build_create_card() -> void:
	var card := _make_panel(_entrance, CREATE_RECT)
	_place_label(card, "部屋を作る", CARD_TITLE_POS, TITLE_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	_place_label(card, "コードを発行して、友達を呼びます", CARD_SUB_POS, SUB_FONT_SIZE, UiPalette.TEXT_MUTED)
	_place_label(card, "持ち時間", TIME_LABEL_POS, BODY_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	_time_on_button = _make_button(card, "あり", TIME_ON_RECT, true)
	_time_on_button.pressed.connect(_set_time_limit.bind(true))
	_time_off_button = _make_button(card, "なし", TIME_OFF_RECT, false)
	_time_off_button.pressed.connect(_set_time_limit.bind(false))
	_time_note = _place_label(card, "", TIME_NOTE_POS, NOTE_FONT_SIZE, UiPalette.TEXT_MUTED)
	_create_button = _make_button(card, "部屋を作る", CREATE_BUTTON_RECT, true)
	_create_button.pressed.connect(_on_create_pressed)


func _build_join_card() -> void:
	var card := _make_panel(_entrance, JOIN_RECT)
	_place_label(card, "コードで参加する", CARD_TITLE_POS, TITLE_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	_place_label(
		card,
		"友達から受け取った%d桁のコードを入力します" % RoomMatch.CODE_LENGTH,
		CARD_SUB_POS,
		SUB_FONT_SIZE,
		UiPalette.TEXT_MUTED
	)
	_join_tiles = CodeTiles.new()
	_join_tiles.position = ENTRY_TILES_RECT.position
	_join_tiles.size = ENTRY_TILES_RECT.size
	card.add_child(_join_tiles)
	_join_tiles.make_editable("ルームコード")
	_join_tiles.submitted.connect(_on_join_pressed)
	_join_pad = NumberPad.make(_join_tiles.input, PAD_KEY_SIZE, false)
	_join_pad.position = PAD_POS
	card.add_child(_join_pad)
	_join_button = _make_button(card, "参加する", JOIN_BUTTON_RECT, true)
	_join_button.pressed.connect(_on_join_pressed)
	_spectate_button = _make_button(card, "観戦する", SPECTATE_BUTTON_RECT, false)
	_spectate_button.pressed.connect(_on_spectate_pressed)


func _build_deck_strip() -> void:
	var strip := _make_panel(_entrance, DECK_RECT)
	_place_label(strip, "使用デッキ", DECK_CAPTION_POS, NOTE_FONT_SIZE, UiPalette.TEXT_MUTED)
	_deck_name_label = _place_label(
		strip, "", DECK_NAME_POS, DECK_NAME_FONT_SIZE, UiPalette.TEXT_OFFWHITE
	)
	_deck_button = _make_button(strip, "デッキを変更", DECK_BUTTON_RECT, false)
	_deck_button.pressed.connect(func() -> void: deck_change_requested.emit())


func _build_code_plate() -> void:
	var plate := _make_panel(_room_view, CODE_RECT)
	_code_caption = _place_label(
		plate, "", CODE_CAPTION_POS, STATUS_FONT_SIZE, UiPalette.TEXT_MUTED
	)
	_code_hint = _place_label(plate, "", CODE_HINT_POS, NOTE_FONT_SIZE, UiPalette.TEXT_MUTED)
	_room_tiles = CodeTiles.new()
	_room_tiles.position = ROOM_TILES_RECT.position
	_room_tiles.size = ROOM_TILES_RECT.size
	plate.add_child(_room_tiles)
	_copy_button = _make_button(plate, "コピー", COPY_BUTTON_RECT, false)
	_copy_button.pressed.connect(_on_copy_pressed)


func _build_seats() -> void:
	_my_seat = RoomSeat.new()
	_my_seat.position = MINE_RECT.position
	_my_seat.size = MINE_RECT.size
	_room_view.add_child(_my_seat)
	_seat_deck_button = _make_button(_my_seat, "変更", RoomSeat.DECK_BUTTON_RECT, false)
	_seat_deck_button.pressed.connect(func() -> void: deck_change_requested.emit())
	_foe_seat = RoomSeat.new()
	_foe_seat.position = FOE_RECT.position
	_foe_seat.size = FOE_RECT.size
	_room_view.add_child(_foe_seat)
	_vs_mark = Control.new()
	_vs_mark.anchor_right = 1.0
	_vs_mark.anchor_bottom = 1.0
	_vs_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vs_mark.draw.connect(_draw_vs)
	_room_view.add_child(_vs_mark)
	_spectate_state = EmptyState.new()
	_spectate_state.position = SEATS_RECT.position
	_spectate_state.size = SEATS_RECT.size
	_room_view.add_child(_spectate_state)


func _draw_vs() -> void:
	var rid := _vs_mark.get_canvas_item()
	UiPaint.fill_circle(rid, VS_CENTER, VS_RADIUS, UiPalette.OUTLINE_DARK, 32)
	UiPaint.draw_ring(rid, VS_CENTER, VS_RADIUS, UiPalette.BRASS_LIGHT, VS_RING, 32)
	_vs_mark.draw_string(
		get_theme_default_font(),
		VS_CENTER + Vector2(-VS_RADIUS, VS_FONT_SIZE * 0.36),
		"VS",
		HORIZONTAL_ALIGNMENT_CENTER,
		VS_RADIUS * 2.0,
		VS_FONT_SIZE,
		UiPalette.BRASS_HIGHLIGHT
	)


func _build_footer() -> void:
	_time_info = _place_label(_room_view, "", TIME_INFO_POS, STATUS_FONT_SIZE, UiPalette.TEXT_MUTED)
	_status_label = _place_label(
		_room_view, "", STATUS_POS, STATUS_FONT_SIZE, UiPalette.TEXT_OFFWHITE
	)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.size = Vector2(STATUS_WIDTH, 0)
	_leave_button = _make_button(_room_view, "", LEAVE_RECT, false)
	_leave_button.pressed.connect(_on_cancel_pressed)
	_start_button = _make_button(_room_view, "対局を開始", START_RECT, true)
	_start_button.pressed.connect(_on_start_pressed)


## 入口へ戻す。message は失敗・キャンセルの文言(無ければ空)。
func _show_entrance(message: String) -> void:
	_role = Role.NONE
	_in_lobby = false
	_starting = false
	_code = ""
	_entrance.visible = true
	_room_view.visible = false
	_set_busy(false)
	_message_label.text = message
	_refresh_settings()


## 部屋の中へ切り替える。コードが決まる前(部屋を作成中)は升を空で出す。
func _show_room(role: Role) -> void:
	_role = role
	_entrance.visible = false
	_room_view.visible = true
	_room_tiles.code = _code
	var spectating := role == Role.SPECTATOR
	_code_caption.text = "観戦するルーム" if spectating else "ルームコード"
	_code_hint.text = "友達に伝えてください" if role == Role.HOST else ""
	_copy_button.visible = role == Role.HOST
	_my_seat.visible = not spectating
	_foe_seat.visible = not spectating
	_vs_mark.visible = not spectating
	if spectating:
		_spectate_state.show_message("対局の開始を待っています", "", true)
	else:
		_spectate_state.hide_message()
		_show_my_seat()
		_foe_seat.show_empty(WAIT_FOE_TEXT, WAIT_FOE_HINT)
	_start_button.visible = role == Role.HOST
	_start_button.disabled = true
	var leave_labels := {Role.HOST: "部屋を閉じる", Role.GUEST: "退出する"}
	_leave_button.text = leave_labels.get(role, "キャンセル")
	var leave_rect := LEAVE_RECT if role == Role.HOST else LEAVE_ALONE_RECT
	_leave_button.position = leave_rect.position
	_leave_button.disabled = false
	_refresh_settings()


func _show_my_seat() -> void:
	_my_seat.show_player(
		"あなた",
		AccountService.display_name_or_default(),
		AccountService.title_id(),
		AccountService.icon_id(),
		_deck_name()
	)


func _deck_name() -> String:
	var decks := CardDeckSave.list_decks()
	if decks.is_empty():
		return "基本(プリセット)"
	return str(decks[clampi(CardDeckSave.selected_index(), 0, decks.size() - 1)]["name"])


## 使用デッキと持ち時間の表示を描き直す。**持ち時間を変えられるのは部屋を作る前だけ**
## (GameDesign.md 5章)。デッキは相手を待っている間も変えられる。
func _refresh_settings() -> void:
	var has_decks := not CardDeckSave.list_decks().is_empty()
	_deck_name_label.text = _deck_name()
	_deck_button.disabled = _busy or not has_decks
	_seat_deck_button.disabled = not has_decks or _starting
	if _my_seat.visible and not _my_seat.empty:
		_my_seat.deck_name = _deck_name()
		_my_seat.queue_redraw()
	var on_group := CodedButton.PRIMARY_ACTION_GROUP if _time_limit else CodedButton.WIDE_GROUP
	var off_group := CodedButton.WIDE_GROUP if _time_limit else CodedButton.PRIMARY_ACTION_GROUP
	CodedButton.apply_styles(_time_on_button, on_group)
	CodedButton.apply_styles(_time_off_button, off_group)
	_time_on_button.disabled = _busy
	_time_off_button.disabled = _busy
	_time_note.text = TIME_ON_NOTE if _time_limit else TIME_OFF_NOTE
	var limit := _room.time_limit if _room != null and _role == Role.GUEST else _time_limit
	_time_info.text = "持ち時間: あり(1手番60秒)" if limit else "持ち時間: なし"
	_time_info.visible = _role != Role.SPECTATOR


func _set_time_limit(enabled: bool) -> void:
	if _busy:
		return
	_time_limit = enabled
	_refresh_settings()


## コピーはブラウザに拒否されることがあるが、**失敗しても画面には何も出さない**
## (GameDesign.md 11章)。コード自体が大きく出ており、手入力で足りるため。
func _on_copy_pressed() -> void:
	if _code != "":
		DisplayServer.clipboard_set(_code)


## 入口で通信を待っている間は、入口の操作をまとめて止める。
func _set_busy(busy: bool) -> void:
	_busy = busy
	_create_button.disabled = busy
	_join_button.disabled = busy
	_spectate_button.disabled = busy
	_join_tiles.set_editable(not busy)
	_join_pad.set_disabled(busy)
	_refresh_settings()


## 部屋のノードを片付ける。参照を外すだけだと、待機のたびに子が積み上がる。
func _discard_session() -> void:
	if is_instance_valid(_room):
		_room.queue_free()
	_room = null


## waiting: 通信を待っている状態。末尾へ巡回ドットが付く。
func _set_status(text: String, waiting := false) -> void:
	_status_base_text = text
	_status_waiting = waiting
	_busy_dot_count = 0
	if waiting:
		_busy_dots_timer.start()
	else:
		_busy_dots_timer.stop()
	_refresh_status_display()


func _refresh_status_display() -> void:
	var dots := ".".repeat(_busy_dot_count) if _status_waiting else ""
	if _entrance.visible:
		_message_label.text = _status_base_text + dots
	else:
		_status_label.text = _status_base_text + dots


func _on_busy_dots_timeout() -> void:
	_busy_dot_count = (_busy_dot_count % EmptyState.DOTS_MAX) + 1
	_refresh_status_display()


func _sign_in_or_fail() -> bool:
	var ok: bool = await NetSession.sign_in()
	if not ok:
		_fail("通信に失敗しました。もう一度お試しください")
	return ok


func _fail(message: String) -> void:
	_discard_session()
	_set_status("")
	_show_entrance(message)


## 入力欄のコードを取り出す。桁数の合わない入力は空文字にして呼び出し側で弾く
## (4桁しかないため、打ち間違いをそのまま通信させる意味がない)。
func _room_code_input() -> String:
	var code := _join_tiles.code
	return code if code.length() == RoomMatch.CODE_LENGTH else ""


func _new_room() -> RoomMatch:
	_room = RoomMatch.new(NetSession.client, NetSession.auth)
	add_child(_room)
	return _room


func _on_back_pressed() -> void:
	if _busy or _role != Role.NONE:
		_on_cancel_pressed()
	# 画面を出た後まで「キャンセルしました」を残さない。
	_message_label.text = ""
	back_pressed.emit()


func _on_create_pressed() -> void:
	if _busy:
		return
	_set_busy(true)
	_set_status("部屋を作成中", true)
	if not await _sign_in_or_fail():
		return
	var room := _new_room()
	room.room_created.connect(_on_room_created)
	room.matched.connect(_on_matched)
	room.room_ready.connect(_on_room_ready)
	room.room_closed.connect(_on_room_closed)
	room.join_failed.connect(_on_join_failed)
	room.create_room(_time_limit)


func _on_join_pressed() -> void:
	if _busy:
		return
	var code := _room_code_input()
	if code == "":
		_message_label.text = "ルームコードは%d桁の数字です" % RoomMatch.CODE_LENGTH
		return
	_set_busy(true)
	_set_status("参加中", true)
	if not await _sign_in_or_fail():
		return
	_code = code
	var room := _new_room()
	room.matched.connect(_on_matched)
	room.room_ready.connect(_on_room_ready)
	room.room_closed.connect(_on_room_closed)
	room.join_failed.connect(_on_join_failed)
	room.join_room(code)


## 観戦は、対局がまだ始まっていなければ部屋の中で待つ(GameDesign.md 11章)。
func _on_spectate_pressed() -> void:
	if _busy:
		return
	var code := _room_code_input()
	if code == "":
		_message_label.text = "ルームコードは%d桁の数字です" % RoomMatch.CODE_LENGTH
		return
	_set_busy(true)
	_set_status("観戦先を確認中", true)
	if not await _sign_in_or_fail():
		return
	_code = code
	var room := _new_room()
	room.spectate_ready.connect(_on_spectate_ready)
	room.spectate_waiting.connect(_on_spectate_waiting)
	room.spectate_failed.connect(_on_spectate_failed)
	room.spectate(code)


## **キャンセルは押した瞬間に効かせ、後片付け(通信)の完了は待たない**
## (応答が遅いと「押しても何も起きない」ように見えるため)。
func _on_cancel_pressed() -> void:
	var room := _room
	_room = null
	var was_waiting := _busy or _role != Role.NONE
	_set_status("")
	_show_entrance("キャンセルしました" if was_waiting else "")
	if room != null:
		await room.cancel()
		room.queue_free()


func _on_room_created(code: String) -> void:
	_code = code
	_busy = false
	_set_status("")
	_show_room(Role.HOST)


## 両者が入室した後のロビー。ここではまだ対局画面へ遷移しない。
func _on_room_ready(_match_id: String, opponent_uid: String, is_host: bool) -> void:
	_busy = false
	if not is_host:
		_set_status("")
		_show_room(Role.GUEST)
	_in_lobby = true
	_start_button.disabled = false
	_set_status("相手が入室しました。準備ができたら開始してください" if is_host else "ホストの開始を待っています", not is_host)
	_fill_foe_seat(opponent_uid)
	_refresh_settings()


## 相手の席をプロフィールで埋める。読み終える前に部屋を出ていたら描かない
## (古い応答で次の部屋の席を上書きしないため)。
func _fill_foe_seat(opponent_uid: String) -> void:
	var room := _room
	_foe_seat.show_player("相手", LOADING_FOE_NAME, UserProfileLibrary.DEFAULT_TITLE_ID, "", "")
	var profile: Dictionary = await AccountService.fetch_profile(NetSession.client, opponent_uid)
	if room != _room or not _in_lobby:
		return
	var name := str(profile.get("display_name", ""))
	_foe_seat.show_player(
		"相手",
		name if name != "" else FOE_FALLBACK_NAME,
		str(profile.get("title_id", UserProfileLibrary.DEFAULT_TITLE_ID)),
		str(profile.get("icon_id", UserProfileLibrary.DEFAULT_ICON_ID)),
		""
	)


func _on_start_pressed() -> void:
	if not _in_lobby or _role != Role.HOST or _room == null:
		return
	_set_starting(true)
	_set_status("対局を開始しています", true)
	if not await _room.start_room():
		_set_starting(false)
		_set_status("開始できませんでした。もう一度お試しください")


func _set_starting(starting: bool) -> void:
	_starting = starting
	_start_button.disabled = starting
	_leave_button.disabled = starting
	_refresh_settings()


func _on_room_closed() -> void:
	_fail("ルームが閉じられました")


func _on_spectate_waiting() -> void:
	_busy = false
	_set_status("")
	_show_room(Role.SPECTATOR)


func _on_spectate_ready(match_id: String) -> void:
	_busy = false
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
	_in_lobby = false
	_set_status("対戦相手が見つかりました!")
	matched.emit(match_id, my_side, opponent_uid, time_limit)
