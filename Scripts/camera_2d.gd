extends Camera2D

## ==========================================================
##                CONFIG CAMÉRA
## ==========================================================
@export var speed: float = 400.0
@export var zoom_step: float = 0.05

# Zoom minimal (vue "normale") et zoom max (dézoom max)
@export var min_zoom: float = 1.0
@export var max_zoom: float = 1.8

## ==========================================================
##                LIMITES DU MONDE
## ==========================================================
# ⚠️ VALEURS D’EXEMPLE : tu les ajusteras dans l’inspecteur
@export var world_left: float = 40.0
@export var world_top: float = 100.0
@export var world_right: float = 4000.0
@export var world_bottom: float = 2400.0


func _ready() -> void:
	add_to_group("player_camera")
	zoom = Vector2(min_zoom, min_zoom)
	_snap_to_top_left()  # on se cale en haut à gauche dès le début


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
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom += Vector2(zoom_step, zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom -= Vector2(zoom_step, zoom_step)

		# clamp du zoom
		zoom.x = clamp(zoom.x, min_zoom, max_zoom)
		zoom.y = zoom.x

		_clamp_position()


func _clamp_position() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size

	# ✅ IMPORTANT : clamp basé sur le zoom ACTUEL (sinon tu “perds” le haut)
	var half_w: float = viewport_size.x * zoom.x / 2.0
	var half_h: float = viewport_size.y * zoom.y / 2.0

	var min_x: float = world_left + half_w
	var max_x: float = world_right - half_w
	var min_y: float = world_top + half_h
	var max_y: float = world_bottom - half_h

	# Sécurité si la zone est plus petite que l’écran à ce zoom :
	# on force la caméra à rester centrée plutôt que partir en NaN / clamp inversé.
	if min_x > max_x:
		global_position.x = (world_left + world_right) / 2.0
	else:
		global_position.x = clamp(global_position.x, min_x, max_x)

	if min_y > max_y:
		global_position.y = (world_top + world_bottom) / 2.0
	else:
		global_position.y = clamp(global_position.y, min_y, max_y)


func _snap_to_top_left() -> void:
	# ✅ Snap basé sur le zoom ACTUEL (pas max_zoom)
	var viewport_size: Vector2 = get_viewport_rect().size
	var half_w: float = viewport_size.x * zoom.x / 2.0
	var half_h: float = viewport_size.y * zoom.y / 2.0

	global_position = Vector2(
		world_left + half_w,
		world_top + half_h
	)

	_clamp_position()


# Appelé après la story
func reset_after_story() -> void:
	zoom = Vector2(min_zoom, min_zoom)
	_snap_to_top_left()
	make_current()
