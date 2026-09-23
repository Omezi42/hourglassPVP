class_name CardMatchTutorial
extends Control
## 誘導対局の進行そのもの(GameDesign.md 18章)。**両者の手をすべて決めた台本**
## (`TutorialScriptData`)を先頭から順に指させる。プレイヤーの手はここが答える
## 「関門」(`gate_*()`)だけを通し、CPUの手は `TutorialCpuStrategy` が `cpu_action()`
## 経由でここへ問い合わせる。台本の内容そのもの(deck/steps)はここへ書かず
## `resources/tutorial/tutorial_script.tres` だけを直せば済むようにする。
##
## **話すのはマスコットのすなえる**(GameDesign.md 18章)。指示だけが帯に出ていると
## 話者がおらず、画面が一方的に命令しているように読めるため。指示の文は短く保つこと。
##
## **プレイヤーは指示された1か所しか押せない**。`gate_*()` が偽を返す操作は
## `CardMatchTouch`/`CardMatchMulligan`/`CardMatchScreen` 側で何も起きずに終わる。
## メニューからの投了・ホームへ戻る導線はどの関門も塞がない。
##
## **段階を終えたときの説明は時間で消さない。**「つぎへ」を押すまで残す。読む速さは人により、
## 1秒足らずでは読み切れない(GameDesign.md 18章)。

## 読み終えてCPUが指してよくなった(`cpu_waiting()` が偽へ戻った)。
signal cpu_resumed

const SCREEN_SIZE := Vector2(1280, 720)
## 置き場所は**卓の上端へ横長に渡した帯**とする。相手のHP・マナ・山札を覆う位置
## (画面の最上段)は避ける。攻撃や反転の判断に要る情報が誘導対局の間ずっと読めなくなるため。
const BAND_RECT := Rect2(206, 74, 824, 64)
## **マリガンの間だけ帯を下げる**。マリガン画面は見出し・手札・確定ボタンで y=66〜432 を
## 使うため、通常の位置(y=74)へ出すと見出しへ重なる。確定ボタンの下が唯一の空きになる。
const MULLIGAN_BAND_TOP := 470.0
## 帯の枠は大きなパネル用(枠8px・角丸16)より細くする。高さ64の帯に太い枠を使うと、
## 文の入る高さが足りずパネルが帯より縦へ伸び、絵とボタンが枠からはみ出して見える。
const BAND_FRAME := 4.0
const BAND_CORNER := 10.0
## 枠の内側へ置く絵・ボタン・文と枠との隙間。
const BAND_INSET := BAND_FRAME + 4.0
## すなえるは帯の底に立たせ、頭を帯の上へはみ出させる。帯の高さに収めると小さすぎて
## 話し手として目に入らない。
const PORTRAIT_SIZE := Vector2(72, 96)
const PORTRAIT_TEXT_GAP := 6.0
## 進み具合の点。準備+4手番の5つ(GameDesign.md 18章)。
const STAGE_COUNT := 5
const DOTS_WIDTH := 60.0
const DOT_RADIUS := 4.0
const DOT_STEP := 12.0
## いま触るものを囲む枠(GameDesign.md 18章)。手は塞がず、視線だけを誘導する。
const FOCUS_COLOR := Color(0.55, 0.9, 1.0)
const FOCUS_PERIOD := 1.2
const FOCUS_GROW := 5.0
const FOCUS_WIDTH := 2.5
const FOCUS_RINGS := [0, 1]
## 説明を読んでいる間に光らせる数字(GameDesign.md 18章「数字の光」)。操作を求める
## 輪郭とは色を分け、押す場所と読む場所を取り違えさせない。
const NUMBER_GLOW_COLOR := Color(1.0, 0.82, 0.35)
const NEXT_SIZE := Vector2(88, 36)
## CPUが指す前に帯の文を読み切れるだけ待つ(GameDesign.md 18章)。文の長さに比例させる。
const READ_SECONDS_BASE := 1.0
const READ_SECONDS_PER_CHAR := 0.1
## CPUの台本を指し終えてからターンを返すまでの間。最後の手の結果を見届けさせる。
const CPU_HANDOFF_SECONDS := 1.2
## 自分の駒が「戦闘ではなくターン終了の砂落ち」で割れた初回に1度だけ出す補足
## (GameDesign.md 18章)。
const CALLOUT_OWN_UNIT_DIED_TO_SAND := "体力が0になると割れちゃうよ。反転すれば長生きできるんだ"

