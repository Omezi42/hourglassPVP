class_name MatchClock
extends RefCounted

signal time_out(side: GameState.PlayerSide)

const DEFAULT_TIME_SECONDS := 180.0

var total_seconds: float
var remaining: Dictionary = {}
var active_side: GameState.PlayerSide = GameState.PlayerSide.A
var running := false


func _init(p_total_seconds: float = DEFAULT_TIME_SECONDS) -> void:
	total_seconds = p_total_seconds
	remaining = {GameState.PlayerSide.A: total_seconds, GameState.PlayerSide.B: total_seconds}


func start_turn(side: GameState.PlayerSide) -> void:
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


func finish_turn(next_side: GameState.PlayerSide) -> void:
	active_side = next_side


func get_remaining(side: GameState.PlayerSide) -> float:
	return remaining[side]
