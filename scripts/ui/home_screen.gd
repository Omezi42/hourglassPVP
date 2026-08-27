class_name HomeScreen
extends Control

signal online_match_found(match_id: String, my_side: int, opponent_uid: String, is_room: bool)
signal deck_list_requested
signal hourglass_list_requested
signal replay_list_requested
signal spectate_requested(match_id: String)
signal cpu_match_requested
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

var _tab_fade_tween: Tween

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
	deck_nav_button.pressed.connect(_select_tab.bind(0))
	battle_nav_button.pressed.connect(_select_tab.bind(1))
	settings_button.pressed.connect(func() -> void: settings_panel.open())
	account_button.pressed.connect(func() -> void: account_requested.emit())
	_select_tab(0)
	refresh_account()


func refresh_battle_tab() -> void:
	battle_tab.refresh()


## 左上のアカウント表示を、キャッシュ済みのプロフィールから描き直す
## (GameDesign.md 9章)。ここでは通信しない。
func refresh_account() -> void:
	account_button.text = AccountService.display_name_or_default()
	currency_label.text = "%s:%d" % [CurrencyRules.CURRENCY_NAME, AccountService.currency()]


func _select_tab(index: int) -> void:
	_apply_nav_style(deck_nav_button, index == 0)
	_apply_nav_style(battle_nav_button, index == 1)
	background.texture = DECK_BACKGROUND if index == 0 else BATTLE_BACKGROUND
	if index == 1:
		battle_tab.refresh()
	var to_show: Control = deck_tab if index == 0 else battle_tab
	var to_hide: Control = battle_tab if index == 0 else deck_tab
	if to_show.visible and to_show.modulate.a >= 1.0 and not to_hide.visible:
		return
	if _tab_fade_tween != null and _tab_fade_tween.is_valid():
		_tab_fade_tween.kill()
	to_show.modulate.a = 0.0
	to_show.visible = true
	_tab_fade_tween = create_tween()
	_tab_fade_tween.set_parallel(true)
	_tab_fade_tween.tween_property(to_show, "modulate:a", 1.0, TAB_FADE_DURATION)
	_tab_fade_tween.tween_property(to_hide, "modulate:a", 0.0, TAB_FADE_DURATION)
	_tab_fade_tween.finished.connect(_on_tab_fade_finished.bind(to_hide))


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
