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
signal solo_requested
signal tutorial_requested
signal rules_requested
signal screen_guide_requested
signal keyword_dict_requested
signal random_match_deck_requested
signal room_match_requested
signal account_requested

## 下部タブの寸法。**幅は共通で、高さだけ変える。**幅まで変えると `HBoxContainer` の
## 中で他のタブが横へ押し出され、選択するたびに4つの位置がずれる(実際にそうなった)。
const NAV_WIDTH := 196
const NAV_HEIGHT_ACTIVE := 128
const NAV_HEIGHT_INACTIVE := 100
const NAV_FONT_ACTIVE := 26
const NAV_FONT_INACTIVE := 20
## 選択していないタブへ掛ける色。沈めるだけで、押せないようには見せない。
const NAV_INACTIVE_TINT := Color(0.70, 0.68, 0.66)
## 下部タブに打つ印の大きさ(GameDesign.md 9章)。
const NAV_BADGE_SIZE := 30.0
## アカウント帯の右端をどれだけ空けるか(右上のメニューのボタンのぶん)。
const ACCOUNT_BAR_RIGHT_INSET := 116.0
## ヘッダーの残高を他の画面より大きく出す倍率。
const CURRENCY_CHIP_SCALE := 1.55
## 名札の大きさ。**帯(112px)の中で小さすぎると、右の残高とのつり合いが取れない。**
const NAMEPLATE_SIZE := Vector2(268, 68)
const DECK_BACKGROUND := preload("res://assets/backgrounds/processed/home/background.png")
const BATTLE_BACKGROUND := preload("res://assets/backgrounds/processed/battle/background.png")
## タブ切り替え時のクロスフェード時間。Main._show_only()の画面遷移と同じ考え方を踏襲する。
const TAB_FADE_DURATION := 0.18

## 下部タブの並び(GameDesign.md 9章)。**行いで分ける**——以前は
## 「ルール / デッキ / ソロ / バトル」で、対局を始める入口が4つのタブすべてに散っていた。
const TAB_BATTLE := 0
const TAB_DECK := 1
const TAB_RECORD := 2
const TAB_LEARN := 3
## タブの文言。クラス名(`BattleTab` / `DeckTab` / `RulesTab`)は `.tscn` の参照を
## 壊さないため変えていないので、**画面に出る名前はここだけが持つ**。
const TAB_LABELS := ["たたかう", "そろえる", "きろく", "おぼえる"]

## 右上のメニュー(ハンバーガー)ボタンのスタイル。
const MENU_BUTTON_GROUP := "icon_menu"

var _tab_fade_tween: Tween
## いま表示しているタブ。4つに増えたため、隠す相手を index の対から求めない。
var _active_tab: Control
var _rules_tab: RulesTab
var _rules_nav_button: Button
var _record_tab: RecordTab
var _record_nav_button: Button
var _record_badge: Label

