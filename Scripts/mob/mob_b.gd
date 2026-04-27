extends CharacterBody2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hp_bar: Range = $HealthBar

@export var speed: float = 100.0

# --- Modificateurs de vitesse (ralentissements, etc.) ---
# source_id -> multiplier (ex: 0.85 = -15% vitesse)
var _speed_mods: Dictionary = {}                # source_id -> float
var _speed_mod_timers: Dictionary = {}          # source_id -> Timer

@export var max_hp: int = 5
var hp: int

@export var gold_reward: int = 1
@export var damage: int = 1

# --- Combat vs Marine ---
@export var attack_damage: int = 1
@export var attack_interval: float = 0.8
var engaged_by: Node = null
var _attack_timer: Timer = null

signal died(mob: Node)
signal reached_end(mob: Node)

# Sert à détecter le sens d’avancée pour flip horizontal
var _prev_pos: Vector2 = Vector2.INF

var _is_dead := false


func _ready() -> void:
	if anim:
		anim.play("walk")

	hp = max_hp
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
		hp_bar.visible = false

	add_to_group("Enemy")

	# Orientation safe au spawn
	global_rotation = 0.0
	if anim:
		anim.flip_v = false
	scale.y = abs(scale.y)
	_prev_pos = global_position

	# Timer d'attaque
	_attack_timer = Timer.new()
	_attack_timer.one_shot = false
	_attack_timer.wait_time = attack_interval
	add_child(_attack_timer)
	_attack_timer.timeout.connect(_enemy_attack_tick)


func _process(delta: float) -> void:
	if _is_dead:
		return

	var follower := get_parent() as PathFollow2D
	if follower == null:
		return

	# Stop si engagé
	if engaged_by != null:
		if anim and anim.animation != "attack":
			anim.play("attack")
		return

	# Avancer sur le path
	follower.progress += get_effective_speed() * delta

	# Verrouille l’orientation monde
	global_rotation = 0.0
	scale.y = abs(scale.y)
	if anim:
		anim.flip_v = false

	# Flip horizontal suivant la direction
	var dx := global_position.x - _prev_pos.x
	if abs(dx) > 0.1 and anim:
		anim.flip_h = dx < 0.0
	_prev_pos = global_position

	# Fin de chemin
	var path := follower.get_parent() as Path2D
	if path:
		var length: float = path.curve.get_baked_length()
		if follower.progress >= length:
			if damage > 0 and "lose_health" in Game:
				Game.lose_health(damage)
			emit_signal("reached_end", self)
			queue_free()


# =========================================================
#                    SLOW API (NEW)
# =========================================================
# Convention (bluebullet):
# apply_slow(duration_sec, factor, source_id)
# factor < 1.0 = ralentit ; duration sec ; source_id sert à empiler proprement.
func apply_slow(duration_sec: float, factor: float, source_id: StringName) -> void:
	if _is_dead:
		return

	# garde-fous
	if duration_sec <= 0.0:
		return
	if factor >= 1.0:
		# pas un slow -> on retire éventuellement la source
		remove_speed_modifier(source_id)
		return

	# (Optionnel) garde-fou "achat au vaisseau" :
	# normalement inutile car BlueTower n'appelle apply_slow que si slow_enabled=true.
	# Si tu ajoutes plus tard un flag dans Game, tu peux le décommenter :
	# if Game and Game.has_method("is_gun_slow_unlocked") and not Game.is_gun_slow_unlocked():
	#     return

	add_speed_modifier(source_id, factor)

	# Timer par source : refresh la durée si on re-hit
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

	# (Optionnel) feedback visuel léger : petit flash bleu
	# _slow_flash()


func _slow_flash() -> void:
	if not anim:
		return
	var tw := create_tween()
	tw.tween_property(anim, "modulate", Color(0.7, 0.85, 1.0), 0.05)
	tw.tween_property(anim, "modulate", Color(1, 1, 1), 0.10)


# =========================================================
#                       Dégâts
# =========================================================
func apply_damage(amount: int) -> void:
	if _is_dead:
		return
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


func _die() -> void:
	if _is_dead:
		return
	_is_dead = true

	# Retire du groupe pour que les tours/marines cessent de le cibler
	remove_from_group("Enemy")

	# Désactive les collisions immédiatement
	set_collision_layer(0)
	set_collision_mask(0)

	# Nettoyage slows (timers + mods)
	_clear_speed_mods()

	# Libère le Marine engagé s'il y en a un
	if engaged_by and is_instance_valid(engaged_by) and engaged_by.has_method("release_target_from_enemy"):
		engaged_by.call("release_target_from_enemy", self)
	engaged_by = null

	# Empêche double mort / double gain
	if gold_reward > 0 and "add_gold" in Game:
		Game.add_gold(gold_reward)
	gold_reward = 0

	emit_signal("died", self)

	if anim:
		anim.play("dead")

	speed = 0

	if hp_bar:
		hp_bar.visible = false

	if _attack_timer:
		_attack_timer.stop()

	await get_tree().create_timer(2.6).timeout
	queue_free()


# =========================================================
#             Mouvement (modificateurs)
# =========================================================
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


# =========================================================
#           Engagement Marine ↔ Ennemi
# =========================================================
func request_engage(marine: Node) -> bool:
	if _is_dead:
		return false
	if engaged_by == null:
		engaged_by = marine
		_attack_timer.wait_time = attack_interval
		_attack_timer.start()
		if anim:
			anim.play("attack")
		return true
	return false


func release_engage(marine: Node) -> void:
	if engaged_by == marine:
		engaged_by = null
		if _attack_timer:
			_attack_timer.stop()
		if anim:
			anim.play("walk")


func _enemy_attack_tick() -> void:
	if _is_dead:
		return
	if engaged_by == null or not is_instance_valid(engaged_by):
		if _attack_timer:
			_attack_timer.stop()
		if anim:
			anim.play("walk")
		return
	if engaged_by.has_method("take_damage"):
		engaged_by.call("take_damage", attack_damage)
