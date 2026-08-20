class_name MatchEventCaption
extends RefCounted
## ターン進行の逐次演出(MatchTurnResolver)で起きたことを、該当する駒の近くへ短時間
## フロート表示する(P-3)。文言はMatchBattleLogが記録するのと同じもの(format_*関数)を
## そのまま使い、ログと実況表示の内容を一致させる。MatchTurnResolver/MatchDamagePresenterと
## 同様、MatchScreenの責務を分離するために切り出している。

const RISE_DISTANCE := 24.0
const RISE_DURATION := 0.5
const HOLD_DURATION := 0.3
const FADE_DURATION := 0.35
const FONT_SIZE := 20
const ABOVE_SLOT_GAP := 14.0

var _screen: MatchScreen


func _init(screen: MatchScreen) -> void:
	_screen = screen


## MatchTurnResolverの"state"イベント(駒の状態進行)を実況する。
func show_state_event(state: GameState, event: Dictionary) -> void:
	var text: String = _screen._battle_log.format_state_event(state, event)
	_spawn_near_slot(text, event["side"], event["position"])


## MatchTurnResolverの"hp"イベント(ダメージ)を実況する。発生源の駒が分かる場合は
## その駒の近くへ、分からない場合は盤面中央へフロートさせる。
func show_damage_event(
	side: GameState.PlayerSide, amount: int, new_hp: int, source: Variant
) -> void:
	var text: String = _screen._battle_log.format_damage_event(side, amount, new_hp)
	if source != null:
		_spawn_near_slot(text, source["side"], source["position"])
	else:
		_spawn_at(text, _screen.game_board.get_global_rect().get_center())


## 何も起きないマス(既に落ちきり)の実況(フェーズ17 V-3)。ズームして見せる以上、
## 「なぜ何も起きないのか」も言葉で示す。ログには残さない(毎ターン繰り返され冗長なため)。
func show_idle_step(state: GameState, side: GameState.PlayerSide, position: int) -> void:
	var instance: HourglassInstance = state.board[side][position]
	_spawn_near_slot("『%s』は落ちきったまま" % instance.data.display_name, side, position)


## 行動(反転/移動/交代)の実況(フェーズ14 S-1、MatchActionPresenterから呼ぶ)。文言は
## MatchBattleLog.format_action()が組み立てたものをそのまま受け取り、対象の駒の近くへ出す。
func show_action_text(text: String, side: GameState.PlayerSide, position: int) -> void:
	_spawn_near_slot(text, side, position)


func _spawn_near_slot(text: String, side: GameState.PlayerSide, position: int) -> void:
	var rect: Rect2 = _screen.game_board.get_board_slot_rect(
		_screen.perspective_side(), side, position
	)
	if rect.size == Vector2.ZERO:
		_spawn_at(text, _screen.game_board.get_global_rect().get_center())
		return
	_spawn_at(text, Vector2(rect.get_center().x, rect.position.y - ABOVE_SLOT_GAP))


func _spawn_at(text: String, origin: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.85, 1))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.05, 0.95))
	label.add_theme_constant_override("outline_size", 4)
	_screen.add_child(label)

	var min_size: Vector2 = label.get_minimum_size()
	label.position = origin - Vector2(min_size.x * 0.5, min_size.y)
	label.modulate.a = 0.0

	var tween := _screen.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 0.1)
	tween.tween_property(label, "position:y", label.position.y - RISE_DISTANCE, RISE_DURATION)
	tween.chain().tween_interval(HOLD_DURATION)
	tween.chain().tween_property(label, "modulate:a", 0.0, FADE_DURATION)
	tween.chain().tween_callback(label.queue_free)