## `CardMatchScreen._on_match_ended()` が結果パネルの案内文を選ぶために読む。

var ran_this_match := false

var _state: MatchState
var _my_side := MatchState.Side.A
var _screen: CardMatchScreen
var _steps: Array = []
var _index := 0
## 台本の「置いた駒」を後の手から参照するための表(参照名 → CardInstance)。
var _refs: Dictionary = {}
## 台本を読み込んでいる間(マリガンの選択を塞ぐ範囲)。`visible`(帯の表示)より広い——
## マリガン画面はまだ帯を出す前から関門を効かせる必要がある。
var _active := false

var _label: Label
var _band: Control
var _next_button: Button
var _portrait: SunaeruPortrait
var _dots: Control
var _elapsed := 0.0
var _showing_done := false
## 段階を終えたときの一言へ差し込む、いま自分の盤面で起きた実際の数値
## (GameDesign.md 18章)。一般論より目の前の駒と結びついた説明のほうが速く入る。
var _fact := ""
## 攻撃の最中かどうか。`attack_performed` はダメージの解決より前に出るため、
## 実際に削れた量は後から届く `unit_damaged` / `hp_changed` で数える。
var _counting_attack := false
var _dealt := 0
var _taken := 0
var _face_damage := 0
var _foe_hp := 0

