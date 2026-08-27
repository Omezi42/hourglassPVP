class_name CardMatchScreen
extends Control
## v5.0の対局画面(GameDesign.md 9章「対局画面」)。
## 上から「相手の情報帯 / 相手の場6枠 / 自分の場6枠 / 自分の情報帯 / 自分の手札」。
##
## 子はすべてコード描画のControl(`CardView`/`PlayerInfoBar`)で、Inspectorから
## 編集する値を持たないため、.tscn を作らずこの1クラスで組み立てている。

signal back_pressed

const CARD_GAP := 12.0
const HAND_GAP := 10.0
const MARGIN := 16.0
const FOE_BAR_TOP := 10.0
const FOE_ROW_TOP := 78.0
const OWN_ROW_TOP := 258.0
const OWN_BAR_TOP := 440.0
const HAND_TOP := 512.0
const HAND_AREA := Rect2(190, 512, 900, 158)
const CPU_THINK_SECONDS := 0.5
const BACKGROUND := Color(0.07, 0.06, 0.08, 1.0)
## 反転・コイン・ターン終了を縦に並べる右の列。
const ACTION_COLUMN_X := 1096.0

var state: MatchState
## 自分の側。CPU戦・オンラインでは固定する。
var my_side: int = MatchState.Side.A

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
## 相手を待っている間に出す文言。空なら出さない。
var _waiting_text := ""
var _log: CardMatchLog
var _result: CardMatchResult
var _pile: CardPileViewer
var _log_button: Button
var _surrender_button: Button


func _ready() -> void:
	_build()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	var y := (FOE_ROW_TOP + CardView.BOARD_SIZE_PX.y + OWN_ROW_TOP) * 0.5
	draw_line(
		Vector2(120, y), Vector2(size.x - 120, y), UiPalette.GLOW_AMBER * Color(1, 1, 1, 0.25), 2.0
	)
	if _selection != null and _selection.is_targeting():
		_draw_target_prompt()
	if not _waiting_text.is_empty():
		draw_string(
			get_theme_default_font(),
			Vector2(size.x * 0.5 - 180, size.y * 0.5),
			_waiting_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			26,
			UiPalette.TEXT_OFFWHITE
		)


## 対象選択中であることを、行動ボタンの列(盤面と重ならない場所)へ出す。
## 盤面の上へ重ねると、選ばせたい相手のカードそのものを隠してしまう。
func _draw_target_prompt() -> void:
	var font := get_theme_default_font()
	var rect := Rect2(ACTION_COLUMN_X, 270, 168, 52)
	draw_rect(rect, Color(0.08, 0.12, 0.14, 0.95))
	draw_rect(rect, CardView.SELECT_CYAN, false, 2.0)
	draw_string(
		font,
		rect.position + Vector2(12, 24),
		"対象を選ぶ",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		20,
		CardView.SELECT_CYAN
	)
	draw_string(
		font,
		rect.position + Vector2(12, 44),
		"他を押すと取消",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		UiPalette.TEXT_OFFWHITE
	)


## CPU戦を開始する。deck_self / deck_foe は CardData の配列(20枚)。
func start_cpu_match(deck_self: Array, deck_foe: Array) -> void:
	_cpu = CardCpuStrategy.new()
	_interactive = true
	my_side = MatchState.Side.A
	_begin_state(deck_self, deck_foe, 0)


## オンライン対戦を開始する。配置フェーズは無く、デッキと山札の種を交換したら
## そのまま対局へ入る(GameDesign.md 2章・11章)。
func start_online_match(
	deck_self: Array, client: FirestoreClient, p_match_id: String, p_my_side: int
) -> void:
	_cpu = null
	_interactive = true
	my_side = p_my_side
	_waiting_text = "対戦相手を待っています"
	queue_redraw()
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
		_waiting_text = _setup.abort_message()
		queue_redraw()
		return
	_waiting_text = ""
	var opponent_deck := CardLibrary.deck_from_ids(opponent_ids)
	_begin_state(
		deck_self if p_my_side == MatchState.Side.A else opponent_deck,
		opponent_deck if p_my_side == MatchState.Side.A else deck_self,
		int(result["seed"])
	)
	_online = OnlineMatch.new(client)
	add_child(_online)
	_online.action_received.connect(_on_action_received)
	_online.start(p_match_id)


func _on_action_received(action: Dictionary) -> void:
	MatchAction.apply(state, action)
	refresh()


## リプレイ再生モードとして開始する(GameDesign.md 12章)。
## 手番の判定を使わず、`_interactive` で操作をまとめて塞ぐ。
func start_replay(record: Dictionary) -> bool:
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
		await _setup.cancel()


# --- 組み立て -----------------------------------------------------------


