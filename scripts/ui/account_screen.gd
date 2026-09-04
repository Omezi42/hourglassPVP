class_name AccountScreen
extends Control
## アカウントの状態確認・表示名の変更・アイコン/称号設定・登録・ログイン・ログアウトを行う画面
## (GameDesign.md 14章、Architecture.md 10.5)。
## 2カラム構成(左: プロフィール設定 / 右: アカウント管理)。

signal back_pressed
## 表示名・残高・アイコン・称号が変わったことを通知する。ホーム画面のヘッダーが購読する。
signal profile_changed

const OK_COLOR := Color(0.62, 0.86, 0.6, 1)
const ERROR_COLOR := Color(1, 0.55, 0.5, 1)
const HINT_COLOR := Color(0.86, 0.82, 0.74, 1)
## アイコン一覧の高さ。初期の8種(2行)がちょうど収まり、買って増えたぶんは
## スクロールで受ける。
const ICON_SCROLL_HEIGHT := 108

var _busy := false
var _selected_icon_id := UserProfileLibrary.DEFAULT_ICON_ID
var _selected_title_id := UserProfileLibrary.DEFAULT_TITLE_ID
## いま敷くプレイマット(GameDesign.md 9章・14章)。ショップは買う場所であって
## 設定する場所を兼ねないため、選ぶのはここ。
var _selected_playmat_id := PlaymatLibrary.DEFAULT_ID

var _icon_buttons: Dictionary = {}
var _playmat_row: HBoxContainer
var _title_buttons: Dictionary = {}
var _preview: ProfilePreviewPlate

var _profile_save_button: Button
var _emote_button: Button
var _emote_panel: EmoteSlotPanel
var _register_button: Button
var _login_button: Button
var _logout_button: Button

@onready var screen_header: ScreenHeader = $ScreenHeader
@onready
var preview_container: Control = $Panel/Margin/Columns/LeftColumn/PreviewRow/PreviewContainer
@onready var name_input: LineEdit = $Panel/Margin/Columns/LeftColumn/NameRow/NameInput
@onready var icon_grid: GridContainer = $Panel/Margin/Columns/LeftColumn/IconGrid
@onready var title_list: VBoxContainer = $Panel/Margin/Columns/LeftColumn/TitleScroll/TitleList
@onready var save_row: CenterContainer = $Panel/Margin/Columns/LeftColumn/SaveRow

@onready var status_label: Label = $Panel/Margin/Columns/RightColumn/StatusLabel
@onready var currency_label: Label = $Panel/Margin/Columns/RightColumn/CurrencyLabel
@onready var credential_box: VBoxContainer = $Panel/Margin/Columns/RightColumn/CredentialBox
@onready var id_input: LineEdit = $Panel/Margin/Columns/RightColumn/CredentialBox/IdRow/IdInput
# ノードのパスが1行に収まらないため、1つ上の欄から辿る。
@onready var password_input: LineEdit = credential_box.get_node("PasswordRow/PasswordInput")
@onready var button_row: HBoxContainer = $Panel/Margin/Columns/RightColumn/CredentialBox/ButtonRow
@onready var logout_row: CenterContainer = $Panel/Margin/Columns/RightColumn/LogoutRow
@onready var message_label: Label = $Panel/Margin/Columns/RightColumn/MessageLabel


func _ready() -> void:
	screen_header.set_title("アカウント")
	screen_header.back_pressed.connect(func() -> void: back_pressed.emit())
	name_input.max_length = AccountService.DISPLAY_NAME_MAX_LENGTH
	name_input.text_changed.connect(_on_name_text_changed)
	id_input.max_length = FirebaseAuth.ID_MAX_LENGTH

	_setup_buttons()
	_setup_profile_ui()


func _setup_buttons() -> void:
	_profile_save_button = CodedButton.make("プロフィールを保存", Vector2(240, 46))
	_profile_save_button.pressed.connect(_on_profile_save_pressed)
	save_row.add_child(_profile_save_button)

	_register_button = CodedButton.make("登録する", Vector2(170, 48))
	_register_button.pressed.connect(_on_register_pressed)
	button_row.add_child(_register_button)

	_login_button = CodedButton.make("ログイン", Vector2(170, 48))
	_login_button.pressed.connect(_on_login_pressed)
	button_row.add_child(_login_button)

	_logout_button = CodedButton.make("ログアウト", Vector2(200, 48))
	_logout_button.pressed.connect(_on_logout_pressed)
	logout_row.add_child(_logout_button)

	# エモートの枠(GameDesign.md 9章)はヘッダーの主アクションから開く。左カラムは
	# 既に埋まっており、ここへ4つの枠を足すと下端の保存ボタンを押し出すため。
	_emote_button = CodedButton.make("エモート", Vector2(160, 46))
	_emote_button.pressed.connect(func() -> void: _emote_panel.open())
	screen_header.add_action(_emote_button)