var _nameplate_button: AccountNameplateButton
## デイリーミッション(GameDesign.md 23章)のモーダル。最初に開いたときだけ作る。
var _mission_panel: DailyMissionPanel
## 日曜イベント(GameDesign.md 15章・25章)の表示。通常時は空文字で隠れる。
var _sunday_banner: Label
## 残高のチップ(GameDesign.md 9章)。**最初の1回だけは脈を出さない**——
## 起動して開いた時点の残高は「増えた」わけではない。
var _currency_chip: CurrencyChip
var _currency_seen := false

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
	battle_tab.cpu_match_requested.connect(func() -> void: cpu_match_requested.emit())
	battle_tab.puzzle_requested.connect(func() -> void: puzzle_requested.emit())
	battle_tab.solo_requested.connect(func() -> void: solo_requested.emit())
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
	battle_tab.random_match_deck_requested.connect(
		func() -> void: random_match_deck_requested.emit()
	)
	battle_tab.room_match_requested.connect(func() -> void: room_match_requested.emit())
	# 背景の絵の上へ帯と幕を敷く(GameDesign.md 9章)。**背景の直後へ入れる**——
	# タブの中身・アカウント帯・下部タブはいずれもこれより手前に来る必要がある。
	var scrim := HomeScrim.make()
	add_child(scrim)
	move_child(scrim, background.get_index() + 1)
	_build_rules_tab()
	_build_record_tab()
	deck_nav_button.text = TAB_LABELS[TAB_DECK]
	battle_nav_button.text = TAB_LABELS[TAB_BATTLE]
	deck_nav_button.pressed.connect(_select_tab.bind(TAB_DECK))
	battle_nav_button.pressed.connect(_select_tab.bind(TAB_BATTLE))
	# 並びを「たたかう / そろえる / きろく / おぼえる」に揃える(9章)。
	var nav: Node = battle_nav_button.get_parent()
	nav.move_child(battle_nav_button, 0)
	nav.move_child(deck_nav_button, 1)
	nav.move_child(_record_nav_button, 2)
	nav.move_child(_rules_nav_button, 3)
	_style_menu_button()
	settings_button.pressed.connect(func() -> void: settings_panel.open())

	account_button.visible = false
	_nameplate_button = AccountNameplateButton.new()
	_nameplate_button.pressed.connect(func() -> void: account_requested.emit())
	$AccountBar.add_child(_nameplate_button)
	$AccountBar.move_child(_nameplate_button, 0)

	# 残高は枠を持たない Label だったため、真鍮で組まれたヘッダーの中でそこだけ浮いていた。
	# .tscn は書き換えず、同じ場所へチップを挿して元のラベルを隠す。
	currency_label.visible = false
	_currency_chip = CurrencyChip.new()
	# ヘッダーは面積に余裕があり、残高は押す前に分かるべきことの代表(9章)。
	_currency_chip.scale_factor = CURRENCY_CHIP_SCALE
	$AccountBar.add_child(_currency_chip)
	$AccountBar.move_child(_currency_chip, $AccountBar.get_children().find(currency_label) + 1)

	# **残高は右端へ寄せる。**名札の隣へ詰めると、ヘッダーの左半分だけが賑やかになり、
	# 右半分がまるごと空く(押す前に分かる情報を両端へ置く。GameDesign.md 9章)。
	# 帯そのものが幅460pxしか無く、右へ寄せる余地が無い。メニューのボタンへ掛からない
	# ところまで伸ばす(`.tscn` は書き換えない)。
	$AccountBar.anchor_right = 1.0
	$AccountBar.offset_right = -ACCOUNT_BAR_RIGHT_INSET
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$AccountBar.add_child(spacer)
	$AccountBar.move_child(spacer, $AccountBar.get_children().find(_currency_chip))

	_sunday_banner = Label.new()
	_sunday_banner.add_theme_font_size_override("font_size", 14)
	_sunday_banner.add_theme_color_override("font_color", UiPalette.GLOW_AMBER)
	_sunday_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sunday_banner.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	$AccountBar.add_child(_sunday_banner)
	$AccountBar.move_child(_sunday_banner, $AccountBar.get_children().find(_currency_chip) + 1)

	# 初回起動時だけ「おぼえる」から始める(GameDesign.md 9章)。読了は測らない。
	# **2回目以降は「たたかう」**——ホームを開いて最初に見たいのは対局であり、
	# デッキ編集は準備であって目的ではない。
	var first_visit := not UiState.has_seen_home()
	UiState.mark_home_seen()
	_select_tab(TAB_LEARN if first_visit else TAB_BATTLE)
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
	if _currency_chip != null:
		_currency_chip.set_amount(AccountService.currency(), _currency_seen)
		_currency_seen = true
	if _sunday_banner != null:
		var banner_text := SundayEventRules.banner_text()
		_sunday_banner.text = banner_text
		_sunday_banner.visible = not banner_text.is_empty()
	if deck_tab != null:
		deck_tab.refresh()


func _select_tab(index: int) -> void:
	var tabs: Array[Control] = [battle_tab, deck_tab, _record_tab, _rules_tab]
	var buttons: Array[Button] = [
		battle_nav_button, deck_nav_button, _record_nav_button, _rules_nav_button
	]
	for i in buttons.size():
		_apply_nav_style(buttons[i], i == index)
	background.texture = BATTLE_BACKGROUND if index == TAB_BATTLE else DECK_BACKGROUND
	# デッキも砂金も日課も画面の外で変わる。開くたびに札の副題を読み直す。
	if index == TAB_BATTLE:
		battle_tab.refresh()
	elif index == TAB_DECK:
		deck_tab.refresh()
	elif index == TAB_RECORD:
		_record_tab.refresh()
	_refresh_record_badge()
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
	deck_tab.get_parent().move_child(_rules_tab, 3)

	_rules_nav_button = deck_nav_button.duplicate(0) as Button
	_rules_nav_button.text = TAB_LABELS[TAB_LEARN]
	_rules_nav_button.pressed.connect(_select_tab.bind(TAB_LEARN))
	deck_nav_button.get_parent().add_child(_rules_nav_button)
	# tscn 側で表示されているのはデッキタブのため、隠す相手の初期値をそこへ合わせる。
	_active_tab = deck_tab


## 「きろく」タブとそのタブボタンはここで生成する(GameDesign.md 9章)。
## `_build_rules_tab()` と同じ理由で `scenes/home_screen.tscn` を書き換えずに追加する。
## ミッション・戦績・リプレイは、以前バトルタブに対局の入口と並んでいたものを移した。
func _build_record_tab() -> void:
	_record_tab = RecordTab.new()
	_record_tab.set_anchors_preset(Control.PRESET_FULL_RECT)
	_record_tab.visible = false
	_record_tab.mission_requested.connect(_on_mission_requested)
	_record_tab.stats_requested.connect(func() -> void: stats_requested.emit())
	_record_tab.replay_list_requested.connect(func() -> void: replay_list_requested.emit())
	deck_tab.get_parent().add_child(_record_tab)
	deck_tab.get_parent().move_child(_record_tab, 2)

	_record_nav_button = deck_nav_button.duplicate(0) as Button
	_record_nav_button.text = TAB_LABELS[TAB_RECORD]
	_record_nav_button.pressed.connect(_select_tab.bind(TAB_RECORD))
	deck_nav_button.get_parent().add_child(_record_nav_button)


