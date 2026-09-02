class_name CardMatchScreen
extends Control
## v5.0の対局画面(GameDesign.md 9章「対局画面」)。
## 上から「相手の情報帯 / 相手の場6枠 / 自分の場6枠 / 自分の情報帯 / 自分の手札」。
##
## 子はすべてコード描画のControl(`CardView`/`PlayerInfoBar`)で、Inspectorから
## 編集する値を持たないため、.tscn を作らずこの1クラスで組み立てている。

signal back_pressed

const CARD_GAP := 12.0
const HAND_GAP := 8.0
const MARGIN := 24.0
const FOE_BAR_TOP := 8.0
const FOE_ROW_TOP := 92.0
const OWN_ROW_TOP := 268.0
const OWN_BAR_TOP := 456.0
const HAND_TOP := 528.0
## 手札は卓と同じ左右の範囲へ置き、盤面の真下で中央に揃える。
const HAND_AREA := Rect2(190, 528, 900, 158)
## 12枠を載せる卓上(GameDesign.md 9章)。両陣営の6枠がこの上に並ぶ。
const TABLE_RECT := Rect2(190, 74, 900, 372)
const CPU_THINK_SECONDS := 0.5
## 反転・コイン・ターン終了を縦に並べる右の列。
const ACTION_COLUMN_X := 1108.0
const TURN_END_BUTTON_SIZE := Vector2(148, 76)
const TURN_END_BUTTON_TOP := 290.0
const ACTION_BUTTON_SIZE := Vector2(148, 42)
## 反転ボタンは選んだ駒のすぐ下へ出す(GameDesign.md 9章)。
const FLIP_BUTTON_SIZE := Vector2(104, 34)
const FLIP_BUTTON_OVERLAP := 3.0
const LOG_BUTTON_TOP := 384.0
const SURRENDER_BUTTON_TOP := 434.0
const EMOTE_BUTTON_TOP := 484.0
## リプレイ・観戦のときだけ出す戻るボタン。行動の列の先頭に置く。
const BACK_BUTTON_TOP := 24.0
## 情報帯の幅。行動の列(ACTION_COLUMN_X)の手前で止める。
const BAR_WIDTH := ACTION_COLUMN_X - MARGIN - 24.0

var state: MatchState
## 自分の側。CPU戦・オンラインでは固定する。
var my_side: int = MatchState.Side.A
## いま選んでいるものと相手の情報帯。切り出した進行役(`CardMatchTargets` 等)から読む。
var selection: CardMatchSelection:
	get:
		return _selection
var foe_bar: PlayerInfoBar:
	get:
		return _foe_bar
## 持ち時間の焦燥演出。残り時間は時計の進行役(`CardMatchClock`)が書き込む。
var alert: CardMatchAlert:
	get:
		return _alert
## 対局中の効果音。攻撃の演出が当たった瞬間に持ち越した音を出すため、進行役から引く。
var sound: CardMatchSound:
	get:
		return _sound
## 操作を受け付ける対局かどうか(再生モードでは false)。
var interactive: bool:
	get:
		return _interactive
## 攻撃以外の演出。攻撃が当たった瞬間に持ち越したぶんを出すため、進行役から引く。
var clocks: CardMatchClock:
	get:
		return _clocks
var effects: CardMatchEffects:
	get:
		return _effects
## 盤面へ伸びる光の筋。反転と設置効果が共有する。
var beam: CardFlipBeam:
	get:
		return _flip_beam

var _foe_bar: PlayerInfoBar
var _own_bar: PlayerInfoBar
var _foe_slots: Array[CardView] = []
var _own_slots: Array[CardView] = []
var _hand_views: Array[CardView] = []
var _flip_button: Button
var _coin_button: Button
var _end_turn_button: Button
var _selection := CardMatchSelection.new()
var _cpu: CardCpuStrategy = null
var _cpu_timer: Timer
var _online: OnlineMatch = null
var _setup: OnlineSetup = null
var _client: FirestoreClient = null
var _match_id := ""
var _replay: CardMatchReplay = null
var _interactive := true
var _mulligan: CardMatchMulligan
var _detail: CardMatchDetail
var _own_deck: Array = []
var _tutorial: CardMatchTutorial
var _outcome: CardMatchOutcome
var _match_kind: CurrencyRules.MatchKind = CurrencyRules.MatchKind.NONE
var _clocks: CardMatchClock
var _cpu_record: Dictionary = {}
var _log: CardMatchLog
var _result: CardMatchResult
var _pile: CardPileViewer
var _log_button: Button
var _flip_beam: CardFlipBeam
var _strike: CardMatchStrike
var _sound: CardMatchSound
var _effects: CardMatchEffects
var _targets: CardMatchTargets
## 砂術を撃つ段取り。CardMatchTargets が対象の側を引くためにも読む。
var _spell: CardMatchSpell
var _feed: CardMatchTurnFeed
var _cpu_followup := false
var _surrender_button: Button
var _back_button: Button
var _status: CardMatchStatus
var _online_ctl: CardMatchOnline
var _emote: CardMatchEmote
var _alert: CardMatchAlert
var _damage_assist: CardMatchDamageAssist
var _history: CardMatchActionHistory


