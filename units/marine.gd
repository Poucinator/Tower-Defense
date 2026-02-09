extends Node2D

# --- Références ---
@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var hp_bar: Range = get_node_or_null("HealthBar")
@onready var aggro: Area2D = get_node_or_null("Aggro")
@onready var muzzle: AnimatedSprite2D = get_node_or_null("MuzzleFlash")

# --- Réglages ---
@export var max_hp: int = 12
@export var attack_damage: int = 2
@export var attack_interval: float = 0.6
@export var engage_radius: float = 64.0
@export var support_radius: float = 140.0
@export var face_target: bool = true
@export var muzzle_offset: float = 5.0
@export var regen_per_sec: float = 1.0   # regen HP/sec

var barrack: Node = null

# --- Données caserne ---
var rally: Node2D = null
var slot_offset: Vector2 = Vector2.ZERO

# --- État interne ---
var hp: int
var engaged_enemy: Node = null
var _attack_timer: Timer
var is_dead: bool = false
var is_moving: bool = false

# --- Invincibilité ---
var _invincible_time_left: float = 0.0

# --- Regen interne ---
var _regen_buffer: float = 0.0   # cumule la regen partielle

# ============================================================
#                 BUFFS DÉGÂTS (Barracks aura)
# ============================================================
var _damage_mult_sources: Dictionary = {} # source_id -> float

func set_damage_buff(source_id: StringName, mult: float) -> void:
	# mult <= 1.0 => retire/neutralise cette source
	if mult <= 1.0:
		_damage_mult_sources.erase(source_id)
	else:
		_damage_mult_sources[source_id] = mult

func get_damage_mult() -> float:
	var m := 1.0
	for v in _damage_mult_sources.values():
		m *= float(v)
	return m


func _ready() -> void:
	add_to_group("Marine")
	hp = max_hp
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp

	$Area2D.input_pickable = true
	if not $Area2D.is_connected("input_event", Callable(self, "_on_input_event")):
		$Area2D.connect("input_event", Callable(self, "_on_input_event"))

	if aggro:
		var cs := aggro.get_node_or_null("CollisionShape2D")
		if cs and cs.shape is CircleShape2D:
			(cs.shape as CircleShape2D).radius = engage_radius
		aggro.body_entered.connect(_on_body_entered)
		aggro.body_exited.connect(_on_body_exited)

	_attack_timer = Timer.new()
	_attack_timer.one_shot = false
	_attack_timer.wait_time = attack_interval
	add_child(_attack_timer)
	_attack_timer.timeout.connect(_do_attack)

	if anim:
		anim.play("idle")

	if muzzle:
		muzzle.stop()
		muzzle.frame = 0
		muzzle.visible = false

	if rally:
		global_position = rally.global_position + slot_offset


func _process(delta: float) -> void:
	if is_dead:
		return

	# --- Mise à jour de l'invincibilité ---
	if _invincible_time_left > 0.0:
		_invincible_time_left = max(0.0, _invincible_time_left - delta)
		if _invincible_time_left == 0.0:
			_end_invincibility_visual()

	# --- regen auto ---
	if hp < max_hp and regen_per_sec > 0:
		_regen_buffer += regen_per_sec * delta
		if _regen_buffer >= 1.0:
			var gain = int(_regen_buffer)
			_regen_buffer -= gain
			hp = clampi(hp + gain, 0, max_hp)
			if hp_bar:
				hp_bar.value = hp

	if is_moving:
		return

	# --- Si la cible est morte ou supprimée, on arrête ---
	if engaged_enemy and not is_instance_valid(engaged_enemy):
		engaged_enemy = null

	var tgt := _pick_target()

	if face_target and tgt and anim:
		anim.flip_h = (tgt.global_position.x < global_position.x)
		if muzzle:
			muzzle.flip_h = anim.flip_h
			muzzle.position.x = (-abs(muzzle_offset) if anim.flip_h else abs(muzzle_offset))

	if tgt:
		if _attack_timer.is_stopped():
			_attack_timer.start()
		if anim and anim.animation != "attack":
			anim.play("attack")
	else:
		if not _attack_timer.is_stopped():
			_attack_timer.stop()
		if anim and anim.animation != "idle":
			anim.play("idle")
		if muzzle:
			muzzle.stop()
			muzzle.frame = 0
			muzzle.visible = false


