extends Control
class_name LoadingScreen

# =========================================================
#                        EXPORTS
# =========================================================
@export var logo_path: NodePath = NodePath("Logo")
@export var animation_player_path: NodePath = NodePath("AnimationPlayer")

@export_range(1.0, 1.2, 0.01) var pulse_scale: float = 1.05
@export_range(0.2, 2.0, 0.05) var pulse_duration: float = 0.8
@export_range(0.0, 1.0, 0.01) var min_alpha: float = 0.92

@export_range(0.1, 10.0, 0.1) var fallback_min_display_time: float = 4.0
@export_range(1.0, 30.0, 0.5) var threaded_timeout: float = 10.0

const PULSE_ANIM_NAME: StringName = &"logo_pulse"

# =========================================================
#                    REFERENCES NODES
# =========================================================
@onready var logo: TextureRect = get_node_or_null(logo_path) as TextureRect
@onready var animation_player: AnimationPlayer = get_node_or_null(animation_player_path) as AnimationPlayer

# =========================================================
#                         STATE
# =========================================================
var _target_scene_path: String = ""
var _min_display_time: float = 2.0

var _elapsed: float = 0.0
var _load_started: bool = false
var _load_done: bool = false
var _transition_started: bool = false
var _loaded_scene: PackedScene = null

# =========================================================
#                         READY
# =========================================================
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if logo == null:
		push_warning("[LoadingScreen] Logo introuvable. Vérifie logo_path.")
		return

	if animation_player == null:
		push_warning("[LoadingScreen] AnimationPlayer introuvable. Vérifie animation_player_path.")
		return

	_setup_logo_defaults()
	_ensure_pulse_animation()
	animation_player.play(PULSE_ANIM_NAME)

	_target_scene_path = SceneLoader.consume_pending_scene_path()
	_min_display_time = SceneLoader.consume_pending_min_display_time(fallback_min_display_time)

	if _target_scene_path.is_empty():
		push_error("[LoadingScreen] Aucune scène cible fournie par SceneLoader.")
		return

	_start_threaded_load()

# =========================================================
#                        PROCESS
# =========================================================
func _process(delta: float) -> void:
	if _transition_started:
		return

	_elapsed += delta

	if _load_started and not _load_done:
		_poll_threaded_load()

	# Si le chargement threaded prend trop longtemps, fallback propre.
	if _load_started and not _load_done and _elapsed >= threaded_timeout:
		_fallback_to_direct_scene_change()
		return

	_try_finish_transition()

# =========================================================
#                    INITIALISATION LOGO
# =========================================================
func _setup_logo_defaults() -> void:
	logo.scale = Vector2.ONE
	logo.modulate = Color(1.0, 1.0, 1.0, 1.0)

# =========================================================
#              CREATION / RECUP ANIMATION LIBRARY
# =========================================================
func _get_or_create_default_library() -> AnimationLibrary:
	var library := animation_player.get_animation_library(&"")

	if library != null:
		return library

	library = AnimationLibrary.new()
	animation_player.add_animation_library(&"", library)
	return library

# =========================================================
#                  CREATION ANIMATION PULSE
# =========================================================
func _ensure_pulse_animation() -> void:
	var library := _get_or_create_default_library()

	if library.has_animation(PULSE_ANIM_NAME):
		return

	var anim := Animation.new()
	anim.length = pulse_duration * 2.0
	anim.loop_mode = Animation.LOOP_LINEAR

	# SCALE
	var scale_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(scale_track, NodePath("Logo:scale"))
	anim.track_insert_key(scale_track, 0.0, Vector2.ONE)
	anim.track_insert_key(scale_track, pulse_duration, Vector2(pulse_scale, pulse_scale))
	anim.track_insert_key(scale_track, pulse_duration * 2.0, Vector2.ONE)
	anim.track_set_interpolation_type(scale_track, Animation.INTERPOLATION_CUBIC)

	# MODULATE
	var modulate_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(modulate_track, NodePath("Logo:modulate"))
	anim.track_insert_key(modulate_track, 0.0, Color(1.0, 1.0, 1.0, 1.0))
	anim.track_insert_key(modulate_track, pulse_duration, Color(1.0, 1.0, 1.0, min_alpha))
	anim.track_insert_key(modulate_track, pulse_duration * 2.0, Color(1.0, 1.0, 1.0, 1.0))
	anim.track_set_interpolation_type(modulate_track, Animation.INTERPOLATION_CUBIC)

	library.add_animation(PULSE_ANIM_NAME, anim)

# =========================================================
#                   CHARGEMENT THREADE
# =========================================================
func _start_threaded_load() -> void:
	var err := ResourceLoader.load_threaded_request(_target_scene_path)
	if err != OK:
		push_warning("[LoadingScreen] load_threaded_request a échoué pour %s (err=%d). Fallback direct." % [_target_scene_path, err])
		_load_started = false
		return

	_load_started = true

func _poll_threaded_load() -> void:
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_target_scene_path, progress)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			pass

		ResourceLoader.THREAD_LOAD_LOADED:
			var res := ResourceLoader.load_threaded_get(_target_scene_path)
			if res is PackedScene:
				_loaded_scene = res
				_load_done = true
			else:
				push_warning("[LoadingScreen] Ressource chargée non PackedScene pour %s. Fallback direct." % _target_scene_path)
				_fallback_to_direct_scene_change()

		ResourceLoader.THREAD_LOAD_FAILED:
			push_warning("[LoadingScreen] Chargement threaded échoué pour %s. Fallback direct." % _target_scene_path)
			_fallback_to_direct_scene_change()

		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_warning("[LoadingScreen] Ressource invalide pour %s. Fallback direct." % _target_scene_path)
			_fallback_to_direct_scene_change()

# =========================================================
#                      TRANSITION FINALE
# =========================================================
func _try_finish_transition() -> void:
	if _transition_started:
		return

	if _elapsed < _min_display_time:
		return

	# Cas 1 : le threaded a bien préparé la scène.
	if _load_done and _loaded_scene != null:
		_transition_started = true
		get_tree().change_scene_to_packed(_loaded_scene)
		return

	# Cas 2 : le threaded n'a pas démarré -> fallback après le délai mini.
	if not _load_started:
		_fallback_to_direct_scene_change()

func _fallback_to_direct_scene_change() -> void:
	if _transition_started:
		return

	if _elapsed < _min_display_time:
		return

	_transition_started = true

	var err := get_tree().change_scene_to_file(_target_scene_path)
	if err != OK:
		push_error("[LoadingScreen] Impossible d'ouvrir la scène cible : %s (err=%d)" % [_target_scene_path, err])