## 受け取れるミッションがあることを、他のタブを見ている間も分かるようにする
## (GameDesign.md 9章)。**タブ側の印は唯一の手がかり**であり、これが無いと日課は
## 存在ごと忘れられる。
func _refresh_record_badge() -> void:
	if _record_nav_button == null or _record_tab == null:
		return
	var count := _record_tab.claimable_count()
	if _record_nav_button.has_meta("badge") and int(_record_nav_button.get_meta("badge")) == count:
		return
	_record_nav_button.set_meta("badge", count)
	if _record_badge == null:
		_record_badge = Label.new()
		_record_badge.add_theme_font_size_override("font_size", 16)
		_record_badge.add_theme_color_override("font_color", Color(1, 1, 1))
		_record_badge.add_theme_constant_override("outline_size", 0)
		_record_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_record_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_record_badge.custom_minimum_size = Vector2.ONE * NAV_BADGE_SIZE
		_record_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 丸は専用クラスを足さず、角丸を半径いっぱいまで振った StyleBox で出す。
		var dot := StyleBoxFlat.new()
		dot.bg_color = Color(0.86, 0.24, 0.19)
		dot.set_corner_radius_all(int(NAV_BADGE_SIZE * 0.5))
		dot.border_width_bottom = 2
		dot.border_width_top = 2
		dot.border_width_left = 2
		dot.border_width_right = 2
		dot.border_color = Color(0.10, 0.07, 0.05)
		_record_badge.add_theme_stylebox_override("normal", dot)
		_record_nav_button.add_child(_record_badge)
	_record_badge.text = str(count)
	_record_badge.visible = count > 0
	_record_badge.position = Vector2(
		_record_nav_button.size.x - NAV_BADGE_SIZE * 0.9, -NAV_BADGE_SIZE * 0.25
	)


func _on_tab_fade_finished(hidden_tab: Control) -> void:
	hidden_tab.visible = false
	hidden_tab.modulate.a = 1.0
	_tab_fade_tween = null


func _apply_nav_style(button: Button, active: bool) -> void:
	var height: float = NAV_HEIGHT_ACTIVE if active else NAV_HEIGHT_INACTIVE
	button.custom_minimum_size = Vector2(NAV_WIDTH, height)
	# **選択していないタブを下端へ沈め、選択中だけを帯の中央へ置く。**こうすると
	# 選択中の上端だけが持ち上がってせり出して見える。高さを変えるだけでは上下へ
	# 均等に伸びるため、せり出しているのか大きいだけなのかが読み取りにくい。
	button.size_flags_vertical = (Control.SIZE_SHRINK_CENTER if active else Control.SIZE_SHRINK_END)
	button.add_theme_font_size_override(
		"font_size", NAV_FONT_ACTIVE if active else NAV_FONT_INACTIVE
	)
	# **選択していないタブは沈める**(GameDesign.md 9章)。大きさの差だけでは現在地が
	# 読み取れないため、彩度と明るさも落とす。
	button.modulate = Color.WHITE if active else NAV_INACTIVE_TINT


## ホーム画面左上の名札ボタン(真鍮テクスチャ・アイコン・称号・名前)
class AccountNameplateButton:
	extends Button
	var _icon_rect: TextureRect
	var _icon_frame: PanelContainer
	var _title_label: Label
	var _name_label: Label

	func _init() -> void:
		custom_minimum_size = NAMEPLATE_SIZE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		CodedButton.apply_styles(self, "wide_text")
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var hbox := HBoxContainer.new()
		hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_theme_constant_override("separation", 12)
		hbox.offset_left = 16
		hbox.offset_right = -16
		hbox.alignment = BoxContainer.ALIGNMENT_BEGIN

		# アイコン枠
		_icon_frame = PanelContainer.new()
		_icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_frame.custom_minimum_size = Vector2(46, 46)
		_icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var frame_style := StyleBoxFlat.new()
		frame_style.bg_color = Color(0.1, 0.08, 0.06, 0.9)
		frame_style.border_color = UiPalette.BRASS_MID
		frame_style.set_border_width_all(1)
		frame_style.set_corner_radius_all(23)
		_icon_frame.add_theme_stylebox_override("panel", frame_style)

		_icon_rect = TextureRect.new()
		_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon_rect.custom_minimum_size = Vector2(34, 34)
		_icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_icon_frame.add_child(_icon_rect)
		hbox.add_child(_icon_frame)

		# 称号と名前の縦並び
		var vbox := VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vbox.add_theme_constant_override("separation", 2)

		_title_label = Label.new()
		_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_title_label.add_theme_font_size_override("font_size", 13)
		_title_label.add_theme_color_override("font_color", UiPalette.BRASS_HIGHLIGHT)
		_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		vbox.add_child(_title_label)

		_name_label = Label.new()
		_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_name_label.add_theme_font_size_override("font_size", 21)
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
