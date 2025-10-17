extends Camera2D

@export var speed: float = 400     # vitesse déplacement
@export var zoom_speed: float = 0.1   # vitesse de zoom
@export var min_zoom: float = 0.2     # zoom maximum (rapproché)
@export var max_zoom: float = 3.0     # zoom minimum (éloigné)

func _process(delta: float) -> void:
	var move = Vector2.ZERO
	
	if Input.is_action_pressed("ui_right"):
		move.x += 1
	if Input.is_action_pressed("ui_left"):
		move.x -= 1
	if Input.is_action_pressed("ui_down"):
		move.y += 1
	if Input.is_action_pressed("ui_up"):
		move.y -= 1
	
	if move != Vector2.ZERO:
		move = move.normalized()
		global_position += move * speed * delta

func _unhandled_input(event: InputEvent) -> void:
	# Zoom avant avec molette vers le haut
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = (zoom - Vector2(zoom_speed, zoom_speed)).clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = (zoom + Vector2(zoom_speed, zoom_speed)).clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
