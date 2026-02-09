extends Node2D
class_name SummonZone

@export var marine_scene: PackedScene
@export var marine_count: int = 3
@export var lifetime: float = 10.0
@export var spawn_radius: float = 48.0

@export var marine_tier: int = 1

# (Optionnel mais recommandé) : scènes par tier
@export var marine_mk1_scene: PackedScene = preload("res://units/marine.tscn")
@export var marine_mk2_scene: PackedScene = preload("res://units/marine_MK2.tscn")
@export var marine_mk3_scene: PackedScene = preload("res://units/marine_MK3.tscn")
@export var marine_mk4_scene: PackedScene = preload("res://units/marine_MK4.tscn")
@export var marine_mk5_scene: PackedScene = preload("res://units/marine_MK5.tscn")

func _ready() -> void:
	print("[Summon] Déploiement de ", marine_count, " marines pour ", lifetime, "s.")
	_spawn_marines()

	# Zone supprimée automatiquement à la fin (OK)
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _get_scene_for_tier() -> PackedScene:
	# Option 1 (actuel / recommandé chez toi) : le tier fait foi.
	var t := clampi(marine_tier, 1, 5)
	match t:
		1: return marine_mk1_scene
		2: return marine_mk2_scene
		3: return marine_mk3_scene
		4: return marine_mk4_scene
		5: return marine_mk5_scene
		_: return marine_mk1_scene

	# Option 2 (si tu veux un override): décommente :
	# if marine_scene != null:
	# 	return marine_scene

func _spawn_marines() -> void:
	var scene := _get_scene_for_tier()
	if not scene:
		print("[Summon] ERREUR : scène marine introuvable pour tier=", marine_tier)
		return

	var root := get_tree().current_scene
	if root == null:
		push_warning("[Summon] current_scene est null, impossible de spawn")
		return

	for i in range(marine_count):
		var marine := scene.instantiate()
		if not marine:
			continue

		# Position aléatoire dans un petit rayon autour du point
		var offset := Vector2(
			randf_range(-spawn_radius, spawn_radius),
			randf_range(-spawn_radius, spawn_radius)
		)
		marine.global_position = global_position + offset

		# Définir comme "éphémère"
		if "regen_per_sec" in marine: marine.regen_per_sec = 0.0
		if "is_moving" in marine: marine.is_moving = false
		if "barrack" in marine: marine.barrack = null
		marine.set_process(true)

		# Ajouter au niveau
		root.add_child(marine)

		# ✅ IMPORTANT : timer indépendant de SummonZone
		# (si SummonZone est queue_free, ce timer continue quand même)
		get_tree().create_timer(lifetime).timeout.connect(func():
			if is_instance_valid(marine):
				marine.queue_free()
		)

# Tu peux supprimer cette méthode si tu ne l'utilises pas
func _on_marine_removed() -> void:
	pass
