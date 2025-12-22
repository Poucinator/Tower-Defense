extends CharacterBody2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hp_bar: Range = $HealthBar

@export var speed: float = 100.0
var _speed_mods := {}

@export var max_hp: int = 5
var hp: int

@export var gold_reward: int = 1
@export var damage: int = 1

# --- Combat vs Marine ---
@export var attack_damage: int = 1
@export var attack_interval: float = 0.8
var engaged_by: Node = null
var _attack_timer: Timer = null

# --- Spécifique volant ---
@export var is_flying: bool = true  # 👈 flag utilisé par les tours pour filtrer les cibles

signal died(mob: Node)
signal reached_end(mob: Node)

# --- Suivi du déplacement ---
var _prev_pos: Vector2 = Vector2.INF
var _current_dir: String = "down"  # "up", "down", "left", "right"


# ======================================================
#                       READY
# ======================================================
func _ready() -> void:
	if anim:
		anim.play("walk_down")
		# --- Debug : liste les animations disponibles ---
		var names := anim.sprite_frames.get_animation_names()
		print("[MobFlying] Animations trouvées :", names)

	hp = max_hp
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
		hp_bar.visible = false

	add_to_group("Enemy")
	add_to_group("FlyingEnemy")  # 👈 optionnel, pratique si tu veux un groupe pour les vols

	global_rotation = 0.0
	if anim:
		anim.flip_v = false
	scale.y = abs(scale.y)
	_prev_pos = global_position

	_attack_timer = Timer.new()
	_attack_timer.one_shot = false
	_attack_timer.wait_time = attack_interval
	add_child(_attack_timer)
	_attack_timer.timeout.connect(_enemy_attack_tick)


# ======================================================
#                      PROCESS
# ======================================================
func _process(delta: float) -> void:
	var follower := get_parent() as PathFollow2D
	if follower == null:
		return

	# Stop si engagé
	if engaged_by != null:
		if anim and not String(anim.animation).begins_with("attack"):
			_play_anim("attack")
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
#                    MORT DU MOB
# ======================================================
var _is_dead := false


func _die() -> void:
	if _is_dead:
		return
	_is_dead = true

	# Retire le mob du groupe pour qu'il ne soit plus ciblé
	remove_from_group("Enemy")
	remove_from_group("FlyingEnemy")

	# Désactive toute collision
	set_collision_layer(0)
	set_collision_mask(0)

	# Libère le marine engagé
	if engaged_by and is_instance_valid(engaged_by) and engaged_by.has_method("release_target_from_enemy"):
		engaged_by.call("release_target_from_enemy", self)
	engaged_by = null

	# Donne l'or une seule fois
	if gold_reward > 0 and "add_gold" in Game:
		Game.add_gold(gold_reward)
	gold_reward = 0

	# Envoie le signal de mort (pour effets ou score)
	emit_signal("died", self)

	# Animation de mort
	_play_anim("dead")
	speed = 0

	# Cache la barre de vie
	if hp_bar:
		hp_bar.visible = false

	# Stoppe toute attaque en cours
	if _attack_timer:
		_attack_timer.stop()

	# Attend la fin de l'animation avant destruction
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


func add_speed_modifier(id: String, multiplier: float) -> void:
	_speed_mods[id] = multiplier


func remove_speed_modifier(id: String) -> void:
	_speed_mods.erase(id)


# ======================================================
#              ENGAGEMENT MARINE ↔ ENNEMI
# ======================================================
func request_engage(marine: Node) -> bool:
	if engaged_by == null:
		engaged_by = marine
		_attack_timer.wait_time = attack_interval
		_attack_timer.start()
		_play_anim("attack")
		return true
	return false


func release_engage(marine: Node) -> void:
	if engaged_by == marine:
		engaged_by = null
		if _attack_timer:
			_attack_timer.stop()
		_play_anim("walk")


func _enemy_attack_tick() -> void:
	if engaged_by == null or not is_instance_valid(engaged_by):
		if _attack_timer:
			_attack_timer.stop()
		_play_anim("walk")
		return
	if engaged_by.has_method("take_damage"):
		engaged_by.call("take_damage", attack_damage)
