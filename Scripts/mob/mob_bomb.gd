extends CharacterBody2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hp_bar: Range = $HealthBar

@export var speed: float = 100.0

# ======================================================
#          MODIFICATEURS DE VITESSE (slow, etc.)
# ======================================================
# source_id -> multiplier (ex: 0.85 = -15% vitesse)
var _speed_mods: Dictionary = {}
var _speed_mod_timers: Dictionary = {}

@export var max_hp: int = 5
var hp: int

@export var gold_reward: int = 1
@export var damage: int = 1

# ======================================================
#                SELF-DESTRUCT / EXPLOSION
# ======================================================
@export var explosion_area_path: NodePath = NodePath("ExplosionArea")
@export var explosion_damage: int = 2
@export var explosion_trigger_delay: float = 0.35
@export var explosion_cleanup_delay: float = 0.25
@export var give_gold_on_self_destruct: bool = false

var explosion_area: Area2D = null

# --- Combat vs Marine ---
# Conservé pour compatibilité de structure, mais ce mob n'utilise
# plus une attaque répétée : il s'autodétruit au contact.
@export var attack_damage: int = 1
@export var attack_interval: float = 0.8
var engaged_by: Node = null
var _attack_timer: Timer = null

signal died(mob: Node)
signal reached_end(mob: Node)

# --- Suivi du déplacement ---
var _prev_pos: Vector2 = Vector2.INF
var _current_dir: String = "down" # "up", "down", "left", "right"

var _is_dead: bool = false
var _is_self_destructing: bool = false
var _has_exploded: bool = false


# ======================================================
#                       READY
# ======================================================
func _ready() -> void:
	if anim:
		anim.play("walk_down")
		if anim.sprite_frames:
			var names := anim.sprite_frames.get_animation_names()
			print("[MobExplosif] Animations trouvées :", names)

	hp = max_hp
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
		hp_bar.visible = false

	add_to_group("Enemy")

	global_rotation = 0.0
	if anim:
		anim.flip_v = false
	scale.y = abs(scale.y)
	_prev_pos = global_position

	explosion_area = get_node_or_null(explosion_area_path) as Area2D
	if explosion_area == null:
		push_warning("[MobExplosif] ExplosionArea introuvable. Path attendu : %s" % explosion_area_path)
	else:
		explosion_area.monitoring = true
		explosion_area.monitorable = true

	_attack_timer = Timer.new()
	_attack_timer.one_shot = false
	_attack_timer.wait_time = attack_interval
	add_child(_attack_timer)
	_attack_timer.timeout.connect(_enemy_attack_tick)


# ======================================================
#                      PROCESS
# ======================================================
func _process(delta: float) -> void:
	if _is_dead or _is_self_destructing:
		return

	var follower := get_parent() as PathFollow2D
	if follower == null:
		return

	# Si un marine engage ce mob, on déclenche la self-destruction
	if engaged_by != null:
		_start_self_destruct()
		return

	# Avancer sur le path
	follower.progress += get_effective_speed() * delta

	# Verrouille orientation monde
	global_rotation = 0.0
	scale.y = abs(scale.y)
	if anim:
		anim.flip_v = false

	# Déterminer la direction du déplacement
	var move_dir := (global_position - _prev_pos).normalized()
	if move_dir.length() > 0.05:
		var dir_name := _get_dir_from_vector(move_dir)
		if dir_name != _current_dir:
			_current_dir = dir_name
			_play_anim("walk")

	_prev_pos = global_position

	# Fin du chemin
	var path := follower.get_parent() as Path2D
	if path:
		var length: float = path.curve.get_baked_length()
		if follower.progress >= length:
			if damage > 0 and "lose_health" in Game:
				Game.lose_health(damage)
			emit_signal("reached_end", self)
			queue_free()


