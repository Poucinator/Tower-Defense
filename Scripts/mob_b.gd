extends CharacterBody2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hp_bar: Range = $HealthBar

@export var speed: float = 100.0
var _speed_mods := {}                            # id -> multiplier

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

# -------- Dégâts --------
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

func _die() -> void:
	set_collision_layer(0)
	set_collision_mask(0)
	# libère le Marine engagé
	if engaged_by and is_instance_valid(engaged_by) and engaged_by.has_method("release_target_from_enemy"):
		engaged_by.call("release_target_from_enemy", self)
	engaged_by = null

	# Empêche double mort / double gain
	if gold_reward > 0 and "add_gold" in Game:
		Game.add_gold(gold_reward)
	gold_reward = 0

	emit_signal("died", self)

	# Animation de mort
	if anim:
		anim.play("dead")

	speed = 0

	# Cache la barre de vie
	if hp_bar:
		hp_bar.visible = false


	# Arrête ses attaques éventuelles
	if _attack_timer:
		_attack_timer.stop()

	# Attend la fin de l’animation avant de supprimer
	await get_tree().create_timer(2.6).timeout
	queue_free()


# -------- Mouvement (modificateurs) --------
func get_effective_speed() -> float:
	var mult := 1.0
	for v in _speed_mods.values():
		mult *= float(v)
	return speed * mult

func add_speed_modifier(id: String, multiplier: float) -> void:
	_speed_mods[id] = multiplier

func remove_speed_modifier(id: String) -> void:
	_speed_mods.erase(id)

# -------- Engagement Marine ↔ Ennemi --------
func request_engage(marine: Node) -> bool:
	if engaged_by == null:
		engaged_by = marine
		print("[Mob] engaged_by set to ", marine.name, " id=", marine.get_instance_id())
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
	if engaged_by == null or not is_instance_valid(engaged_by):
		if _attack_timer:
			_attack_timer.stop()
		if anim:
			anim.play("walk")
		return
	if engaged_by.has_method("take_damage"):
		engaged_by.call("take_damage", attack_damage)
