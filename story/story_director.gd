extends Node

# =========================
#      CONFIGURATION
# =========================

# 1) Soit tu glisses directement le nœud Overlay dans l’inspecteur :
@export var overlay_ref: CanvasLayer
# 2) Ou un NodePath :
@export var overlay_path: NodePath

var overlay: CanvasLayer = null

# Séquence d’intro (avant la toute première WaveSequence)
@export var intro: StorySequence

# Séquences inter-WaveSequence
# clé = index de la WaveSequence (0 = après intro, 1 = après la première, etc.)
@export var sequences_by_sequence: Dictionary = {
	1: null,
	2: null,
	3: null
}

# interne
var _pending_cb: Callable = Callable()
var _pending_seq_id: String = ""


# =========================
#       READY
# =========================
func _ready() -> void:
	_resolve_overlay()
	if overlay == null:
		call_deferred("_retry_resolve_overlay")

func _retry_resolve_overlay() -> void:
	_resolve_overlay()
	if overlay == null:
		push_warning("[StoryDirector] Overlay introuvable. Vérifie overlay_ref / overlay_path / groupe 'StoryOverPlay'.")


func _resolve_overlay() -> void:
	# 1) Réf directe
	if overlay_ref != null and is_instance_valid(overlay_ref):
		overlay = overlay_ref
		return
	# 2) Par NodePath
	if overlay_path != NodePath("") and overlay == null:
		var n := get_node_or_null(overlay_path)
		if n is CanvasLayer:
			overlay = n
			return
	# 3) Par groupe
	if overlay == null:
		var g := get_tree().get_nodes_in_group("StoryOverPlay")
		if g.size() > 0 and g[0] is CanvasLayer:
			overlay = g[0]


# =========================
#   API → LevelDirector
# =========================

func play_intro_then(cb: Callable) -> void:
	var slides: Array = intro.to_slides() if intro != null else []
	print("[SD] play_intro_then slides=", slides.size(), " overlay=", overlay)
	_play_or_return("intro", slides, cb)


func has_between_for_wave(seq_index: int) -> bool:
	var seq: StorySequence = sequences_by_sequence.get(seq_index, null)
	return seq != null and not seq.to_slides().is_empty()


func play_between_then(seq_index: int, cb: Callable) -> void:
	var seq: StorySequence = sequences_by_sequence.get(seq_index, null)
	var slides: Array = seq.to_slides() if seq != null else []
	print("[SD] play_between_then seq=", seq_index, " slides=", slides.size(), " overlay=", overlay)
	_play_or_return("between_seq_%d" % seq_index, slides, cb)


# =========================
#        INTERNE
# =========================
func _play_or_return(id: String, slides: Array, cb: Callable) -> void:
	if overlay == null:
		_resolve_overlay()

	if slides.is_empty() or overlay == null:
		if overlay == null:
			push_warning("[StoryDirector] Impossible de jouer '" + id + "' : overlay = null")
		if cb.is_valid(): cb.call()
		return

	_pending_cb = cb
	_pending_seq_id = id

	overlay.sequence_finished.connect(_on_sequence_finished, CONNECT_ONE_SHOT)
	overlay.call("play_sequence", id, slides)


func _on_sequence_finished(_id: String) -> void:
	var cb := _pending_cb
	_pending_cb = Callable()
	_pending_seq_id = ""
	if cb.is_valid():
		cb.call()