# ======================================================
#                    SLOW API
# ======================================================
func apply_slow(duration_sec: float, factor: float, source_id: StringName) -> void:
	if _is_dead or _is_self_destructing:
		return
	if duration_sec <= 0.0:
		return
	if factor >= 1.0:
		remove_speed_modifier(source_id)
		return

	add_speed_modifier(source_id, factor)

	var t: Timer = _speed_mod_timers.get(source_id, null)
	if t == null or not is_instance_valid(t):
		t = Timer.new()
		t.one_shot = true
		add_child(t)
		_speed_mod_timers[source_id] = t
		t.timeout.connect(func():
			remove_speed_modifier(source_id)
			if _speed_mod_timers.has(source_id):
				_speed_mod_timers.erase(source_id)
			if t and is_instance_valid(t):
				t.queue_free()
		)

	t.stop()
	t.wait_time = duration_sec
	t.start()


func _slow_flash() -> void:
	if not anim:
		return
	var tw := create_tween()
	tw.tween_property(anim, "modulate", Color(0.7, 0.85, 1.0), 0.05)
	tw.tween_property(anim, "modulate", Color(1, 1, 1), 0.10)


# ======================================================
#             DIRECTION ET ANIMATIONS
# ======================================================
func _get_dir_from_vector(vec: Vector2) -> String:
	if abs(vec.x) > abs(vec.y):
		return "right" if vec.x > 0 else "left"
	else:
		return "down" if vec.y > 0 else "up"


func _play_anim(base_name: String) -> void:
	if anim == null or anim.sprite_frames == null:
		return

	var frames := anim.sprite_frames
	var anim_name := "%s_%s" % [base_name, _current_dir]

	if frames.has_animation(anim_name):
		anim.play(anim_name)
	elif frames.has_animation(base_name):
		anim.play(base_name)
	else:
		var names := anim.sprite_frames.get_animation_names()
		push_warning("Animation '%s' or '%s' manquante sur %s. Trouvées : %s"
			% [anim_name, base_name, name, ", ".join(names)])


# ======================================================
#                     DÉGÂTS
# ======================================================
func apply_damage(amount: int) -> void:
	if _is_dead:
		return

	# Important : si le mob meurt avant d'exploser, il ne doit pas faire son AOE.
	hp -= amount

	if hp_bar:
		hp_bar.visible = true
		hp_bar.value = clampi(hp, 0, max_hp)

	_hit_flash()

	if hp <= 0:
		_die()


func _hit_flash() -> void:
	if anim:
		var tw := create_tween()
		tw.tween_property(anim, "modulate", Color(1, 0.5, 0.5), 0.06)
		tw.tween_property(anim, "modulate", Color(1, 1, 1), 0.06)


# ======================================================
#             SELF-DESTRUCT / EXPLOSION
# ======================================================
func _start_self_destruct() -> void:
	if _is_dead or _is_self_destructing or _has_exploded:
		return

	_is_self_destructing = true

	# On le retire du ciblage ennemi normal pour éviter les comportements bizarres
	remove_from_group("Enemy")

	# Il ne se déplace plus
	speed = 0.0

	# On coupe la collision physique pour éviter les blocages/ré-engagements
	set_collision_layer(0)
	set_collision_mask(0)

	# Stoppe les slows et timers inutiles
	_clear_speed_mods()
	if _attack_timer:
		_attack_timer.stop()

	# Cache la barre de vie pendant la séquence d'explosion
	if hp_bar:
		hp_bar.visible = false

	# Animation d'attaque directionnelle (attack_up/down/left/right)
	_play_anim("attack")

	_self_destruct_sequence()


func _self_destruct_sequence() -> void:
	await get_tree().create_timer(explosion_trigger_delay).timeout

	# Le mob a pu mourir entre-temps
	if _is_dead or _has_exploded:
		return

	_explode()

	await get_tree().create_timer(explosion_cleanup_delay).timeout

	# Libère le marine qui l'avait engagé
	_release_engaged_marine()

	# Récompense optionnelle
	if give_gold_on_self_destruct and gold_reward > 0 and "add_gold" in Game:
		Game.add_gold(gold_reward)
	gold_reward = 0

	emit_signal("died", self)
	queue_free()