## 対局を開始する共通処理。CPU戦とオンラインで同じ経路を通す。
func _begin_state(deck_a: Array, deck_b: Array, seed_value: int) -> void:
	state = MatchState.new()
	add_child(state)
	state.turn_started.connect(_on_turn_started)
	state.match_ended.connect(_on_match_ended)
	# 砂の演出。**ダメージ(消える)とターン終了の1粒(落ちる)を別経路で受ける**
	# (GameDesign.md 9章)。取り違えるとルールを誤解するため。
	state.unit_damaged.connect(_on_unit_damaged)
	state.unit_ticked.connect(_on_unit_ticked)
	_log.set_perspective(my_side)
	state.start_match(deck_a, deck_b, MatchState.Side.A, seed_value)
	_log.watch(state)
	refresh()


func _build() -> void:
	_foe_bar = _make_bar(true, FOE_BAR_TOP)
	_own_bar = _make_bar(false, OWN_BAR_TOP)
	_foe_slots = _make_row(FOE_ROW_TOP, true)
	_own_slots = _make_row(OWN_ROW_TOP, false)
	for i in MatchState.DECK_SIZE:
		var view := CardView.new()
		view.mode = CardView.Mode.HAND
		view.visible = false
		view.pressed.connect(_on_hand_pressed)
		add_child(view)
		_hand_views.append(view)
	# 行動のボタンは盤面と重ならないよう画面右の列にまとめる。
	_flip_button = _add_button("反転", Vector2(168, 48))
	_flip_button.position = Vector2(ACTION_COLUMN_X, 330)
	_flip_button.visible = false
	_flip_button.pressed.connect(_on_flip_pressed)
	_coin_button = _add_button("コイン", Vector2(168, 48))
	_coin_button.position = Vector2(ACTION_COLUMN_X, 386)
	_coin_button.pressed.connect(_on_coin_pressed)
	_end_turn_button = _add_button("ターン終了", Vector2(168, 64))
	_end_turn_button.position = Vector2(ACTION_COLUMN_X, OWN_BAR_TOP)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_log_button = _add_button("ログ", Vector2(168, 44))
	_log_button.position = Vector2(ACTION_COLUMN_X, 512)
	_log_button.pressed.connect(func() -> void: _log.set_open(true))
	_surrender_button = _add_button("投了", Vector2(168, 44))
	_surrender_button.position = Vector2(ACTION_COLUMN_X, 564)
	_surrender_button.pressed.connect(_on_surrender_pressed)
	_cpu_timer = Timer.new()
	_cpu_timer.one_shot = true
	_cpu_timer.timeout.connect(_take_cpu_action)
	add_child(_cpu_timer)
	# ログと結果パネルは最後に足して盤面より手前へ重ねる。
	# **ログは結果パネルより後に足す**(GameDesign.md 9章)。終局後は結果パネルが盤面全体を
	# 塞ぐため、その上からログを開けないと読み返せない。
	_result = CardMatchResult.new()
	_result.home_pressed.connect(func() -> void: back_pressed.emit())
	_result.log_pressed.connect(func() -> void: _log.set_open(true))
	add_child(_result)
	_log = CardMatchLog.new()
	add_child(_log)
	_pile = CardPileViewer.new()
	add_child(_pile)


func _make_bar(opponent: bool, top: float) -> PlayerInfoBar:
	var bar := PlayerInfoBar.new()
	bar.is_opponent = opponent
	bar.position = Vector2(MARGIN, top)
	bar.size = Vector2(1060 if not opponent else 1248, PlayerInfoBar.BAR_HEIGHT)
	if opponent:
		bar.face_pressed.connect(_on_face_pressed)
	bar.graveyard_pressed.connect(_on_graveyard_pressed.bind(opponent))
	add_child(bar)
	return bar


func _make_row(top: float, opponent: bool) -> Array[CardView]:
	var views: Array[CardView] = []
	var width := MatchState.BOARD_SIZE * CardView.BOARD_SIZE_PX.x
	width += (MatchState.BOARD_SIZE - 1) * CARD_GAP
	var start := (1280.0 - width) * 0.5
	for i in MatchState.BOARD_SIZE:
		var view := CardView.new()
		view.mode = CardView.Mode.BOARD
		view.position = Vector2(start + i * (CardView.BOARD_SIZE_PX.x + CARD_GAP), top)
		view.size = CardView.BOARD_SIZE_PX
		if opponent:
			view.pressed.connect(_on_foe_slot_pressed)
		else:
			view.pressed.connect(_on_own_slot_pressed)
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
		queue_redraw()
		return
	var foe := MatchState.other_side(my_side)
	_foe_bar.show_state(state, foe)
	_own_bar.show_state(state, my_side)
	_refresh_row(_foe_slots, foe)
	_refresh_row(_own_slots, my_side)
	_refresh_hand()
	_refresh_targets()
	_refresh_buttons()
	queue_redraw()


func _refresh_row(views: Array[CardView], side: int) -> void:
	for i in MatchState.BOARD_SIZE:
		var unit: CardInstance = state.board[side][i]
		views[i].show_unit(unit)
		views[i].exhausted = unit != null and side == my_side and not unit.can_attack()
		views[i].selected = false
		views[i].enabled = true


