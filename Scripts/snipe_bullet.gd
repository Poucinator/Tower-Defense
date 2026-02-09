# res://scene/tower/snipe_bullet.gd
extends CharacterBody2D

@export var speed: float  = 900.0
@export var lifetime: float = 2.0   # sécurité : s’auto-détruit après N secondes

# ✅ dégâts viennent de la tour
var damage: int = 10

# ✅ Break Snipe : ennemis supplémentaires touchés
var extra_hits: int = 0

var _dir: Vector2 = Vector2.ZERO
var _life_timer_started := false

# ✅ combien de cibles restantes à toucher au total (1 + extra_hits)
var _hits_left: int = 1

# Pour éviter de retoucher la même cible
var _hit_ids := {}

# ✅ API : la tour peut configurer (speed, damage, extra_hits) puis fire_at
func configure(new_speed: float, new_damage: int, new_extra_hits: int = 0) -> void:
	speed = new_speed
	damage = new_damage
	extra_hits = max(0, new_extra_hits)
	_hits_left = 1 + extra_hits


# ✅ Signature compatible + étendue :
# fire_at(target_pos, override_damage=-1, override_speed=-1)
func fire_at(target_pos: Vector2, override_damage: int = -1, override_speed: float = -1.0) -> void:
	if override_damage >= 0:
		damage = override_damage
	if override_speed > 0.0:
		speed = override_speed

	# direction FIXE : la balle continue en ligne droite
	_dir = (target_pos - global_position).normalized()
	set_physics_process(true)

	# Auto-destroy au cas où rien n’est touché (une seule fois)
	if not _life_timer_started:
		_life_timer_started = true
		get_tree().create_timer(lifetime).timeout.connect(func():
			if is_inside_tree():
				queue_free()
		)


func _physics_process(delta: float) -> void:
	var collision := move_and_collide(_dir * speed * delta)
	if not collision:
		return

	var hit := collision.get_collider()
	var mob := _find_enemy_on(hit)

	# Si on tape un ennemi
	if mob:
		# Evite double hit sur la même cible (frames consécutives)
		var id := mob.get_instance_id()
		if _hit_ids.has(id):
			_ignore_collider(hit)
			return

		# ⚠️ Ignore les ennemis volants (traverse sans consommer)
		if ("is_flying" in mob) and mob.is_flying:
			_hit_ids[id] = true
			_ignore_collider(hit)
			return

		# Hit valide
		_hit_ids[id] = true
		if mob.has_method("apply_damage"):
			mob.apply_damage(damage)

		_hits_left -= 1
		if _hits_left <= 0:
			queue_free()
			return

		# Il reste des hits => on traverse
		_ignore_collider(hit)
		return

	# Sinon (mur, décor, autre body) => on détruit
	queue_free()


func _ignore_collider(hit: Object) -> void:
	# Évite de se re-collider sur le même objet
	var co := hit as CollisionObject2D
	if co:
		add_collision_exception_with(co)

	# Petit push vers l'avant pour sortir du contact
	global_position += _dir * 2.0


# Remonte la hiérarchie jusqu’à trouver un node dans le groupe "Enemy"
func _find_enemy_on(n: Object) -> Node:
	var node := n as Node
	while node:
		if node.is_in_group("Enemy"):
			return node
		node = node.get_parent()
	return null
