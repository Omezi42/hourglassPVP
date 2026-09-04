class_name HomeScreen
extends Control

## バトルタブで成立するのはランダムマッチだけ(ルームマッチは専用画面。11章)。
signal online_match_found(match_id: String, my_side: int, opponent_uid: String)
signal online_resume_requested(record: Dictionary)
signal stats_requested
signal puzzle_requested
signal deck_list_requested
signal hourglass_list_requested
signal shop_requested
signal replay_list_requested
signal cpu_match_requested
signal tutorial_requested
signal rules_requested
signal screen_guide_requested
signal keyword_dict_requested
signal random_match_deck_requested
signal room_match_requested
signal account_requested

const NAV_HEIGHT_ACTIVE := 150
const NAV_HEIGHT_INACTIVE := 108
const NAV_ASPECT := 1.787
const NAV_FONT_ACTIVE := 26
const NAV_FONT_INACTIVE := 20
const DECK_BACKGROUND := preload("res://assets/backgrounds/processed/home/background.png")
const BATTLE_BACKGROUND := preload("res://assets/backgrounds/processed/battle/background.png")
## タブ切り替え時のクロスフェード時間。Main._show_only()の画面遷移と同じ考え方を踏襲する。
const TAB_FADE_DURATION := 0.18

## 下部タブの並び(GameDesign.md 9章)。
const TAB_RULES := 0
const TAB_DECK := 1
const TAB_BATTLE := 2

## 右上のメニュー(ハンバーガー)ボタンのスタイル。
const MENU_BUTTON_GROUP := "icon_menu"

var _tab_fade_tween: Tween
## いま表示しているタブ。3つに増えたため、隠す相手を index の対から求めない。
var _active_tab: Control
var _rules_tab: RulesTab
var _rules_nav_button: Button

var _nameplate_button: AccountNameplateButton
## デイリーミッション(GameDesign.md 23章)のモーダル。最初に開いたときだけ作る。
var _mission_panel: DailyMissionPanel

@onready var background: TextureRect = $Background
@onready var deck_tab: DeckTab = $Layout/ContentArea/DeckTab
@onready var battle_tab: BattleTab = $Layout/ContentArea/BattleTab
@onready var deck_nav_button: Button = $Layout/BottomNav/DeckNavButton
@onready var battle_nav_button: Button = $Layout/BottomNav/BattleNavButton
@onready var settings_button: Button = $SettingsButton
@onready var settings_panel: SettingsPanel = $SettingsPanel
@onready var account_button: Button = $AccountBar/AccountButton
@onready var currency_label: Label = $AccountBar/CurrencyLabel


func _ready() -> void:
	battle_tab.stats_requested.connect(func() -> void: stats_requested.emit())
	battle_tab.puzzle_requested.connect(func() -> void: puzzle_requested.emit())
	battle_tab.mission_requested.connect(_on_mission_requested)
	battle_tab.resume_requested.connect(
		func(record: Dictionary) -> void: online_resume_requested.emit(record)
	)
	battle_tab.online_match_found.connect(
		func(match_id: String, my_side: int, opponent_uid: String) -> void:
			online_match_found.emit(match_id, my_side, opponent_uid)
	)
	deck_tab.deck_edit_pressed.connect(func() -> void: deck_list_requested.emit())
	deck_tab.hourglass_list_pressed.connect(func() -> void: hourglass_list_requested.emit())
	deck_tab.shop_pressed.connect(func() -> void: shop_requested.emit())
	battle_tab.replay_list_requested.connect(func() -> void: replay_list_requested.emit())
	battle_tab.cpu_match_requested.connect(func() -> void: cpu_match_requested.emit())
	battle_tab.random_match_deck_requested.connect(
		func() -> void: random_match_deck_requested.emit()
	)
	battle_tab.room_match_requested.connect(func() -> void: room_match_requested.emit())
	_build_rules_tab()
	deck_nav_button.pressed.connect(_select_tab.bind(TAB_DECK))
	battle_nav_button.pressed.connect(_select_tab.bind(TAB_BATTLE))
	_style_menu_button()
	settings_button.pressed.connect(func() -> void: settings_panel.open())

	account_button.visible = false
	_nameplate_button = AccountNameplateButton.new()
	_nameplate_button.pressed.connect(func() -> void: account_requested.emit())
	$AccountBar.add_child(_nameplate_button)
	$AccountBar.move_child(_nameplate_button, 0)

	# 初回起動時だけ「ルール」から始める(GameDesign.md 9章)。読了は測らない。
	var first_visit := not UiState.has_seen_home()
	UiState.mark_home_seen()
	_select_tab(TAB_RULES if first_visit else TAB_DECK)
	refresh_account()


