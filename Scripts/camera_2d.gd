extends Camera2D

@export var speed: float = 400.0
@export var zoom_step: float = 0.05

var min_zoom: float = 1.5
var max_zoom: float = 3   # <-- défini par le LevelDirector

func _ready() -> void:
	add_to_group("player_camera")
	zoom = Vector2(1.0, 1.0)

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

		zoom.x = clamp(zoom.x, min_zoom, max_zoom)
		zoom.y = zoom.x
		_clamp_position()

func _clamp_position() -> void:
	var viewport := get_viewport_rect().size
	var half_w := viewport.x * zoom.x / 2.0
	var half_h := viewport.y * zoom.y / 2.0

	global_position.x = clamp(global_position.x, limit_left + half_w, limit_right - half_w)
	global_position.y = clamp(global_position.y, limit_top + half_h, limit_bottom - half_h)
