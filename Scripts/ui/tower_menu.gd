# res://ui/tower_menu.gd
extends PopupPanel

signal option_chosen

@onready var btn: TextureButton = $Box/UpgradeBtn
@onready var price_label: Label = $Box/PriceLabel

var _target_node: Node2D = null
var _world_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	btn.pressed.connect(func ():
		option_chosen.emit()
		queue_free()
	)
	set_process(true)

func setup(icon: Texture2D, price: int, world_pos: Vector2, owner: Node2D) -> void:
	btn.texture_normal = icon
	price_label.text = "%d PO" % price

	_target_node = owner
	_world_pos   = world_pos

	$Box.custom_minimum_size = Vector2(120, 120)
	btn.custom_minimum_size  = Vector2(72, 72)
	# si dispo dans ta version :
	# btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

	_reposition()
	popup()
	await get_tree().process_frame
	_reposition()

func _process(_dt: float) -> void:
	if _target_node and is_instance_valid(_target_node):
		_world_pos = _target_node.global_position
	_reposition()

func _reposition() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return  # pas de caméra active -> on ne bouge pas

	# monde -> écran
	var screen_pos: Vector2 = cam.project_position(_world_pos)

	# centre le popup sur ce point
	position = screen_pos - size * 0.5
	
