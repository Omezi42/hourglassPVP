class_name MatchClock
extends RefCounted

## 側は 0/1(MatchState.Side)。
signal time_out(side: int)

const DEFAULT_TIME_SECONDS := 180.0

var total_seconds: float
var remaining: Dictionary = {}
var active_side: int = 0
var running := false


func _init(p_total_seconds: float = DEFAULT_TIME_SECONDS) -> void:
	total_seconds = p_total_seconds
	remaining = {0: total_seconds, 1: total_seconds}


func start_turn(side: int) -> void:
	active_side = side
	running = true


func stop() -> void:
	running = false


func tick(delta: float) -> void:
	if not running:
		return
	remaining[active_side] = max(remaining[active_side] - delta, 0.0)
	if remaining[active_side] <= 0.0:
		running = false
		time_out.emit(active_side)


func finish_turn(next_side: int) -> void:
	active_side = next_side


func get_remaining(side: int) -> float:
	return remaining[side]
