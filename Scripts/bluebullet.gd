# res://scene/tower/bluebullet.gd
extends CharacterBody2D

@export var speed: float = 400.0
@export var lifetime: float = 2.0

# ✅ dégâts viennent de la tour
var damage: int = 1

# --- Prépa slow (désactivé par défaut) ---
var slow_enabled: bool = false
var slow_factor: float = 0.85
var slow_duration: float = 1.2
var slow_source_id: StringName = &"gun_slow"

var vel: Vector2 = Vector2.ZERO
var _has_fired: bool = false


func _ready() -> void:
	get_tree().create_timer(lifetime).timeout.connect(func():
		if is_inside_tree():
			queue_free()
	)


# ✅ API robuste : la tour peut configurer d'abord puis fire_at ensuite
func configure(
	new_speed: float,
	new_damage: int,
	p_slow_enabled: bool = false,
	p_slow_factor: float = 0.85,
	p_slow_duration: float = 1.2,
	p_slow_source_id: StringName = &"gun_slow"
) -> void:
	speed = new_speed
	damage = new_damage
	slow_enabled = p_slow_enabled
	slow_factor = p_slow_factor
	slow_duration = p_slow_duration
	slow_source_id = p_slow_source_id


# fire_at(target_pos) OU fire_at(target_pos, damage, speed, slow_enabled, slow_factor, slow_duration, slow_source_id)
func fire_at(
	target_pos: Vector2,
	new_damage: int = -1,
	new_speed: float = -1.0,
	p_slow_enabled: bool = false,
	p_slow_factor: float = 0.85,
	p_slow_duration: float = 1.2,
	p_slow_source_id: StringName = &"gun_slow"
) -> void:
	if new_speed > 0.0:
		speed = new_speed
	if new_damage >= 0:
		damage = new_damage

	# si on passe aussi les params slow ici, on écrase ceux de configure
	slow_enabled = p_slow_enabled
	slow_factor = p_slow_factor
	slow_duration = p_slow_duration
	slow_source_id = p_slow_source_id

	vel = (target_pos - global_position).normalized() * speed
	rotation = vel.angle()
	_has_fired = true


func set_direction(dir: Vector2, spd: float = -1.0) -> void:
	var s := (spd if spd > 0.0 else speed)
	vel = dir.normalized() * s
	rotation = vel.angle()
	_has_fired = true


func _physics_process(delta: float) -> void:
	if not _has_fired:
		return

	var hit := move_and_collide(vel * delta)
	if not hit:
		return

	var other := hit.get_collider()
	if other and other.is_in_group("Enemy"):
		# dégâts
		if other.has_method("apply_damage"):
			other.apply_damage(damage)

		# ✅ hook slow (quand tu l’implémentes côté enemy)
		# Convention : apply_slow(duration_sec, factor, source_id)
		if slow_enabled:
			if other.has_method("apply_slow"):
				other.call("apply_slow", slow_duration, slow_factor, slow_source_id)
			elif "speed_mult" in other:
				# fallback simple si tu as un multiplicateur
				other.speed_mult = min(float(other.speed_mult), slow_factor)

	queue_free()
