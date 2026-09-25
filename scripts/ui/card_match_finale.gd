class_name CardMatchFinale
extends RefCounted
## 決着の瞬間(GameDesign.md 9章「演出」、Architecture.md 10.10.3節)。
##
## `MatchState.match_ended` は手の適用の途中で出るため、そのまま結果パネルを出すと
## 最後の一撃がまだ渡っている最中に暗幕が降りる。**後始末(戦績・砂金・リプレイ)は
## 即座に済ませ、見せる側だけを手の演出が終わるまで持ち越す。**
##
## `card_match_screen.gd` が1000行の上限に近いため、ここへ切り出している。

## 見せ終えた後の締め。
enum Close { RESULT, PUZZLE, SOLO }

## 決着の一撃が当たった瞬間の時間の流れと、それを保つ実時間。
const IMPACT_TIME_SCALE := 0.25
const IMPACT_HOLD_SECONDS := 0.35
## 揺れを上限いっぱいにするための攻撃力(`CardMatchShake` の上限に必ず届く値)。
const IMPACT_SHAKE_POWER := 99
## 器が砕けきってから結果パネルを出すまでの一呼吸。
const BREATH_SECONDS := 0.4

var _screen: CardMatchScreen
## 手の演出が終わるのを待っている終局。新しい対局へ移ったら見せない。
var _state: MatchState
var _pending := false
var _close := Close.RESULT
var _reward := ""
## 時間を落とした対局。1局につき1度だけ落とす(貫通や余砂で当たりが続くため)。
var _slowed_state: MatchState


func _init(screen: CardMatchScreen) -> void:
	_screen = screen


## 終局した。操作しない対局(再生・観戦)は従来どおり盤面を合わせるだけ。
func on_match_ended() -> void:
	if not _screen.is_interactive():
		_screen.refresh()
		return
	_state = _screen.state
	_reward = ""
	if _screen._puzzle != null and _screen._puzzle.active():
		# パズルは勝敗ではなく正誤で締める(GameDesign.md 24章)。リプレイも砂金も戦績も出さない。
		_close = Close.PUZZLE
	elif _screen._solo != null and _screen._solo.active():
		# ソロモードのステージ報酬は `CardMatchSolo` が持つ(GameDesign.md 27章)。
		_close = Close.SOLO
	else:
		_close = Close.RESULT
		_reward = _screen._outcome.finish(_screen._match_kind, _screen._own_deck)
	_pending = true
	# 演出を伴わない手(投了・疲労・時間切れ)は `on_strike_finished()` を経ないことがあるため、
	# 適用が済んだ後にも一度確かめる。
	_try_start.call_deferred()


## 攻撃・紋章の演出が終わった(`CardMatchScreen.on_strike_finished()` から)。
func on_actions_settled() -> void:
	_try_start()


## 攻撃・紋章が当たった瞬間。決着の一撃なら時間を落とし、盤面を上限いっぱいに揺らす。
func on_impact() -> void:
	var state := _screen.state
	if state == null or not state.is_match_over() or not _screen.is_interactive():
		return
	if _slowed_state == state or _broken_sides().is_empty():
		return
	_slowed_state = state
	_screen.shake.hit(IMPACT_SHAKE_POWER)
	Engine.time_scale = IMPACT_TIME_SCALE
	await _screen.get_tree().create_timer(IMPACT_HOLD_SECONDS, true, false, true).timeout
	Engine.time_scale = 1.0


## 対局をまたいで残さない(`CardMatchReset`)。落とした時間の流れも戻す。
func reset() -> void:
	_pending = false
	_state = null
	_slowed_state = null
	Engine.time_scale = 1.0


func _try_start() -> void:
	if not _pending or _screen.state != _state or _screen.strike_busy():
		return
	_pending = false
	_screen.refresh()
	var broken := _broken_sides()
	for side in broken:
		_screen.bar_for(side).play_shatter()
	if not broken.is_empty():
		var wait := HpVesselFx.SHATTER_DURATION + BREATH_SECONDS
		await _screen.get_tree().create_timer(wait).timeout
		if _screen.state != _state:
			return
	_show_close()


## HPが0になった側。投了や時間切れの連続で決まった対局では空になる。
func _broken_sides() -> Array[int]:
	var sides: Array[int] = []
	var state := _screen.state
	for side in [MatchState.Side.A, MatchState.Side.B]:
		if state.hp[side] <= 0:
			sides.append(side)
	return sides


func _show_close() -> void:
	match _close:
		Close.PUZZLE:
			_screen._puzzle.on_match_ended()
		Close.SOLO:
			_screen._solo.on_match_ended()
		_:
			var can_rematch := _screen._match_kind == CurrencyRules.MatchKind.CPU
			var is_tutorial: bool = _screen._tutorial.ran_this_match
			_screen._result.show_for(
				_state, _screen.my_side, _state.turn_count, _reward, can_rematch, is_tutorial
			)
