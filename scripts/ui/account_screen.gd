class_name AccountScreen
extends Control
## アカウントの状態確認・表示名の変更・アイコン/称号設定・登録・ログイン・ログアウトを行う画面
## (GameDesign.md 14章、Architecture.md 10.5)。
## タイトル画面とホーム画面の両方から開く。

signal back_pressed
## 表示名・残高・アイコン・称号が変わったことを通知する。ホーム画面のヘッダーが購読する。
signal profile_changed

const OK_COLOR := Color(0.62, 0.86, 0.6, 1)
const ERROR_COLOR := Color(1, 0.55, 0.5, 1)
const HINT_COLOR := Color(0.86, 0.82, 0.74, 1)

var _busy := false
var _selected_icon_id := UserProfileLibrary.DEFAULT_ICON_ID
var _selected_title_id := UserProfileLibrary.DEFAULT_TITLE_ID

var _icon_buttons: Dictionary = {}
var _title_buttons: Dictionary = {}
var _preview: ProfilePreviewPlate

@onready var screen_header: ScreenHeader = $ScreenHeader
@onready var vbox: VBoxContainer = $Panel/Margin/VBox
@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel
@onready var currency_label: Label = $Panel/Margin/VBox/CurrencyLabel
@onready var name_row: HBoxContainer = $Panel/Margin/VBox/NameRow
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
	name_save_button.pressed.connect(_on_profile_save_pressed)
	name_save_button.text = "保存"
	register_button.pressed.connect(_on_register_pressed)
	login_button.pressed.connect(_on_login_pressed)
	logout_button.pressed.connect(_on_logout_pressed)

	_setup_customization_ui()


func _setup_customization_ui() -> void:
	# NameRowの手前にアイコン選択・称号選択・プレビューを挿入する
	var name_index := name_row.get_index()

	# 1. プレビュー行
	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 10)
	var preview_caption := Label.new()
	preview_caption.custom_minimum_size = Vector2(110, 0)
	preview_caption.add_theme_font_size_override("font_size", 18)
	preview_caption.text = "名札見本"
	preview_row.add_child(preview_caption)
	_preview = ProfilePreviewPlate.new()
	preview_row.add_child(_preview)
	vbox.add_child(preview_row)
	vbox.move_child(preview_row, name_index)
	name_index += 1

	# 2. アイコン選択行
	var icon_row := HBoxContainer.new()
	icon_row.add_theme_constant_override("separation", 10)
	var icon_caption := Label.new()
	icon_caption.custom_minimum_size = Vector2(110, 0)
	icon_caption.add_theme_font_size_override("font_size", 18)
	icon_caption.text = "アイコン"
	icon_row.add_child(icon_caption)

	var icon_container := HBoxContainer.new()
	icon_container.add_theme_constant_override("separation", 6)
	for icon_id in UserProfileLibrary.get_available_icon_ids():
		var btn := IconButton.new(icon_id)
		btn.pressed.connect(func() -> void: _on_icon_selected(icon_id))
		icon_container.add_child(btn)
		_icon_buttons[icon_id] = btn
	icon_row.add_child(icon_container)
	vbox.add_child(icon_row)
	vbox.move_child(icon_row, name_index)
	name_index += 1

	# 3. 称号選択行
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	var title_caption := Label.new()
	title_caption.custom_minimum_size = Vector2(110, 0)
	title_caption.add_theme_font_size_override("font_size", 18)
	title_caption.text = "称号"
	title_row.add_child(title_caption)

	var title_container := HBoxContainer.new()
	title_container.add_theme_constant_override("separation", 8)
	for title_id in UserProfileLibrary.get_available_title_ids():
		var btn := Button.new()
		btn.text = UserProfileLibrary.get_title_name(title_id)
		btn.add_theme_font_size_override("font_size", 16)
		btn.custom_minimum_size = Vector2(140, 36)
		btn.pressed.connect(func() -> void: _on_title_selected(title_id))
		title_container.add_child(btn)
		_title_buttons[title_id] = btn
	title_row.add_child(title_container)
	vbox.add_child(title_row)
	vbox.move_child(title_row, name_index)


## 画面を開くたびにMainが呼ぶ。サインインが済んでいなければここで済ませる。
func refresh() -> void:
	_set_busy(true)
	_set_message("接続しています…", HINT_COLOR)
	var ok: bool = await NetSession.sign_in()
	_set_busy(false)
	if not ok:
		_set_message(
			"接続できませんでした(%s)。オフラインのままでも遊べます。" % NetSession.last_error,
			ERROR_COLOR
		)
	else:
		_set_message("", HINT_COLOR)
	_selected_icon_id = AccountService.icon_id()
	_selected_title_id = AccountService.title_id()
	_refresh_view()


func _refresh_view() -> void:
	var registered: bool = NetSession.auth != null and NetSession.auth.is_registered()
	if registered:
		status_label.text = "ログイン中:%s" % NetSession.auth.login_id
	else:
		status_label.text = "未登録(この端末のゲストとして遊んでいます)"
	currency_label.text = "%s:%d" % [CurrencyRules.CURRENCY_NAME, AccountService.currency()]
	name_input.text = AccountService.display_name()

	# アイコン選択ボタンのハイライト更新
	for id in _icon_buttons:
		var btn: IconButton = _icon_buttons[id]
		btn.is_selected = (id == _selected_icon_id)
		btn.queue_redraw()

	# 称号ボタンのハイライト更新
	for id in _title_buttons:
		var btn: Button = _title_buttons[id]
		if id == _selected_title_id:
			btn.add_theme_color_override("font_color", UiPalette.GLOW_AMBER)
		else:
			btn.remove_theme_color_override("font_color")

	# プレビュー更新
	_update_preview()

	# 登録済みならIDとパスワードの入力欄は不要。代わりにログアウトを出す
	credential_box.visible = not registered
	logout_button.visible = registered
	profile_changed.emit()


