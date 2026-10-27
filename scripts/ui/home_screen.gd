class_name HomeScreen
extends Control
## ホーム画面(GameDesign.md 9章)。**1画面に収め、タブを持たない。**
## ヘッダー(名札・砂金・ルールブック・メニュー)の下は2段。上段の左「ミッション」はここ、中央「対戦する」と
## 右「ソロモード」は `BattleTab`、下段(デッキ編集・図鑑・ショップ)は `DeckTab` が描く。位置は `HomeLayout`。
## ルールを読む・覚える入口はメニューの左隣のルールブック(`LearnMenu`)、戦績はアカウント画面へ置く。

signal online_resume_requested(record: Dictionary)
signal rank_requested
signal puzzle_requested
signal deck_list_requested
signal hourglass_list_requested
signal shop_requested
signal cpu_match_requested
signal solo_requested
signal tutorial_requested
signal rules_requested
signal screen_guide_requested
signal keyword_dict_requested
signal ranked_match_deck_requested
signal room_match_requested
signal account_requested

const PORTRAIT_BANNER_RECT := Rect2(24, 108, 672, 32)
const BANNER_FONT := 14
const PORTRAIT_BANNER_FONT := 22

## 残高のチップの拡大率。ヘッダーは面積に余裕があり、残高は押す前に分かるべきことの代表(9章)。
const CURRENCY_CHIP_SCALE := 1.55
## 名札の大きさ。背丈はヘッダーの部品で揃える(`HomeLayout.header_height()`)。
const NAMEPLATE_SIZE := Vector2(300, HomeLayout.HEADER_HEIGHT)
const BACKGROUND := preload("res://assets/backgrounds/processed/battle/background.png")

## 右上のメニュー(ハンバーガー)ボタンのスタイル。
const MENU_BUTTON_GROUP := "icon_menu"
## メニューの左隣に置くルールブック(開いた本の紋章)。大きさはメニューと揃える。
const RULEBOOK_BUTTON_GROUP := "icon_book"
const RULEBOOK_GAP := 12.0

var _nameplate_button: AccountNameplateButton
## 左の「ミッション」の札(GameDesign.md 9章・23章)。中身は `MissionEntryInfo` が描く。
var _mission_tile: HomeTile
var _mission_info: MissionEntryInfo
var _rulebook_button: Button
## デイリーミッション(GameDesign.md 23章)のモーダル。最初に開いたときだけ作る。
var _mission_panel: DailyMissionPanel
var _learn_menu: LearnMenu
var _welcome_panel: WelcomeDaysPanel
var _welcome_checking := false
## 日曜イベント(GameDesign.md 15章・25章)の表示。通常時は空文字で隠れる。
var _sunday_banner: Label
## 残高のチップ(GameDesign.md 9章)。**最初の1回だけは脈を出さない**——
## 起動して開いた時点の残高は「増えた」わけではない。
var _currency_chip: CurrencyChip
var _currency_seen := false
var _portrait := false

@onready var background: TextureRect = $Background
@onready var deck_tab: DeckTab = $Layout/ContentArea/DeckTab
@onready var battle_tab: BattleTab = $Layout/ContentArea/BattleTab
@onready var settings_button: Button = $SettingsButton
@onready var settings_panel: SettingsPanel = $SettingsPanel
@onready var account_button: Button = $AccountBar/AccountButton
@onready var currency_label: Label = $AccountBar/CurrencyLabel


func _ready() -> void:
	background.texture = BACKGROUND
	battle_tab.cpu_match_requested.connect(func() -> void: cpu_match_requested.emit())
	battle_tab.puzzle_requested.connect(func() -> void: puzzle_requested.emit())
	battle_tab.solo_requested.connect(func() -> void: solo_requested.emit())
	battle_tab.rank_requested.connect(func() -> void: rank_requested.emit())
	battle_tab.resume_requested.connect(
		func(record: Dictionary) -> void: online_resume_requested.emit(record)
	)
	battle_tab.ranked_match_deck_requested.connect(
		func() -> void: ranked_match_deck_requested.emit()
	)
	battle_tab.room_match_requested.connect(func() -> void: room_match_requested.emit())
	deck_tab.deck_edit_pressed.connect(func() -> void: deck_list_requested.emit())
	deck_tab.hourglass_list_pressed.connect(func() -> void: hourglass_list_requested.emit())
	deck_tab.shop_pressed.connect(func() -> void: shop_requested.emit())
	# `.tscn` はデッキの列だけが最初から visible=true になっている。2つの列を常に出す。
	deck_tab.visible = true
	battle_tab.visible = true
	# 背景の絵の上へ帯と幕を敷く(GameDesign.md 9章)。**背景の直後へ入れる**——
	# 列の中身・アカウント帯はいずれもこれより手前に来る必要がある。
	var scrim := HomeScrim.make()
	add_child(scrim)
	move_child(scrim, background.get_index() + 1)
	_style_menu_button()
	settings_button.pressed.connect(func() -> void: settings_panel.open())
	_build_account_bar()
	_build_mission_tile()
	_build_learn_menu()
	_build_rulebook_button()
	_place_header()
	# モーダルはヘッダー・メニューより手前に出す(後から足した子ほど手前に描かれる)。
	battle_tab.mount_pickers(self)
	refresh_account()


