class_name MatchReplayController
extends RefCounted
## リプレイ再生モード(GameDesign.md 12章)の棋譜保持と再生制御を、MatchScreenから切り出した
## コントローラ。保存済みの対局ドキュメント(Firestoreのmatches/{id}、またはCPU戦の
## LocalReplayServiceの記録)から初期配置と手順を復元し、再生コントロール
## (先頭へ/1手戻る/再生/1手進む/最後へ)の操作を受けて指定の手数まで再現する。
## MatchResultPresenter/MatchTurnResolverと同様、MatchScreenの責務を分離するために独立させている。
##
## モードフラグ(_is_replay)・HUDの出し分け・GameStateの生成はMatchScreen側の責務のまま残し、
## ここからはMatchScreen.begin_replay_mode()/reset_state_for_replay()経由で呼び出す。

## 手を一気に再現している最中かどうか。この間は1手ごとの演出・効果音を出さない。
## 観戦(MatchScreen.start_spectate())の追いつきループも同じ意味を持つためこのフラグを共用する。
var catching_up := false

var _screen: MatchScreen
var _actions: Array = []
var _index := 0
var _playing := false
var _board_a: Array[HourglassData] = []
var _bench_a: Array[HourglassData] = []
var _board_b: Array[HourglassData] = []
var _bench_b: Array[HourglassData] = []


func _init(screen: MatchScreen) -> void:
	_screen = screen


func setup() -> void:
	_screen.replay_to_start_button.pressed.connect(func() -> void: _goto(0))
	_screen.replay_back_button.pressed.connect(func() -> void: _goto(_index - 1))
	_screen.replay_forward_button.pressed.connect(func() -> void: _goto(_index + 1))
	_screen.replay_to_end_button.pressed.connect(func() -> void: _goto(_actions.size()))
	_screen.replay_play_button.pressed.connect(_on_play_pressed)
	_screen.replay_timer.timeout.connect(_on_timer_timeout)


## 保存済みのmatches/{match_id}を読み込み、再生モードで開始する。
func start_from_firestore(match_id: String, client: FirestoreClient) -> void:
	var doc: Dictionary = await client.get_document("matches/%s" % match_id)
	start_from_doc(doc)


## 対局1件分の記録から再生モードを開始する。Firestoreのドキュメントと
## LocalReplayService.get_replay()の戻り値は、いずれもフラットなDictionary
## (deck_a/deck_b/placement_a/placement_b/actions)で共通のためどちらも受け付ける。
func start_from_doc(doc: Dictionary) -> void:
	var deck_a_ids: Array = doc.get("deck_a", [])
	var deck_b_ids: Array = doc.get("deck_b", [])
	var placement_a_ids: Array = doc.get("placement_a", [])
	var placement_b_ids: Array = doc.get("placement_b", [])

	_actions = doc.get("actions", [])
	_board_a = ids_to_data(placement_a_ids)
	_bench_a = ids_to_data(ids_minus(deck_a_ids, placement_a_ids))
	_board_b = ids_to_data(placement_b_ids)
	_bench_b = ids_to_data(ids_minus(deck_b_ids, placement_b_ids))

	_playing = false
	_screen.replay_play_button.text = "再生"
	_screen.begin_replay_mode(_board_a, _bench_a, _board_b, _bench_b)
	_goto(0)


## 保存済みドキュメントのid配列をHourglassDataの配列へ変換する。観戦
## (MatchScreen.start_spectate())も同じ形のドキュメントから初期配置を復元するため共用する。
static func ids_to_data(ids: Array) -> Array[HourglassData]:
	var result: Array[HourglassData] = []
	for id in ids:
		var data: HourglassData = MatchSetup.find_by_id(str(id))
		if data != null:
			result.append(data)
	return result


## デッキ5個のidから場3個を除き、控え2個のidを求める(控えは別フィールドを持たず、
## 「デッキ−配置」として導出する。Architecture.md 6章)。
static func ids_minus(all_ids: Array, remove_ids: Array) -> Array:
	var result: Array = []
	for id in all_ids:
		if not remove_ids.has(id):
			result.append(id)
	return result


## 指定した手数(0=対局開始時点)まで、最初から手順を適用し直して状態を再現する。
## GameStateは巻き戻し操作を持たないため、毎回最初から作り直す。
func _goto(index: int) -> void:
	index = clampi(index, 0, _actions.size())
	_screen.replay_timer.stop()
	_playing = false
	_screen.replay_play_button.text = "再生"

	catching_up = true
	_screen.reset_state_for_replay(_board_a, _bench_a, _board_b, _bench_b)
	for i in range(index):
		OnlineMatch.apply(_actions[i], _screen.state)
		if not _screen.state.is_match_over():
			_screen.state.advance_and_end_turn()
	catching_up = false

	_index = index
	_screen.refresh_view()
	_refresh_controls()


func _on_play_pressed() -> void:
	if _index >= _actions.size():
		return
	_playing = not _playing
	_screen.replay_play_button.text = "一時停止" if _playing else "再生"
	if _playing:
		_screen.replay_timer.start()
	else:
		_screen.replay_timer.stop()


func _on_timer_timeout() -> void:
	if _index >= _actions.size():
		_screen.replay_timer.stop()
		_playing = false
		_screen.replay_play_button.text = "再生"
		return
	var was_playing := _playing
	_goto(_index + 1)
	if was_playing and _index < _actions.size():
		_playing = true
		_screen.replay_play_button.text = "一時停止"
		_screen.replay_timer.start()


func _refresh_controls() -> void:
	_screen.replay_step_label.text = "%d / %d手目" % [_index, _actions.size()]
	_screen.replay_to_start_button.disabled = _index == 0
	_screen.replay_back_button.disabled = _index == 0
	_screen.replay_forward_button.disabled = _index >= _actions.size()
	_screen.replay_to_end_button.disabled = _index >= _actions.size()
