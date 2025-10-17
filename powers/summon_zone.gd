extends Node2D
class_name SummonZone

@export var marine_scene: PackedScene
@export var marine_count: int = 3
@export var lifetime: float = 10.0
@export var spawn_radius: float = 48.0

func _ready() -> void:
	print("[Summon] Déploiement de ", marine_count, " marines pour ", lifetime, "s.")
	_spawn_marines()
	
	# Timer de suppression automatique
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _spawn_marines() -> void:
	if not marine_scene:
		print("[Summon] ERREUR : marine_scene non défini.")
		return
	
	for i in range(marine_count):
		var marine = marine_scene.instantiate()
		if not marine:
			continue
			
		# Position aléatoire dans un petit rayon autour du point
		var offset = Vector2(randf_range(-spawn_radius, spawn_radius), randf_range(-spawn_radius, spawn_radius))
		marine.global_position = global_position + offset
		
		# Définir comme "éphémère"
		marine.regen_per_sec = 0.0
		marine.is_moving = false
		marine.barrack = null
		marine.set_process(true)
		
		# Supprimer l’auto-destruction de la caserne (le marine s’autodétruira seul)
		marine.connect("tree_exited", Callable(self, "_on_marine_removed"))
		
		# Timer de disparition pour chaque marine
		var timer := Timer.new()
		timer.one_shot = true
		timer.wait_time = lifetime
		add_child(timer)
		timer.timeout.connect(func():
			if is_instance_valid(marine):
				marine.queue_free()
		)
		timer.start()
		
		get_tree().current_scene.add_child(marine)

func _on_marine_removed() -> void:
	# Rien de spécial à faire ici pour l’instant, mais on garde le hook
	pass