var _callout_active := ""
var _callout_shown := false
## 直前に砂が落ちきった(ターン終了の1粒)枠。**戦闘によるダメージ死とは別経路**。
var _tick_pending: Dictionary = {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SCREEN_SIZE
	_build()


## 台本を読み込む。**マリガンの選択より前に呼ぶ**——`gate_mulligan_pick()` は
## `_active` だけを見るため、これを呼んでからでないと引き直しを塞げない。
func load_script(script: TutorialScriptData) -> void:
	_steps = script.steps
	_index = 0
	_refs.clear()
	_active = true
	ran_this_match = true


## 対局が始まったところから見張り始める。
func watch(screen: CardMatchScreen, state: MatchState, my_side: int) -> void:
	_screen = screen
	_state = state
	_my_side = my_side
	_showing_done = false
	_callout_active = ""
	_callout_shown = false
	_tick_pending = {}
	state.unit_played.connect(_on_unit_played)
	state.attack_performed.connect(_on_attack_performed)
	state.unit_flipped.connect(_on_unit_flipped)
	state.flip_right_used.connect(_on_flip_right_used)
	state.turn_started.connect(_on_turn_started)
	state.mulligan_finished.connect(_on_mulligan_finished)
	state.unit_damaged.connect(_on_unit_damaged)
	state.hp_changed.connect(_on_hp_changed)
	state.unit_ticked.connect(
		func(side: int, slot: int) -> void: _tick_pending["%d:%d" % [side, slot]] = true
	)
	state.unit_destroyed.connect(_on_unit_destroyed)
	state.match_ended.connect(func(_winner: int) -> void: _finish())
	# マリガンの間は暗幕より手前へ、確定ボタンの下へ下げて出す(GameDesign.md 18章)。
	_place_band(state.mulligan_pending)
	visible = true
	_enter_step()


## 新しい対局へ入る前の後始末(GameDesign.md 18章)。
func reset_for_new_match() -> void:
	visible = false
	_active = false
	ran_this_match = false
	_steps = []
	_index = 0
	_refs.clear()


## CPUの手番。台本の現在の手が `side` のものであれば `MatchAction` の形で返す。
## 一致しなければ空を返し、呼び出し側(`TutorialCpuStrategy`)がターン終了で埋める。
func cpu_action(state: MatchState, side: int) -> Dictionary:
	var step := _current_step()
	if step.is_empty() or _side_for(str(step.get("side", ""))) != side:
		return {}
	return _cpu_action_for(state, side, step)


func _cpu_action_for(state: MatchState, side: int, step: Dictionary) -> Dictionary:
	match str(step.get("kind", "")):
		"play":
			return _cpu_play_action(state, side, step)
		"attack":
			return _cpu_attack_action(side, step)
		"flip":
			var slot := _slot_of(side, str(step.get("actor_ref", "")))
			return {} if slot < 0 else MatchAction.flip(side, slot)
		"flip_right":
			return _cpu_flip_right_action(side, step)
		"end_turn":
			return MatchAction.end_turn(side)
	return {}


func _cpu_play_action(state: MatchState, side: int, step: Dictionary) -> Dictionary:
	var hand_index := _hand_index_of(state, side, str(step.get("card_id", "")))
	var empty: Array = state.empty_slots(side)
	if hand_index < 0 or empty.is_empty():
		return {}
	return MatchAction.play(side, hand_index, empty[0])


func _cpu_attack_action(side: int, step: Dictionary) -> Dictionary:
	var actor_slot := _slot_of(side, str(step.get("actor_ref", "")))
	if actor_slot < 0:
		return {}
	if str(step.get("target_kind", "")) == "face":
		return MatchAction.attack(side, actor_slot, -1)
	var target_slot := _slot_of(MatchState.other_side(side), str(step.get("target_ref", "")))
	return {} if target_slot < 0 else MatchAction.attack(side, actor_slot, target_slot)


func _cpu_flip_right_action(side: int, step: Dictionary) -> Dictionary:
	var target_side := (
		side if str(step.get("target_side", "")) == "own" else MatchState.other_side(side)
	)
	var target := _slot_of(target_side, str(step.get("target_ref", "")))
	return {} if target < 0 else MatchAction.flip_right(side, target_side, target)


# --- 関門(GameDesign.md 18章) -------------------------------------------
# 通常の対局(`_active == false`)では常にtrueを返す。


func gate_hand_select(index: int) -> bool:
	if not _active:
		return true
	var step := _current_step()
	if step.is_empty() or step.get("side", "") != "a" or step.get("kind", "") != "play":
		return false
	var hand: Array = _state.hand[_my_side]
	return index >= 0 and index < hand.size() and hand[index].id == str(step.get("card_id", ""))


## 手札を選ばずに自分の駒を選ぶ操作(攻撃/反転の手を始める)。
func gate_board_select(slot: int) -> bool:
	if not _active:
		return true
	var step := _current_step()
	if step.is_empty() or step.get("side", "") != "a":
		return false
	var kind := str(step.get("kind", ""))
	if kind != "attack" and kind != "flip":
		return false
	return _slot_of(_my_side, str(step.get("actor_ref", ""))) == slot


func gate_flip_confirm() -> bool:
	if not _active:
		return true
	var step := _current_step()
	return not step.is_empty() and step.get("side", "") == "a" and step.get("kind", "") == "flip"


## target_slot が -1 なら本体。
func gate_attack_target(target_slot: int) -> bool:
	if not _active:
		return true
	var step := _current_step()
	if step.is_empty() or step.get("side", "") != "a" or step.get("kind", "") != "attack":
		return false
	var wants_face := str(step.get("target_kind", "")) == "face"
	if wants_face:
		return target_slot < 0
	if target_slot < 0:
		return false
	return _slot_of(MatchState.other_side(_my_side), str(step.get("target_ref", ""))) == target_slot


func gate_flip_right_begin() -> bool:
	if not _active:
		return true
	var step := _current_step()
	return (
		not step.is_empty() and step.get("side", "") == "a" and step.get("kind", "") == "flip_right"
	)


func gate_flip_right_target(target_side: int, slot: int) -> bool:
	if not _active:
		return true
	var step := _current_step()
	if step.is_empty() or step.get("side", "") != "a" or step.get("kind", "") != "flip_right":
		return false
	var wants_side := (
		_my_side if str(step.get("target_side", "")) == "own" else MatchState.other_side(_my_side)
	)
	if target_side != wants_side:
		return false
	return _slot_of(wants_side, str(step.get("target_ref", ""))) == slot


func gate_end_turn() -> bool:
	if not _active:
		return true
	var step := _current_step()
	return (
		not step.is_empty() and step.get("side", "") == "a" and step.get("kind", "") == "end_turn"
	)


## マリガンは札を選べず「このままで開始」だけを受け付ける(GameDesign.md 18章)。
func gate_mulligan_pick() -> bool:
	return not _active


# --- 台本の進行 -----------------------------------------------------------


func _current_step() -> Dictionary:
	return _steps[_index] if _index >= 0 and _index < _steps.size() else {}


func _side_for(tag: String) -> int:
	if tag == "a":
		return _my_side
	if tag == "b":
		return MatchState.other_side(_my_side)
	return -1


func _slot_of(side: int, ref: String) -> int:
	if ref.is_empty():
		return -1
	var target: CardInstance = _refs.get(ref)
	if target == null:
		return -1
	for slot in MatchState.BOARD_SIZE:
		if _state.board[side][slot] == target:
			return slot
	return -1


func _hand_index_of(state: MatchState, side: int, card_id: String) -> int:
	var hand: Array = state.hand[side]
	for i in hand.size():
		var card: CardData = hand[i]
		if card.id == card_id:
			return i
	return -1


func _place_band(during_mulligan: bool) -> void:
	_band.position = Vector2(
		BAND_RECT.position.x, MULLIGAN_BAND_TOP if during_mulligan else BAND_RECT.position.y
	)


## 台本の1手が実際に起きた。CPU/マリガンの手はそのまま次へ、プレイヤーの手は
## 「終えたときの説明」を出して「つぎへ」を待つ。
func _complete_current_step() -> void:
	if _state != null and _state.is_match_over():
		_finish()
		return
	var step := _current_step()
	if step.is_empty():
		return
	if _portrait != null:
		_portrait.cheer()
	var kind := str(step.get("kind", ""))
	if kind == "mulligan":
		_place_band(false)
	# 一度説明したことは繰り返さない。説明の無い手は終えたらすぐ次の指示へ進む(GameDesign.md 18章)。
	if (
		str(step.get("side", "")) == "b"
		or kind == "mulligan"
		or str(step.get("done", "")).is_empty()
	):
		_index += 1
		_enter_step()
		return
	_fact = _fact_for(step)
	_showing_done = true
	if kind == "attack":
		_begin_attack_count()
	_refresh()


func _enter_step() -> void:
	if _state != null and _state.is_match_over():
		_finish()
		return
	if _index >= _steps.size():
		_finish()
		return
	_showing_done = str(_current_step().get("side", "")) == "info"
	_fact = ""
	_refresh()


## 対局が終わった。台本の最後まで進めて勝ったときは、結果パネルより手前で
## すなえるが締めの一言を話す(GameDesign.md 18章)。それ以外(投了など)は帯を消す。
func _finish() -> void:
	if not _active:
		return
	var won := _state != null and _state.winner == _my_side
	FunnelService.reach(FunnelService.TUTORIAL_CLEAR)
	UiState.mark_tutorial_done()
	_active = false
	if not won:
		visible = false
		return
	var closing := str(_current_step().get("done", ""))
	_index = _steps.size()
	_callout_active = ""
	_showing_done = false
	_label.text = closing
	_next_button.visible = false
	_portrait.cheer()
	get_parent().move_child(self, -1)
	_dots.queue_redraw()
	queue_redraw()


func _on_next_pressed() -> void:
	if not _callout_active.is_empty():
		_callout_active = ""
		_refresh()
	elif _showing_done:
		_index += 1
		_enter_step()
	if not cpu_waiting() and _state != null and _state.current_turn != _my_side:
		cpu_resumed.emit()


## 説明・補足を読んでいる間はCPUを待たせる。待たずに指すと、台本がまだプレイヤーの手を
## 指している間にCPUが「指す手が無い」と見てターンを終えてしまい、台本が止まる。
func cpu_waiting() -> bool:
	return _active and (_showing_done or not _callout_active.is_empty())


## CPUが次に指すまでの間。誘導対局の間は、帯に出ているCPUの手の予告を読み切れる長さにする。
func cpu_delay(base: float) -> float:
	if not _active:
		return base
	var step := _current_step()
	if str(step.get("side", "")) != "b":
		return CPU_HANDOFF_SECONDS
	return READ_SECONDS_BASE + READ_SECONDS_PER_CHAR * str(step.get("wait_text", "")).length()


# --- MatchStateの信号 -----------------------------------------------------


func _on_unit_played(side: int, slot: int) -> void:
	var step := _current_step()
	if (
		step.is_empty()
		or str(step.get("kind", "")) != "play"
		or _side_for(str(step.get("side", ""))) != side
	):
		return
	var unit: CardInstance = _state.board[side][slot]
	if unit == null or unit.data.id != str(step.get("card_id", "")):
		return
	var ref := str(step.get("ref", ""))
	if not ref.is_empty():
		_refs[ref] = unit
	_complete_current_step()


func _on_attack_performed(side: int, slot: int, target_slot: int) -> void:
	var step := _current_step()
	if (
		step.is_empty()
		or str(step.get("kind", "")) != "attack"
		or _side_for(str(step.get("side", ""))) != side
	):
		return
	var actor: CardInstance = _state.board[side][slot]
	if actor == null or actor != _refs.get(str(step.get("actor_ref", ""))):
		return
	var wants_face := str(step.get("target_kind", "")) == "face"
	if wants_face != (target_slot < 0):
		return
	if not wants_face:
		var expect := _slot_of(MatchState.other_side(side), str(step.get("target_ref", "")))
		if expect != target_slot:
			return
	_complete_current_step()


func _on_unit_flipped(side: int, slot: int) -> void:
	var step := _current_step()
	if (
		step.is_empty()
		or str(step.get("kind", "")) != "flip"
		or _side_for(str(step.get("side", ""))) != side
	):
		return
	var unit: CardInstance = _state.board[side][slot]
	if unit == null or unit != _refs.get(str(step.get("actor_ref", ""))):
		return
	_complete_current_step()


func _on_flip_right_used(actor_side: int, target_side: int, slot: int) -> void:
	var step := _current_step()
	if (
		step.is_empty()
		or str(step.get("kind", "")) != "flip_right"
		or _side_for(str(step.get("side", ""))) != actor_side
	):
		return
	var wants_side := (
		actor_side
		if str(step.get("target_side", "")) == "own"
		else MatchState.other_side(actor_side)
	)
	if wants_side != target_side:
		return
	var unit: CardInstance = _state.board[target_side][slot]
	if unit == null or unit != _refs.get(str(step.get("target_ref", ""))):
		return
	_complete_current_step()


func _on_turn_started(side: int) -> void:
	_tick_pending.clear()
	var step := _current_step()
	if step.is_empty() or str(step.get("kind", "")) != "end_turn":
		return
	if _side_for(str(step.get("side", ""))) == MatchState.other_side(side):
		_complete_current_step()


func _on_mulligan_finished() -> void:
	var step := _current_step()
	if not step.is_empty() and str(step.get("kind", "")) == "mulligan":
		_complete_current_step()


func _begin_attack_count() -> void:
	_counting_attack = true
	_dealt = 0
	_taken = 0
	_face_damage = 0
	_foe_hp = int(_state.hp[MatchState.other_side(_my_side)])


func _on_unit_damaged(side: int, _slot: int, amount: int) -> void:
	if not _counting_attack:
		return
	if side == _my_side:
		_taken += amount
	else:
		_dealt += amount
	_update_attack_fact()


func _on_hp_changed(side: int, new_hp: int) -> void:
	if not _counting_attack or side == _my_side:
		return
	_face_damage += maxi(_foe_hp - new_hp, 0)
	_foe_hp = new_hp
	_update_attack_fact()


## 相打ちの結果を書き直す。**攻撃はおたがいさま**であることを、自分が受けた量を
## 数字で見せて伝える(GameDesign.md 18章)。
func _update_attack_fact() -> void:
	if _face_damage > 0 and _dealt == 0:
		_fact = "相手のHPへ%dダメージ！" % _face_damage
	elif _dealt > 0 or _taken > 0:
		_fact = "相手に%dダメージ、こっちも%d削れたよ。" % [_dealt, _taken]
	_refresh()


## 自分の駒が「戦闘ではなくターン終了の砂落ち」で割れた初回(GameDesign.md 18章)。
func _on_unit_destroyed(side: int, slot: int, _card: CardData) -> void:
	var key := "%d:%d" % [side, slot]
	if side == _my_side and _tick_pending.get(key, false) and not _callout_shown:
		_callout_shown = true
		_callout_active = CALLOUT_OWN_UNIT_DIED_TO_SAND
		visible = true
		_refresh()
	_tick_pending.erase(key)


## 段階を終えたときの一言へ差し込む、いま自分の盤面で起きた実際の数値。
func _fact_for(step: Dictionary) -> String:
	match str(step.get("kind", "")):
		"play":
			return _fact_for_play(step)
		"end_turn":
			return _fact_for_end_turn(step)
		"flip":
			return _fact_for_flip(step)
		"flip_right":
			return _fact_for_flip_right(step)
	return ""


func _fact_for_play(step: Dictionary) -> String:
	var played: CardInstance = _refs.get(str(step.get("ref", "")))
	return "" if played == null else "マナを%dつかったよ。" % played.data.cost


func _fact_for_end_turn(step: Dictionary) -> String:
	var ref := str(step.get("ref", ""))
	var ticked: CardInstance = _refs.get(ref) if not ref.is_empty() else null
	if ticked == null:
		return ""
	return (
		"%sの体力が%d→%d、攻撃力が%d→%dになったよ。"
		% [
			ticked.data.display_name,
			ticked.health + 1,
			ticked.health,
			ticked.attack - 1,
			ticked.attack,
		]
	)


func _fact_for_flip(step: Dictionary) -> String:
	var flipped: CardInstance = _refs.get(str(step.get("actor_ref", "")))
	if flipped == null:
		return ""
	return (
		"体力%d・攻撃力%dが入れ替わって、体力%d・攻撃力%dになったよ。"
		% [flipped.attack, flipped.health, flipped.health, flipped.attack]
	)


func _fact_for_flip_right(step: Dictionary) -> String:
	var target: CardInstance = _refs.get(str(step.get("target_ref", "")))
	if target == null:
		return ""
	return "相手の「%s」の体力が%dになったよ。" % [target.data.display_name, target.health]


# --- 見た目 -----------------------------------------------------------


func _build() -> void:
	_band = Control.new()
	_band.size = BAND_RECT.size
	_band.position = BAND_RECT.position
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = BAND_RECT.size
	panel.size = BAND_RECT.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base: StyleBox = load("res://resources/theme/content_panel.tres")
	if base is CodedPanelStyle:
		var style := base.duplicate() as CodedPanelStyle
		style.frame_thickness = BAND_FRAME
		style.corner_radius = BAND_CORNER
		style.content_margin_left = 0.0
		style.content_margin_right = 0.0
		style.content_margin_top = BAND_INSET
		style.content_margin_bottom = BAND_INSET
		panel.add_theme_stylebox_override("panel", style)
	_band.add_child(panel)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	# 文が「つぎへ」の下へ潜らないよう、ボタンぶんの余白を右へ空ける。
	margin.add_theme_constant_override("margin_right", int(NEXT_SIZE.x + BAND_INSET + DOTS_WIDTH))
	# 左はすなえるの立ち絵ぶん。文と絵を重ねない。
	margin.add_theme_constant_override(
		"margin_left", int(BAND_INSET + PORTRAIT_SIZE.x + PORTRAIT_TEXT_GAP)
	)
	panel.add_child(margin)
	margin.add_child(_label)

	_next_button = CodedButton.make("つぎへ", NEXT_SIZE)
	_next_button.visible = false
	_next_button.position = Vector2(
		BAND_RECT.size.x - NEXT_SIZE.x - BAND_INSET, (BAND_RECT.size.y - NEXT_SIZE.y) * 0.5
	)
	_next_button.pressed.connect(_on_next_pressed)
	_band.add_child(_next_button)

	# 進み具合の点は「つぎへ」の左へ置く。準備+4手番の5つ(GameDesign.md 18章)。
	_dots = Control.new()
	_dots.position = Vector2(BAND_RECT.size.x - NEXT_SIZE.x - BAND_INSET - DOTS_WIDTH, 0.0)
	_dots.size = Vector2(DOTS_WIDTH, BAND_RECT.size.y)
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots.draw.connect(_draw_dots)
	_band.add_child(_dots)

	# すなえるは帯の左端へ小さく置くだけにする(GameDesign.md 18章)。
	_portrait = SunaeruPortrait.new()
	_portrait.size = PORTRAIT_SIZE
	_portrait.position = Vector2(BAND_INSET, BAND_RECT.size.y - BAND_FRAME - PORTRAIT_SIZE.y)
	_band.add_child(_portrait)


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	queue_redraw()


func _refresh() -> void:
	# ボタンは一度広がると自分では縮まない。組み立て時に広がったまま帯の枠へかかるため、毎回戻す。
	_next_button.size = NEXT_SIZE
	if not _callout_active.is_empty():
		_label.text = _callout_active
		_next_button.text = "つぎへ"
		_next_button.visible = true
		_dots.queue_redraw()
		queue_redraw()
		return
	var step := _current_step()
	if step.is_empty():
		return
	_next_button.text = "つぎへ"
	var side := str(step.get("side", ""))
	if side == "b":
		_label.text = str(step.get("wait_text", ""))
		_next_button.visible = false
		_dots.queue_redraw()
		queue_redraw()
		return
	var is_info := side == "info"
	_next_button.visible = _showing_done or is_info
	var line: String
	if is_info:
		line = str(step.get("text", ""))
	else:
		line = str(step.get("done", "")) if _showing_done else str(step.get("text", ""))
	_label.text = (
		(_fact + "\n" + line) if (_showing_done and not is_info and not _fact.is_empty()) else line
	)
	_dots.queue_redraw()
	queue_redraw()


## 何手番のうちどこにいるかを点で示す(GameDesign.md 18章)。準備+4手番の5つ。
func _draw_dots() -> void:
	var width: float = DOT_STEP * (STAGE_COUNT - 1)
	var left: float = (DOTS_WIDTH - width) * 0.5
	var y: float = _dots.size.y * 0.5
	var step := _current_step()
	var current_stage: int = (
		int(step.get("stage", STAGE_COUNT - 1)) if not step.is_empty() else STAGE_COUNT
	)
	for i in STAGE_COUNT:
		var at := Vector2(left + DOT_STEP * i, y)
		if i < current_stage:
			_dots.draw_circle(at, DOT_RADIUS, UiPalette.GLOW_AMBER)
		else:
			_dots.draw_circle(at, DOT_RADIUS, Color(UiPalette.GLOW_AMBER, 0.22))
			_dots.draw_arc(at, DOT_RADIUS, 0.0, TAU, 16, Color(UiPalette.GLOW_AMBER, 0.7), 1.2)


## いま触るもの(輪郭)と、いま話題にしている数字(色違いの光)を描く
## (GameDesign.md 18章)。**手は塞がず、視線だけを誘導する**ため、
## `mouse_filter` は IGNORE のまま枠だけを描く。
func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_elapsed * TAU / FOCUS_PERIOD)
	for rect: Rect2 in _focus_rects():
		for ring in FOCUS_RINGS:
			var spread: float = 2.0 + FOCUS_GROW * (float(ring) + pulse)
			var alpha: float = 0.8 / (float(ring) + 1.0)
			draw_rect(rect.grow(spread), Color(FOCUS_COLOR, alpha), false, FOCUS_WIDTH)
	for rect: Rect2 in _number_rects():
		var spread: float = 2.0 + FOCUS_GROW * pulse
		draw_rect(rect.grow(spread), Color(NUMBER_GLOW_COLOR, 0.85), false, FOCUS_WIDTH)


