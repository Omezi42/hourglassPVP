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
## 手札は**卓と同じ左右の範囲**へ置き、盤面の真下で中央に揃える。以前は右下の
## 「ログ」「投了」を避けるため左へ寄せており、駒の列と手札の中心が94pxずれていた。
const HAND_AREA := Rect2(190, 528, 900, 158)
## 12枠を載せる卓上(GameDesign.md 9章)。両陣営の6枠がこの上に並ぶ。
const TABLE_RECT := Rect2(190, 74, 900, 372)
const CPU_THINK_SECONDS := 0.5
## 相手の持ち時間が0になってから、申告が来なくても勝ちにするまでの猶予
## (GameDesign.md 11章)。相手が切断していると申告そのものが届かないため。
const OPPONENT_TIMEOUT_GRACE := 8.0
## 反転・コイン・ターン終了を縦に並べる右の列。
const ACTION_COLUMN_X := 1108.0
## 対局中のカード詳細(GameDesign.md 9章)。盤面は左右の余白が190pxしかないため
## 卓へ重ねて出す。**指しているカードと反対側へ出す**ことで、読みたいものを
## 自分で隠さないようにする。ホバーを外すと消えるため、盤面を塞ぎ続けはしない。
const DETAIL_TOP := 40.0
const DETAIL_MARGIN := 12.0
## ホバーを外してから消すまでの猶予。カードとパネルの間をカーソルが通るため。
const DETAIL_HIDE_DELAY := 0.12
const ACTION_BUTTON_SIZE := Vector2(148, 48)
const LOG_BUTTON_SIZE := Vector2(148, 44)
const LOG_BUTTON_TOP := 546.0
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
## 再生モードでは盤面を一切操作できない(GameDesign.md 12章)。
var _interactive := true
var _mulligan: CardMatchMulligan
var _detail: CardDetailPanel
var _keyword_popup: KeywordPopup
var _detail_timer: Timer
## 自分が持ち込んだデッキ。「もう一度」で組み直すときと、戦績の記録(GameDesign.md 19章)に使う。
var _own_deck: Array = []
var _tutorial: CardMatchTutorial
var _outcome: CardMatchOutcome
## 砂金の獲得量を決める対局の種別(GameDesign.md 15章)。
var _match_kind: CurrencyRules.MatchKind = CurrencyRules.MatchKind.NONE
## 持ち時間。オンライン対戦だけが使う(CPU戦はローカルのため無制限。GameDesign.md 13章)。
var _clock: MatchClock = null
## 相手の持ち時間が0になってからの経過。申告が来ない(切断した)場合の保険。
var _opponent_timeout_wait := 0.0
## CPU戦の棋譜。オンラインは matches/{id} が同じ内容を持つため、こちらはCPU戦だけが使う。
var _cpu_record: Dictionary = {}
## 相手を待っている間に出す文言。空なら出さない。
var _log: CardMatchLog
var _result: CardMatchResult
var _pile: CardPileViewer
var _log_button: Button
var _flip_beam: CardFlipBeam
## 攻撃の演出の進行役。演出中は盤面の操作を止める。
var _strike: CardMatchStrike
var _targets: CardMatchTargets
## 手番のバナーと、相手の1手の実況。
var _feed: CardMatchTurnFeed
## 演出が終わったらCPUに続きを指させるか。
var _cpu_followup := false
var _surrender_button: Button
var _back_button: Button
var _status: CardMatchStatus


func _ready() -> void:
	_build()
	# 持ち時間を持つのはオンライン対戦だけ。それ以外では毎フレーム走らせない。
	set_process(false)
	_outcome = CardMatchOutcome.new(self)
	_strike = CardMatchStrike.new(self)
	_targets = CardMatchTargets.new(self)


