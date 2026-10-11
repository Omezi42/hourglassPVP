extends SceneTree
## オンライン対戦の記録(match_records)を棋譜から再生し、終局の局面を書き出す(GameDesign.md 22章)。
## 棋譜は「手札の何枚目を出したか」しか持たないため、HP・盤面・出したカードはエンジンで並べ直して作る。
## `tools/analyze_matches.py --surrenders` が呼ぶ。
##
## 使い方:
##   Godot --headless --path . --script tools/replay_match_records.gd -- \
##       in=records.json out=replayed.json
##
## **再生は今のカードで行う。**カードの数値が記録の版から変わっていると局面がずれるため、
## 記録の最終HP・手数と一致したかを `matches` に残す(一致しない局は集計で信用しない)。
## HPで決着した局は、記録を書いた時点でとどめの手がまだ棋譜へ届いていないことがあり、一致しにくい。

## 終局の直前として遡る手番の数。投了した側が直前に見た相手の手番まで含める。
const RECENT_TURNS := 2


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var text := FileAccess.get_file_as_string(str(args.get("in", "")))
	var records: Variant = JSON.parse_string(text)
	if not records is Array:
		push_error("in= に記録の配列(JSON)を渡してください")
		quit(1)
		return
	var results: Array = []
	for record in records:
		results.append(_replay(record))
	var file := FileAccess.open(str(args.get("out", "")), FileAccess.WRITE)
	file.store_string(JSON.stringify(results))
	file.close()
	quit()


func _replay(record: Dictionary) -> Dictionary:
	var result := {"id": record.get("id", ""), "replayed": false}
	var deck_a := CardLibrary.deck_from_ids(record.get("deck_a", []))
	var deck_b := CardLibrary.deck_from_ids(record.get("deck_b", []))
	if deck_a.size() != MatchState.DECK_SIZE or deck_b.size() != MatchState.DECK_SIZE:
		return result
	var actions: Array = record.get("actions", [])
	var state := MatchState.new()
	root.add_child(state)
	state.start_match(
		deck_a,
		deck_b,
		MatchState.Side.A,
		int(record.get("seed", 0)),
		MatchState.COIN_ENABLED,
		MatchAction.contains_mulligan(actions)
	)
	var plays: Array = []
	var rejected := 0
	for action in actions:
		var played := _played_card(state, action)
		if not MatchAction.apply(state, action):
			rejected += 1
			continue
		if played != "":
			plays.append({"turn": state.turn_count, "side": int(action["side"]), "card": played})
	result["replayed"] = true
	result["rejected"] = rejected
	result["matches"] = (
		rejected == 0
		and state.turn_count == int(record.get("turns", -1))
		and state.hp[MatchState.Side.A] == int(record.get("hp_a", -1))
		and state.hp[MatchState.Side.B] == int(record.get("hp_b", -1))
	)
	result["turn"] = state.turn_count
	result["current_side"] = state.current_turn
	result["sides"] = [
		_side_snapshot(state, MatchState.Side.A), _side_snapshot(state, MatchState.Side.B)
	]
	result["recent_plays"] = plays.filter(
		func(play: Dictionary) -> bool: return play["turn"] > state.turn_count - RECENT_TURNS
	)
	state.queue_free()
	return result


## 出す・撃つ手なら、適用する前の手札からカード名を引く(適用すると手札から消えるため)。
func _played_card(state: MatchState, action: Dictionary) -> String:
	if not action.get("type", "") in ["play", "cast"]:
		return ""
	var hand: Array = state.hand.get(int(action.get("side", -1)), [])
	var index := int(action.get("hand_index", -1))
	if index < 0 or index >= hand.size():
		return ""
	return hand[index].display_name


func _side_snapshot(state: MatchState, side: int) -> Dictionary:
	var units: Array = []
	var attack := 0
	for unit in state.units(side):
		units.append("%s %d/%d" % [unit.data.display_name, unit.attack, unit.health])
		attack += unit.attack
	return {
		"hp": state.hp[side],
		"units": units,
		"attack": attack,
		"hand": state.hand[side].size(),
		"max_mana": state.max_mana[side],
	}


func _parse_args() -> Dictionary:
	var parsed: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			parsed[pair[0]] = pair[1]
	return parsed