## 光らせる場所。**説明を読んでいる間(「つぎへ」が出ている間)は光らせない**。
func _focus_rects() -> Array[Rect2]:
	var found: Array[Rect2] = []
	if _screen == null or _state == null or _showing_done or not _callout_active.is_empty():
		return found
	var step := _current_step()
	if step.is_empty() or _state.is_match_over():
		return found
	var side := str(step.get("side", ""))
	if side == "info" or side == "b" or _state.current_turn != _my_side:
		return found
	match str(step.get("kind", "")):
		"mulligan":
			if _state.mulligan_pending and _screen._mulligan != null:
				found.append(_screen._mulligan.confirm_rect())
		"play":
			found.append_array(_hand_rects_for(str(step.get("card_id", ""))))
		"end_turn":
			found.append(_screen._geometry.end_turn_button_rect())
		"attack":
			found.append_array(_attack_focus_rects(step))
		"flip":
			var slot := _slot_of(_my_side, str(step.get("actor_ref", "")))
			if slot >= 0:
				found.append(_slot_rect(_my_side, slot))
		"flip_right":
			# 反転権のボタンを押す前はボタンを、押した後は対象を囲む(攻撃の段と同じ2段階)。
			if not _screen.selection.is_flip_right():
				found.append(_screen._flip_right.button_rect())
				return found
			var wants_side := (
				_my_side
				if str(step.get("target_side", "")) == "own"
				else MatchState.other_side(_my_side)
			)
			var slot2 := _slot_of(wants_side, str(step.get("target_ref", "")))
			if slot2 >= 0:
				found.append(_slot_rect(wants_side, slot2))
	return found


