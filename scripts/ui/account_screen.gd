class_name AccountScreen
extends Control
## アカウント画面(GameDesign.md 14章、Architecture.md 10.5)。
## 左 = 自分とアカウント(見本・表示名・状態・登録/ログイン)、右 = 見た目を選ぶ4つのタブ。
## 選んだものはその場で保存する(保存ボタンを置かない)。

signal back_pressed
## 表示名・残高・アイコン・称号が変わったことを通知する。ホーム画面のヘッダーが購読する。
signal profile_changed

const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const OK_COLOR := Color(0.62, 0.86, 0.6, 1)
const ERROR_COLOR := Color(1, 0.55, 0.5, 1)
const WARNING_COLOR := Color(1, 0.72, 0.45, 1)
## パネルの横位置は画面中央からの距離で持つ(左520px・右696px、間16px)。
const LEFT_PANEL_X := Vector2(-616, -96)
const RIGHT_PANEL_X := Vector2(-80, 616)
const PANEL_TOP := 128.0
const PANEL_BOTTOM_MARGIN := 24.0
const PREVIEW_HEIGHT := 150
const NAME_CAPTION_WIDTH := 70
const STATUS_FONT_SIZE := 19
const SMALL_FONT_SIZE := 14
const ACCOUNT_BUTTON_SIZE := Vector2(220, 50)
const DISCORD_BUTTON_SIZE := Vector2(220, 42)
## 選んでから保存するまでの待ち。続けて選び直したときに書き込みを重ねない。
const SAVE_DELAY := 0.5

var _busy := false
var _selected_icon_id := UserProfileLibrary.DEFAULT_ICON_ID
var _selected_title_id := UserProfileLibrary.DEFAULT_TITLE_ID
## いま敷くプレイマット(GameDesign.md 9章・14章)。ショップは買う場所であって
## 設定する場所を兼ねないため、選ぶのはここ。
var _selected_playmat_id := PlaymatLibrary.DEFAULT_ID
var _saving := false
var _save_again := false

var _preview: AccountTablePreview
var _name_input: LineEdit
var _status_label: Label
var _currency_label: Label
var _note_label: Label
var _message_label: Label
var _guest_row: HBoxContainer
var _member_row: HBoxContainer
var _account_buttons: Array[Button] = []
var _discord_label: Label
var _looks: AccountLooksTabs
var _save_label: Label
var _dialog: AccountCredentialDialog
var _save_timer: Timer

@onready var screen_header: ScreenHeader = $ScreenHeader


func _ready() -> void:
	screen_header.set_title("アカウント")
	screen_header.back_pressed.connect(_on_back_pressed)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.timeout.connect(_save_profile)
	add_child(_save_timer)
	_build_left(_panel(LEFT_PANEL_X))
	_build_right(_panel(RIGHT_PANEL_X))
	_dialog = AccountCredentialDialog.new()
	_dialog.submitted.connect(_on_credentials_submitted)
	# モーダルは最後の子へ置く(後から足した子ほど手前に描かれる)。
	add_child(_dialog)


## 画面を開くたびにMainが呼ぶ。サインインが済んでいなければここで済ませる。
func refresh() -> void:
	_set_busy(true)
	_set_message("接続しています…", UiPalette.TEXT_MUTED)
	_save_label.text = ""
	var ok: bool = await NetSession.sign_in()
	_set_busy(false)
	if not ok:
		_set_message("接続できませんでした(%s)。オフラインのままでも遊べます。" % NetSession.last_error, ERROR_COLOR)
	else:
		_set_message("", UiPalette.TEXT_MUTED)
	_load_from_account()


## 保存済みの値を画面へ読み込む(開いたとき・ログインやログアウトでアカウントが変わったとき)。
func _load_from_account() -> void:
	_selected_icon_id = AccountService.icon_id()
	_selected_title_id = AccountService.title_id()
	_selected_playmat_id = AccountService.playmat_id()
	_name_input.text = AccountService.display_name()
	_looks.reload(_selected_icon_id, _selected_title_id, _selected_playmat_id)
	_discord_label.text = ""
	_refresh_account()
	_update_preview()


func _refresh_account() -> void:
	var registered: bool = NetSession.auth != null and NetSession.auth.is_registered()
	_currency_label.text = CurrencyRules.label_text(AccountService.currency())
	if registered:
		_status_label.text = "ID: %s でログイン中" % NetSession.auth.login_id
		_note_label.text = "別の端末やブラウザからも、このIDとパスワードで続きを遊べます。"
		_note_label.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	else:
		_status_label.text = "ゲストで遊んでいます"
		_note_label.text = "ゲストの記録と砂金は、このブラウザにだけ残ります。ブラウザのデータを消すと失われます。IDを登録すると、別の端末からも続きを遊べます。"
		_note_label.add_theme_color_override("font_color", WARNING_COLOR)
	_guest_row.visible = not registered
	_member_row.visible = registered
	profile_changed.emit()


