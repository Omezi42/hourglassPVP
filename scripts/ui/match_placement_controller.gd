class_name MatchPlacementController
extends Node
## 配置フェーズ(GameDesign.md 9章「配置フェーズは専用画面を設けず、対局画面の中で行う」)の
## 状態と操作をMatchScreenから切り出したコントローラ。MatchScreenのUIノードを直接操作し、
## 配置確定時にMatchScreen.start_match()/start_online_match()/start_cpu_match()を呼び出す。
## MatchScreen本体(対局フェーズの責務)と配置フェーズの責務を分離するために独立させている。

enum Kind { LOCAL, ONLINE, CPU }

var active := false

var _screen: MatchScreen
var _kind: Kind = Kind.LOCAL
var _deck: Array[HourglassData] = []
## サイズGameState.BOARD_SIZE固定。null要素は未配置のマス。
var _board: Array = []
var _selected_id := ""
var _busy := false

var _online_setup: OnlineSetup = null
var _online_match_id := ""
var _my_side: GameState.PlayerSide = GameState.PlayerSide.A
var _opponent_deck: Array[HourglassData] = []

## Kind.CPU用: Mainが事前にランダム生成したCPU側の場・控え(固定、変化しない)。
var _cpu_board: Array[HourglassData] = []
var _cpu_bench: Array[HourglassData] = []
## Kind.LOCAL用: 相手側の場・控え(この経路では相手も選択済みの固定値として渡される)。
var _opponent_board_fixed: Array[HourglassData] = []
var _opponent_bench_fixed: Array[HourglassData] = []
var _is_first := true


func _init(screen: MatchScreen) -> void:
	_screen = screen


func setup() -> void:
	_screen.own_slot_strip.placement_slot_pressed.connect(_on_hand_pressed)
	_screen.placement_start_button.pressed.connect(_on_start_pressed)


## ローカル対戦(同一端末での交互操作)の入り口。相手側は既に配置済みの固定値として渡す
## (真に対称な2人分の配置UIは現状Mainから未接続のため、既存のCPU戦経路と同じ
## 非対称な形で先に用意しておく)。確定後、is_firstに応じてA/B側を割り当てる。
func begin_match(
	own_deck: Array[HourglassData],
	opponent_board: Array[HourglassData],
	opponent_bench: Array[HourglassData],
	is_first: bool
) -> void:
	_kind = Kind.LOCAL
	_opponent_board_fixed = opponent_board
	_opponent_bench_fixed = opponent_bench
	_is_first = is_first
	var opponent_deck: Array[HourglassData] = opponent_board + opponent_bench
	_enter(own_deck, opponent_deck, "あなたは先手です" if is_first else "あなたは後手です")


## CPU戦の入り口。CPUの場・控えはMainが対局開始前にランダム生成済みで、配置フェーズでは
## 変化しない(GameDesign.md 13章)。プレイヤーは常に先手のため配置フェーズも先手として扱う。
func begin_cpu(
	own_deck: Array[HourglassData], cpu_board: Array[HourglassData], cpu_bench: Array[HourglassData]
) -> void:
	_kind = Kind.CPU
	_cpu_board = cpu_board
	_cpu_bench = cpu_bench
	var cpu_deck: Array[HourglassData] = cpu_board + cpu_bench
	_enter(own_deck, cpu_deck, "あなたは先手です")


