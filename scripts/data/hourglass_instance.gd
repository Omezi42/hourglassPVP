class_name HourglassInstance
extends RefCounted

var data: HourglassData
var state: GameEnums.HourglassState = GameEnums.HourglassState.UPRIGHT


func _init(p_data: HourglassData) -> void:
	data = p_data


func flip() -> void:
	state = GameEnums.HourglassState.UPRIGHT


func advance() -> void:
	if state < GameEnums.HourglassState.FALLEN:
		state += 1