## 前の対局の名残を落としてから新しい対局へ入る。結果パネル・ログ・選択・
## タイマー・通信・棋譜はいずれも画面が使い回されるため対局をまたいで残り、
## 片付けないと2局目が「対戦終了の表示のまま遊べない」状態になる。
func _reset_for_new_match() -> void:
	_result.visible = false
	_log.set_open(false)
	_log.clear()
	_pile.visible = false
	_selection.clear()
	_cpu_timer.stop()
	if _replay != null:
		_replay.stop()
	if _online != null:
		# 停止したノードは解放しない(Architecture.md 6.1節)。参照だけを落とす。
		_online.stop()
		_online = null
	_setup = null
	_client = null
	_match_id = ""
	_clock = null
	_cpu_record = {}
	_status.set_waiting("")
	_opponent_timeout_wait = 0.0
	if _mulligan != null:
		_mulligan.close()
	if _tutorial != null:
		_tutorial.visible = false
	set_process(false)
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
	_foe_bar.display_name = "CPU"
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
	_tutorial.watch(state, my_side)


## オンライン対戦を開始する。配置フェーズは無く、デッキと山札の種を交換したら
## そのまま対局へ入る(GameDesign.md 2章・11章)。
func start_online_match(
	deck_self: Array,
	client: FirestoreClient,
	p_match_id: String,
	p_my_side: int,
	is_room: bool = false,
	opponent_uid: String = ""
) -> void:
	_reset_for_new_match()
	_cpu = null
	_interactive = true
	_match_kind = CurrencyRules.MatchKind.ROOM if is_room else CurrencyRules.MatchKind.RANDOM
	my_side = p_my_side
	_own_deck = deck_self
	_apply_player_names(client, opponent_uid)
	_status.set_waiting("対戦相手を待っています")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var seed_value := rng.randi_range(1, 1 << 30)
	_client = client
	_match_id = p_match_id
	_setup = OnlineSetup.new(client, p_match_id, p_my_side)
	add_child(_setup)
	await _setup.push_setup(CardLibrary.ids_from_deck(deck_self), seed_value)
	var result: Dictionary = await _setup.wait_for_opponent_setup(seed_value)
	var opponent_ids: Array = result["deck"]
	if opponent_ids.is_empty():
		_status.set_waiting(_setup.abort_message())
		return
	_status.set_waiting("")
	var opponent_deck := CardLibrary.deck_from_ids(opponent_ids)
	_begin_state(
		deck_self if p_my_side == MatchState.Side.A else opponent_deck,
		opponent_deck if p_my_side == MatchState.Side.A else deck_self,
		int(result["seed"]),
		true
	)
	_online = OnlineMatch.new(client)
	add_child(_online)
	_online.action_received.connect(_on_action_received)
	_online.start(p_match_id)
	# 切断しても同じ対局へ戻れるようにする(GameDesign.md 11章)。
	OnlineResume.remember(p_match_id, p_my_side, is_room, opponent_uid)
	# マリガンは手と同じ `actions` として送り合う(GameDesign.md 2章)。両者の確定が
	# 揃うまで対局は始まらないため、持ち時間はここを抜けてから動かし始める。
	if state.mulligan_pending:
		_mulligan.show_hand(state.hand[my_side])
		await state.mulligan_finished
	# 持ち時間はオンライン対戦だけが使う(GameDesign.md 13章)。
	_clock = MatchClock.new()
	_clock.time_out.connect(_on_local_timeout)
	_clock.start_turn(state.current_turn)
	set_process(true)


## 対戦相手の表示名を出す(GameDesign.md 14章)。取得できなければ既定の「相手」のまま。
func _apply_player_names(client: FirestoreClient, opponent_uid: String) -> void:
	_own_bar.display_name = AccountService.display_name()
	if opponent_uid.is_empty():
		return
	var name: String = await AccountService.fetch_display_name(client, opponent_uid)
	if not name.is_empty():
		_foe_bar.display_name = name
	refresh()