func _build_account_bar() -> void:
	account_button.visible = false
	_nameplate_button = AccountNameplateButton.new()
	_nameplate_button.pressed.connect(func() -> void: account_requested.emit())
	$AccountBar.add_child(_nameplate_button)
	$AccountBar.move_child(_nameplate_button, 0)

	# 残高は枠を持たない Label だったため、真鍮で組まれたヘッダーの中でそこだけ浮いていた。
	# .tscn は書き換えず、同じ場所へチップを挿して元のラベルを隠す。
	currency_label.visible = false
	_currency_chip = CurrencyChip.new()
	_currency_chip.scale_factor = CURRENCY_CHIP_SCALE
	$AccountBar.add_child(_currency_chip)
	$AccountBar.move_child(_currency_chip, $AccountBar.get_children().find(currency_label) + 1)

	# **残高は右端へ寄せる。**名札の隣へ詰めると、ヘッダーの左半分だけが賑やかになり、
	# 右半分がまるごと空く(押す前に分かる情報を両端へ置く。GameDesign.md 9章)。
	# 帯の幅は `_place_header()` がルールブックの手前まで伸ばす(`.tscn` は書き換えない)。
	$AccountBar.anchor_right = 1.0
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$AccountBar.add_child(spacer)
	$AccountBar.move_child(spacer, $AccountBar.get_children().find(_currency_chip))

	_sunday_banner = Label.new()
	_sunday_banner.add_theme_font_size_override("font_size", BANNER_FONT)
	_sunday_banner.add_theme_color_override("font_color", UiPalette.GLOW_AMBER)
	_sunday_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sunday_banner.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	$AccountBar.add_child(_sunday_banner)
	$AccountBar.move_child(_sunday_banner, $AccountBar.get_children().find(_currency_chip) + 1)


## 日課は目に入らないと忘れられるため、ヘッダーの小さな札ではなく中身ごと左の札に見せる(GameDesign.md 9章)。
func _build_mission_tile() -> void:
	_mission_tile = HomeTile.make("", "", "", Vector2.ZERO)
	_mission_tile.emblem = null
	_mission_tile.pressed.connect(_on_mission_requested)
	$Layout/ContentArea.add_child(_mission_tile)
	_mission_info = MissionEntryInfo.new()
	_mission_info.anchor_right = 1.0
	_mission_info.anchor_bottom = 1.0
	_mission_tile.add_child(_mission_info)
	_place_mission_tile()


func _place_mission_tile() -> void:
	var rect := HomeLayout.mission_rect(_portrait)
	_mission_tile.custom_minimum_size = rect.size
	_mission_tile.position = rect.position
	_mission_tile.size = rect.size


## ヘッダーの部品(名札・残高・ルールブック・メニュー)を同じ背丈にし、左右の端を下の札の列に揃える(GameDesign.md 9章)。
func _place_header() -> void:
	var margin := HomeLayout.header_margin(_portrait)
	var height := HomeLayout.header_height(_portrait)
	var top := HomeLayout.HEADER_TOP
	var buttons: Array[Button] = [settings_button, _rulebook_button]
	for i in buttons.size():
		var right := margin + (height + RULEBOOK_GAP) * float(i)
		var button := buttons[i]
		button.custom_minimum_size = Vector2(height, height)
		button.offset_left = -(right + height)
		button.offset_right = -right
		button.offset_top = top
		button.offset_bottom = top + height
	var bar: HBoxContainer = $AccountBar
	bar.offset_left = margin
	bar.offset_top = top
	bar.offset_bottom = top + height
	bar.offset_right = -(margin + (height + RULEBOOK_GAP) * float(buttons.size()) + RULEBOOK_GAP)
	_currency_chip.height_override = height


