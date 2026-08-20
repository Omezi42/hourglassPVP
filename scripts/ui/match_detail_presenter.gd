class_name MatchDetailPresenter
extends RefCounted
## 砂時計の効果詳細表示(GameDesign.md 9章)。GameBoard/HourglassSlotStripの
## info_requestedシグナルを受けて共通コンポーネント(HourglassDetailPanel)へ反映するだけの
## 責務を持つ。選択→ActionMenuの操作フローとは独立しており、開いたままにしても既存操作を
## 妨げない。MatchTurnResolver等と同様、MatchScreenの責務を分離するために切り出している。

var _screen: MatchScreen


func _init(screen: MatchScreen) -> void:
	_screen = screen


func setup() -> void:
	_screen.game_board.own_info_requested.connect(_on_own_info_requested)
	_screen.game_board.opponent_info_requested.connect(_on_opponent_info_requested)
	_screen.own_slot_strip.info_requested.connect(_on_own_hand_info_requested)
	_screen.opponent_slot_strip.info_requested.connect(_on_opponent_hand_info_requested)
	_screen.detail_close_button.pressed.connect(hide)


func _on_own_info_requested(position: int) -> void:
	if _screen._placement.active:
		show_data(_screen._placement.data_at(position))
		return
	if _screen.state == null:
		return
	show_data(_screen.state.board[_screen.perspective_side()][position].data)


func _on_opponent_info_requested(position: int) -> void:
	if _screen._placement.active or _screen.state == null:
		return
	var opponent_side: GameState.PlayerSide = _screen.state.other_side(_screen.perspective_side())
	show_data(_screen.state.board[opponent_side][position].data)


## 配置フェーズの手札(HourglassSlotStrip)クリックによる詳細表示(J-16)。対局フェーズ中
## (場のゴースト表示・控え)はGameBoard側の選択導線と役割が重複するため対象外とする。
func _on_own_hand_info_requested(index: int) -> void:
	if not _screen._placement.active:
		return
	show_data(_screen._placement.hand_data_at(index))


func _on_opponent_hand_info_requested(index: int) -> void:
	if not _screen._placement.active:
		return
	show_data(_screen._placement.opponent_hand_data_at(index))


func show_data(data: HourglassData) -> void:
	if data == null:
		return
	_screen.detail_panel.show_data(data)
	_screen.detail_panel.visible = true
	_screen.detail_close_button.visible = true


func hide() -> void:
	_screen.detail_panel.visible = false
	_screen.detail_close_button.visible = false