## オンライン対戦の入り口。相手のデッキ取得・自分の配置送信・相手の配置待ちの手順は、
## 旧DeckSelectScreen.setup_online()/_on_start_pressed()から一字一句そのまま移植している。
func begin_online(
	own_deck: Array[HourglassData], match_id: String, my_side: GameState.PlayerSide
) -> void:
	_kind = Kind.ONLINE
	_my_side = my_side
	_online_match_id = match_id
	_enter(own_deck, [], "対戦相手のデッキを待っています...")

	_online_setup = OnlineSetup.new(NetSession.client, match_id, my_side)
	add_child(_online_setup)

	var own_ids: Array[String] = []
	for hourglass_data in own_deck:
		own_ids.append(hourglass_data.id)
	await _online_setup.push_deck(own_ids)

	var opponent_ids: Array[String] = await _online_setup.wait_for_opponent_deck()
	if opponent_ids.is_empty():
		_screen.turn_label.text = "対戦相手のデッキ取得がタイムアウトしました。通信状態を確認してください"
		return

	var opponent_deck: Array[HourglassData] = []
	for id in opponent_ids:
		opponent_deck.append(MatchSetup.find_by_id(id))
	_opponent_deck = opponent_deck

	_opponent_deck = opponent_deck
	_screen.turn_label.text = ("あなたは先手です" if my_side == GameState.PlayerSide.A else "あなたは後手です")
	_screen.opponent_slot_strip.show_placement_hand(opponent_deck, [])
	_screen.opponent_slot_strip.set_placement_interactive(false)


## 配置フェーズ共通の初期化。対局用HUDを隠し、自分の手札・相手の公開デッキを表示する。
## 効果詳細は駒のクリック(MatchDetailPanel)で確認する方式に統一しており、専用の効果一覧
## テキストは表示しない(J-16)。
func _enter(
	own_deck: Array[HourglassData], opponent_deck: Array[HourglassData], status_text: String
) -> void:
	active = true
	_deck = own_deck
	_opponent_deck = opponent_deck
	_board = []
	_board.resize(GameState.BOARD_SIZE)
	_selected_id = ""
	_busy = false

	_screen.result_overlay.visible = false
	_screen.action_menu.visible = false
	_screen.back_button.visible = false
	_screen.surrender_button.visible = false
	_screen.end_turn_button.visible = false
	_screen._detail_presenter.hide()
	_screen.replay_controls.visible = false
	_screen.spectate_label.visible = false
	_screen.own_status.visible = false
	_screen.opponent_status.visible = false
	_screen.placement_controls.visible = true
	_screen.placement_start_button.disabled = true

	_screen.turn_label.text = status_text
	_screen.opponent_slot_strip.show_placement_hand(opponent_deck, [])
	_screen.opponent_slot_strip.set_placement_interactive(false)
	_refresh_view()


func exit() -> void:
	active = false
	_screen.placement_controls.visible = false
	# 空きマスの配置候補ハイライトは対局中の移動先候補と同じ表現を流用しているため、
	# 抜けるときに必ず消す(GameDesign.md 9章)
	_screen.game_board.clear_move_targets()
	_screen.own_status.visible = true
	_screen.opponent_status.visible = true
	_screen.own_slot_strip.exit_placement_mode()
	_screen.opponent_slot_strip.exit_placement_mode()
	if _online_setup != null:
		_online_setup.queue_free()
		_online_setup = null


## 配置フェーズ中の自分の場(position)に置かれている砂時計データ。未配置ならnull。
## 対局中の効果詳細表示(GameDesign.md 9章)が配置フェーズでも動くよう、MatchScreen側から参照する。
func data_at(position: int) -> HourglassData:
	return _board[position]


## 配置フェーズ中の自分の手札(HourglassSlotStrip)のindex番目のデータ。既に場へ配置済みの
## 駒はこのストリップから消える(clear()表示)ため、その場合はnullを返す(J-16)。
func hand_data_at(index: int) -> HourglassData:
	if index < 0 or index >= _deck.size():
		return null
	var data := _deck[index]
	if _board_has(data):
		return null
	return data


## 配置フェーズ中に公開されている相手の手札(HourglassSlotStrip)のindex番目のデータ(J-16)。
func opponent_hand_data_at(index: int) -> HourglassData:
	if index < 0 or index >= _opponent_deck.size():
		return null
	return _opponent_deck[index]


func on_board_pressed(position: int) -> void:
	if _busy:
		return
	if _board[position] != null:
		_board[position] = null
	elif _selected_id != "":
		_board[position] = _find_deck_data(_selected_id)
		_selected_id = ""
	_refresh_view()


