class_name Main
extends Control

## 画面切り替え時のクロスフェード時間。
const SCREEN_FADE_DURATION := 0.18

## v5.0の対局画面(子がすべてコード描画のControlで .tscn を持たないため _ready() で生成する)。
var card_match_screen: CardMatchScreen
var rule_screen: RuleScreen
## v5.0のデッキ編集画面(同上)。
var card_deck_editor_screen: CardDeckEditorScreen
## v5.0のカード一覧画面(同上)。
var card_list_screen: CardListScreen

var _match_return_screen: Control
## アカウント画面を閉じたときの戻り先。タイトルから開いた場合だけタイトルへ戻す。
var _account_return_to_title := false

var _screens: Array[Control] = []
## タイトルからホームへ移るときだけ使う砂のトランジション(GameDesign.md 9章)。
## 他の画面遷移はクロスフェード(_show_only)のまま変えていない。
var _sand_transition: SandTransition
var _active_screen: Control = null
var _fade_tween: Tween
## 遷移中は全画面の入力を塞ぐ透明ブロッカー。連打による二重遷移や、
## フェード中に背後の画面がクリックされることを防ぐ。
var _transition_blocker: ColorRect

@onready var title_screen: TitleScreen = $TitleScreen
@onready var home_screen: HomeScreen = $HomeScreen
@onready var replay_list_screen: ReplayListScreen = $ReplayListScreen
@onready var account_screen: AccountScreen = $AccountScreen


func _ready() -> void:
	_screens = [
		title_screen,
		home_screen,
		replay_list_screen,
		account_screen,
	]
	# v5.0の対局画面は子がすべてコード描画のControlで .tscn を持たないため、
	# ここで生成して画面一覧へ加える(Architecture.md 4.0節)。
	card_match_screen = CardMatchScreen.new()
	card_match_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_match_screen.visible = false
	add_child(card_match_screen)
	card_match_screen.back_pressed.connect(_on_card_match_back)
	_screens.append(card_match_screen)
	card_deck_editor_screen = CardDeckEditorScreen.new()
	card_deck_editor_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_deck_editor_screen.visible = false
	add_child(card_deck_editor_screen)
	card_deck_editor_screen.back_pressed.connect(func() -> void: _show_only(home_screen))
	_screens.append(card_deck_editor_screen)
	card_list_screen = CardListScreen.new()
	card_list_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_list_screen.visible = false
	add_child(card_list_screen)
	card_list_screen.back_pressed.connect(func() -> void: _show_only(home_screen))
	_screens.append(card_list_screen)
	rule_screen = RuleScreen.new()
	rule_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	rule_screen.visible = false
	add_child(rule_screen)
	rule_screen.back_pressed.connect(func() -> void: _show_only(home_screen))
	_screens.append(rule_screen)
	_transition_blocker = _make_transition_blocker()
	add_child(_transition_blocker)
	_sand_transition = SandTransition.new()
	add_child(_sand_transition)
	title_screen.start_requested.connect(_on_title_start_requested)
	# アカウント画面はタイトルとホームの両方から開く(GameDesign.md 14章)。
	# 戻り先が異なるため、どちらから来たかを_account_return_screenに覚えておく
	title_screen.account_requested.connect(_on_account_requested.bind(true))
	home_screen.account_requested.connect(_on_account_requested.bind(false))
	account_screen.back_pressed.connect(_on_account_back)
	account_screen.profile_changed.connect(func() -> void: home_screen.refresh_account())
	# 対局画面から戻る先は各導線が設定するが、設定される前に戻る操作が起きても
	# 落ちないよう既定をホームにしておく
	_match_return_screen = home_screen
	home_screen.online_match_found.connect(_on_online_match_found)
	home_screen.deck_list_requested.connect(_on_deck_list_requested)
	home_screen.hourglass_list_requested.connect(_on_hourglass_list_requested)
	home_screen.rules_requested.connect(_on_rules_requested)
	home_screen.replay_list_requested.connect(_on_replay_list_requested)
	home_screen.spectate_requested.connect(_on_spectate_requested)
	home_screen.cpu_match_requested.connect(_on_cpu_match_deck_requested)
	home_screen.random_match_deck_requested.connect(_on_random_match_deck_requested)
	home_screen.create_room_deck_requested.connect(_on_create_room_deck_requested)
	replay_list_screen.back_pressed.connect(func() -> void: _show_only(home_screen))
	replay_list_screen.replay_selected.connect(_on_replay_selected)
	NetSession.ensure_ready(self)
	SoundBank.ensure_ready(self)
	SoundBank.wire_buttons(self)
	MusicPlayer.ensure_ready(self)
	MusicPlayer.set_volume(SoundBank.get_bgm_volume())
	_show_only(title_screen)


## ブラウザは最初のユーザー操作より前の音声再生を許さないため、最初の入力をここで拾って
## BGMの再生開始を許可する。1度きりでよいので、通知したら以降は入力を見ない。
func _input(event: InputEvent) -> void:
	if not (
		event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey
	):
		return
	MusicPlayer.notify_user_gesture()
	set_process_input(false)


## タイトル画面を押されたときの遷移。ロゴの演出 → 砂が画面を覆う → 画面を差し替える →
## 砂が下へ抜ける、の順で進める。砂が覆いきっている間に差し替えるため、
## 通常のクロスフェード(_show_only)は砂の下で起きて見えない。
func _on_title_start_requested() -> void:
	await title_screen.play_launch()
	await _sand_transition.cover()
	_show_only(home_screen)
	await _sand_transition.reveal()


func _on_match_back() -> void:
	_show_only(_match_return_screen)
	home_screen.refresh_account()


