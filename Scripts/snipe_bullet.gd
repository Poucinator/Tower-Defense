# res://scene/tower/snipe_bullet.gd
extends CharacterBody2D

@export var speed: float  = 900.0
@export var damage: int   = 10
@export var lifetime: float = 2.0   # sécurité : s’auto-détruit après N secondes

var _dir: Vector2 = Vector2.ZERO

func fire_at(target_pos: Vector2, override_damage: int = -1) -> void:
	if override_damage >= 0:
		damage = override_damage
	_dir = (target_pos - global_position).normalized()
	set_physics_process(true)
	# Auto-destroy au cas où rien n’est touché
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	var collision := move_and_collide(_dir * speed * delta)
	if collision:
		var hit := collision.get_collider()
		var mob := _find_enemy_on(hit)
		if mob and mob.has_method("apply_damage"):
			mob.apply_damage(damage)
		queue_free()  # toujours supprimer la balle à l’impact

# Remonte la hiérarchie jusqu’à trouver un node dans le groupe "Enemy"
func _find_enemy_on(n: Object) -> Node:
	var node := n as Node
	while node:
		if node.is_in_group("Enemy"):
			return node
		node = node.get_parent()
	return null
