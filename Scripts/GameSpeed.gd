# res://scripts/autoload/GameSpeed.gd
extends Node
class_name GameSpeed

signal speed_changed(multiplier: float)

const SPEEDS: Array[float] = [1.0, 2.0, 4.0]
var _index := 0

func _ready() -> void:
	_apply()

func get_multiplier() -> float:
	return SPEEDS[_index]

func cycle_next() -> void:
	_index = (_index + 1) % SPEEDS.size()
	_apply()

func reset() -> void:
	_index = 0
	_apply()

func set_multiplier(mult: float) -> void:
	var i := SPEEDS.find(mult)
	if i == -1:
		push_warning("[GameSpeed] multiplier invalide: %s" % mult)
		return
	_index = i
	_apply()

func _apply() -> void:
	Engine.time_scale = SPEEDS[_index]
	speed_changed.emit(Engine.time_scale)