func _on_account_requested(from_title: bool) -> void:
	_account_return_to_title = from_title
	_show_only(account_screen)
	account_screen.refresh()


func _on_account_back() -> void:
	_show_only(title_screen if _account_return_to_title else home_screen)
	home_screen.refresh_account()


func _on_replay_list_requested() -> void:
	replay_list_screen.refresh()
	_show_only(replay_list_screen)


## 棋譜を読み込んで再生画面へ。**v5.0の棋譜は `seed` を持つ**ことで見分けられる。
## v1.0の棋譜(位相制・配置フェーズあり)は再生できないため、一覧の時点で除いてある。
## CPU戦のローカルリプレイは"cpu_"始まりのidで区別する(LocalReplayService.mark_finished()参照)。
func _on_replay_selected(match_id: String) -> void:
	var record: Dictionary = (
		LocalReplayService.get_replay(match_id)
		if match_id.begins_with("cpu_")
		else await NetSession.client.get_document("matches/%s" % match_id)
	)
	if not card_match_screen.start_replay(record):
		return
	_match_return_screen = replay_list_screen
	_show_only(card_match_screen)


func _on_spectate_requested(match_id: String) -> void:
	_match_return_screen = home_screen
	if await card_match_screen.start_spectate(NetSession.client, match_id):
		_show_only(card_match_screen)


## CPU戦(v5.0)。先手/後手は常にプレイヤーが先手とし、相手のデッキはランダムに組む
## (GameDesign.md 13章)。
func _start_cpu_match() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	card_match_screen.start_cpu_match(CardDeckSave.load_deck(), CardDeckSave.random_deck(rng))
	_match_return_screen = home_screen
	_show_only(card_match_screen)


## v5.0はデッキを1つしか持たないため、開始前のデッキ選択画面を挟まない。
## 複数デッキを持たせるときに、選択画面をv5.0向けに作り直す。
func _on_random_match_deck_requested() -> void:
	home_screen.battle_tab.begin_random_match()


func _on_create_room_deck_requested() -> void:
	home_screen.battle_tab.begin_create_room()


func _on_cpu_match_deck_requested() -> void:
	_start_cpu_match()


## v5.0はデッキを1つだけ持つため、デッキ一覧(v1.0の複数デッキ管理)を挟まず
## 編集画面へ直行する。複数デッキを持たせるときに一覧を作り直す。
func _on_deck_list_requested() -> void:
	card_deck_editor_screen.open()
	_show_only(card_deck_editor_screen)


## 砂時計一覧はカード一覧(CardListScreen)。
func _on_hourglass_list_requested() -> void:
	_show_only(card_list_screen)


## ルール(遊び方)。進捗は保存せず、開くたび先頭のページから始める。
func _on_rules_requested() -> void:
	rule_screen.restart()
	_show_only(rule_screen)


## オンライン対戦(v5.0)。配置フェーズが無いため、デッキと山札の種を交換したら
## そのまま対局へ入る。is_room は砂金の獲得量(GameDesign.md 15章)、
## opponent_uid は相手の表示名(14章)に使う。
func _on_online_match_found(
	match_id: String, my_side: int, opponent_uid: String, is_room: bool
) -> void:
	card_match_screen.start_online_match(
		CardDeckSave.load_deck(), NetSession.client, match_id, my_side, is_room, opponent_uid
	)
	_match_return_screen = home_screen
	_show_only(card_match_screen)


## 対局画面から戻るときは、必ずポーリングを止めてから離れる(Architecture.md 6.1節)。
func _on_card_match_back() -> void:
	await card_match_screen.stop_networking()
	_on_match_back()


func _make_transition_blocker() -> ColorRect:
	var blocker := ColorRect.new()
	blocker.color = Color(0, 0, 0, 0)
	blocker.anchor_right = 1.0
	blocker.anchor_bottom = 1.0
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.visible = false
	return blocker


## 表示中の画面を screen へクロスフェードで切り替える。連打などで遷移中に
## 別の遷移が始まっても破綻しないよう、進行中のTweenをkillしてから作り直す。
func _show_only(screen: Control) -> void:
	if screen == _active_screen:
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	var previous := _active_screen
	_active_screen = screen

	for s in _screens:
		if s != previous and s != screen:
			s.visible = false
			s.modulate.a = 1.0

	if not screen.visible:
		screen.modulate.a = 0.0
	screen.visible = true
	_transition_blocker.visible = true

	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(screen, "modulate:a", 1.0, SCREEN_FADE_DURATION)
	if previous != null:
		_fade_tween.tween_property(previous, "modulate:a", 0.0, SCREEN_FADE_DURATION)
	_fade_tween.finished.connect(_on_transition_finished.bind(screen, previous))

	# BGMの切り替えは画面遷移のハブであるここ1箇所で行い、画面ごとに書き散らさない
	# (Architecture.md 9章)。対局が終わって結果パネルが出ている間は対局画面が止める。
	MusicPlayer.play(_track_for(screen))


## 画面ごとのBGM。対局だけ専用曲、タイトルだけ専用曲、それ以外はホーム曲。
func _track_for(screen: Control) -> MusicPlayer.Track:
	if screen == card_match_screen:
		return MusicPlayer.Track.MATCH
	if screen == title_screen:
		return MusicPlayer.Track.TITLE
	return MusicPlayer.Track.HOME


func _on_transition_finished(screen: Control, previous: Control) -> void:
	screen.modulate.a = 1.0
	if previous != null and previous != screen:
		previous.visible = false
		previous.modulate.a = 1.0
	_transition_blocker.visible = false
	_fade_tween = null
