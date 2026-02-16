extends Node2D

# --- Références ---
@onready var hp_bar: Range = get_node_or_null("HealthBar")
@onready var aggro: Area2D = get_node_or_null("Aggro")

# IMPORTANT : ta sprite ne s'appelle pas Sprite2D, donc on la prend "au premier Sprite2D trouvé"
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var any_sprite: CanvasItem = sprite if sprite else (get_node_or_null("ChatGptImage18Sept_2025,110") as CanvasItem)

const EXPLOSION_SCENE: PackedScene = preload("res://fx/explosion_small.tscn")

@export var max_hp: int = 80
@export var engage_radius: float = 140.0

var hp: int
var is_dead := false

signal ship_destroyed(ship: Node)

const DBG_SHIP := true

func _ready() -> void:
	add_to_group("Ship")
	add_to_group("Drill") # (temp) tu avais ça pour tests

	# =========================
	# HP init (avec upgrade)
	# =========================
	var mult := 1.0
	if Game and Game.has_method("get_building_hp_multiplier"):
		mult = float(Game.get_building_hp_multiplier())

	var effective_max_hp := maxi(1, int(round(float(max_hp) * mult)))

	# IMPORTANT: on remplace max_hp runtime pour que le reste du script reste simple
	max_hp = effective_max_hp
	hp = max_hp

	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
		hp_bar.visible = true

	# Aggro (comme avant)
	# ...

	# Aggro (comme la foreuse)
	if aggro:
		aggro.monitoring = true
		aggro.monitorable = true

		var cs := aggro.get_node_or_null("CollisionShape2D")
		if cs and cs.shape is CircleShape2D:
			(cs.shape as CircleShape2D).radius = engage_radius

		if not aggro.body_entered.is_connected(_on_body_entered):
			aggro.body_entered.connect(_on_body_entered)
		if not aggro.body_exited.is_connected(_on_body_exited):
			aggro.body_exited.connect(_on_body_exited)

		if DBG_SHIP:
			print("[SHIP] Aggro ready. radius=", engage_radius,
				" layer=", aggro.collision_layer,
				" mask=", aggro.collision_mask)
	else:
		push_warning("[SHIP] Aggro introuvable : vérifie le nom 'Aggro'")

func _on_body_entered(b: Node) -> void:
	if DBG_SHIP:
		print("[SHIP] body_entered:", b.name, " Enemy=", b.is_in_group("Enemy"))

	if is_dead:
		return
	if not b.is_in_group("Enemy"):
		return
	if b.has_method("request_engage"):
		b.call("request_engage", self)

func _on_body_exited(_b: Node) -> void:
	pass

func take_damage(amount: int) -> void:
	if is_dead:
		return

	hp -= amount
	if hp_bar:
		hp_bar.value = clampi(hp, 0, max_hp)

	if hp <= 0:
		_die()
	else:
		_hit_flash()

func _hit_flash() -> void:
	if any_sprite:
		var tw := create_tween()
		tw.tween_property(any_sprite, "modulate", Color(1, 0.7, 0.7), 0.06)
		tw.tween_property(any_sprite, "modulate", Color(1, 1, 1), 0.06)

func _play_death_explosions() -> void:
	var offsets: Array[Vector2] = [
		Vector2(0, 0),
		Vector2(40, -10),
		Vector2(-40, -10),
		Vector2(20, 30),
		Vector2(-20, 30),
	]
	var delay := 0.35
	var radius := 140.0

	for offset in offsets:
		var e = EXPLOSION_SCENE.instantiate()
		if e:
			(get_parent() if get_parent() else self).add_child(e)
			e.global_position = global_position + offset
			if e.has_method("play"):
				e.call("play", radius)
		await get_tree().create_timer(delay).timeout

func _die() -> void:
	if is_dead:
		return
	is_dead = true

	# (libérer ennemis engagés si tu fais comme foreuse, etc...)

	# ✅ Explosions d'abord
	await _play_death_explosions()

	# ✅ Attente “cinématique” si tu veux
	await get_tree().create_timer(1.0).timeout

	# ✅ Seulement maintenant on déclenche la défaite
	emit_signal("ship_destroyed", self)
	queue_free()