func _explode() -> void:
	if _is_dead or _has_exploded:
		return

	_has_exploded = true

	var victims := _collect_explosion_targets()
	for target in victims:
		if target and is_instance_valid(target) and target.has_method("take_damage"):
			target.call("take_damage", explosion_damage)


func _collect_explosion_targets() -> Array[Node]:
	var results: Array[Node] = []
	var unique := {}

	if explosion_area == null:
		push_warning("[MobExplosif] Impossible d'appliquer les dégâts de zone : ExplosionArea introuvable.")
		return results

	# Corps dans l'Area2D
	for body in explosion_area.get_overlapping_bodies():
		var target := _resolve_damage_target(body)
		if target != null and not unique.has(target):
			unique[target] = true
			results.append(target)

	# Areas dans l'Area2D (au cas où tes marines portent un hitbox Area2D)
	for area in explosion_area.get_overlapping_areas():
		var target := _resolve_damage_target(area)
		if target != null and not unique.has(target):
			unique[target] = true
			results.append(target)

	return results


func _resolve_damage_target(candidate: Node) -> Node:
	if candidate == null or not is_instance_valid(candidate):
		return null

	# Cas direct : le node touché sait prendre des dégâts
	if candidate.has_method("take_damage"):
		return candidate

	# Cas fréquent : on touche une Area2D/CollisionShape dont le parent est le marine
	var p := candidate.get_parent()
	if p and is_instance_valid(p) and p.has_method("take_damage"):
		return p

	return null


func _release_engaged_marine() -> void:
	if engaged_by and is_instance_valid(engaged_by) and engaged_by.has_method("release_target_from_enemy"):
		engaged_by.call("release_target_from_enemy", self)
	engaged_by = null


# ======================================================
#                    MORT DU MOB
# ======================================================
func _die() -> void:
	if _is_dead:
		return

	_is_dead = true
	_is_self_destructing = false

	# Retire le mob du groupe pour qu'il ne soit plus ciblé
	remove_from_group("Enemy")

	# Désactive toute collision
	set_collision_layer(0)
	set_collision_mask(0)

	# Nettoyage slows
	_clear_speed_mods()

	# Libère le marine engagé
	_release_engaged_marine()

	# Donne l'or une seule fois
	if gold_reward > 0 and "add_gold" in Game:
		Game.add_gold(gold_reward)
	gold_reward = 0

	# Envoie le signal de mort
	emit_signal("died", self)

	# Animation de mort (et surtout PAS d'explosion)
	_play_anim("dead")
	speed = 0.0

	# Cache la barre de vie
	if hp_bar:
		hp_bar.visible = false

	# Stoppe toute attaque en cours
	if _attack_timer:
		_attack_timer.stop()

	await get_tree().create_timer(2.6).timeout
	queue_free()


# ======================================================
#                MOUVEMENT ET MODIFICATEURS
# ======================================================
func get_effective_speed() -> float:
	var mult := 1.0
	for v in _speed_mods.values():
		mult *= float(v)
	return speed * mult


func add_speed_modifier(id: StringName, multiplier: float) -> void:
	_speed_mods[id] = multiplier


func remove_speed_modifier(id: StringName) -> void:
	_speed_mods.erase(id)


func _clear_speed_mods() -> void:
	_speed_mods.clear()
	for t in _speed_mod_timers.values():
		if t and is_instance_valid(t):
			t.stop()
			t.queue_free()
	_speed_mod_timers.clear()


# ======================================================
#              ENGAGEMENT MARINE ↔ ENNEMI
# ======================================================
func request_engage(marine: Node) -> bool:
	if _is_dead or _is_self_destructing or _has_exploded:
		return false

	if engaged_by == null:
		engaged_by = marine
		return true

	return false


func release_engage(marine: Node) -> void:
	if engaged_by == marine and not _is_self_destructing:
		engaged_by = null
		_play_anim("walk")


func _enemy_attack_tick() -> void:
	# Ce mob n'utilise pas l'attaque répétée.
	# On garde la fonction pour éviter toute régression structurelle,
	# mais elle ne fait rien volontairement.
	return