func _ready() -> void:
	_build()
	set_process(true)
	_outcome = CardMatchOutcome.new(self)
	_strike = CardMatchStrike.new(self)
	_sound = CardMatchSound.new(self)
	_effects = CardMatchEffects.new(self)
	_online_ctl = CardMatchOnline.new(self)
	_targets = CardMatchTargets.new(self)
	_spell = CardMatchSpell.new(self)
	_clocks = CardMatchClock.new(self)
	_emote = CardMatchEmote.new(self)
	_emote.set_position(Vector2(ACTION_COLUMN_X, EMOTE_BUTTON_TOP))


## 前の対局の名残を落としてから新しい対局へ入る。結果パネル・ログ・選択・
## タイマー・通信・棋譜はいずれも画面が使い回されるため対局をまたいで残り、
## 片付けないと2局目が「対戦終了の表示のまま遊べない」状態になる。
func _reset_for_new_match() -> void:
	_result.visible = false
	_log.set_open(false)
	_log.clear()
	if _history != null:
		_history.clear()
	_pile.visible = false
	_selection.clear()
	_cpu_timer.stop()
	if _emote != null:
		_emote.close_popup()
	if _replay != null:
		_replay.stop()
	if _online != null:
		# 停止したノードは解放しない(Architecture.md 6.1節)。参照だけを落とす。
		_online.stop()
	_setup = null
	_client = null
	_match_id = ""
	_clocks.clear()
	# 持ち時間を持たない対局(CPU戦・持ち時間を切ったルームマッチ)へ入ったときに、
	# 前の対局の残り時間が情報帯に残らないようにする(負の値は表示しない)。
	_own_bar.clock_seconds = -1.0
	_foe_bar.clock_seconds = -1.0
	if _alert != null:
		_alert.remaining_seconds = -1.0
		_alert.is_my_turn = false
	_cpu_record = {}
	_status.set_waiting("")
	if _mulligan != null:
		_mulligan.close()
	if _tutorial != null:
		_tutorial.visible = false
	set_process(true)
	if state != null and is_instance_valid(state):
		state.queue_free()
	state = null


## CPU戦を開始する。deck_self / deck_foe は CardData の配列(20枚)。
func start_cpu_match(deck_self: Array, deck_foe: Array) -> void:
	_reset_for_new_match()
	_own_deck = deck_self
	_cpu = CardCpuStrategy.new()
	_interactive = true
	_match_kind = CurrencyRules.MatchKind.CPU
	my_side = MatchState.Side.A
	_own_bar.display_name = AccountService.display_name()
	_own_bar.icon_id = AccountService.icon_id()
	_own_bar.title_id = AccountService.title_id()
	_foe_bar.display_name = "CPU"
	_foe_bar.icon_id = UserProfileLibrary.CPU_ICON_ID
	_foe_bar.title_id = UserProfileLibrary.CPU_TITLE_ID
	# CPU戦もリプレイとして残すため、山札の種を決めてから始める(GameDesign.md 12章)。
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var seed_value := rng.randi_range(1, 1 << 30)
	_cpu_record = {
		"deck_a": CardLibrary.ids_from_deck(deck_self),
		"deck_b": CardLibrary.ids_from_deck(deck_foe),
		"seed": seed_value,
		"actions": [],
		"source": "cpu",
	}
	_begin_state(deck_self, deck_foe, seed_value, true)
	_start_cpu_mulligan()


## 誘導対局を始める(GameDesign.md 18章)。中身は通常のCPU戦で、指示を重ねるだけ。
## デッキは保存済みのものを使わずプリセットの「基本」で固定する。覚えてほしい動きが
## 出ないデッキで始まると成立しないため。
func start_tutorial_match() -> void:
	start_cpu_match(CardPresetDecks.basic(), CardPresetDecks.basic())
	_tutorial.watch(self, state, my_side)


## オンライン対戦の3つの入口は `CardMatchOnline` が持つ(Architecture.md 4.0節)。
func start_online_match(
	deck_self: Array,
	client: FirestoreClient,
	p_match_id: String,
	p_my_side: int,
	is_room: bool = false,
	opponent_uid: String = "",
	time_limit: bool = true
) -> void:
	await _online_ctl.start(
		deck_self, client, p_match_id, p_my_side, is_room, opponent_uid, time_limit
	)


func resume_online_match(client: FirestoreClient, record: Dictionary) -> bool:
	return await _online_ctl.resume(client, record)


func start_spectate(client: FirestoreClient, p_match_id: String) -> bool:
	return await _online_ctl.spectate(client, p_match_id)