## 自分の持ち時間が尽きた。切れた本人が申告する(GameDesign.md 11章)。
func _on_local_timeout(_side: int) -> void:
	if state != null and not state.is_match_over():
		_perform({"type": "timeout", "side": my_side})


func _process(delta: float) -> void:
	if _clock == null or state == null or state.is_match_over():
		return
	_clock.tick(delta)
	_watch_opponent_timeout(delta)
	_refresh_clocks()


## 相手の持ち時間が0になっても申告が来ない場合、猶予を置いて待っている側の勝ちにする。
func _watch_opponent_timeout(delta: float) -> void:
	var foe := MatchState.other_side(my_side)
	if _clock.get_remaining(foe) > 0.0:
		_opponent_timeout_wait = 0.0
		return
	_opponent_timeout_wait += delta
	if _opponent_timeout_wait >= OPPONENT_TIMEOUT_GRACE:
		_opponent_timeout_wait = 0.0
		state.surrender(foe, MatchState.EndReason.TIMEOUT)


func _refresh_clocks() -> void:
	_own_bar.clock_seconds = _clock.get_remaining(my_side)
	_foe_bar.clock_seconds = _clock.get_remaining(MatchState.other_side(my_side))
	_own_bar.queue_redraw()
	_foe_bar.queue_redraw()


func _on_action_received(action: Dictionary) -> void:
	if _clock != null and action.has("clock"):
		_clock.remaining[MatchState.other_side(my_side)] = float(action["clock"])
		_clock.finish_turn(state.current_turn)
	_strike.capture(action)
	MatchAction.apply(state, action)
	if _clock != null and state != null and not state.is_match_over():
		_clock.start_turn(state.current_turn)
	_finish_action()


## 切断した対局へ戻る(GameDesign.md 11章)。局面は保存しておらず、
## `matches/{id}` に残る「デッキ・山札の種・指した手の並び」から作り直す
## (リプレイ・観戦と同じ経路)。終わっている対局へは戻さない。
func resume_online_match(client: FirestoreClient, record: Dictionary) -> bool:
	var match_id: String = record.get("match_id", "")
	var p_my_side: int = int(record.get("side", MatchState.Side.A))
	_reset_for_new_match()
	_cpu = null
	_interactive = true
	_match_kind = (
		CurrencyRules.MatchKind.ROOM
		if bool(record.get("is_room", false))
		else CurrencyRules.MatchKind.RANDOM
	)
	my_side = p_my_side
	_apply_player_names(client, record.get("opponent_uid", ""))
	var doc: Dictionary = await client.get_document("matches/%s" % match_id)
	var deck_a := CardLibrary.deck_from_ids(doc.get("deck_a", []))
	var deck_b := CardLibrary.deck_from_ids(doc.get("deck_b", []))
	if deck_a.size() != MatchState.DECK_SIZE or deck_b.size() != MatchState.DECK_SIZE:
		OnlineResume.clear()
		_status.set_waiting("前回の対局は見つかりませんでした")
		return false
	_own_deck = deck_a if p_my_side == MatchState.Side.A else deck_b
	var actions: Array = doc.get("actions", [])
	_begin_state(deck_a, deck_b, int(doc.get("seed", 0)), MatchAction.contains_mulligan(actions))
	for action in actions:
		MatchAction.apply(state, action)
	if state.is_match_over() or doc.has("finished_at"):
		OnlineResume.clear()
		_status.set_waiting("前回の対局は既に終わっています")
		return false
	refresh()
	_client = client
	_match_id = match_id
	_online = OnlineMatch.new(client)
	add_child(_online)
	_online.action_received.connect(_on_action_received)
	_online.start(match_id, actions.size())
	# 持ち時間はこちら側では初期値から数え直すが、**相手はこちらの残り時間を
	# 自分の手元で減らし続けている**(GameDesign.md 11章)。したがって再読み込みで
	# 時計を戻す抜け道にはならず、時間切れの判定は相手側が持つ。
	_clock = MatchClock.new()
	_clock.time_out.connect(_on_local_timeout)
	_clock.start_turn(state.current_turn)
	set_process(true)
	return true


