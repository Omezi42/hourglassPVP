class_name MatchCpuReplayRecorder
extends RefCounted
## CPU戦の棋譜をLocalReplayServiceへ保存するための蓄積役(K-2)。MatchBattleLog等と同様に
## _screen参照を持つRefCountedとして切り出し、MatchScreen本体の責務から分離している。
## オンライン版matches/{id}に対応する内容(deck_a/deck_b・placement_a/placement_b・actions・
## winner)を対局中に蓄積し、対局終了時にLocalReplayService.mark_finished()へ渡す。

var _screen: MatchScreen
var _actions: Array = []
var _deck_a_ids: Array = []
var _deck_b_ids: Array = []
var _placement_a_ids: Array = []
var _placement_b_ids: Array = []


func _init(screen: MatchScreen) -> void:
	_screen = screen


## CPU戦開始時に呼ぶ。deck_a/deck_b・placement_a/placement_bを、配置済みのHourglassDataから算出する。
func begin(
	board_a: Array[HourglassData],
	bench_a: Array[HourglassData],
	board_b: Array[HourglassData],
	bench_b: Array[HourglassData]
) -> void:
	_actions = []
	_deck_a_ids = _to_ids(board_a) + _to_ids(bench_a)
	_deck_b_ids = _to_ids(board_b) + _to_ids(bench_b)
	_placement_a_ids = _to_ids(board_a)
	_placement_b_ids = _to_ids(board_b)


func record_action(action: Dictionary) -> void:
	_actions.append(action)


## 対局終了時に呼ぶ。LocalReplayServiceへ棋譜を保存する。
func save_finished(winner: GameState.PlayerSide) -> void:
	var winner_str := "a" if winner == GameState.PlayerSide.A else "b"
	(
		LocalReplayService
		. mark_finished(
			{
				"deck_a": _deck_a_ids,
				"deck_b": _deck_b_ids,
				"placement_a": _placement_a_ids,
				"placement_b": _placement_b_ids,
				"actions": _actions,
				"winner": winner_str,
			}
		)
	)


static func _to_ids(data_list: Array[HourglassData]) -> Array:
	var result: Array = []
	for hourglass_data in data_list:
		result.append(hourglass_data.id)
	return result