## 持ち時間が尽きた。**減っているのは手番側の時計であり、相手の手番でも発火する**ため、
## 自分の側でなければ何もしない。申告できるのは自分の時間切れだけで(GameDesign.md 11章)、
## 相手の時間切れは `_watch_opponent_timeout()` が猶予を置いて拾う。
## **これは敗北ではなく手番の強制終了**(GameDesign.md 5章)。連続の上限に達したときだけ、
## 適用した `MatchState` の側が終局させる。
func _on_local_timeout(side: int) -> void:
	if side != my_side:
		return
	if state != null and not state.is_match_over():
		_perform({"type": "time_up", "side": my_side})


func _process(delta: float) -> void:
	if _emote != null:
		_emote.tick(delta)
	_clocks.tick(delta)


func _on_action_received(action: Dictionary) -> void:
	if action.get("type", "") == "emote":
		if _emote != null:
			_emote.handle_emote(action)
		return
	if _history != null:
		var side: int = action.get("side", MatchState.other_side(my_side))
		_history.push_action(side, _action_summary(action))
	_strike.capture(action)
	MatchAction.apply(state, action)
	if _clocks.active() and state != null and not state.is_match_over():
		_clocks.start_turn()
		# 添えられた残り時間で上書きするのは、相手の手番がまだ続いている間だけ。
		# 手番が移ったなら、その側の時計は手番ぶんの持ち時間から数え直す。
		if action.has("clock") and state.current_turn != my_side:
			_clocks.overwrite_foe(float(action["clock"]))
	_finish_action()


## リプレイ再生モードとして開始する(GameDesign.md 12章)。
## 手番の判定を使わず、`_interactive` で操作をまとめて塞ぐ。
func start_replay(record: Dictionary) -> bool:
	_reset_for_new_match()
	_cpu = null
	_online = null
	_interactive = false
	my_side = MatchState.Side.A
	if _replay == null:
		_replay = CardMatchReplay.new()
		_replay.state_rebuilt.connect(_on_replay_state)
		add_child(_replay)
	return _replay.load_record(record)


## 指定の手数まで進めた局面へ飛ぶ(再生コントロールと検証から使う)。
func replay_goto(count: int) -> void:
	if _replay != null:
		_replay.goto(count)


## 巻き戻すたびに `MatchState` が作り直されるため、購読も張り直す。
func _on_replay_state(new_state: MatchState) -> void:
	if state != null and is_instance_valid(state):
		state.queue_free()
	state = new_state
	refresh()


## 相手の手番中・準備中は操作できない。
func stop_networking() -> void:
	if _online != null:
		_online.stop()
	if _setup != null:
		# 対局が始まる前の中断は「取りやめ」なので、復帰の記録も残さない。
		OnlineResume.clear()
		await _setup.cancel()


# --- 組み立て -----------------------------------------------------------


## 対局を開始する共通処理。CPU戦とオンラインで同じ経路を通す。
func _begin_state(
	deck_a: Array, deck_b: Array, seed_value: int, use_mulligan: bool = false
) -> void:
	state = MatchState.new()
	add_child(state)
	state.turn_started.connect(_on_turn_started)
	state.match_ended.connect(_on_match_ended)
	# 砂の演出。**ダメージ(消える)とターン終了の1粒(落ちる)を別経路で受ける**
	# (GameDesign.md 9章)。取り違えるとルールを誤解するため。
	state.unit_damaged.connect(_strike.on_unit_damaged)
	state.unit_ticked.connect(_strike.on_unit_ticked)
	state.unit_flipped.connect(
		func(side: int, slot: int) -> void: _flip_beam.play_flip(self, side, slot)
	)
	_log.set_perspective(my_side)
	state.start_match(
		deck_a, deck_b, MatchState.Side.A, seed_value, MatchState.COIN_ENABLED, use_mulligan
	)
	_log.watch(state)
	_feed.watch(self, _log)
	# 効果音と演出は配り終えてから張る(初期手札のドローまで鳴らさないため)。
	_sound.watch(state)
	_effects.watch(state)
	# 決着で止めた対局のBGMを、「もう一度」で戻す(GameDesign.md 9章)。
	MusicPlayer.play(MusicPlayer.Track.MATCH)
	refresh()