# =========================================================
#             Sélection des cibles
# =========================================================
func _pick_target() -> Node2D:
	if engaged_enemy:
		return engaged_enemy

	var engaged_nearby := _enemies_in_radius(support_radius).filter(func(e):
		return ("engaged_by" in e) and e.engaged_by != null)
	if not engaged_nearby.is_empty():
		return _closest_enemy(engaged_nearby)

	var all := _enemies_in_radius(support_radius)
	return _closest_enemy(all) if not all.is_empty() else null


# =========================================================
#                     Aggro
# =========================================================
func _on_body_entered(b: Node) -> void:
	if not b.is_in_group("Enemy"):
		return

	# Connexion au signal de mort sans duplication
	if b.has_signal("died"):
		if not b.died.is_connected(_on_enemy_died):
			b.died.connect(_on_enemy_died)

	if engaged_enemy == null:
		if b.has_method("request_engage") and b.call("request_engage", self):
			engaged_enemy = b


func _on_body_exited(b: Node) -> void:
	# Déconnexion du signal quand l’ennemi sort de la zone
	if b.has_signal("died") and b.died.is_connected(_on_enemy_died):
		b.died.disconnect(_on_enemy_died)


# =========================================================
#                        Combat
# =========================================================
func _do_attack() -> void:
	var tgt := _pick_target()
	if tgt == null or not is_instance_valid(tgt):
		return

	# ✅ Dégâts = dégâts de base (export) * buffs (Barracks etc.)
	var dmg := int(round(float(attack_damage) * get_damage_mult()))

	if tgt.has_method("apply_damage"):
		tgt.call("apply_damage", dmg)

	if muzzle:
		muzzle.visible = true
		muzzle.play("flash")


# =========================================================
#                 Dégâts subis / mort
# =========================================================
func take_damage(amount: int) -> void:
	# --- Invincibilité : aucun dégât ---
	if _invincible_time_left > 0.0:
		return

	hp -= amount
	if hp_bar:
		hp_bar.value = clampi(hp, 0, max_hp)
	if hp <= 0:
		_die()
	else:
		_hit_flash()


func _hit_flash() -> void:
	if anim:
		var t := create_tween()
		t.tween_property(anim, "modulate", Color(1, 0.6, 0.6), 0.06)
		t.tween_property(anim, "modulate", Color(1, 1, 1), 0.06)


func _die() -> void:
	is_dead = true
	_attack_timer.stop()

	if engaged_enemy and is_instance_valid(engaged_enemy) and engaged_enemy.has_method("release_engage"):
		engaged_enemy.call("release_engage", self)
	engaged_enemy = null

	if muzzle:
		muzzle.stop()
		muzzle.frame = 0
		muzzle.visible = false

	if anim:
		anim.play("dead")

	# informer la caserne avant destruction
	if barrack and barrack.has_method("notify_marine_dead"):
		barrack.notify_marine_dead(self)

	await get_tree().create_timer(0.8).timeout
	queue_free()


func release_target_from_enemy(enemy: Node) -> void:
	if enemy == engaged_enemy:
		engaged_enemy = null


# =========================================================
#                 Gestion mort ennemi
# =========================================================
func _on_enemy_died(dead_enemy: Node) -> void:
	if engaged_enemy == dead_enemy:
		engaged_enemy = null
		if anim:
			anim.play("idle")
		if not _attack_timer.is_stopped():
			_attack_timer.stop()
		if muzzle:
			muzzle.stop()
			muzzle.visible = false


# =========================================================
#                 Outils utilitaires
# =========================================================
func _enemies_in_radius(radius: float) -> Array[Node2D]:
	var out: Array[Node2D] = []
	var r2 := radius * radius
	for e in get_tree().get_nodes_in_group("Enemy"):
		if e == null or not is_instance_valid(e):
			continue
		if global_position.distance_squared_to(e.global_position) <= r2:
			out.append(e)
	return out


func _closest_enemy(enemies: Array[Node2D]) -> Node2D:
	var best: Node2D = null
	var best_d2 := INF
	for e in enemies:
		var d2 := global_position.distance_squared_to(e.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = e
	return best


# =========================================================
#              Sélection via clic
# =========================================================
func _on_input_event(_vp, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if barrack and barrack.has_method("select_group"):
			barrack.select_group()


# =========================================================
#              Invincibilité temporaire
# =========================================================
func set_invincible_for(duration: float) -> void:
	# Si on enchaîne plusieurs heals, on garde le plus long
	_invincible_time_left = max(_invincible_time_left, duration)
	_start_invincibility_visual()


func _start_invincibility_visual() -> void:
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.modulate = Color(1, 1, 1, 0.5)  # semi-transparent


func _end_invincibility_visual() -> void:
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.modulate = Color(1, 1, 1, 1.0)  # normal