func _setup_profile_ui() -> void:
	_preview = ProfilePreviewPlate.new()
	preview_container.add_child(_preview)
	_wrap_icon_grid()
	_build_playmat_row()
	_rebuild_icon_grid()

	_emote_panel = EmoteSlotPanel.new()
	# アンカーは直接代入する(`set_anchors_preset()` は生成直後のサイズ0を保つため)。
	_emote_panel.anchor_right = 1.0
	_emote_panel.anchor_bottom = 1.0
	add_child(_emote_panel)

	# 称号一覧 (スクロールリスト)
	for title_id in UserProfileLibrary.get_available_title_ids():
		var item := TitleListItem.new(title_id)
		item.pressed.connect(func() -> void: _on_title_selected(title_id))
		title_list.add_child(item)
		_title_buttons[title_id] = item


## アイコンはショップ(GameDesign.md 21章)で増えるため、一覧をスクロールできるように
## `ScrollContainer` を実行時に挟む(`.tscn` は変えない)。9種買うと17個で5行になり、
## そのままでは左カラム下端の保存ボタンを押し出す。
func _wrap_icon_grid() -> void:
	var parent := icon_grid.get_parent()
	var index := icon_grid.get_index()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, ICON_SCROLL_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.remove_child(icon_grid)
	scroll.add_child(icon_grid)
	icon_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	parent.move_child(scroll, index)


## プレイマットの帯。アイコンの一覧のすぐ下へ、所有しているマットを横に並べる。
## **見本は盤面と同じ `PlaymatPaint` を通す**(選ぶ絵と敷かれる絵を食い違わせない)。
func _build_playmat_row() -> void:
	var column := icon_grid.get_parent().get_parent()
	var label := Label.new()
	label.text = "プレイマット"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", UiPalette.BRASS_HIGHLIGHT)
	column.add_child(label)
	column.move_child(label, icon_grid.get_parent().get_index() + 1)
	_playmat_row = HBoxContainer.new()
	_playmat_row.add_theme_constant_override("separation", 8)
	column.add_child(_playmat_row)
	column.move_child(_playmat_row, label.get_index() + 1)


func _rebuild_playmat_row() -> void:
	if _playmat_row == null:
		return
	for child in _playmat_row.get_children():
		child.queue_free()
	for mat_id in AccountService.owned_playmat_ids():
		var swatch := PlaymatSwatch.new(mat_id)
		swatch.pressed.connect(func() -> void: _on_playmat_selected(mat_id))
		_playmat_row.add_child(swatch)


func _on_playmat_selected(mat_id: String) -> void:
	_selected_playmat_id = mat_id
	for child in _playmat_row.get_children():
		var swatch := child as PlaymatSwatch
		if swatch != null:
			swatch.is_selected = swatch.mat_id == mat_id
			swatch.queue_redraw()


## 所有しているものだけを並べる(GameDesign.md 14章)。買った直後にも呼ぶ。
func _rebuild_icon_grid() -> void:
	for child in icon_grid.get_children():
		child.queue_free()
	_icon_buttons.clear()
	for icon_id in AccountService.owned_icon_ids():
		var btn := IconButton.new(icon_id)
		btn.pressed.connect(func() -> void: _on_icon_selected(icon_id))
		icon_grid.add_child(btn)
		_icon_buttons[icon_id] = btn


## 画面を開くたびにMainが呼ぶ。サインインが済んでいなければここで済ませる。
func refresh() -> void:
	_set_busy(true)
	_set_message("接続しています…", HINT_COLOR)
	var ok: bool = await NetSession.sign_in()
	_set_busy(false)
	if not ok:
		_set_message("接続できませんでした(%s)。オフラインのままでも遊べます。" % NetSession.last_error, ERROR_COLOR)
	else:
		_set_message("", HINT_COLOR)
	_selected_icon_id = AccountService.icon_id()
	_selected_title_id = AccountService.title_id()
	_selected_playmat_id = AccountService.playmat_id()
	_rebuild_icon_grid()
	_rebuild_playmat_row()
	_on_playmat_selected(_selected_playmat_id)
	_refresh_view()


func _refresh_view() -> void:
	var registered: bool = NetSession.auth != null and NetSession.auth.is_registered()
	if registered:
		status_label.text = "ログイン中: %s" % NetSession.auth.login_id
	else:
		status_label.text = "ゲスト (この端末のゲストとして遊んでいます)"
	currency_label.text = "%s: %d" % [CurrencyRules.CURRENCY_NAME, AccountService.currency()]
	name_input.text = AccountService.display_name()

	# アイコン選択ボタンのハイライト更新
	for id in _icon_buttons:
		var btn: IconButton = _icon_buttons[id]
		btn.is_selected = (id == _selected_icon_id)
		btn.queue_redraw()

	# 称号ボタンのハイライト更新
	for id in _title_buttons:
		var item: TitleListItem = _title_buttons[id]
		item.is_selected = (id == _selected_title_id)
		item.queue_redraw()

	# プレビュー更新
	_update_preview()

	# 登録済みならIDとパスワードの入力欄は不要。代わりにログアウトを出す
	credential_box.visible = not registered
	logout_row.visible = registered
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
		_title_buttons[id].is_selected = (id == _selected_title_id)
		_title_buttons[id].queue_redraw()
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
		NetSession.client,
		uid,
		name_input.text,
		_selected_icon_id,
		_selected_title_id,
		_selected_playmat_id
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
	if _profile_save_button != null:
		_profile_save_button.disabled = value
	if _register_button != null:
		_register_button.disabled = value
	if _login_button != null:
		_login_button.disabled = value
	if _logout_button != null:
		_logout_button.disabled = value