## 観戦モードとして開始する(GameDesign.md 12章)。進行中の対局を第三者が見る。
## 手を送らず、受け取って反映するだけ。観戦者のuidは対局者のどちらとも違うため、
## OnlineMatch のポーリングは両者の手をそのまま配ってくる。
func start_spectate(client: FirestoreClient, p_match_id: String) -> bool:
	_reset_for_new_match()
	_cpu = null
	_interactive = false
	my_side = MatchState.Side.A
	var record: Dictionary = await client.get_document("matches/%s" % p_match_id)
	var deck_a := CardLibrary.deck_from_ids(record.get("deck_a", []))
	var deck_b := CardLibrary.deck_from_ids(record.get("deck_b", []))
	if deck_a.size() != MatchState.DECK_SIZE or deck_b.size() != MatchState.DECK_SIZE:
		_status.set_waiting("この対局はまだ始まっていません")
		return false
	var actions: Array = record.get("actions", [])
	_begin_state(deck_a, deck_b, int(record.get("seed", 0)), MatchAction.contains_mulligan(actions))
	# 既に進んでいる手をまとめて追いつかせてから、以降をポーリングで受け取る。
	for action in actions:
		MatchAction.apply(state, action)
	refresh()
	_online = OnlineMatch.new(client)
	add_child(_online)
	_online.action_received.connect(_on_action_received)
	_online.start(p_match_id, actions.size())
	return true


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
	refresh()


func _build() -> void:
	# 下地と卓は最初に足して盤面の駒より背面へ置く。
	add_child(ScreenBackdrop.new())
	var table := BoardTable.new()
	table.position = TABLE_RECT.position
	table.size = TABLE_RECT.size
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		view.hovered.connect(_on_card_hovered)
		view.mouse_exited.connect(_hide_detail_soon)
		add_child(view)
		_hand_views.append(view)
	# 行動のボタンは盤面と重ならないよう画面右の列にまとめる。
	_flip_button = _add_button("反転", ACTION_BUTTON_SIZE)
	_flip_button.position = Vector2(ACTION_COLUMN_X, 306)
	_flip_button.visible = false
	_flip_button.pressed.connect(_on_flip_pressed)
	_coin_button = _add_button("コイン", ACTION_BUTTON_SIZE)
	_coin_button.position = Vector2(ACTION_COLUMN_X, 362)
	_coin_button.pressed.connect(_on_coin_pressed)
	# ターン終了は画面右下の大きなボタンとする(GameDesign.md 9章)。
	_end_turn_button = _add_button("ターン終了", Vector2(148, 66))
	_end_turn_button.position = Vector2(ACTION_COLUMN_X, OWN_BAR_TOP - 4)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	# 「ログ」「投了」は画面下部にまとめる(同上)。手札の右隣へ置いて重ならないようにする。
	# 「ログ」「投了」も右の列へ続けて置く。手札を画面の中央へ戻すため、
	# 手札の右隣という置き場所はやめた。
	_log_button = _add_button("ログ", LOG_BUTTON_SIZE)
	_log_button.position = Vector2(ACTION_COLUMN_X, LOG_BUTTON_TOP)
	_log_button.pressed.connect(func() -> void: _log.set_open(true))
	_surrender_button = _add_button("投了", LOG_BUTTON_SIZE)
	_surrender_button.position = Vector2(ACTION_COLUMN_X, LOG_BUTTON_TOP + 56)
	_surrender_button.pressed.connect(_on_surrender_pressed)
	# リプレイ再生・観戦には終局の結果パネル(「ホームへ」)が出ないため、
	# この戻るボタンが唯一の出口になる。対局中は投了が出口のため出さない。
	_back_button = _add_button("戻る", LOG_BUTTON_SIZE)
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
	_detail = CardDetailPanel.new()
	_detail.visible = false
	_detail.mouse_entered.connect(func() -> void: _detail_timer.stop())
	_detail.mouse_exited.connect(_hide_detail_soon)
	add_child(_detail)
	_detail_timer = Timer.new()
	_detail_timer.one_shot = true
	_detail_timer.timeout.connect(func() -> void: _detail.visible = false)
	add_child(_detail_timer)
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
	# 語の意味はポップで引ける(GameDesign.md 17章)。詳細より手前へ重ねる。
	_keyword_popup = KeywordPopup.new()
	add_child(_keyword_popup)
	_detail.keyword_pressed.connect(func(entry: Dictionary) -> void: _keyword_popup.open(entry))


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
		if opponent:
			view.pressed.connect(_on_foe_slot_pressed)
		else:
			view.pressed.connect(_on_own_slot_pressed)
		view.hovered.connect(_on_card_hovered)
		view.mouse_exited.connect(_hide_detail_soon)
		# 手札は空き枠へドラッグしても出せる(GameDesign.md 9章)。
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
	_status.set_targeting(_selection != null and _selection.is_targeting())


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
		view.show_card(hand[i], _my_turn() and state.can_play(my_side, i))
		view.selected = _selection.is_hand(i)
		view.draggable = view.enabled