func _on_hand_pressed(index: int) -> void:
	if not active or _busy or index >= _deck.size():
		return
	var data := _deck[index]
	if _board_has(data):
		return
	_selected_id = "" if _selected_id == data.id else data.id
	_refresh_view()


func _board_has(data: HourglassData) -> bool:
	for placed in _board:
		if placed != null and placed.id == data.id:
			return true
	return false


func _find_deck_data(id: String) -> HourglassData:
	for hourglass_data in _deck:
		if hourglass_data.id == id:
			return hourglass_data
	return null


func _refresh_view() -> void:
	var placed_ids: Array[String] = []
	for placed in _board:
		if placed != null:
			placed_ids.append((placed as HourglassData).id)
	_screen.own_slot_strip.show_placement_hand(_deck, placed_ids, _selected_id)
	_screen.own_slot_strip.set_placement_interactive(not _busy)
	_screen.game_board.show_own_placement(_board)
	_screen.game_board.set_own_placement_interactive(not _busy)
	_screen.placement_start_button.disabled = _busy or placed_ids.size() < GameState.BOARD_SIZE


func _on_start_pressed() -> void:
	if _busy:
		return
	var board_order: Array[HourglassData] = []
	for placed in _board:
		board_order.append(placed as HourglassData)
	var bench: Array[HourglassData] = []
	for hourglass_data in _deck:
		if not _board_has(hourglass_data):
			bench.append(hourglass_data)

	match _kind:
		Kind.CPU:
			var cpu_board := _cpu_board
			var cpu_bench := _cpu_bench
			exit()
			_screen.start_cpu_match(board_order, bench, cpu_board, cpu_bench)
		Kind.LOCAL:
			var opponent_board := _opponent_board_fixed
			var opponent_bench := _opponent_bench_fixed
			var is_first := _is_first
			exit()
			if is_first:
				_screen.start_match(board_order, bench, opponent_board, opponent_bench)
			else:
				_screen.start_match(opponent_board, opponent_bench, board_order, bench)
		Kind.ONLINE:
			await _start_online(board_order, bench)


## Kind.ONLINE用。自分の配置送信→相手の配置待ちの手順は、旧DeckSelectScreen
## ._on_start_pressed()のオンライン分岐、およびMain._on_online_placement_ready()の
## OnlineMatch生成手順を一字一句そのまま移植している。
func _start_online(board_order: Array[HourglassData], bench: Array[HourglassData]) -> void:
	_busy = true
	_refresh_view()
	_screen.turn_label.text = "相手の配置を待っています..."

	var board_ids: Array[String] = []
	for hourglass_data in board_order:
		board_ids.append(hourglass_data.id)
	await _online_setup.push_placement(board_ids)

	var opponent_board_ids: Array[String] = await _online_setup.wait_for_opponent_placement()
	if opponent_board_ids.is_empty():
		_screen.turn_label.text = "対戦相手の配置取得がタイムアウトしました。通信状態を確認してください"
		_busy = false
		_refresh_view()
		return

	var opponent_board: Array[HourglassData] = []
	for id in opponent_board_ids:
		opponent_board.append(MatchSetup.find_by_id(id))
	var opponent_bench: Array[HourglassData] = []
	for hourglass_data in _opponent_deck:
		if not opponent_board_ids.has(hourglass_data.id):
			opponent_bench.append(hourglass_data)

	var online_match := OnlineMatch.new(NetSession.client)
	_screen.add_child(online_match)
	online_match.start(_online_match_id)

	var my_side := _my_side
	exit()
	if my_side == GameState.PlayerSide.A:
		_screen.start_online_match(
			board_order, bench, opponent_board, opponent_bench, online_match, my_side
		)
	else:
		_screen.start_online_match(
			opponent_board, opponent_bench, board_order, bench, online_match, my_side
		)
