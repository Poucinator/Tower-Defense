extends Node


const LOADING_SCREEN_PATH: String = "res://ui/loading/loading_screen.tscn"

var _pending_scene_path: String = ""
var _pending_min_display_time: float = 10.0

func goto_scene_with_loading(scene_path: String, min_display_time: float = 10.0) -> void:
	if scene_path.is_empty():
		push_warning("[SceneLoader] scene_path vide.")
		return

	_pending_scene_path = scene_path
	_pending_min_display_time = max(min_display_time, 0.0)

	var err := get_tree().change_scene_to_file(LOADING_SCREEN_PATH)
	if err != OK:
		push_error("[SceneLoader] Impossible d'ouvrir le loading screen : %s (err=%d)" % [LOADING_SCREEN_PATH, err])

func goto_scene_direct(scene_path: String) -> void:
	if scene_path.is_empty():
		push_warning("[SceneLoader] scene_path vide.")
		return

	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("[SceneLoader] Impossible d'ouvrir la scène : %s (err=%d)" % [scene_path, err])

func consume_pending_scene_path() -> String:
	var path := _pending_scene_path
	_pending_scene_path = ""
	return path

func consume_pending_min_display_time(default_value: float = 4.0) -> float:
	var value := _pending_min_display_time
	_pending_min_display_time = default_value
	return value