func _build() -> void:
	# 下地と卓は最初に足して盤面の駒より背面へ置く。
	add_child(ScreenBackdrop.new())
	var table := BoardTable.new()
	table.position = TABLE_RECT.position
	table.size = TABLE_RECT.size
	add_child(table)
	_foe_bar = _make_bar(true, FOE_BAR_TOP)
	_own_bar = _make_bar(false, OWN_BAR_TOP)
	_foe_slots = _make_row(FOE_ROW_TOP, true)
	_own_slots = _make_row(OWN_ROW_TOP, false)
	for i in MatchState.DECK_SIZE:
		var view := CardView.new()
		view.mode = CardView.Mode.HAND
		view.visible = false
		view.hover_zoom = true
		view.pressed.connect(_on_hand_pressed)
		view.hovered.connect(_on_view_hovered)
		view.mouse_exited.connect(_on_view_left)
		add_child(view)
		_hand_views.append(view)
	# 反転だけは選んだ駒のすぐ下へ出す。位置は `_refresh_buttons()` が毎回決める。
	_flip_button = _add_button("反転", FLIP_BUTTON_SIZE)
	_flip_button.visible = false
	_flip_button.pressed.connect(_on_flip_pressed)
	_coin_button = _add_button("コイン", ACTION_BUTTON_SIZE)
	_coin_button.position = Vector2(ACTION_COLUMN_X, 230)
	_coin_button.pressed.connect(_on_coin_pressed)
	# ターン終了は画面中央付近の大きなボタンとする。
	_end_turn_button = _add_button("ターン終了", TURN_END_BUTTON_SIZE)
	_end_turn_button.position = Vector2(ACTION_COLUMN_X, TURN_END_BUTTON_TOP)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	# 「ログ」「投了」「エモート」はターン終了ボタンの下へ順に並べる。
	_log_button = _add_button("ログ", ACTION_BUTTON_SIZE)
	_log_button.position = Vector2(ACTION_COLUMN_X, LOG_BUTTON_TOP)
	_log_button.pressed.connect(func() -> void: _log.set_open(true))
	_surrender_button = _add_button("投了", ACTION_BUTTON_SIZE)
	_surrender_button.position = Vector2(ACTION_COLUMN_X, SURRENDER_BUTTON_TOP)
	_surrender_button.pressed.connect(_on_surrender_pressed)
	# リプレイ再生・観戦には終局の結果パネル(「ホームへ」)が出ないため、
	# この戻るボタンが唯一の出口になる。対局中は投了が出口のため出さない。
	_back_button = _add_button("戻る", ACTION_BUTTON_SIZE)
	_back_button.position = Vector2(ACTION_COLUMN_X, BACK_BUTTON_TOP)
	_back_button.pressed.connect(func() -> void: back_pressed.emit())
	_cpu_timer = Timer.new()
	_cpu_timer.one_shot = true
	_cpu_timer.timeout.connect(_take_cpu_action)
	add_child(_cpu_timer)
	# ログと結果パネルは最後に足して盤面より手前へ重ねる。
	# **ログは結果パネルより後に足す**(GameDesign.md 9章)。終局後は結果パネルが盤面全体を
	# 塞ぐため、その上からログを開けないと読み返せない。
	# 光の筋は盤面の駒より手前、ログ・結果パネルより背面に置く。
	_flip_beam = CardFlipBeam.new()
	add_child(_flip_beam)
	_detail = CardMatchDetail.new(self)
	# 通信待ちの文言と対象選択の案内は、駒より手前へ出すため独立したノードで描く。
	_status = CardMatchStatus.new()
	add_child(_status)
	_feed = CardMatchTurnFeed.new()
	add_child(_feed)
	_mulligan = CardMatchMulligan.new()
	_mulligan.confirmed.connect(_on_mulligan_confirmed)
	add_child(_mulligan)
	# **誘導対局の帯はマリガンより後に足す**(GameDesign.md 18章)。マリガンの暗幕の下へ
	# 敷くと、いちばん案内が要る最初の画面ですなえるが読めなくなる。
	_tutorial = CardMatchTutorial.new()
	add_child(_tutorial)
	_result = CardMatchResult.new()
	_result.home_pressed.connect(func() -> void: back_pressed.emit())
	_result.rematch_pressed.connect(_on_rematch_pressed)
	_result.log_pressed.connect(func() -> void: _log.set_open(true))
	add_child(_result)
	_log = CardMatchLog.new()
	add_child(_log)
	_pile = CardPileViewer.new()
	add_child(_pile)
	_alert = CardMatchAlert.new()
	add_child(_alert)
	_damage_assist = CardMatchDamageAssist.new(self)
	add_child(_damage_assist)
	_history = CardMatchActionHistory.new(self)
	add_child(_history)


func _make_bar(opponent: bool, top: float) -> PlayerInfoBar:
	var bar := PlayerInfoBar.new()
	bar.is_opponent = opponent
	bar.position = Vector2(MARGIN, top)
	# 両者の情報帯は同じ幅にする。右端に行動の列を通すため、どちらもその手前で止める
	# (相手側だけ画面いっぱいに伸ばすと、対面させた2本の帯が揃わない)。
	bar.size = Vector2(BAR_WIDTH, PlayerInfoBar.BAR_HEIGHT)
	if opponent:
		bar.face_pressed.connect(_on_face_pressed)
	bar.graveyard_pressed.connect(_on_graveyard_pressed.bind(opponent))
	add_child(bar)
	return bar


