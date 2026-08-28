class_name HomeScreen
extends Control

signal online_match_found(match_id: String, my_side: int, opponent_uid: String, is_room: bool)
signal deck_list_requested
signal hourglass_list_requested
signal replay_list_requested
signal spectate_requested(match_id: String)
signal cpu_match_requested
signal tutorial_requested
signal rules_requested
signal keyword_dict_requested
signal random_match_deck_requested
signal create_room_deck_requested
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

var _tab_fade_tween: Tween
## いま表示しているタブ。3つに増えたため、隠す相手を index の対から求めない。
var _active_tab: Control
var _rules_tab: RulesTab
var _rules_nav_button: Button

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
	battle_tab.online_match_found.connect(
		func(match_id: String, my_side: int, opponent_uid: String, is_room: bool) -> void:
			online_match_found.emit(match_id, my_side, opponent_uid, is_room)
	)
	deck_tab.deck_edit_pressed.connect(func() -> void: deck_list_requested.emit())
	deck_tab.hourglass_list_pressed.connect(func() -> void: hourglass_list_requested.emit())
	battle_tab.replay_list_requested.connect(func() -> void: replay_list_requested.emit())
	battle_tab.spectate_requested.connect(
		func(match_id: String) -> void: spectate_requested.emit(match_id)
	)
	battle_tab.cpu_match_requested.connect(func() -> void: cpu_match_requested.emit())
	battle_tab.random_match_deck_requested.connect(
		func() -> void: random_match_deck_requested.emit()
	)
	battle_tab.create_room_deck_requested.connect(func() -> void: create_room_deck_requested.emit())
	_build_rules_tab()
	deck_nav_button.pressed.connect(_select_tab.bind(TAB_DECK))
	battle_nav_button.pressed.connect(_select_tab.bind(TAB_BATTLE))
	settings_button.pressed.connect(func() -> void: settings_panel.open())
	account_button.pressed.connect(func() -> void: account_requested.emit())
	# 初回起動時だけ「ルール」から始める(GameDesign.md 9章)。読了は測らない。
	var first_visit := not UiState.has_seen_home()
	UiState.mark_home_seen()
	_select_tab(TAB_RULES if first_visit else TAB_DECK)
	refresh_account()


func refresh_battle_tab() -> void:
	battle_tab.refresh()


## 左上のアカウント表示を、キャッシュ済みのプロフィールから描き直す
## (GameDesign.md 9章)。ここでは通信しない。
func refresh_account() -> void:
	account_button.text = AccountService.display_name_or_default()
	currency_label.text = "%s:%d" % [CurrencyRules.CURRENCY_NAME, AccountService.currency()]


func _select_tab(index: int) -> void:
	var tabs: Array[Control] = [_rules_tab, deck_tab, battle_tab]
	var buttons: Array[Button] = [_rules_nav_button, deck_nav_button, battle_nav_button]
	for i in buttons.size():
		_apply_nav_style(buttons[i], i == index)
	background.texture = BATTLE_BACKGROUND if index == TAB_BATTLE else DECK_BACKGROUND
	if index == TAB_BATTLE:
		battle_tab.refresh()
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