## 右上のボタンをハンバーガー(横3本のバー)の紋章にする。文言を持たない代わりに
## 中身が音量だけに限られなくなるため、名前は「メニュー」で通す。StyleBoxはリソース
## 参照のため .tscn のパッチでは差し替えられず、ここで指定する。
func _style_menu_button() -> void:
	CodedButton.apply_styles(settings_button, MENU_BUTTON_GROUP)
	settings_button.tooltip_text = "メニュー"


func refresh_battle_tab() -> void:
	battle_tab.refresh()


## 対局から戻ってきたときに、バトルタブへ残っているマッチングの待機状態を解く。
func reset_battle_tab() -> void:
	battle_tab.reset_after_match()


## 左上のアカウント表示を、キャッシュ済みのプロフィールから描き直す
## (GameDesign.md 9章・14章)。ここでは通信しない。
func refresh_account() -> void:
	if _nameplate_button != null:
		_nameplate_button.update_profile(
			AccountService.display_name_or_default(),
			AccountService.icon_id(),
			AccountService.title_id()
		)
	currency_label.text = "%s:%d" % [CurrencyRules.CURRENCY_NAME, AccountService.currency()]
	if deck_tab != null:
		deck_tab.refresh()


func _select_tab(index: int) -> void:
	var tabs: Array[Control] = [_rules_tab, deck_tab, battle_tab]
	var buttons: Array[Button] = [_rules_nav_button, deck_nav_button, battle_nav_button]
	for i in buttons.size():
		_apply_nav_style(buttons[i], i == index)
	background.texture = BATTLE_BACKGROUND if index == TAB_BATTLE else DECK_BACKGROUND
	if index == TAB_BATTLE:
		battle_tab.refresh()
	# デッキも砂金も画面の外で変わる。開くたびに札の副題を読み直す。
	elif index == TAB_DECK:
		deck_tab.refresh()
	var to_show: Control = tabs[index]
	if to_show == _active_tab and to_show.visible and to_show.modulate.a >= 1.0:
		return
	var to_hide: Control = _active_tab
	_active_tab = to_show
	if _tab_fade_tween != null and _tab_fade_tween.is_valid():
		_tab_fade_tween.kill()
	to_show.modulate.a = 0.0
	to_show.visible = true
	_tab_fade_tween = create_tween()
	_tab_fade_tween.set_parallel(true)
	_tab_fade_tween.tween_property(to_show, "modulate:a", 1.0, TAB_FADE_DURATION)
	if to_hide != null and to_hide != to_show:
		_tab_fade_tween.tween_property(to_hide, "modulate:a", 0.0, TAB_FADE_DURATION)
		_tab_fade_tween.finished.connect(_on_tab_fade_finished.bind(to_hide))


## 「ルール」タブとそのタブボタンはここで生成する。`scenes/home_screen.tscn` を
## 書き換えずに3つ目を足すためで、ボタンは「デッキ」を複製して文言だけ差し替える
## (スタイルの指定漏れが起きない)。複製の flags は0にして、後から張る
## `pressed` の接続を引き継がせない。
func _build_rules_tab() -> void:
	_rules_tab = RulesTab.new()
	_rules_tab.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rules_tab.visible = false
	_rules_tab.tutorial_requested.connect(func() -> void: tutorial_requested.emit())
	_rules_tab.rules_requested.connect(func() -> void: rules_requested.emit())
	_rules_tab.screen_guide_requested.connect(func() -> void: screen_guide_requested.emit())
	_rules_tab.keyword_dict_requested.connect(func() -> void: keyword_dict_requested.emit())
	deck_tab.get_parent().add_child(_rules_tab)
	# タブの中身が背面へ回らないよう、既存のタブと同じ並びへ入れる。
	deck_tab.get_parent().move_child(_rules_tab, 0)

	_rules_nav_button = deck_nav_button.duplicate(0) as Button
	_rules_nav_button.text = "ルール"
	_rules_nav_button.pressed.connect(_select_tab.bind(TAB_RULES))
	deck_nav_button.get_parent().add_child(_rules_nav_button)
	deck_nav_button.get_parent().move_child(_rules_nav_button, 0)
	# tscn 側で表示されているのはデッキタブのため、隠す相手の初期値をそこへ合わせる。
	_active_tab = deck_tab