func _update_preview() -> void:
	_preview.show_profile(
		_name_input.text, _selected_icon_id, _selected_title_id, _selected_playmat_id
	)


# ---------------------------------------------------------------- 見た目の選択と保存


func _on_icon_selected(icon_id: String) -> void:
	_selected_icon_id = icon_id
	_on_looks_changed()


func _on_title_selected(title_id: String) -> void:
	_selected_title_id = title_id
	_on_looks_changed()


func _on_playmat_selected(mat_id: String) -> void:
	_selected_playmat_id = mat_id
	_on_looks_changed()


func _on_looks_changed() -> void:
	_looks.mark_selected(_selected_icon_id, _selected_title_id, _selected_playmat_id)
	_update_preview()
	_preview.bump()
	_save_timer.start()


func _on_name_text_changed(text: String) -> void:
	var kept := TextGlyphs.sanitize(text)
	if kept != text:
		var caret := maxi(_name_input.caret_column - (text.length() - kept.length()), 0)
		_name_input.text = kept
		_name_input.caret_column = caret
		_set_message("この文字は使えません(絵文字などは表示できません)。", ERROR_COLOR)
	_update_preview()


## 表示名は入力欄から離れたとき・Enterで保存する(1文字ごとに書き込まない)。
func _commit_name() -> void:
	if _name_input.text.strip_edges() != AccountService.display_name():
		_save_timer.stop()
		_save_profile()


## 戻るときは待ちを打ち切ってすぐ保存する(待ちの間に離れても選んだものを消さない)。
func _on_back_pressed() -> void:
	if not _save_timer.is_stopped():
		_save_timer.stop()
		_save_profile()
	else:
		_commit_name()
	_dialog.visible = false
	back_pressed.emit()


func _save_profile() -> void:
	if _saving:
		_save_again = true
		return
	_saving = true
	var uid := NetSession.auth.uid if NetSession.auth != null else ""
	var ok: bool = await AccountService.save_profile(
		NetSession.client,
		uid,
		_name_input.text,
		_selected_icon_id,
		_selected_title_id,
		_selected_playmat_id
	)
	_saving = false
	_show_saved(ok)
	profile_changed.emit()
	if _save_again:
		_save_again = false
		_save_profile()


func _show_saved(ok: bool) -> void:
	if ok:
		_save_label.text = "保存しました"
		_save_label.add_theme_color_override("font_color", OK_COLOR)
	else:
		_save_label.text = "保存できませんでした。接続を確認してください。"
		_save_label.add_theme_color_override("font_color", ERROR_COLOR)


# ---------------------------------------------------------------- アカウント


func _open_dialog(mode: AccountCredentialDialog.Mode) -> void:
	if _busy:
		return
	var registered: bool = NetSession.auth != null and NetSession.auth.is_registered()
	_dialog.open(mode, -1 if registered else AccountService.currency())


func _on_credentials_submitted(
	mode: AccountCredentialDialog.Mode, login_id: String, password: String
) -> void:
	_set_busy(true)
	var error: String
	if mode == AccountCredentialDialog.Mode.REGISTER:
		error = await NetSession.register(login_id, password)
	else:
		error = await NetSession.log_in(login_id, password)
	_set_busy(false)
	_dialog.finish(error)
	if not error.is_empty():
		return
	if mode == AccountCredentialDialog.Mode.REGISTER:
		_set_message("登録しました。次からはこのIDとパスワードでログインできます。", OK_COLOR)
		_refresh_account()
	else:
		_set_message("ログインしました。", OK_COLOR)
		_load_from_account()


func _on_logout_pressed() -> void:
	if _busy:
		return
	_set_busy(true)
	_set_message("ログアウトしています…", UiPalette.TEXT_MUTED)
	await NetSession.log_out()
	_set_busy(false)
	_set_message("ログアウトしました。ゲストとして遊べます。", OK_COLOR)
	_load_from_account()


func _on_discord_link_pressed() -> void:
	if _busy:
		return
	_set_busy(true)
	_discord_label.text = "発行しています…"
	var uid := NetSession.auth.uid if NetSession.auth != null else ""
	var code: String = await DiscordLinkService.publish_code(NetSession.client, uid)
	_set_busy(false)
	if code.is_empty():
		_discord_label.text = ""
		_set_message("連携コードの発行に失敗しました。接続を確認してください。", ERROR_COLOR)
	else:
		_discord_label.text = "コード: %s" % code
		_set_message("Discordで「/link %s」と入力してください。" % code, OK_COLOR)


