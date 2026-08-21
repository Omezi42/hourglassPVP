class_name MatchBattleLog
extends RefCounted
## 対局ログ(GameDesign.md 9章)。反転/移動/交代の直接操作と、ターン進行で起きた
## 状態変化・ダメージを記録し、MatchScreenのLogPanel/LogListへ反映する。
## MatchPlacementController/MatchTurnResolverと同様、MatchScreenの責務を分離するために
## 切り出している。

const MAX_ENTRIES := 200

var _screen: MatchScreen
var _entries: Array[String] = []
var _open := false


func _init(screen: MatchScreen) -> void:
	_screen = screen


func setup() -> void:
	_screen.log_button.pressed.connect(func() -> void: set_open(not _open))
	_screen.log_close_button.pressed.connect(func() -> void: set_open(false))
	# 暗幕(Dim)のクリックでも閉じられるようにする(O-3: モーダル化に伴うクリックアウト対応)。
	_screen.log_dim.gui_input.connect(_on_dim_gui_input)
	_screen.log_panel.visible = false


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		set_open(false)


func reset() -> void:
	_entries.clear()
	set_open(false)
	_refresh()


func set_open(open: bool) -> void:
	_open = open
	_screen.log_panel.visible = open


## 反転/移動/交代の直接操作を記録する。
func record_action(state: GameState, action: Dictionary) -> void:
	var text := format_action(state, action)
	if not text.is_empty():
		_append(text)


## record_action()と同じ文言を組み立てるだけの関数。行動の実況フロート表示
## (MatchActionPresenter)がログと同一の文言を使うために公開している。
func format_action(state: GameState, action: Dictionary) -> String:
	match action.get("type", ""):
		"flip":
			return _format_flip(state, action)
		"move":
			var side: int = action["side"]
			var from_position: int = action["from"]
			var to_position: int = action["to"]
			var name: String = state.board[side][to_position].data.display_name
			return (
				"%sが「%s」を%s→%sへ移動"
				% [
					_side_label(side),
					name,
					_position_label(from_position),
					_position_label(to_position)
				]
			)
		"swap_in":
			var side: int = action["side"]
			var name: String = state.board[side][GameState.BoardPosition.LEFT].data.display_name
			return "%sが控えの「%s」に交代" % [_side_label(side), name]
		"skill":
			return _format_skill(state, action)
		"surrender":
			var side: int = action["side"]
			return "%sが投了" % _side_label(side)
	return ""


## 自陣の駒を反転した場合は「先手が先手の…」と同じ側を2度呼ぶ形になり読みにくいため所属を
## 書かない。相手の駒を反転した場合だけ、誰の駒なのかを明示する。
func _format_flip(state: GameState, action: Dictionary) -> String:
	var actor: int = action["actor"]
	var target_side: int = action["side"]
	var name: String = state.board[target_side][action["position"]].data.display_name
	if actor == target_side:
		return "%sが「%s」を反転" % [_side_label(actor), name]
	return "%sが%sの「%s」を反転" % [_side_label(actor), _side_label(target_side), name]


func _format_skill(state: GameState, action: Dictionary) -> String:
	var side: int = action["side"]
	var data: HourglassData = state.board[side][action["position"]].data
	if data.skill == null:
		return ""
	var names := [_side_label(side), data.display_name, data.skill.display_name]
	return "%sが「%s」のスキル『%s』を使用" % names


## ターン進行の逐次演出(MatchTurnResolver)で発生した状態変化を記録する。
func record_state_event(state: GameState, event: Dictionary) -> void:
	_append(format_state_event(state, event))


## ターン進行の逐次演出(MatchTurnResolver)で発生したダメージを記録する。
func record_damage_event(side: int, amount: int, new_hp: int) -> void:
	_append(format_damage_event(side, amount, new_hp))


## record_state_event()と同じ文言を組み立てるだけの関数。実況フロート表示(P-3、
## MatchEventCaption)がログと同一の文言を使うために公開している。
func format_state_event(state: GameState, event: Dictionary) -> String:
	var side: int = event["side"]
	var position: int = event["position"]
	var name: String = state.board[side][position].data.display_name
	return "%sの「%s」が%sへ進行" % [_side_label(side), name, _state_label(event["new_state"])]


## record_damage_event()と同じ文言を組み立てるだけの関数(P-3用に公開)。
func format_damage_event(side: int, amount: int, new_hp: int) -> String:
	return "%sに%dダメージ(残りHP%d)" % [_side_label(side), amount, new_hp]


## 決着そのものを1手として記録する(GameDesign.md 9章、フェーズ18 W-4)。ログだけを追っても
## 何で勝負が決したのかが分かるようにするため、勝者と決着の要因を1行残す。
func record_match_end(state: GameState, winner: int) -> void:
	_append(format_match_end(state, winner))


## record_match_end()と同じ文言を組み立てるだけの関数。結果パネル側と文言を揃えるために
## 公開している(既存のformat_*関数と同じ扱い)。
func format_match_end(state: GameState, winner: int) -> String:
	var loser: int = state.other_side(winner)
	var reason: String
	match state.end_reason:
		GameState.EndReason.TIMEOUT:
			reason = "%sの持ち時間切れ" % _side_label(loser)
		GameState.EndReason.SURRENDER:
			reason = "%sの投了" % _side_label(loser)
		_:
			reason = "%sのHPが0" % _side_label(loser)
	return "%sの勝利(%s)" % [_side_label(winner), reason]


func _side_label(side: int) -> String:
	return "先手" if side == GameState.PlayerSide.A else "後手"


func _position_label(position: int) -> String:
	match position:
		GameState.BoardPosition.LEFT:
			return "左"
		GameState.BoardPosition.CENTER:
			return "中央"
		GameState.BoardPosition.RIGHT:
			return "右"
		_:
			return "?"


func _state_label(hourglass_state: int) -> String:
	match hourglass_state:
		GameEnums.HourglassState.UPRIGHT:
			return "上向き"
		GameEnums.HourglassState.FALLING:
			return "落下中"
		GameEnums.HourglassState.FALLEN:
			return "落ちきり"
		_:
			return "?"


func _append(text: String) -> void:
	_entries.push_front(text)
	if _entries.size() > MAX_ENTRIES:
		_entries.resize(MAX_ENTRIES)
	_refresh()


func _refresh() -> void:
	for child in _screen.log_list.get_children():
		child.queue_free()
	for entry in _entries:
		var label := Label.new()
		label.text = entry
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.89, 1))
		_screen.log_list.add_child(label)