func _make_row(top: float, opponent: bool) -> Array[CardView]:
	var views: Array[CardView] = []
	var width := MatchState.BOARD_SIZE * CardView.BOARD_SIZE_PX.x
	width += (MatchState.BOARD_SIZE - 1) * CARD_GAP
	var start := TABLE_RECT.position.x + (TABLE_RECT.size.x - width) * 0.5
	for i in MatchState.BOARD_SIZE:
		var view := CardView.new()
		view.mode = CardView.Mode.BOARD
		view.position = Vector2(start + i * (CardView.BOARD_SIZE_PX.x + CARD_GAP), top)
		view.size = CardView.BOARD_SIZE_PX
		view.pressed.connect(_on_foe_slot_pressed if opponent else _on_own_slot_pressed)
		view.hovered.connect(_on_view_hovered)
		view.mouse_exited.connect(_on_view_left)
		if not opponent:
			view.drop_handler = _on_slot_drop.bind(i)
		add_child(view)
		views.append(view)
	return views


func _add_button(label: String, button_size: Vector2) -> Button:
	var button := CodedButton.make(label, button_size)
	add_child(button)
	return button


# --- 表示の同期 ---------------------------------------------------------


func refresh() -> void:
	if state == null:
		return
	var foe := MatchState.other_side(my_side)
	refresh_bars()
	var live: bool = _interactive and not state.is_match_over()
	_own_bar.active = live and state.current_turn == my_side
	_foe_bar.active = live and state.current_turn == foe
	_refresh_row(_foe_slots, foe)
	_refresh_row(_own_slots, my_side)
	_refresh_hand()
	_targets.refresh()
	_refresh_buttons()
	if _damage_assist != null:
		_damage_assist.sync()
	_status.set_targeting(_selection != null and _selection.is_targeting())
	# 対象選択に入った・演出が始まったぶんは、ホバーが動かなくてもここで引っ込める。
	if _detail != null:
		_detail.sync()


func _refresh_row(views: Array[CardView], side: int) -> void:
	for i in MatchState.BOARD_SIZE:
		var unit: CardInstance = state.board[side][i]
		views[i].show_unit(unit)
		views[i].exhausted = unit != null and side == my_side and not unit.can_attack()
		views[i].ready_mark = unit != null and side == my_side and unit.can_attack()
		views[i].selected = false
		views[i].enabled = true
		views[i].preview_health = -1
		views[i].preview_dead = false


func _refresh_hand() -> void:
	var hand: Array = state.hand[my_side]
	var count: int = mini(hand.size(), _hand_views.size())
	# 手札は最大10枚を超えうるため、収まらなくなったら重ねてでも領域内に留める
	# (はみ出すと「ログ」「投了」のボタンへ潜り込んでしまう)。
	var step := CardView.HAND_SIZE_PX.x + HAND_GAP
	if count > 1:
		step = minf(step, (HAND_AREA.size.x - CardView.HAND_SIZE_PX.x) / float(count - 1))
	var width := CardView.HAND_SIZE_PX.x + maxf(count - 1, 0) * step
	var start := HAND_AREA.position.x + (HAND_AREA.size.x - width) * 0.5
	for i in _hand_views.size():
		var view := _hand_views[i]
		if i >= count:
			view.visible = false
			continue
		view.visible = true
		view.position = Vector2(start + i * step, HAND_TOP)
		view.size = CardView.HAND_SIZE_PX
		var usable: bool = state.can_play(my_side, i) or state.can_cast(my_side, i)
		view.show_card(hand[i], _my_turn() and usable)
		view.selected = _selection.is_hand(i)
		view.draggable = view.enabled


func _refresh_buttons() -> void:
	var over: bool = state.is_match_over()
	_end_turn_button.visible = _interactive
	_end_turn_button.disabled = not _my_turn()
	_end_turn_button.modulate = Color(1, 1, 1)
	_log_button.visible = _interactive
	_surrender_button.visible = _interactive and not over
	_back_button.visible = not _interactive
	_coin_button.visible = _interactive and state.coin_available.get(my_side, false)
	_coin_button.disabled = not _my_turn()
	var show_flip := (
		_selection.is_board_selection() and _my_turn() and state.can_flip(my_side, _selection.slot)
	)
	_flip_button.visible = show_flip
	if show_flip:
		_flip_button.position = _flip_button_position(_selection.slot)
	if _emote != null:
		_emote.refresh()


## 選んだ駒の真下。駒の中心へ横を揃え、下端へわずかに重ねて置く。
func _flip_button_position(slot: int) -> Vector2:
	var view: CardView = _own_slots[slot]
	var x: float = view.position.x + (view.size.x - FLIP_BUTTON_SIZE.x) * 0.5
	return Vector2(x, view.position.y + view.size.y - FLIP_BUTTON_OVERLAP)


func _my_turn() -> bool:
	if not _interactive or _strike.busy():
		return false
	return state != null and not state.is_match_over() and state.current_turn == my_side


