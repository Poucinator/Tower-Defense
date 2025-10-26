extends Area2D

@export var price_override: int = -1
@export var stage_scene: PackedScene    # 🔗 tu glisses ici ton Path2D.tscn

@onready var highlight: Node2D = null

var tower: Node = null          # Tour actuellement posée
var path2d: Path2D = null       # Instance locale du path

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

	tower = t
	if highlight:
		highlight.visible = false

	# Si la tour posée supporte set_path → on lui passe le path
	if tower and path2d and tower.has_method("set_path"):
		tower.call("set_path", path2d)

# ==========================================
#            LIBÉRATION DU SLOT
# ==========================================
func clear_if(t: Node) -> void:
	# 🧠 Si la tour du slot n'existe plus → reset complet
	if not is_instance_valid(tower):
		tower = null
		if highlight:
			highlight.visible = true
		return

	# 🧩 Si aucune tour précisée, on nettoie de toute façon
	if t == null:
		tower = null
		if highlight:
			highlight.visible = true
		return

	# 💡 Si c’est bien la même tour → on libère
	if t == tower:
		tower = null
		if highlight:
			highlight.visible = true

# ==========================================
#             UTILITAIRES
# ==========================================
func _set_highlight(on: bool) -> void:
	if highlight:
		highlight.visible = on

func is_free() -> bool:
	return tower == null or not is_instance_valid(tower)
