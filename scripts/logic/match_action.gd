class_name MatchAction
extends RefCounted
## 1手を Dictionary として表し、`MatchState` へ適用する唯一の経路。
## 自分の操作・CPUの着手・オンラインで受け取った手・リプレイの再生が
## すべてここを通ることで、棋譜の形と盤面の更新を1箇所に保つ。
##
## 形:
##   {"type": "play",     "side":, "hand_index":, "slot":, "target": {"side":, "slot":}}
##   {"type": "cast",     "side":, "hand_index":, "target": {"side":, "slot":}}
##   {"type": "flip",     "side":, "slot":}
##   {"type": "flip_right","side":, "target_side":, "slot":}   反転権(GameDesign.md 2章)
##   {"type": "attack",   "side":, "slot":, "target_slot":}   target_slot が -1 なら本体
##   {"type": "end_turn", "side":}
##   {"type": "surrender","side":}
##   {"type": "time_up",  "side":}   持ち時間切れ。手番を強制的に終える
##   {"type": "timeout",  "side":}   切断とみなした時間切れ(その場で敗北)
##   {"type": "coin",     "side":}   後手が1度だけ使える +1マナ
##   {"type": "mulligan","side":, "indices": [手札の位置]}   初手の引き直し


static func play(side: int, hand_index: int, slot: int, target: Dictionary = {}) -> Dictionary:
	return {"type": "play", "side": side, "hand_index": hand_index, "slot": slot, "target": target}


static func cast(side: int, hand_index: int, target: Dictionary = {}) -> Dictionary:
	return {"type": "cast", "side": side, "hand_index": hand_index, "target": target}


static func flip(side: int, slot: int) -> Dictionary:
	return {"type": "flip", "side": side, "slot": slot}


static func flip_right(side: int, target_side: int, slot: int) -> Dictionary:
	return {"type": "flip_right", "side": side, "target_side": target_side, "slot": slot}


static func attack(side: int, slot: int, target_slot: int) -> Dictionary:
	return {"type": "attack", "side": side, "slot": slot, "target_slot": target_slot}


static func end_turn(side: int) -> Dictionary:
	return {"type": "end_turn", "side": side}


static func mulligan(side: int, indices: Array) -> Dictionary:
	return {"type": "mulligan", "side": side, "indices": indices}


static func emote(side: int, emote_id: String) -> Dictionary:
	return {"type": "emote", "side": side, "emote_id": emote_id}


## 棋譜がマリガンを含むか(GameDesign.md 2章)。マリガンの導入前に保存された棋譜は
## 含まないため、再生・観戦はこれを見て待つかどうかを決める。
static func contains_mulligan(actions: Array) -> bool:
	for action in actions:
		if action.get("type", "") == "mulligan":
			return true
	return false


## 1手を適用する。適用できた場合のみ true を返す。
static func apply(state: MatchState, action: Dictionary) -> bool:
	var side: int = action.get("side", state.current_turn)
	match action.get("type", ""):
		"play":
			return state.play_card(
				side, action["hand_index"], action["slot"], action.get("target", {})
			)
		"cast":
			return state.cast_spell(side, action["hand_index"], action.get("target", {}))
		"flip_right":
			return state.use_flip_right(side, action["target_side"], action["slot"])
		"flip":
			return state.flip(side, action["slot"])
		"attack":
			return state.attack(side, action["slot"], action["target_slot"])
		"end_turn":
			state.end_turn()
			return true
		"surrender":
			state.surrender(side)
			return true
		"time_up":
			return state.time_up(side)
		"timeout":
			state.surrender(side, MatchState.EndReason.TIMEOUT)
			return true
		"coin":
			return state.use_coin(side)
		"mulligan":
			return state.mulligan(side, action.get("indices", []))
		"emote":
			return true
	return false
