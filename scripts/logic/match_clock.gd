class_name MatchClock
extends RefCounted

## 側は 0/1(MatchState.Side)。
## **手番側の時計が尽きたという通知であり、自分の時間切れとは限らない**
## (相手の手番でも発火する)。受け取る側が引数の側を必ず見ること。
signal time_out(side: int)

## 1手番ぶんの持ち時間。手番が移るたびにここへ戻る(GameDesign.md 5章)。
const DEFAULT_TURN_SECONDS := 60.0
## 時間切れを重ねても、これより短くはしない。
const MIN_TURN_SECONDS := 10.0

var turn_seconds: float
var remaining: Dictionary = {}
## いま時計が動いている側。まだ1手番も始まっていなければ -1。
var active_side: int = -1
var running := false


func _init(p_turn_seconds: float = DEFAULT_TURN_SECONDS) -> void:
	turn_seconds = p_turn_seconds
	remaining = {0: turn_seconds, 1: turn_seconds}


## 手番の始まり。**側が変わったときだけ持ち時間を戻す**。1手番のうちに
## 何度も指す(出す→攻撃→反転)たびに戻すと、指し続けている限り尽きなくなる。
## `seconds` を渡すとその値から始める(時間切れを重ねた側は短くなる。下記)。
func start_turn(side: int, seconds: float = -1.0) -> void:
	if side != active_side:
		remaining[side] = seconds if seconds > 0.0 else turn_seconds
		active_side = side
	running = true


## 時間切れを重ねた側の、次の手番の持ち時間(GameDesign.md 5章)。1回ごとに半分にする。
## **回数そのものは `MatchState` が持つ**(手として送り合うため、両者で同じ値になる)。
## ここは「回数 → 秒数」の対応だけを持ち、状態を持たない。
static func seconds_after_forfeits(count: int, base: float = DEFAULT_TURN_SECONDS) -> float:
	return maxf(base / pow(2.0, count), MIN_TURN_SECONDS)


func stop() -> void:
	running = false


func tick(delta: float) -> void:
	if not running:
		return
	remaining[active_side] = max(remaining[active_side] - delta, 0.0)
	if remaining[active_side] <= 0.0:
		running = false
		time_out.emit(active_side)


func get_remaining(side: int) -> float:
	return remaining[side]
