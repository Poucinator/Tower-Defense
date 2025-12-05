extends AnimatedSprite2D

func _ready():
	_resize_to_window()
	get_tree().root.size_changed.connect(_resize_to_window) # si la fenêtre change de taille


func _resize_to_window():
	var viewport_size = get_viewport_rect().size
	var texture_size = sprite_frames.get_frame_texture("default", 0).get_size()

	# ratio d'échelle
	var scale_factor = viewport_size / texture_size

	# on prend le plus grand pour couvrir tout l'écran
	var final_scale = max(scale_factor.x, scale_factor.y)

	scale = Vector2(final_scale, final_scale)

	# centre l'image
	position = viewport_size / 2
