extends Node2D

@onready var anim:  AnimatedSprite2D    = $AnimatedSprite2D
@onready var sfx:   AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var fx:    GPUParticles2D      = $GPUParticles2D if has_node("GPUParticles2D") else null
@onready var flash: Light2D             = $DirectionalLight2D        if has_node("DirectionalLight2D") else null

@export var auto_free: bool = true
@export var base_scale: float = 1.0
@export var flash_energy: float = 0.8
@export var sfx_random_pitch: float = 0.1

func play(radius: float = 64.0) -> void:
	# Taille visuelle en fonction du rayon
	var k: float = clamp(radius / 64.0, 0.6, 2.5)
	self.scale = Vector2.ONE * base_scale * k  # éviter le warning "scale shadowing"

	# Si play() est appelé avant l'ajout à l'arbre, attendre
	if not is_inside_tree():
		await ready

	# Sprite + callback de fin
	if anim:
		anim.animation_finished.connect(_on_anim_finished, CONNECT_ONE_SHOT)
		anim.play()

	# Particules
	if fx:
		fx.one_shot = true
		fx.emitting = true

	# Flash de lumière
	if flash:
		flash.energy = flash_energy
		var t := create_tween()
		t.tween_property(flash, "energy", 0.0, 0.15)

	# Son
	if sfx and sfx.stream:
		sfx.pitch_scale = 1.0 + randf_range(-sfx_random_pitch, sfx_random_pitch)
		sfx.play()

	# Sécurité d'auto-destruction
	get_tree().create_timer(1.2).timeout.connect(func ():
		if auto_free and is_instance_valid(self):
			queue_free()
	)

func _on_anim_finished() -> void:
	if auto_free:
		queue_free()
