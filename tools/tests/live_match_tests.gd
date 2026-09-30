extends RefCounted

## ランクマッチの観戦一覧(GameDesign.md 12章)の絞り込みとターン数の検証。

const NOW := "2026-10-01T12:00:00.000000Z"
const RECENT := "2026-10-01T11:59:00.000000Z"
const LONG_AGO := "2026-10-01T11:50:00.000000Z"


func run(assert_true: Callable) -> void:
	assert_true.call(LiveMatchService.is_live(_doc({})), "始まっていて続いているランクマッチは一覧に出ること")
	assert_true.call(
		not LiveMatchService.is_live(_doc({"kind": LiveMatchService.KIND_ROOM})), "ルームマッチは一覧に出さないこと"
	)
	assert_true.call(not LiveMatchService.is_live(_doc({"kind": ""})), "種別を持たない古い対局は出さないこと")
	assert_true.call(not LiveMatchService.is_live(_doc({"build": "other"})), "違う版の対局は出さないこと")
	assert_true.call(not LiveMatchService.is_live(_doc({"deck_b": []})), "後手のデッキがまだ無い対局は出さないこと")
	assert_true.call(not LiveMatchService.is_live(_doc({"finished_at": 1.0})), "終わった対局は出さないこと")
	assert_true.call(not LiveMatchService.is_live(_doc({"abandoned": true})), "放棄された対局は出さないこと")
	assert_true.call(not LiveMatchService.is_live(_doc({}, LONG_AGO)), "3分以上書き込みの無い対局は出さないこと")
	var actions := [
		{"type": "mulligan", "side": 0},
		{"type": "play", "side": 0},
		{"type": "end_turn", "side": 0},
		{"type": "time_up", "side": 1},
		{"type": "attack", "side": 0}
	]
	assert_true.call(LiveMatchService.turn_of(actions) == 3, "手番を終える手の数 + 1 がターン数であること")
	assert_true.call(LiveMatchService.turn_of([]) == 1, "手が無ければ1ターン目")


func _doc(overrides: Dictionary, update_time := RECENT) -> Dictionary:
	var fields := {
		"kind": LiveMatchService.KIND_RANKED,
		"build": GameVersion.build_id(),
		"seed": 1,
		"deck_b": ["a"],
	}
	fields.merge(overrides, true)
	return {"id": "m1", "fields": fields, "update_time": update_time, "read_time": NOW}
