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
const BUTTON_STYLES := "res://resources/theme/buttons/img_wide_text_%s.tres"

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
var _log: CardMatchLog
var _result: CardMatchResult
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
	my_side = MatchState.Side.A
	state = MatchState.new()
	add_child(state)
	state.turn_started.connect(_on_turn_started)
	state.match_ended.connect(_on_match_ended)
	_log.set_perspective(my_side)
	state.start_match(deck_self, deck_foe, MatchState.Side.A)
	_log.watch(state)
	refresh()


# --- 組み立て -----------------------------------------------------------


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
	_flip_button = _make_button("反転", Vector2(168, 48))
	_flip_button.position = Vector2(ACTION_COLUMN_X, 330)
	_flip_button.visible = false
	_flip_button.pressed.connect(_on_flip_pressed)
	_coin_button = _make_button("コイン", Vector2(168, 48))
	_coin_button.position = Vector2(ACTION_COLUMN_X, 386)
	_coin_button.pressed.connect(_on_coin_pressed)
	_end_turn_button = _make_button("ターン終了", Vector2(168, 64))
	_end_turn_button.position = Vector2(ACTION_COLUMN_X, OWN_BAR_TOP)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_log_button = _make_button("ログ", Vector2(168, 44))
	_log_button.position = Vector2(ACTION_COLUMN_X, 512)
	_log_button.pressed.connect(func() -> void: _log.set_open(true))
	_surrender_button = _make_button("投了", Vector2(168, 44))
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


func _make_bar(opponent: bool, top: float) -> PlayerInfoBar:
	var bar := PlayerInfoBar.new()
	bar.is_opponent = opponent
	bar.position = Vector2(MARGIN, top)
	bar.size = Vector2(1060 if not opponent else 1248, PlayerInfoBar.BAR_HEIGHT)
	if opponent:
		bar.face_pressed.connect(_on_face_pressed)
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


func _make_button(label: String, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = button_size
	button.size = button_size
	for name in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBox = load(BUTTON_STYLES % name)
		if style != null:
			button.add_theme_stylebox_override(name, style)
	# 文字色はプロジェクト共通テーマに任せず明示する。真鍮のボタン画像の上では
	# テーマ既定の暗い文字色が沈んで読めなくなる。
	button.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_pressed_color", UiPalette.BRASS_HIGHLIGHT)
	add_child(button)
	return button


# --- 表示の同期 ---------------------------------------------------------


func refresh() -> void:
	if state == null:
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
	_end_turn_button.disabled = not _my_turn()
	_log_button.visible = true
	_surrender_button.visible = not over
	_coin_button.visible = state.coin_available.get(my_side, false)
	_coin_button.disabled = not _my_turn()
	var show_flip := (
		_selection.is_board_selection() and _my_turn() and state.can_flip(my_side, _selection.slot)
	)
	_flip_button.visible = show_flip


func _my_turn() -> bool:
	return state != null and not state.is_match_over() and state.current_turn == my_side


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
		state.play_card(my_side, _selection.hand_index, _selection.slot, target)
		_selection.clear()
		refresh()
		return
	if not _selection.is_board_selection():
		return
	if not state.can_attack(my_side, _selection.slot, slot):
		return
	state.attack(my_side, _selection.slot, slot)
	_selection.clear()
	refresh()


func _on_face_pressed() -> void:
	if not _my_turn() or not _selection.is_board_selection():
		return
	if not state.can_attack(my_side, _selection.slot, -1):
		return
	state.attack(my_side, _selection.slot, -1)
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
	state.play_card(my_side, index, slot)
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
	state.flip(my_side, _selection.slot)
	refresh()


func _on_coin_pressed() -> void:
	if _my_turn():
		state.use_coin(my_side)
		refresh()


func _on_end_turn_pressed() -> void:
	if _my_turn():
		_selection.clear()
		state.end_turn()


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
		state.surrender(my_side)


# --- 手番・CPU ----------------------------------------------------------


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
	_result.show_for(state, my_side, state.turn_count)