func _set_busy(value: bool) -> void:
	_busy = value
	for button in _account_buttons:
		button.disabled = value


func _set_message(text: String, color: Color) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", color)


# ---------------------------------------------------------------- 組み立て


func _panel(x_range: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", load(PANEL_STYLE))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = x_range.x
	panel.offset_right = x_range.y
	panel.offset_top = PANEL_TOP
	panel.offset_bottom = -PANEL_BOTTOM_MARGIN
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	return column


func _build_left(column: VBoxContainer) -> void:
	column.add_child(_label("対局ではこう見えます", SMALL_FONT_SIZE, UiPalette.TEXT_MUTED))
	_preview = AccountTablePreview.new()
	_preview.custom_minimum_size = Vector2(0, PREVIEW_HEIGHT)
	column.add_child(_preview)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	column.add_child(name_row)
	var caption := _label("表示名", 16, UiPalette.TEXT_OFFWHITE)
	caption.custom_minimum_size = Vector2(NAME_CAPTION_WIDTH, 0)
	name_row.add_child(caption)
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "10文字まで"
	_name_input.max_length = AccountService.DISPLAY_NAME_MAX_LENGTH
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.text_changed.connect(_on_name_text_changed)
	_name_input.text_submitted.connect(func(_text: String) -> void: _commit_name())
	_name_input.focus_exited.connect(_commit_name)
	MobileTextInput.wire(_name_input, "表示名")
	name_row.add_child(_name_input)

	column.add_child(HSeparator.new())
	var status_row := HBoxContainer.new()
	column.add_child(status_row)
	_status_label = _label("", STATUS_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(_status_label)
	_currency_label = _label("", STATUS_FONT_SIZE, UiPalette.BRASS_HIGHLIGHT)
	status_row.add_child(_currency_label)
	_note_label = _wrapping_label(SMALL_FONT_SIZE)
	column.add_child(_note_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	_message_label = _wrapping_label(SMALL_FONT_SIZE)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_message_label)

	_guest_row = _button_row(column)
	var register := CodedButton.make_in_group(
		"IDを登録する", ACCOUNT_BUTTON_SIZE, CodedButton.PRIMARY_ACTION_GROUP
	)
	register.pressed.connect(_open_dialog.bind(AccountCredentialDialog.Mode.REGISTER))
	_add_account_button(_guest_row, register)
	var login := CodedButton.make("登録済みのIDで入る", ACCOUNT_BUTTON_SIZE)
	login.pressed.connect(_open_dialog.bind(AccountCredentialDialog.Mode.LOGIN))
	_add_account_button(_guest_row, login)

	_member_row = _button_row(column)
	var logout := CodedButton.make("ログアウト", ACCOUNT_BUTTON_SIZE)
	logout.pressed.connect(_on_logout_pressed)
	_add_account_button(_member_row, logout)

	var discord_row := _button_row(column)
	var discord := CodedButton.make("Discordと連携", DISCORD_BUTTON_SIZE)
	discord.pressed.connect(_on_discord_link_pressed)
	_add_account_button(discord_row, discord)
	_discord_label = _label("", 16, UiPalette.BRASS_HIGHLIGHT)
	discord_row.add_child(_discord_label)


func _build_right(column: VBoxContainer) -> void:
	_looks = AccountLooksTabs.new()
	_looks.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_looks.icon_selected.connect(_on_icon_selected)
	_looks.title_selected.connect(_on_title_selected)
	_looks.playmat_selected.connect(_on_playmat_selected)
	_looks.emote_saved.connect(_show_saved)
	column.add_child(_looks)
	var foot := HBoxContainer.new()
	column.add_child(foot)
	_save_label = _label("", SMALL_FONT_SIZE, OK_COLOR)
	_save_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_save_label)
	foot.add_child(_label("選ぶとすぐに反映され、保存されます", SMALL_FONT_SIZE, UiPalette.TEXT_MUTED))


func _button_row(parent: Container) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	return row


func _add_account_button(row: HBoxContainer, button: Button) -> void:
	row.add_child(button)
	_account_buttons.append(button)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _wrapping_label(font_size: int) -> Label:
	var label := Label.new()
	# 折り返しは幅が決まる前に立てる(Pitfalls「autowrap_mode は size より先に」)。
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	return label