func _on_tab_fade_finished(hidden_tab: Control) -> void:
	hidden_tab.visible = false
	hidden_tab.modulate.a = 1.0
	_tab_fade_tween = null


func _apply_nav_style(button: Button, active: bool) -> void:
	var height: float = NAV_HEIGHT_ACTIVE if active else NAV_HEIGHT_INACTIVE
	button.custom_minimum_size = Vector2(roundi(height * NAV_ASPECT), height)
	button.add_theme_font_size_override(
		"font_size", NAV_FONT_ACTIVE if active else NAV_FONT_INACTIVE
	)


## ホーム画面左上の名札ボタン(真鍮テクスチャ・アイコン・称号・名前)
class AccountNameplateButton:
	extends Button
	var _icon_rect: TextureRect
	var _icon_frame: PanelContainer
	var _title_label: Label
	var _name_label: Label

	func _init() -> void:
		custom_minimum_size = Vector2(210, 56)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		CodedButton.apply_styles(self, "wide_text")
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var hbox := HBoxContainer.new()
		hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_theme_constant_override("separation", 10)
		hbox.offset_left = 12
		hbox.offset_right = -12
		hbox.alignment = BoxContainer.ALIGNMENT_BEGIN

		# アイコン枠
		_icon_frame = PanelContainer.new()
		_icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_frame.custom_minimum_size = Vector2(34, 34)
		_icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var frame_style := StyleBoxFlat.new()
		frame_style.bg_color = Color(0.1, 0.08, 0.06, 0.9)
		frame_style.border_color = UiPalette.BRASS_MID
		frame_style.set_border_width_all(1)
		frame_style.set_corner_radius_all(17)
		_icon_frame.add_theme_stylebox_override("panel", frame_style)

		_icon_rect = TextureRect.new()
		_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon_rect.custom_minimum_size = Vector2(24, 24)
		_icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_icon_frame.add_child(_icon_rect)
		hbox.add_child(_icon_frame)

		# 称号と名前の縦並び
		var vbox := VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vbox.add_theme_constant_override("separation", 1)

		_title_label = Label.new()
		_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_title_label.add_theme_font_size_override("font_size", 11)
		_title_label.add_theme_color_override("font_color", UiPalette.BRASS_HIGHLIGHT)
		_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		vbox.add_child(_title_label)

		_name_label = Label.new()
		_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_name_label.add_theme_font_size_override("font_size", 15)
		_name_label.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
		_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		vbox.add_child(_name_label)

		hbox.add_child(vbox)
		add_child(hbox)

	func update_profile(display_name: String, icon_id: String, title_id: String) -> void:
		_icon_rect.texture = UserProfileLibrary.get_icon_texture(icon_id)
		var title_text := UserProfileLibrary.get_title_display(title_id)
		_title_label.text = title_text
		_title_label.visible = not title_text.is_empty()
		var label := display_name.strip_edges()
		_name_label.text = label if not label.is_empty() else "ゲスト"


## デイリーミッション(GameDesign.md 23章)。画面を増やさずホームへ重ねるモーダルにする。
## **受け取ると残高が動く**ため、閉じたらヘッダーの砂金を読み直す。
func _on_mission_requested() -> void:
	if _mission_panel == null:
		_mission_panel = DailyMissionPanel.new()
		_mission_panel.closed.connect(func() -> void: refresh_account())
		add_child(_mission_panel)
	_mission_panel.open()