## 対局が終わったらポーリングを止める(Architecture.md 6.1節)。ホームへ戻った後も
## Firestoreを読み続けないようにするため。
func _stop_polling() -> void:
	if _online != null:
		_online.stop()


# --- 詳細(ホバー中だけ表示) --------------------------------------------


## 出し消しは `CardMatchDetail` が持つ(GameDesign.md 9章)。ここに残すのは、
## 手を指した直後など「盤面が変わったから消す」側の呼び出しだけ。
func _hide_detail() -> void:
	if _detail != null:
		_detail.hide_now()


## 詳細は `_build()` の途中で作るため、駒より後に用意される。受け口を関数にして
## その時点の `_detail` を読む(生成時に束ねると、まだ空の参照を掴む)。
func _on_view_hovered(view: CardView) -> void:
	if _detail != null:
		_detail.hover(view)


func _on_view_left() -> void:
	if _detail != null:
		_detail.leave()


# --- 操作 ---------------------------------------------------------------


func _on_hand_pressed(view: CardView) -> void:
	if not _my_turn():
		return
	var index := _hand_views.find(view)
	if index < 0:
		return
	if state.can_cast(my_side, index):
		_spell.begin(index)
		return
	if not state.can_play(my_side, index):
		return
	_selection.select_hand(index)
	refresh()


## 手札を空き枠へドラッグして出す(GameDesign.md 9章)。押して枠を選ぶ経路と同じ
## `_play_selected()` へ合流させ、設置効果の対象選択も同じように働くようにする。
func _on_slot_drop(source: CardView, slot: int) -> void:
	if not _my_turn() or state.board[my_side][slot] != null:
		return
	var index := _hand_views.find(source)
	if index < 0:
		return
	if state.can_cast(my_side, index):
		_spell.begin(index)
		return
	if not state.can_play(my_side, index):
		return
	_selection.select_hand(index)
	_play_selected(slot)


func _on_own_slot_pressed(view: CardView) -> void:
	var slot := _own_slots.find(view)
	if slot < 0:
		return
	if not _my_turn():
		return
	if _selection.is_targeting():
		# 味方1体を対象に取る砂術は、自分の駒を押して確定する。
		if _selection.slot < 0 and state.board[my_side][slot] != null:
			_spell.cast_at(my_side, slot)
			return
		_selection.clear()
		refresh()
		return
	if _selection.is_hand_selection():
		# 上書き設置は行わないため、埋まっている枠は選べない。
		if state.board[my_side][slot] == null:
			_play_selected(slot)
		return
	if state.board[my_side][slot] == null:
		_selection.clear()
	else:
		_selection.select_board(slot)
	refresh()


func _on_foe_slot_pressed(view: CardView) -> void:
	var slot := _foe_slots.find(view)
	if slot < 0:
		return
	if _my_turn() and _selection.is_targeting():
		if state.board[MatchState.other_side(my_side)][slot] == null:
			return
		var foe := MatchState.other_side(my_side)
		# slot が -1 のままなら砂術(置く枠を持たない)。
		if _selection.slot < 0:
			_spell.cast_at(foe, slot)
			return
		var target := {"side": foe, "slot": slot}
		_perform(MatchAction.play(my_side, _selection.hand_index, _selection.slot, target))
		_selection.clear()
		_hide_detail()
		refresh()
		return
	if _my_turn() and _selection.is_board_selection():
		if state.can_attack(my_side, _selection.slot, slot):
			_perform(MatchAction.attack(my_side, _selection.slot, slot))
			_selection.clear()
			_hide_detail()
			refresh()
			return


func _on_face_pressed() -> void:
	if not _my_turn() or not _selection.is_board_selection():
		return
	if not state.can_attack(my_side, _selection.slot, -1):
		return
	_perform(MatchAction.attack(my_side, _selection.slot, -1))
	_selection.clear()
	refresh()


func _play_selected(slot: int) -> void:
	var index := _selection.hand_index
	var card: CardData = state.hand[my_side][index]
	# 相手1体を対象に取る設置効果は、出す前に対象を選ばせる(GameDesign.md 9章)。
	# 相手の場が空なら選ばせる意味がないため、そのまま出す。
	if _needs_target(card) and not state.units(MatchState.other_side(my_side)).is_empty():
		_selection.await_target(index, slot)
		refresh()
		return
	_perform(MatchAction.play(my_side, index, slot))
	_selection.clear()
	refresh()


static func _needs_target(card: CardData) -> bool:
	for effect in card.effects_for(CardEnums.Trigger.ON_PLAY):
		if effect.target == CardEnums.EffectTarget.ENEMY_UNIT:
			return true
	return false


func _on_flip_pressed() -> void:
	if not _my_turn() or not _selection.is_board_selection():
		return
	_perform(MatchAction.flip(my_side, _selection.slot))
	refresh()