func _set_message(text: String, color: Color) -> void:
	message_label.text = text
	message_label.add_theme_color_override("font_color", color)


## アイコン選択用ボタン(真鍮枠・丸型)
## プレイマットの見本1枚。押すとそれを敷く。
class PlaymatSwatch:
	extends Button

	const SWATCH_SIZE := Vector2(84, 54)

	var mat_id: String
	var is_selected := false

	func _init(p_mat_id: String) -> void:
		mat_id = p_mat_id
		custom_minimum_size = SWATCH_SIZE
		flat = true
		# 模様は矩形の外まで伸びる。見本でも必ず切り抜く(BoardTable と同じ理由)。
		clip_contents = true
		tooltip_text = PlaymatLibrary.display_name(p_mat_id)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		PlaymatPaint.draw_mat(self, rect, mat_id)
		draw_rect(
			rect,
			UiPalette.GLOW_AMBER if is_selected else UiPalette.BRASS_DARK,
			false,
			3.0 if is_selected else 1.4
		)


class IconButton:
	extends Button
	var icon_id: String
	var is_selected := false

	func _init(p_icon_id: String) -> void:
		icon_id = p_icon_id
		custom_minimum_size = Vector2(44, 44)
		flat = true

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var center := rect.position + rect.size * 0.5
		var bg_color := Color(0.12, 0.1, 0.08, 0.9)
		draw_circle(center, 20.0, bg_color)
		var tex := UserProfileLibrary.get_icon_texture(icon_id)
		if tex != null:
			draw_texture_rect(tex, Rect2(center - Vector2(16, 16), Vector2(32, 32)), false)
		if is_selected:
			draw_arc(center, 20.0, 0.0, TAU, 28, UiPalette.GLOW_AMBER, 2.5)
			# 外側の微かなハロー
			draw_arc(center, 22.0, 0.0, TAU, 28, Color(1.0, 0.84, 0.4, 0.4), 1.0)
		else:
			draw_arc(center, 20.0, 0.0, TAU, 28, UiPalette.BRASS_MID, 1.2)


## 称号選択用リスト項目(真鍮スタイル・選択ハイライト)
class TitleListItem:
	extends Button
	var title_id: String
	var is_selected := false
	var _font: Font

	func _init(p_title_id: String) -> void:
		title_id = p_title_id
		custom_minimum_size = Vector2(0, 34)
		flat = true

	func _ready() -> void:
		_font = get_theme_default_font()
		if _font == null:
			_font = ThemeDB.fallback_font

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var points := UiPaint.rounded_rect_points_uniform(rect, 4.0, 4)
		var bg_top := Color(0.18, 0.15, 0.12, 0.9) if is_selected else Color(0.1, 0.08, 0.07, 0.8)
		var bg_bottom := (
			Color(0.12, 0.1, 0.08, 0.9) if is_selected else Color(0.06, 0.05, 0.04, 0.8)
		)
		UiPaint.fill_gradient_polygon(
			get_canvas_item(), points, rect, [[0.0, bg_top], [1.0, bg_bottom]]
		)

		var outline := points.duplicate()
		outline.append(points[0])
		var border_color := UiPalette.GLOW_AMBER if is_selected else UiPalette.BRASS_DARK
		var border_width := 1.5 if is_selected else 1.0
		draw_polyline(outline, border_color, border_width, true)

		if _font == null:
			return
		var mark := "◆ " if is_selected else "   "
		var text := mark + UserProfileLibrary.get_title_name(title_id)
		var text_color := UiPalette.GLOW_AMBER if is_selected else UiPalette.TEXT_OFFWHITE
		draw_string(
			_font, Vector2(12, size.y - 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, text_color
		)


## 名札見本プレビュー
class ProfilePreviewPlate:
	extends Control
	var display_name := ""
	var icon_id := ""
	var title_id := ""
	var font: Font

	func _ready() -> void:
		custom_minimum_size = Vector2(170, 42)
		font = get_theme_default_font()
		if font == null:
			font = ThemeDB.fallback_font

	func _draw() -> void:
		var rect := Rect2(0, 0, 170, 40)
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
				120,
				11,
				UiPalette.BRASS_HIGHLIGHT
			)
			draw_string(
				font,
				Vector2(text_x, 32),
				label,
				HORIZONTAL_ALIGNMENT_LEFT,
				120,
				15,
				UiPalette.TEXT_OFFWHITE
			)
		else:
			draw_string(
				font,
				Vector2(text_x, 26),
				label,
				HORIZONTAL_ALIGNMENT_LEFT,
				120,
				17,
				UiPalette.TEXT_OFFWHITE
			)
