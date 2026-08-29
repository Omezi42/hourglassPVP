class_name AccountScreen
extends Control
## アカウントの状態確認・表示名の変更・登録・ログイン・ログアウトを行う画面
## (GameDesign.md 14章、Architecture.md 10.5)。
## タイトル画面とホーム画面の両方から開く。
##
## 認証と`players/{uid}`の読み書きは`NetSession`/`AccountService`が持ち、
## この画面は入力を渡して結果の文言を出すだけに留める。

signal back_pressed
## 表示名・残高が変わったことを通知する。ホーム画面のヘッダーが購読する。
signal profile_changed

const OK_COLOR := Color(0.62, 0.86, 0.6, 1)
const ERROR_COLOR := Color(1, 0.55, 0.5, 1)
const HINT_COLOR := Color(0.86, 0.82, 0.74, 1)

var _busy := false

@onready var screen_header: ScreenHeader = $ScreenHeader
@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel
@onready var currency_label: Label = $Panel/Margin/VBox/CurrencyLabel
@onready var name_input: LineEdit = $Panel/Margin/VBox/NameRow/NameInput
@onready var name_save_button: Button = $Panel/Margin/VBox/NameRow/NameSaveButton
@onready var credential_box: VBoxContainer = $Panel/Margin/VBox/CredentialBox
@onready var id_input: LineEdit = $Panel/Margin/VBox/CredentialBox/IdRow/IdInput
@onready var password_input: LineEdit = $Panel/Margin/VBox/CredentialBox/PasswordRow/PasswordInput
@onready var register_button: Button = $Panel/Margin/VBox/CredentialBox/ButtonRow/RegisterButton
@onready var login_button: Button = $Panel/Margin/VBox/CredentialBox/ButtonRow/LoginButton
@onready var logout_button: Button = $Panel/Margin/VBox/LogoutButton
@onready var message_label: Label = $Panel/Margin/VBox/MessageLabel


func _ready() -> void:
	screen_header.set_title("アカウント")
	screen_header.back_pressed.connect(func() -> void: back_pressed.emit())
	name_input.max_length = AccountService.DISPLAY_NAME_MAX_LENGTH
	name_input.text_changed.connect(_on_name_text_changed)
	id_input.max_length = FirebaseAuth.ID_MAX_LENGTH
	name_save_button.pressed.connect(_on_name_save_pressed)
	register_button.pressed.connect(_on_register_pressed)
	login_button.pressed.connect(_on_login_pressed)
	logout_button.pressed.connect(_on_logout_pressed)


## 画面を開くたびにMainが呼ぶ。サインインが済んでいなければここで済ませる。
func refresh() -> void:
	_set_busy(true)
	_set_message("接続しています…", HINT_COLOR)
	var ok: bool = await NetSession.sign_in()
	_set_busy(false)
	if not ok:
		# 原因を添えないと「接続できませんでした」だけが出て切り分けようがない
		_set_message("接続できませんでした(%s)。オフラインのままでも遊べます。" % NetSession.last_error, ERROR_COLOR)
	else:
		_set_message("", HINT_COLOR)
	_refresh_view()


func _refresh_view() -> void:
	var registered: bool = NetSession.auth != null and NetSession.auth.is_registered()
	if registered:
		status_label.text = "ログイン中:%s" % NetSession.auth.login_id
	else:
		status_label.text = "未登録(この端末のゲストとして遊んでいます)"
	currency_label.text = "%s:%d" % [CurrencyRules.CURRENCY_NAME, AccountService.currency()]
	name_input.text = AccountService.display_name()
	# 登録済みならIDとパスワードの入力欄は不要。代わりにログアウトを出す
	credential_box.visible = not registered
	logout_button.visible = registered
	profile_changed.emit()


## 同梱フォントに字形が無い文字(絵文字など)は受け付けない(GameDesign.md 14章)。
## 黙って消すと打ち間違いに見えるため、取り除いたことを1行で伝える。
func _on_name_text_changed(text: String) -> void:
	var kept := TextGlyphs.sanitize(text)
	if kept == text:
		return
	var caret := maxi(name_input.caret_column - (text.length() - kept.length()), 0)
	name_input.text = kept
	name_input.caret_column = caret
	_set_message("この文字は使えません(絵文字などは表示できません)。", ERROR_COLOR)


func _on_name_save_pressed() -> void:
	if _busy:
		return
	_set_busy(true)
	var ok: bool = await AccountService.save_display_name(
		NetSession.client, NetSession.auth.uid, name_input.text
	)
	_set_busy(false)
	if ok:
		_set_message("表示名を保存しました。", OK_COLOR)
	else:
		_set_message("表示名を保存できませんでした。接続を確認してください。", ERROR_COLOR)
	_refresh_view()


func _on_register_pressed() -> void:
	if _busy:
		return
	_set_busy(true)
	_set_message("登録しています…", HINT_COLOR)
	var error: String = await NetSession.register(id_input.text, password_input.text)
	_set_busy(false)
	if error == "":
		password_input.text = ""
		_set_message("登録しました。次からはこのIDとパスワードでログインできます。", OK_COLOR)
	else:
		_set_message(error, ERROR_COLOR)
	_refresh_view()


func _on_login_pressed() -> void:
	if _busy:
		return
	_set_busy(true)
	_set_message("ログインしています…", HINT_COLOR)
	var error: String = await NetSession.log_in(id_input.text, password_input.text)
	_set_busy(false)
	if error == "":
		password_input.text = ""
		_set_message("ログインしました。", OK_COLOR)
	else:
		_set_message(error, ERROR_COLOR)
	_refresh_view()


func _on_logout_pressed() -> void:
	if _busy:
		return
	_set_busy(true)
	_set_message("ログアウトしています…", HINT_COLOR)
	await NetSession.log_out()
	_set_busy(false)
	id_input.text = ""
	password_input.text = ""
	_set_message("ログアウトしました。ゲストとして遊べます。", OK_COLOR)
	_refresh_view()


func _set_busy(value: bool) -> void:
	_busy = value
	name_save_button.disabled = value
	register_button.disabled = value
	login_button.disabled = value
	logout_button.disabled = value


func _set_message(text: String, color: Color) -> void:
	message_label.text = text
	message_label.add_theme_color_override("font_color", color)