func _on_coin_pressed() -> void:
	if _my_turn():
		_perform({"type": "coin", "side": my_side})
		refresh()


func _on_end_turn_pressed() -> void:
	if _my_turn():
		_selection.clear()
		_hide_detail()
		_perform(MatchAction.end_turn(my_side))


func hand_view(index: int) -> CardView:
	return _hand_views[index]


func own_slot_view(slot: int) -> CardView:
	return _own_slots[slot]


func foe_slot_view(slot: int) -> CardView:
	return _foe_slots[slot]


func selection_kind() -> int:
	return _selection.kind


func battle_log() -> CardMatchLog:
	return _log


func _on_surrender_pressed() -> void:
	if state != null and not state.is_match_over():
		_perform({"type": "surrender", "side": my_side})


# --- 手番・CPU ----------------------------------------------------------


## 墓地の中身を見る。山札の中身は見られない(GameDesign.md 9章)。
func _on_graveyard_pressed(opponent: bool) -> void:
	if state == null:
		return
	var side: int = MatchState.other_side(my_side) if opponent else my_side
	_pile.open_pile("相手の墓地" if opponent else "あなたの墓地", state.graveyard[side])


func _record(action: Dictionary) -> void:
	# エモートは盤面を動かさないため棋譜へ残さない。残すとリプレイの手数だけが増え、
	# コマ送りで何も起きない手を挟むことになる(オンラインは通信の経路として送る)。
	if action.get("type", "") == "emote":
		return
	if not _cpu_record.is_empty():
		(_cpu_record["actions"] as Array).append(action)


## 自分の1手を適用する。オンラインなら同時に相手へ送る。
## **すべての操作をこの1箇所へ通す**ことで、送信し忘れる経路が生まれないようにする。
## CPUのマリガンは先に決めておく。適用の順序は `MatchState` が A → B に固定するため、
## どちらが先に確定しても同じ対局になる。
func _start_cpu_mulligan() -> void:
	if not state.mulligan_pending:
		return
	var foe := MatchState.other_side(my_side)
	_perform(MatchAction.mulligan(foe, _cpu.choose_mulligan(state, foe)))
	_mulligan.show_hand(state.hand[my_side])


func _on_mulligan_confirmed(indices: Array) -> void:
	if state == null or not state.mulligan_pending:
		return
	_perform(MatchAction.mulligan(my_side, indices))


func _perform(action: Dictionary) -> void:
	if _emote != null and action.get("type", "") != "emote":
		_emote.close_popup()
	if _history != null:
		var atype: String = action.get("type", "")
		if atype != "emote" and atype != "mulligan":
			_history.push_action(my_side, _action_summary(action))
	_record(action)
	_strike.capture(action)
	MatchAction.apply(state, action)
	if _online == null:
		_clocks.start_turn()
		_finish_action()
		return
	var payload := action.duplicate(true)
	# 持ち時間は各手に添えて送る(GameDesign.md 11章)。通信の遅延ぶん相手の時計を
	# 手元で減らし続けると、実際より早く時間切れと判定してしまうため。
	if _clocks.active():
		payload["clock"] = _clocks.remaining(my_side)
		_clocks.start_turn()
	_online.send(payload)
	_finish_action()


## アクション辞書を短い日本語1行にまとめる。履歴プレビューに使う。
static func _action_summary(action: Dictionary) -> String:
	match action.get("type", ""):
		"play":
			return "ユニット設置"
		"attack":
			return "攻撃"
		"flip":
			return "反転"
		"cast":
			return "砂術使用"
		"end_turn":
			return "ターン終了"
		"time_up":
			return "時間切れ"
		"coin":
			return "コイン使用"
		"surrender":
			return "投了"
		"mulligan":
			return "マリガン"
	return action.get("type", "?")


## 1手を適用し終えたときの締め。攻撃なら演出を挟み、終わってから表示を更新する。
## **すべての適用経路(自分・オンライン・CPU)をここへ通す**ことで、
## 演出を挟むかどうかの判断が1箇所に収まる。
func _finish_action() -> void:
	if _strike.play():
		return
	on_strike_finished()


## 攻撃の演出が終わった(攻撃でなければ即座に呼ばれる)。
func on_strike_finished() -> void:
	refresh()
	if _cpu_followup:
		_cpu_followup = false
		if _cpu != null and not state.is_match_over():
			_cpu_timer.start(CPU_THINK_SECONDS * 0.4)


## 情報帯。ドロー・疲労の演出の出どころとして進行役から引く。
func bar_for(side: int) -> PlayerInfoBar:
	return _own_bar if side == my_side else _foe_bar


## 攻撃の演出中かどうか。効果音・演出を当たる瞬間まで持ち越すかの判断に使う。
func strike_busy() -> bool:
	return _strike.busy()


