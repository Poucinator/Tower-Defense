extends Node2D

# --- Références ---
@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var hp_bar: Range          = get_node_or_null("HealthBar")
@onready var aggro: Area2D          = get_node_or_null("Aggro")

const EXPLOSION_SCENE: PackedScene = preload("res://fx/explosion_small.tscn")


# --- Réglages ---
@export var max_hp: int = 40
@export var engage_radius: float = 96.0  # rayon dans lequel les mobs vont l'engager

var hp: int
var is_dead: bool = false

signal drill_destroyed(drill: Node)


func _ready() -> void:
	add_to_group("Drill")

	hp = max_hp
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
		hp_bar.visible = true

	# Config de la zone d’aggro
	if aggro:
		var cs := aggro.get_node_or_null("CollisionShape2D")
		if cs and cs.shape is CircleShape2D:
			(cs.shape as CircleShape2D).radius = engage_radius

		if not aggro.body_entered.is_connected(_on_body_entered):
			aggro.body_entered.connect(_on_body_entered)
		if not aggro.body_exited.is_connected(_on_body_exited):
			aggro.body_exited.connect(_on_body_exited)

	if anim:
		# Mets le nom d’anim que tu veux : "idle", "work", etc.
		anim.play("idle")


# =========================================================
#                 Dégâts subis / mort
# =========================================================
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
	if anim:
		var t := create_tween()
		t.tween_property(anim, "modulate", Color(1, 0.7, 0.7), 0.06)
		t.tween_property(anim, "modulate", Color(1, 1, 1), 0.06)


# --- Séquence d'explosions de mort ---
func _play_death_explosions() -> void:
	# Offsets des explosions autour de la foreuse
	var offsets: Array[Vector2] = [
		Vector2(0, 0),      # centre
		Vector2(0, 20),     # un peu en dessous
		Vector2(18, -10),   # à droite / légèrement au-dessus
		Vector2(-18, -10)   # à gauche / légèrement au-dessus
	]

	var delay := 0.5       # temps entre chaque explosion
	var radius := 80.0     # taille visuelle (tu peux ajuster)

	for offset in offsets:
		var e = EXPLOSION_SCENE.instantiate()
		if e:
			# même parent que la foreuse
			if get_parent():
				get_parent().add_child(e)
			else:
				add_child(e)  # fallback

			e.global_position = global_position + offset

			# Lancer l'explosion (script explosion.gd)
			if e.has_method("play"):
				e.call("play", radius)

		# Attendre avant la prochaine explosion
		await get_tree().create_timer(delay).timeout


func _die() -> void:
	if is_dead:
		return
	is_dead = true

	# Libérer les ennemis qui étaient en train de l’attaquer
	for e in get_tree().get_nodes_in_group("Enemy"):
		if e == null or not is_instance_valid(e):
			continue
		# Si le mob a la méthode release_engage, on lui dit d’arrêter d’attaquer la foreuse
		if e.has_method("release_engage") and "engaged_by" in e and e.engaged_by == self:
			e.call("release_engage", self)

	# Animation de mort de la foreuse
	if anim:
		anim.play("dead")

	emit_signal("drill_destroyed", self)

	# 🔥 Rafale de 4 explosions
	await _play_death_explosions()

	# Puis destruction de la foreuse
	queue_free()


# =========================================================
#                 Gestion des ennemis proches
# =========================================================
func _on_body_entered(b: Node) -> void:
	if is_dead:
		return
	if not b.is_in_group("Enemy"):
		return

	# On demande au mob de nous "engager", exactement comme un Marine.
	# S’il est déjà engagé ailleurs, son request_engage retournera false
	# mais on s’en fiche, on n’a pas besoin du résultat ici.
	if b.has_method("request_engage"):
		b.call("request_engage", self)


func _on_body_exited(_b: Node) -> void:
	# On ne fait rien ici :
	# les mobs engagés sont de toute façon figés sur leur PathFollow2D
	# tant qu’ils sont en train d’attaquer la foreuse.
	pass