func _hand_rects_for(card_id: String) -> Array[Rect2]:
	var found: Array[Rect2] = []
	var hand: Array = _state.hand[_my_side]
	for i in hand.size():
		var card: CardData = hand[i]
		if card.id == card_id and i < _screen._hand_views.size():
			var view := _screen._hand_views[i]
			found.append(Rect2(view.position, view.size))
			break
	return found


## 攻撃の段は2段階で囲む。自分の駒を選ぶ前は台本の駒を、選んだ後はその駒で殴る相手
## (駒か本体のHP帯)を囲み、次に押す場所へ視線を運ぶ(GameDesign.md 18章)。
func _attack_focus_rects(step: Dictionary) -> Array[Rect2]:
	var found: Array[Rect2] = []
	var actor_slot := _slot_of(_my_side, str(step.get("actor_ref", "")))
	if actor_slot < 0:
		return found
	var chosen: CardMatchSelection = _screen.selection
	if chosen.is_board_selection() and chosen.slot == actor_slot:
		if str(step.get("target_kind", "")) == "face":
			found.append(_screen._geometry.hp_bar_global_rect(MatchState.other_side(_my_side)))
		else:
			var target_slot := _slot_of(
				MatchState.other_side(_my_side), str(step.get("target_ref", ""))
			)
			if target_slot >= 0:
				found.append(_slot_rect(MatchState.other_side(_my_side), target_slot))
		return found
	found.append(_slot_rect(_my_side, actor_slot))
	return found


## いま話題にしている数字(GameDesign.md 18章「数字の光」)。「つぎへ」表示中
## (段階を終えたときの説明)か、読むだけの段のときだけ光らせる。
func _number_rects() -> Array[Rect2]:
	var found: Array[Rect2] = []
	if _screen == null or _state == null or not _callout_active.is_empty():
		return found
	var step := _current_step()
	if step.is_empty():
		return found
	var topic := str(step.get("topic", ""))
	if topic.is_empty():
		return found
	var is_info := str(step.get("side", "")) == "info"
	if not is_info and not _showing_done:
		return found
	match topic:
		"mana":
			found.append(_screen._geometry.mana_badge_rect(_my_side))
		"stats":
			var slot := _slot_of(_my_side, str(step.get("ref", "")))
			if slot >= 0:
				found.append_array(_screen._geometry.unit_stat_rects(_my_side, slot))
		"foe_hp":
			found.append(_screen._geometry.hp_bar_global_rect(MatchState.other_side(_my_side)))
		"flip_right":
			found.append(_screen._geometry.flip_right_gauge_rect())
	return found


func _slot_rect(side: int, slot: int) -> Rect2:
	var view := _screen.view_at(side, slot)
	return Rect2(view.position, view.size)
