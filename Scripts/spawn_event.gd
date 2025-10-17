# res://scripts/spawn_event.gd
extends Resource
class_name SpawnEvent

@export var path: NodePath
@export var delay: float = 0.0
@export var wait_clear: bool = false
