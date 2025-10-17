extends Area2D

@export var price_override: int = -1
@export var stage_scene: PackedScene    # 🔗 tu glisses ici ton Path2D.tscn

@onready var highlight: Node2D = null

var occupied := false
var tower: Node = null
var path2d: Path2D = null   # instance locale du path

func _ready() -> void:
	add_to_group("BuildSlot")
	input_pickable = true
	if highlight:
		highlight.visible = false

	# Si une scène a été assignée → on instancie le Path2D
	if stage_scene:
		var inst = stage_scene.instantiate()
		if inst is Path2D:
			path2d = inst
		else:
			push_error("[BuildSlot] La stage_scene n’est pas un Path2D")

# ==========================================
#            OCCUPATION DU SLOT
# ==========================================
func set_occupied(t: Node) -> void:
	if t == null:
		push_warning("[BuildSlot] ⚠️ set_occupied appelé avec un Node nul")
		return

	occupied = true
	tower = t
	if highlight:
		highlight.visible = false

	# Si la tour posée supporte set_path → on lui passe le path
	if tower and path2d and tower.has_method("set_path"):
		tower.call("set_path", path2d)

# ==========================================
#            LIBÉRATION DU SLOT
# ==========================================
# ✅ Corrigé pour ne JAMAIS planter, même si la tour est déjà détruite
func clear_if(t = null) -> void:
	# Sécurité : si le tower actuel n’est plus valide → on reset tout
	if not is_instance_valid(tower):
		occupied = false
		tower = null
		return

	# Si un argument est passé, on vérifie sa validité
	if t == null or not is_instance_valid(t):
		# Si t est nul (ou déjà libéré), on compare autrement
		if not is_instance_valid(tower):
			occupied = false
			tower = null
		return

	# Si l’argument correspond bien à la tour du slot → on la libère
	if t == tower:
		occupied = false
		tower = null

# ==========================================
#             UTILITAIRES
# ==========================================
func _set_highlight(on: bool) -> void:
	if highlight:
		highlight.visible = on

func is_free() -> bool:
	return not occupied
