# res://fx/rain_screen_fx.gd
extends GPUParticles2D
class_name RainScreenFX

## =========================================================
##          CONFIG (plein écran, indépendant caméra)
## =========================================================
@export_range(0.0, 2.0, 0.01) var intensity: float = 1.0
@export var base_amount: int = 1800
@export_range(0.1, 6.0, 0.05) var base_lifetime: float = 1.4
@export_range(0.0, 1.0, 0.01) var alpha: float = 0.45

@export var directional_velocity_min: float = 650.0
@export var directional_velocity_max: float = 950.0
@export var gravity_y: float = 1800.0
@export var wind_x: float = 120.0
@export var wind_random: float = 0.0

# marge écran (pixels) pour couvrir bords + particules rapides
@export var margin_px: Vector2 = Vector2(300, 300)

var _ppm: ParticleProcessMaterial

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_ensure_material()
	_apply_render()
	_apply_physics()
	_apply_intensity()

	_update_screen_box()
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func _process(_dt: float) -> void:
	# Si tu changes le zoom/resize runtime, on reste plein écran
	_update_screen_box()

func set_intensity(v: float) -> void:
	intensity = clampf(v, 0.0, 2.0)
	_apply_intensity()

# ---------------------------------------------------------
# Internals
# ---------------------------------------------------------
func _ensure_material() -> void:
	if process_material != null and process_material is ParticleProcessMaterial:
		_ppm = process_material as ParticleProcessMaterial
	else:
		_ppm = ParticleProcessMaterial.new()
		process_material = _ppm

	_ppm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX

func _apply_render() -> void:
	lifetime = base_lifetime

	var c := modulate
	c.a = clampf(alpha, 0.0, 1.0)
	modulate = c

func _apply_physics() -> void:
	_ppm.gravity = Vector3(0.0, gravity_y, 0.0)

	_ppm.set_param_min(ParticleProcessMaterial.PARAM_DIRECTIONAL_VELOCITY, directional_velocity_min)
	_ppm.set_param_max(ParticleProcessMaterial.PARAM_DIRECTIONAL_VELOCITY, directional_velocity_max)

	_ppm.set_param_min(ParticleProcessMaterial.PARAM_LINEAR_ACCEL, wind_x)
	_ppm.set_param_max(ParticleProcessMaterial.PARAM_LINEAR_ACCEL, wind_x + wind_random)

func _apply_intensity() -> void:
	emitting = intensity > 0.001
	amount = int(round(base_amount * intensity))

func _on_viewport_size_changed() -> void:
	_update_screen_box()

func _update_screen_box() -> void:
	if _ppm == null:
		return

	# ✅ visible_rect = la vraie taille de l'écran (après stretch/aspect)
	var r: Rect2 = get_viewport().get_visible_rect()
	var size := r.size
	var half := size * 0.5 + margin_px

	# GPUParticles2D sous CanvasLayer => coordonnées écran.
	# Position au centre écran.
	global_position = r.position + size * 0.5

	# Emission box couvre tout l’écran (+ marge)
	_ppm.emission_box_extents = Vector3(half.x, half.y, 0.0)

	# ✅ culling : énorme aussi, sinon Godot coupe
	var cull_half := half + margin_px
	visibility_rect = Rect2(-cull_half, cull_half * 2.0)
