# res://powers/freeze_zone.gd
extends Area2D

@onready var anim:  AnimatedSprite2D  = $AnimatedSprite2D
@onready var timer: Timer             = $Timer
@onready var cs:    CollisionShape2D  = $CollisionShape2D

# --- Effet de gameplay ---
@export var radius: float = 96.0
@export var slow_multiplier: float = 0.8   
@export var duration: float = 4.0

# --- VFX (9 sprites) ---
@export var vfx_frames: SpriteFrames
@export var vfx_animation: StringName = &"ice"   # nom de l’animation dans SpriteFrames
@export var vfx_base_diameter: float = 128.0     # diamètre (px) "référence" de tes images
@export var vfx_speed_scale: float = 1.0
@export var vfx_loop: bool = true
@export var vfx_fade_out: bool = true

var _id: String = ""

func _ready() -> void:
	_id = "freeze_%s" % str(get_instance_id())

	# ✅ Upgrade Labo : facteur de slow global
	# Niveau 0 = 0.8 (base), puis 0.6 / 0.4 / 0.0
	if Game and Game.has_method("get_freeze_strength_factor"):
		slow_multiplier = float(Game.get_freeze_strength_factor())
		# Sécurité : clamp [0..1]
		slow_multiplier = clampf(slow_multiplier, 0.0, 1.0)



	# Rayon de collision
	if cs and cs.shape is CircleShape2D:
		(cs.shape as CircleShape2D).radius = radius

	# Connexions
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Durée de vie
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(_on_timeout)
	timer.start()

	# --- VFX ---
	if anim:
		if vfx_frames:
			anim.sprite_frames = vfx_frames
		if anim.sprite_frames and anim.sprite_frames.has_animation(vfx_animation):
			# activer/désactiver la boucle sur la ressource
			anim.sprite_frames.set_animation_loop(vfx_animation, vfx_loop)
			anim.animation = vfx_animation
		anim.speed_scale = vfx_speed_scale
		anim.play()

		# Adapter l’échelle visuelle au rayon
		var factor: float = (radius * 2.0) / max(1.0, vfx_base_diameter)
		anim.scale = Vector2.ONE * factor

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Enemy") and body.has_method("add_speed_modifier"):
		body.add_speed_modifier(_id, slow_multiplier)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("Enemy") and body.has_method("remove_speed_modifier"):
		body.remove_speed_modifier(_id)

func _on_timeout() -> void:
	# Nettoyer ceux encore dedans
	for b in get_overlapping_bodies():
		if b.is_in_group("Enemy") and b.has_method("remove_speed_modifier"):
			b.remove_speed_modifier(_id)

	# Sortie visuelle propre (fondu) ou destruction directe
	if vfx_fade_out and anim:
		var t := create_tween()
		t.tween_property(anim, "modulate:a", 0.0, 0.20)
		t.finished.connect(queue_free, CONNECT_ONE_SHOT)
	else:
		queue_free()
