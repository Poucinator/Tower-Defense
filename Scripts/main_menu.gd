extends Node2D

const LEVEL_MAIN_PATH: String = "res://scene/niveaux/main.tscn"

func _ready() -> void:
	# Connect buttons
	$CanvasLayer/AnimatedSprite2D/PlayButton.pressed.connect(_on_play_pressed)
	$CanvasLayer/AnimatedSprite2D/SettingsButton.pressed.connect(_on_settings_pressed)
	$CanvasLayer/AnimatedSprite2D/ExitButton.pressed.connect(_on_exit_pressed)

func _on_play_pressed() -> void:
	print("Lancement du jeu…")
	SceneLoader.goto_scene_with_loading(LEVEL_MAIN_PATH, 2.0)

func _on_settings_pressed() -> void:
	print("Ouverture des paramètres…")
	# Plus tard : popup ou scène dédiée

func _on_exit_pressed() -> void:
	print("Sortie du jeu…")
	get_tree().quit()
