extends CharacterBody2D

# --- Réglages de gameplay ---
@export_range(100.0, 2000.0, 10.0, "or_greater", "suffix:px/s") var speed: float = 420.0
@export_range(1, 999, 1, "or_greater") var damage: int = 30
@export_range(8.0, 512.0, 1.0, "or_greater", "suffix:px") var splash_radius: float = 64.0
@export_range(0.0, 4.0, 0.1, "or_greater") var splash_falloff: float = 0.0
@export_range(0.2, 10.0, 0.1, "or_greater", "suffix:s") var lifetime: float = 3.0
@export_range(0.0, 64.0, 1.0, "suffix:px") var proximity_trigger: float = 6.0

# --- Orientation ---
@export var rotation_offset_deg: float = 0.0

# --- FX ---
const EXPLOSION_SCN := preload("res://fx/explosion_small.tscn")

# --- État interne ---
var _direction: Vector2 = Vector2.ZERO
var _time_alive: float = 0.0
var _target_pos: Vector2 = Vector2.ZERO
var _armed: bool = false
var _damage_override: int = -1
var _radius_override: float = -1.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null

func _ready() -> void:
	if anim:
		anim.play("fly")

func fire_at(target_pos: Vector2, damage_override: int = -1, radius_override: float = -1.0) -> void:
	_target_pos = target_pos
	_damage_override = damage_override
	_radius_override = radius_override

	_direction = (_target_pos - global_position).normalized()
	rotation = _direction.angle() + deg_to_rad(rotation_offset_deg)
	_armed = true

func _physics_process(delta: float) -> void:
	if not _armed:
		return

	velocity = _direction * speed
	var collision := move_and_collide(velocity * delta)
	if collision:
		_explode()
		return

	if proximity_trigger > 0.0:
		var dist: float = global_position.distance_to(_target_pos)
		if dist <= proximity_trigger:
			_explode()
			return

	_time_alive += delta
	if _time_alive >= lifetime:
		_explode()

func _explode() -> void:
	# --------- DÉGÂTS DE ZONE ----------
	var dmg: int = (_damage_override if _damage_override >= 0 else damage)
	var radius: float = (_radius_override if _radius_override >= 0.0 else splash_radius)

	var shape := CircleShape2D.new()
	shape.radius = radius

	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, global_position)
	params.collide_with_areas = true
	params.collide_with_bodies = true

	var space := get_world_2d().direct_space_state
	var hits: Array[Dictionary] = space.intersect_shape(params, 64)

	for hit in hits:
		var n: Node = hit.get("collider") as Node
		if n == null:
			continue

		var enemy: Node2D = null
		if n.is_in_group("Enemy"):
			enemy = n
		elif n.get_parent() and n.get_parent().is_in_group("Enemy"):
			enemy = n.get_parent() as Node2D

		if enemy:
			var dist: float = (enemy.global_position - global_position).length()
			if dist <= radius:
				var ratio: float = 1.0
				if splash_falloff > 0.0:
					var lin: float = clamp(1.0 - (dist / radius), 0.0, 1.0)
					ratio = pow(lin, splash_falloff)
				var final_damage: int = int(round(float(dmg) * ratio))
				if final_damage > 0 and enemy.has_method("apply_damage"):
					enemy.call("apply_damage", final_damage)

	# --------- FX D’EXPLOSION ----------
	var ex := EXPLOSION_SCN.instantiate()
	ex.global_position = global_position

	# IMPORTANT : ajouter à l'arbre AVANT d'appeler play()
	get_tree().current_scene.add_child(ex)  # ou get_parent().add_child(ex)

	if ex.has_method("play"):
		ex.play(radius)

	queue_free()