func _refresh_hand() -> void:
	var hand: Array = state.hand[my_side]
	var count: int = mini(hand.size(), _hand_views.size())
	var width := count * CardView.HAND_SIZE_PX.x + maxf(count - 1, 0) * HAND_GAP
	var start := HAND_AREA.position.x + (HAND_AREA.size.x - width) * 0.5
	for i in _hand_views.size():
		var view := _hand_views[i]
		if i >= count:
			view.visible = false
			continue
		view.visible = true
		view.position = Vector2(start + i * (CardView.HAND_SIZE_PX.x + HAND_GAP), HAND_TOP)
		view.size = CardView.HAND_SIZE_PX
		view.show_card(hand[i], _my_turn() and state.can_play(my_side, i))
		view.selected = _selection.is_hand(i)


## 選んでいるものに応じて、置ける枠・殴れる相手を光らせる。
func _refresh_targets() -> void:
	var foe := MatchState.other_side(my_side)
	_foe_bar.targetable = false
	if _selection.is_targeting():
		for slot in MatchState.BOARD_SIZE:
			_foe_slots[slot].selected = state.board[foe][slot] != null
		return
	if _selection.is_hand_selection():
		for i in MatchState.BOARD_SIZE:
			_own_slots[i].selected = true
		return
	if not _selection.is_board_selection():
		return
	_own_slots[_selection.slot].selected = true
	var attacker: CardInstance = state.board[my_side][_selection.slot]
	if attacker == null or not attacker.can_attack():
		return
	for slot in state.attackable_slots(foe):
		_foe_slots[slot].selected = true
	_foe_bar.targetable = state.can_attack_player(my_side)


func _refresh_buttons() -> void:
	var over: bool = state.is_match_over()
	_end_turn_button.visible = _interactive
	_end_turn_button.disabled = not _my_turn()
	_log_button.visible = _interactive
	_surrender_button.visible = _interactive and not over
	_coin_button.visible = _interactive and state.coin_available.get(my_side, false)
	_coin_button.disabled = not _my_turn()
	var show_flip := (
		_selection.is_board_selection() and _my_turn() and state.can_flip(my_side, _selection.slot)
	)
	_flip_button.visible = show_flip


func _my_turn() -> bool:
	if not _interactive:
		return false
	return state != null and not state.is_match_over() and state.current_turn == my_side


## 対局が終わったらポーリングを止める(Architecture.md 6.1節)。ホームへ戻った後も
## Firestoreを読み続けないようにするため。
func _stop_polling() -> void:
	if _online != null:
		_online.stop()


# --- 操作 ---------------------------------------------------------------


func _on_hand_pressed(view: CardView) -> void:
	if not _my_turn():
		return
	var index := _hand_views.find(view)
	if index < 0 or not state.can_play(my_side, index):
		return
	_selection.select_hand(index)
	refresh()


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


## 自分の1手を適用する。オンラインなら同時に相手へ送る。
## **すべての操作をこの1箇所へ通す**ことで、送信し忘れる経路が生まれないようにする。
func _perform(action: Dictionary) -> void:
	MatchAction.apply(state, action)
	if _online != null:
		_online.send(action)


func _view_at(side: int, slot: int) -> CardView:
	return _own_slots[slot] if side == my_side else _foe_slots[slot]


func _on_unit_damaged(side: int, slot: int, amount: int) -> void:
	_view_at(side, slot).play_shatter(amount)


func _on_unit_ticked(side: int, slot: int) -> void:
	_view_at(side, slot).play_drop()


func _on_turn_started(side: int) -> void:
	refresh()
	if _cpu != null and side != my_side and not state.is_match_over():
		_cpu_timer.start(CPU_THINK_SECONDS)


func _take_cpu_action() -> void:
	if _cpu == null or state.is_match_over():
		return
	var side := state.current_turn
	if side == my_side:
		return
	var action := _cpu.choose_action(state, side)
	MatchAction.apply(state, action)
	refresh()
	if action["type"] != "end_turn" and not state.is_match_over():
		_cpu_timer.start(CPU_THINK_SECONDS * 0.4)


func _on_match_ended(_winner: int) -> void:
	_selection.clear()
	refresh()
	_stop_polling()
	# 再生中は結果パネルを出さない。最後の手まで進めるたびに操作を塞ぐと
	# 前後に動かせなくなるため(GameDesign.md 9章)。
	if not _interactive:
		return
	_result.show_for(state, my_side, state.turn_count)
	_save_replay()


## 終了済みマッチとして finished_at/winner を書き、リプレイとして残す
## (GameDesign.md 12章)。書き込むのは対局者だけで、観戦者は行わない。
func _save_replay() -> void:
	if _client == null or _match_id.is_empty() or state.winner < 0:
		return
	var uid: String = _client.auth.uid if _client.auth != null else ""
	var winner := "a" if state.winner == MatchState.Side.A else "b"
	ReplayService.mark_finished(_client, _match_id, winner, uid)
