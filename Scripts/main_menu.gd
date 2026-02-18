extends Node2D

func _ready():
	# Connect buttons
	$CanvasLayer/AnimatedSprite2D/PlayButton.pressed.connect(_on_play_pressed)
	$CanvasLayer/AnimatedSprite2D/SettingsButton.pressed.connect(_on_settings_pressed)
	$CanvasLayer/AnimatedSprite2D/ExitButton.pressed.connect(_on_exit_pressed)


func _on_play_pressed():
	print("Lancement du jeu…")
	get_tree().change_scene_to_file("res://scene/niveaux/main.tscn")   # mets ton chemin exact


func _on_settings_pressed():
	print("Ouverture des paramètres…")
	# plus tard on fera une pop-up ou une scène dédiée


func _on_exit_pressed():
	print("Sortie du jeu…")
	get_tree().quit()
