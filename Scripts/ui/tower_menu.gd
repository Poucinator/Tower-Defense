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


func setup(icon: Texture2D, price: int, world_pos: Vector2, tower_owner: Node2D) -> void:
	# 🚫 Protection anti-vente : pas de menu d'upgrade si on vend
	if ("is_selling_mode" in Game and Game.is_selling_mode):
		queue_free()
		return

	# 🚫 Protection anti-tour supprimée
	if tower_owner == null or not is_instance_valid(tower_owner):
		queue_free()
		return

	btn.texture_normal = icon
	price_label.text = "%d PO" % price

	_target_node = tower_owner
	_world_pos   = world_pos

	$Box.custom_minimum_size = Vector2(120, 120)
	btn.custom_minimum_size  = Vector2(72, 72)

	# =========================================================
	# ✅ FIX UI : le prix doit être lisible et centré (global)
	# =========================================================
	# Donne une zone "pleine largeur" au label et centre le texte dedans
	price_label.custom_minimum_size.x = $Box.custom_minimum_size.x
	price_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Si tu veux un léger décalage vers la droite (optionnel, safe)
	# (utile si ton fond/ombre visuelle "mange" le côté gauche)
	# ⚠️ Si Box est un Container, la position peut être ignorée -> donc on reste sur centrage.
	# price_label.position.x = 6.0

	_reposition()
	popup()
	await get_tree().process_frame
	_reposition()


func _process(_dt: float) -> void:
	# 🔒 Sécurité continue : si mode vente activé, on ferme
	if ("is_selling_mode" in Game and Game.is_selling_mode):
		queue_free()
		return

	# 🔒 Si la tour a été détruite, on ferme aussi
	if _target_node == null or not is_instance_valid(_target_node):
		queue_free()
		return

	# Suivi de position normal sinon
	_world_pos = _target_node.global_position
	_reposition()


func _reposition() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var screen_pos: Vector2 = cam.project_position(_world_pos)
	position = screen_pos - size * 0.5