func _refresh_buttons() -> void:
	var over: bool = state.is_match_over()
	_end_turn_button.visible = _interactive
	_end_turn_button.disabled = not _my_turn()
	# まだ指せる手が残っているうちは色を変えて知らせる(GameDesign.md 9章)。
	# 押せなくはしない。あえて残す選択もあるため。
	var remains: bool = _my_turn() and state.has_moves_left(my_side)
	_end_turn_button.modulate = Color(1.0, 0.84, 0.6) if remains else Color(1, 1, 1)
	_log_button.visible = _interactive
	_surrender_button.visible = _interactive and not over
	_back_button.visible = not _interactive
	_coin_button.visible = _interactive and state.coin_available.get(my_side, false)
	_coin_button.disabled = not _my_turn()
	var show_flip := (
		_selection.is_board_selection() and _my_turn() and state.can_flip(my_side, _selection.slot)
	)
	_flip_button.visible = show_flip


func _my_turn() -> bool:
	if not _interactive or _strike.busy():
		return false
	return state != null and not state.is_match_over() and state.current_turn == my_side


## 対局が終わったらポーリングを止める(Architecture.md 6.1節)。ホームへ戻った後も
## Firestoreを読み続けないようにするため。
func _stop_polling() -> void:
	if _online != null:
		_online.stop()


# --- 操作 ---------------------------------------------------------------


## カードにカーソルを乗せたら効果の詳細を出す(GameDesign.md 9章)。
## 効果を覚えていないと戦えない状態を避けるため、手札・自分の駒・相手の駒すべてで引ける。
func _on_card_hovered(view: CardView) -> void:
	if view.card == null:
		return
	_detail_timer.stop()
	_detail.show_card(view.card)
	# 指しているカードと反対の側へ出す。読みたいものを自分で隠さないため。
	var to_right: bool = view.position.x + view.size.x * 0.5 < size.x * 0.5
	var left := size.x - CardDetailPanel.PANEL_SIZE.x - DETAIL_MARGIN if to_right else DETAIL_MARGIN
	_detail.position = Vector2(left, DETAIL_TOP)
	_detail.visible = true


func _hide_detail_soon() -> void:
	if _detail_timer != null:
		_detail_timer.start(DETAIL_HIDE_DELAY)


func _on_hand_pressed(view: CardView) -> void:
	if not _my_turn():
		return
	var index := _hand_views.find(view)
	if index < 0 or not state.can_play(my_side, index):
		return
	_selection.select_hand(index)
	refresh()


