# res://scene/tower/bluebullet.gd
extends CharacterBody2D

@export var speed: float = 400.0      # vitesse de déplacement
@export var damage: int = 1           # dégâts infligés à l'ennemi
@export var lifetime: float = 2.0     # durée de vie max (sec)

var vel: Vector2 = Vector2.ZERO       # vecteur vitesse de la balle

func _ready() -> void:
	# auto-destruction si la balle ne touche rien
	get_tree().create_timer(lifetime).timeout.connect(func():
		if is_inside_tree():
			queue_free()
	)

# --- Lancement vers une position précise (utilisé par la tour) ---
func fire_at(target_pos: Vector2) -> void:
	vel = (target_pos - global_position).normalized() * speed
	rotation = vel.angle()

# --- Alternative : donner directement une direction (optionnelle) ---
func set_direction(dir: Vector2, spd: float = -1.0) -> void:
	var s := (spd if spd > 0.0 else speed)
	vel = dir.normalized() * s
	rotation = vel.angle()

func _physics_process(delta: float) -> void:
	var hit := move_and_collide(vel * delta)
	if hit:
		var other := hit.get_collider()
		if other and other.is_in_group("Enemy"):
			if other.has_method("apply_damage"):
				other.apply_damage(damage)
			# sinon, on pourrait gérer un champ "hp" sur l'ennemi
		queue_free()  # on détruit la balle quoi qu'il arrive au contact