func _build_learn_menu() -> void:
	_learn_menu = LearnMenu.new()
	_learn_menu.tutorial_requested.connect(func() -> void: tutorial_requested.emit())
	_learn_menu.rules_requested.connect(func() -> void: rules_requested.emit())
	_learn_menu.screen_guide_requested.connect(func() -> void: screen_guide_requested.emit())
	_learn_menu.keyword_dict_requested.connect(func() -> void: keyword_dict_requested.emit())
	add_child(_learn_menu)


## ルールを読む・覚える入口(GameDesign.md 9章)。メニューの左隣へ同じ大きさで並べ、
## 引き出しを開かなくても目に入るようにする。
func _build_rulebook_button() -> void:
	var button := CodedButton.make_in_group(
		"", settings_button.custom_minimum_size, RULEBOOK_BUTTON_GROUP
	)
	button.tooltip_text = "遊び方"
	button.anchor_left = settings_button.anchor_left
	button.anchor_right = settings_button.anchor_right
	button.pressed.connect(func() -> void: _learn_menu.open())
	add_child(button)
	move_child(button, settings_button.get_index())
	_rulebook_button = button


## 縦横が変わったときに `Main` から呼ばれる(Architecture.md 4.7節)。
func apply_orientation(portrait: bool) -> void:
	_portrait = portrait
	_nameplate_button.set_portrait(portrait)
	_place_header()
	_place_mission_tile()
	_place_sunday_banner()
	battle_tab.apply_orientation(portrait)
	deck_tab.apply_orientation(portrait)
	_learn_menu.apply_orientation(portrait)


## 縦では知らせをヘッダーから外し、その下の行へ置く。横はアカウント帯の中(残高の右)。
func _place_sunday_banner() -> void:
	var bar: HBoxContainer = $AccountBar
	var parent := _sunday_banner.get_parent()
	if _portrait and parent == bar:
		bar.remove_child(_sunday_banner)
		add_child(_sunday_banner)
		move_child(_sunday_banner, bar.get_index() + 1)
	elif not _portrait and parent != bar:
		remove_child(_sunday_banner)
		bar.add_child(_sunday_banner)
		bar.move_child(_sunday_banner, bar.get_children().find(_currency_chip) + 1)
	_sunday_banner.add_theme_font_size_override(
		"font_size", PORTRAIT_BANNER_FONT if _portrait else BANNER_FONT
	)
	_sunday_banner.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT if _portrait else HORIZONTAL_ALIGNMENT_LEFT
	)
	if _portrait:
		_sunday_banner.position = PORTRAIT_BANNER_RECT.position
		_sunday_banner.size = PORTRAIT_BANNER_RECT.size


## 右上のボタンをハンバーガー(横3本のバー)の紋章にする。文言を持たない代わりに
## 中身が音量だけに限られなくなるため、名前は「メニュー」で通す。StyleBoxはリソース
## 参照のため .tscn のパッチでは差し替えられず、ここで指定する。
func _style_menu_button() -> void:
	CodedButton.apply_styles(settings_button, MENU_BUTTON_GROUP)
	settings_button.tooltip_text = "メニュー"


func refresh_battle_tab() -> void:
	battle_tab.refresh()


## 対局から戻ってきたときに、バトルの列へ残っているマッチングの待機状態を解く。
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
	_refresh_mission_tile()


## 今日の3つの進み具合と、受け取れる数(GameDesign.md 9章・23章)。日付で入れ替わるため開くたびに読む。
func _refresh_mission_tile() -> void:
	if _mission_info == null:
		return
	_mission_info.set_rows(DailyMissionService.missions(_uid()))


func _uid() -> String:
	if NetSession.client != null and NetSession.client.auth != null:
		return NetSession.client.auth.uid
	return ""