## 手札を空き枠へドラッグして出す(GameDesign.md 9章)。押して枠を選ぶ経路と同じ
## `_play_selected()` へ合流させ、設置効果の対象選択も同じように働くようにする。
func _on_slot_drop(source: CardView, slot: int) -> void:
	if not _my_turn() or state.board[my_side][slot] != null:
		return
	var index := _hand_views.find(source)
	if index < 0 or not state.can_play(my_side, index):
		return
	_selection.select_hand(index)
	_play_selected(slot)


func _on_own_slot_pressed(view: CardView) -> void:
	if not _my_turn():
		return
	var slot := _own_slots.find(view)
	if slot < 0:
		return
	if _selection.is_targeting():
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
	if not _my_turn():
		return
	var slot := _foe_slots.find(view)
	if slot < 0:
		return
	if _selection.is_targeting():
		if state.board[MatchState.other_side(my_side)][slot] == null:
			return
		var target := {"side": MatchState.other_side(my_side), "slot": slot}
		_perform(MatchAction.play(my_side, _selection.hand_index, _selection.slot, target))
		_selection.clear()
		refresh()
		return
	if not _selection.is_board_selection():
		return
	if not state.can_attack(my_side, _selection.slot, slot):
		return
	_perform(MatchAction.attack(my_side, _selection.slot, slot))
	_selection.clear()
	refresh()


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
		_perform(MatchAction.end_turn(my_side))


## 検証用に個々のビューを引く。
func hand_view(index: int) -> CardView:
	return _hand_views[index]


func own_slot_view(slot: int) -> CardView:
	return _own_slots[slot]


func foe_slot_view(slot: int) -> CardView:
	return _foe_slots[slot]


## いま何を選んでいるか(検証用)。
func selection_kind() -> int:
	return _selection.kind


## 対局ログ(検証・将来のリプレイ用に外から参照できるようにしておく)。
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
	_record(action)
	_strike.capture(action)
	MatchAction.apply(state, action)
	if _online == null:
		_finish_action()
		return
	var payload := action.duplicate(true)
	# 持ち時間は各手に添えて送る(GameDesign.md 11章)。通信の遅延ぶん相手の時計を
	# 手元で減らし続けると、実際より早く時間切れと判定してしまうため。
	if _clock != null:
		payload["clock"] = _clock.get_remaining(my_side)
		_clock.finish_turn(state.current_turn)
	_online.send(payload)
	_finish_action()


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


## HPバーの中心。攻撃が相手プレイヤーを狙うときの的。
func hp_bar_center(side: int) -> Vector2:
	var bar: PlayerInfoBar = _own_bar if side == my_side else _foe_bar
	return bar.position + bar.hp_bar_rect().get_center()


## 反転した。行った側の情報帯から対象の駒へ光の筋を伸ばし、届いた瞬間に駒を裏返す。
## 自分の駒しか反転できないため、筋の向き(上から / 下から)がそのまま
## 「どちらのプレイヤーが手を出したのか」を示す。
func _on_turn_started(side: int) -> void:
	_mulligan.close()
	refresh()
	# 自分の番が回ってきたことだけ知らせる。相手の番であることは情報帯の縁と実況で分かる。
	if side == my_side and _interactive and not state.is_match_over():
		_feed.announce_turn()
	if _cpu != null and side != my_side and not state.is_match_over():
		_cpu_timer.start(CPU_THINK_SECONDS)


## 選択は右クリックとEscでも取り消せるようにする(GameDesign.md 9章)。
## 「他を押す」以外に戻る手段が無いと、対象選択に入った後の抜け方が分からない。
func _unhandled_input(event: InputEvent) -> void:
	if not _interactive or _selection.is_empty():
		return
	var cancelled := event.is_action_pressed("ui_cancel")
	if not cancelled and event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		cancelled = click.pressed and click.button_index == MOUSE_BUTTON_RIGHT
	if not cancelled:
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