func _on_icon_selected(icon_id: String) -> void:
	_selected_icon_id = icon_id
	for id in _icon_buttons:
		_icon_buttons[id].is_selected = (id == _selected_icon_id)
		_icon_buttons[id].queue_redraw()
	_update_preview()


func _on_title_selected(title_id: String) -> void:
	_selected_title_id = title_id
	for id in _title_buttons:
		var btn: Button = _title_buttons[id]
		if id == _selected_title_id:
			btn.add_theme_color_override("font_color", UiPalette.GLOW_AMBER)
		else:
			btn.remove_theme_color_override("font_color")
	_update_preview()


func _update_preview() -> void:
	if _preview != null:
		_preview.display_name = name_input.text
		_preview.icon_id = _selected_icon_id
		_preview.title_id = _selected_title_id
		_preview.queue_redraw()


func _on_name_text_changed(text: String) -> void:
	var kept := TextGlyphs.sanitize(text)
	if kept != text:
		var caret := maxi(name_input.caret_column - (text.length() - kept.length()), 0)
		name_input.text = kept
		name_input.caret_column = caret
		_set_message("この文字は使えません(絵文字などは表示できません)。", ERROR_COLOR)
	_update_preview()


func _on_profile_save_pressed() -> void:
	if _busy:
		return
	_set_busy(true)
	var uid := NetSession.auth.uid if NetSession.auth != null else ""
	var ok: bool = await AccountService.save_profile(
		NetSession.client, uid, name_input.text, _selected_icon_id, _selected_title_id
	)
	_set_busy(false)
	if ok:
		_set_message("プロフィールを保存しました。", OK_COLOR)
	else:
		_set_message("プロフィールの保存に失敗しました。接続を確認してください。", ERROR_COLOR)
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


## アイコン選択用ボタン
class IconButton extends Button:
	var icon_id: String
	var is_selected := false

	func _init(p_icon_id: String) -> void:
		icon_id = p_icon_id
		custom_minimum_size = Vector2(40, 40)
		flat = true

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var center := rect.position + rect.size * 0.5
		var bg_color := Color(0.12, 0.1, 0.08, 0.9)
		draw_circle(center, 18.0, bg_color)
		var tex := UserProfileLibrary.get_icon_texture(icon_id)
		if tex != null:
			draw_texture_rect(tex, Rect2(center - Vector2(14, 14), Vector2(28, 28)), false)
		if is_selected:
			draw_arc(center, 18.0, 0.0, TAU, 24, UiPalette.GLOW_AMBER, 2.5)
		else:
			draw_arc(center, 18.0, 0.0, TAU, 24, UiPalette.BRASS_MID, 1.0)


## 名札見本プレビュー
class ProfilePreviewPlate extends Control:
	var display_name := ""
	var icon_id := ""
	var title_id := ""
	var font: Font

	func _ready() -> void:
		custom_minimum_size = Vector2(160, 42)
		font = get_theme_default_font()
		if font == null:
			font = ThemeDB.fallback_font

	func _draw() -> void:
		var rect := Rect2(0, 0, 160, 40)
		var points := UiPaint.rounded_rect_points_uniform(rect, 6.0, 5)
		UiPaint.fill_gradient_polygon(
			get_canvas_item(),
			points,
			rect,
			[[0.0, UiPalette.NAMEPLATE_PANEL_TOP], [1.0, UiPalette.NAMEPLATE_PANEL_BOTTOM]]
		)
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, UiPalette.BRASS_LIGHT, 1.5, true)

		var icon_rect := Rect2(6, 6, 28, 28)
		var icon_center := icon_rect.position + icon_rect.size * 0.5
		var icon_tex := UserProfileLibrary.get_icon_texture(icon_id)
		if icon_tex != null:
			draw_texture_rect(icon_tex, icon_rect, false)
		draw_arc(icon_center, 14.5, 0.0, TAU, 20, UiPalette.BRASS_LIGHT, 1.5)

		var title_text := UserProfileLibrary.get_title_display(title_id)
		var label := display_name.strip_edges()
		if label.is_empty():
			label = "ゲスト"
		var text_x := 40.0
		if not title_text.is_empty():
			draw_string(
				font,
				Vector2(text_x, 16),
				title_text,
				HORIZONTAL_ALIGNMENT_LEFT,
				110,
				11,
				UiPalette.BRASS_HIGHLIGHT
			)
			draw_string(
				font,
				Vector2(text_x, 32),
				label,
				HORIZONTAL_ALIGNMENT_LEFT,
				110,
				15,
				UiPalette.TEXT_OFFWHITE
			)
		else:
			draw_string(
				font,
				Vector2(text_x, 26),
				label,
				HORIZONTAL_ALIGNMENT_LEFT,
				110,
				17,
				UiPalette.TEXT_OFFWHITE
			)
