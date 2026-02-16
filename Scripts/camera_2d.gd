# res://scripts/camera_2d.gd
extends Camera2D
class_name PlayerCamera2D

@export var speed: float = 400.0
@export var zoom_step: float = 0.05

# Zoom utilisateur (max = zoom-in)
@export var user_min_zoom: float = 0.6   # tentative de dézoom max (sera remontée si besoin)
@export var user_max_zoom: float = 1.4   # zoom-in max

# Limites monde (en coordonnées monde)
@export var world_left: float = -1300.0
@export var world_top: float = -120.0
@export var world_right: float = 1300.0
@export var world_bottom: float = 870.0

var _min_zoom_fit: float = 1.0

func _ready() -> void:
	add_to_group("player_camera")
	offset = Vector2.ZERO
	rotation = 0.0
	scale = Vector2.ONE

	get_viewport().size_changed.connect(_on_viewport_size_changed)

	_recompute_zoom_fit()
	# zoom initial = 1 mais clampé dans la plage valide
	_set_zoom_clamped(1.0)
	_snap_to_top_left()
	make_current()

func _process(delta: float) -> void:
	var dir := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)

	if dir != Vector2.ZERO:
		global_position += dir.normalized() * speed * delta
		_clamp_position()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var z := zoom.x
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			z += zoom_step # zoom in
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			z -= zoom_step # zoom out
		else:
			return
		_set_zoom_clamped(z)
		_clamp_position()

func _on_viewport_size_changed() -> void:
	_recompute_zoom_fit()
	_set_zoom_clamped(zoom.x)
	_clamp_position()

func _recompute_zoom_fit() -> void:
	var vp := get_viewport_rect().size
	var world_w := maxf(world_right - world_left, 1.0)
	var world_h := maxf(world_bottom - world_top, 1.0)

	# ✅ zoom minimal pour éviter le noir (viewport / zoom <= world)
	var fit_x := vp.x / world_w
	var fit_y := vp.y / world_h
	_min_zoom_fit = maxf(fit_x, fit_y)

func _set_zoom_clamped(target: float) -> void:
	# zoom minimal réel = max(ce que veut le user, ce que le monde permet)
	var minz := maxf(user_min_zoom, _min_zoom_fit)
	var maxz := maxf(user_max_zoom, minz) # sécurité
	var z := clampf(target, minz, maxz)
	zoom = Vector2(z, z)

func _visible_half_extents() -> Vector2:
	var vp := get_viewport_rect().size
	var zx := maxf(zoom.x, 0.01)
	var zy := maxf(zoom.y, 0.01)
	return Vector2(vp.x * 0.5 / zx, vp.y * 0.5 / zy)

func _clamp_position() -> void:
	var half := _visible_half_extents()

	var min_x := world_left + half.x
	var max_x := world_right - half.x
	var min_y := world_top + half.y
	var max_y := world_bottom - half.y

	# Si encore impossible (monde trop petit), on centre proprement
	if min_x > max_x:
		global_position.x = (world_left + world_right) * 0.5
	else:
		global_position.x = clampf(global_position.x, min_x, max_x)

	if min_y > max_y:
		global_position.y = (world_top + world_bottom) * 0.5
	else:
		global_position.y = clampf(global_position.y, min_y, max_y)

func _snap_to_top_left() -> void:
	var half := _visible_half_extents()
	global_position = Vector2(world_left + half.x, world_top + half.y)
	_clamp_position()

func reset_after_story() -> void:
	offset = Vector2.ZERO
	rotation = 0.0
	scale = Vector2.ONE
	_recompute_zoom_fit()
	_set_zoom_clamped(1.0)
	_snap_to_top_left()
	make_current()