## ホーム画面左上の名札ボタン(真鍮テクスチャ・アイコン・称号・名前)
class AccountNameplateButton:
	extends Button
	const ICON_FRAME := 46.0
	const ICON := 34.0
	const TITLE_FONT := 13
	const NAME_FONT := 21
	const PORTRAIT_NAMEPLATE_SIZE := Vector2(290, HomeLayout.PORTRAIT_HEADER_HEIGHT)
	const PORTRAIT_ICON_FRAME := 60.0
	const PORTRAIT_ICON := 44.0
	const PORTRAIT_TITLE_FONT := 20
	const PORTRAIT_NAME_FONT := 28
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
		_icon_frame.custom_minimum_size = Vector2.ONE * ICON_FRAME
		_icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var frame_style := StyleBoxFlat.new()
		frame_style.bg_color = Color(0.1, 0.08, 0.06, 0.9)
		frame_style.border_color = UiPalette.BRASS_MID
		frame_style.set_border_width_all(1)
		frame_style.set_corner_radius_all(int(ICON_FRAME * 0.5))
		_icon_frame.add_theme_stylebox_override("panel", frame_style)

		_icon_rect = TextureRect.new()
		_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon_rect.custom_minimum_size = Vector2.ONE * ICON
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
		_title_label.add_theme_font_size_override("font_size", TITLE_FONT)
		_title_label.add_theme_color_override("font_color", UiPalette.BRASS_HIGHLIGHT)
		_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		vbox.add_child(_title_label)

		_name_label = Label.new()
		_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_name_label.add_theme_font_size_override("font_size", NAME_FONT)
		_name_label.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
		_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		vbox.add_child(_name_label)

		hbox.add_child(vbox)
		add_child(hbox)

	## 縦では称号・名前を文字の目安(GameDesign.md 9章「縦画面」)まで大きくする。
	func set_portrait(portrait: bool) -> void:
		custom_minimum_size = PORTRAIT_NAMEPLATE_SIZE if portrait else NAMEPLATE_SIZE
		var icon_frame := PORTRAIT_ICON_FRAME if portrait else ICON_FRAME
		_icon_frame.custom_minimum_size = Vector2.ONE * icon_frame
		var frame_style := _icon_frame.get_theme_stylebox("panel") as StyleBoxFlat
		frame_style.set_corner_radius_all(int(icon_frame * 0.5))
		_icon_rect.custom_minimum_size = Vector2.ONE * (PORTRAIT_ICON if portrait else ICON)
		_title_label.add_theme_font_size_override(
			"font_size", PORTRAIT_TITLE_FONT if portrait else TITLE_FONT
		)
		_name_label.add_theme_font_size_override(
			"font_size", PORTRAIT_NAME_FONT if portrait else NAME_FONT
		)

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
		_mission_panel.reward_claimed.connect(_on_mission_reward_claimed)
		add_child(_mission_panel)
	_mission_panel.open()


## 受け取ったミッションの砂金を、押した位置からヘッダーの残高へ飛ばす
## (GameDesign.md 9章)。数値そのものは通信が確定するまで正しく読めないため、
## ここでは脈だけを出す(実際の反映はパネルを閉じたときの `refresh_account()` が行う)。
func _on_mission_reward_claimed(from_rect: Rect2, _amount: int) -> void:
	if _currency_chip == null:
		return
	await CardFlightFx.fly(_mission_panel, from_rect, _currency_chip.get_global_rect())
	_currency_chip.bump()


## はじめの7日(GameDesign.md 23章)。ホームを出すたびに `Main` が呼ぶ。今日のぶんがまだなら札を出す。
## **通信できないときは出さない**(受け取れないため)。サインインを待つ間に二重に開かない。
func offer_welcome_days() -> void:
	if _welcome_checking or NetSession.auth == null:
		return
	if _welcome_panel != null and _welcome_panel.visible:
		return
	_welcome_checking = true
	var signed_in: bool = await NetSession.sign_in()
	_welcome_checking = false
	if not signed_in or not visible or not WelcomeDays.can_claim_today():
		return
	if _welcome_panel == null:
		_welcome_panel = WelcomeDaysPanel.new()
		_welcome_panel.closed.connect(func() -> void: refresh_account())
		_welcome_panel.reward_claimed.connect(_on_welcome_reward_claimed)
		add_child(_welcome_panel)
	else:
		move_child(_welcome_panel, get_child_count() - 1)
	_welcome_panel.open()


func _on_welcome_reward_claimed(from_rect: Rect2, _amount: int) -> void:
	if _currency_chip == null:
		return
	await CardFlightFx.fly(self, from_rect, _currency_chip.get_global_rect())
	_currency_chip.bump()