## 盤面の1枠の表示。切り出した進行役(`CardMatchStrike` 等)からも引く。
func view_at(side: int, slot: int) -> CardView:
	return _own_slots[slot] if side == my_side else _foe_slots[slot]


## 情報帯だけを同期する。攻撃が当たった瞬間にHPを合わせるために使う
## (盤面の駒は演出が終わるまで更新しない)。
func refresh_bars() -> void:
	if state == null:
		return
	_foe_bar.show_state(state, MatchState.other_side(my_side))
	_own_bar.show_state(state, my_side)


## 盤面の1枠の中心。実況の吹き出しを出す位置に使う。
func slot_center(side: int, slot: int) -> Vector2:
	if slot < 0:
		return Vector2(size.x * 0.5, FOE_ROW_TOP)
	var view := view_at(side, slot)
	return view.position + Vector2(view.size.x * 0.5, CardView.PEDESTAL_CENTER_Y)


## いま操作を受け付ける対局か(再生・観戦では実況を出さない)。
func is_interactive() -> bool:
	return _interactive


## マリガン画面が開いているか。詳細をホバーで出してよいかの判断に使う。
func mulligan_open() -> bool:
	return _mulligan != null and _mulligan.visible


## いま出せる手札の矩形。誘導対局が「これを押す」と光らせるのに使う。
func playable_hand_rects() -> Array[Rect2]:
	var found: Array[Rect2] = []
	for view in _hand_views:
		if view.visible and view.enabled:
			found.append(Rect2(view.position, view.size))
	return found


## ターン終了ボタンの矩形。誘導対局が「ここを押す」と光らせるのに使う。
func end_turn_button_rect() -> Rect2:
	return Rect2(_end_turn_button.position, _end_turn_button.size)


## HPバーの中心。攻撃が相手プレイヤーを狙うときの的。
func hp_bar_center(side: int) -> Vector2:
	var bar: PlayerInfoBar = _own_bar if side == my_side else _foe_bar
	return bar.position + bar.hp_bar_rect().get_center()


## 反転した。行った側の情報帯から対象の駒へ光の筋を伸ばし、届いた瞬間に駒を裏返す。
## 自分の駒しか反転できないため、筋の向き(上から / 下から)がそのまま
## 「どちらのプレイヤーが手を出したのか」を示す。
func _on_turn_started(side: int) -> void:
	_mulligan.close()
	_hide_detail()
	refresh()
	# 自分の番が回ってきたことだけ知らせる。相手の番であることは情報帯の縁と実況で分かる。
	if side == my_side and _interactive and not state.is_match_over():
		_feed.announce_turn()
	if _cpu != null and side != my_side and not state.is_match_over():
		_cpu_timer.start(CPU_THINK_SECONDS)


## 選択は右クリックとEscでも取り消せるようにする(GameDesign.md 9章)。
## 「他を押す」以外に戻る手段が無いと、対象選択に入った後の抜け方が分からない。
func _unhandled_input(event: InputEvent) -> void:
	if not _interactive:
		return
	var cancelled := event.is_action_pressed("ui_cancel")
	if not cancelled and event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		cancelled = click.pressed and click.button_index == MOUSE_BUTTON_RIGHT
	if not cancelled:
		return
	# エモートの選択も同じ操作で閉じる。開いたまま盤面を隠し続ける状態を作らない。
	if _emote != null and _emote.popup_open():
		_emote.close_popup()
		get_viewport().set_input_as_handled()
		return
	if _selection.is_empty():
		return
	_selection.clear()
	refresh()
	get_viewport().set_input_as_handled()


func _take_cpu_action() -> void:
	if _cpu == null or state.is_match_over():
		return
	var side := state.current_turn
	if side == my_side:
		return
	var action := _cpu.choose_action(state, side)
	_record(action)
	_strike.capture(action)
	MatchAction.apply(state, action)
	# 続けて指すのは演出が終わってから。重ねると駒が2体同時に渡ってしまう。
	_cpu_followup = action["type"] != "end_turn" and not state.is_match_over()
	_finish_action()


## 同じデッキでもう1局(GameDesign.md 9章)。相手のデッキは13章のとおり毎回ランダムに組む。
func _on_rematch_pressed() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	start_cpu_match(_own_deck, CardDeckSave.random_deck(rng))


func _on_match_ended(_winner: int) -> void:
	OnlineResume.clear()
	_selection.clear()
	_hide_detail()
	refresh()
	_stop_polling()
	# 再生中は結果パネルを出さない。最後の手まで進めるたびに操作を塞ぐと
	# 前後に動かせなくなるため(GameDesign.md 9章)。
	if not _interactive:
		return
	# 終局後の後始末(リプレイ・砂金・戦績)は `CardMatchOutcome` が持つ。
	var reward := _outcome.finish(_match_kind, _own_deck)
	_result.show_for(
		state, my_side, state.turn_count, reward, _match_kind == CurrencyRules.MatchKind.CPU
	)
