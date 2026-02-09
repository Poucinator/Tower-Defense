extends Node2D
class_name BuffAuraRing

@export var radius: float = 38.0
@export var width: float = 2.0
@export var alpha: float = 0.35

func _ready() -> void:
	z_index = 1000
	queue_redraw()

func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1, 1, 0, alpha), width, true)
