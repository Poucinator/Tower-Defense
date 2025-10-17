extends Node2D
@export var radius: float = 96.0

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.6, 0.8, 1.0, 0.25))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(0.6, 0.8, 1.0, 0.8))

func set_radius(r: float) -> void:
	radius = r
	queue_redraw()
