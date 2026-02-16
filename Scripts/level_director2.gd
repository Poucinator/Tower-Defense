# res://scripts/LevelDirector_Level2.gd
extends Node
class_name LevelDirectorLevel2

## ==========================================================
##              CONFIGURATION EXPORT
## ==========================================================
@export var hud_path: NodePath
@export var wave_paths: Array[NodePath] = []
@export var inter_level_delay: float = 20.0
@export var start_first_on_ready: bool = true

@export var story_director_path: NodePath
@export var camera_path: NodePath   # optionnel

## ==========================================================
##                     VICTORY
## ==========================================================
@export var victory_overlay_scene: PackedScene = preload("res://scene/Victory_Overlay.tscn")
@export var labo_scene_path: String = "res://scene/Vaisseau/Labo.tscn"
@export var main_menu_scene_path: String = "res://scene/MainMenu.tscn"

var _victory_ui: CanvasLayer = null
var _victory_reward_applied := false
var _last_victory_crystals_earned: int = 0

## ==========================================================
##                     DEFEAT
## ==========================================================
@export var defeat_overlay_scene: PackedScene = preload("res://scene/defeat_overlay.tscn")
var _defeat_ui: CanvasLayer = null
var _defeat_shown := false

## ==========================================================
##                     INTERNES
## ==========================================================
var hud: Node = null
var story: Node = null
var camera: Camera2D = null

var waves: Array[Node] = []
var current_idx := -1
var _skip_inter_delay := false
var _inter_left := 0.0

## Debug defeat (optionnel)
const DBG_DEFEAT := true


## ==========================================================
##                     READY
## ==========================================================
func _ready() -> void:
	add_to_group("LevelDirector")

	# ✅ Appliquer l'or de départ acheté (upgrade start_gold)
	# À faire AU DÉBUT, avant que le HUD lise Game.gold dans son _ready().
	if Game and Game.has_method("reset_gold_to_start_value"):
		Game.reset_gold_to_start_value()
	else:
		push_warning("[LD2] Game.reset_gold_to_start_value() introuvable (autoload Game ?)")

	# ✅ Niveau 2 : par défaut, les tours doivent pouvoir aller jusqu'à MK2
	# (l'achat labo sert uniquement à débloquer MK3 par type)
	if Game:
		if "max_tower_tier" in Game:
			Game.max_tower_tier = maxi(int(Game.max_tower_tier), 2)

	# HUD
	hud = get_node_or_null(hud_path)
	if hud == null:
		hud = get_tree().get_first_node_in_group("HUD")

	# Story
	story = get_node_or_null(story_director_path)

	# Caméra
	_init_camera()

	# Defeat hooks (robuste, late + node_added)
	call_deferred("_connect_defeat_objectives_late")

	# Charger les waves
	_load_waves()
	if waves.is_empty():
		push_error("[LD2] Aucune WaveSequence configurée.")
		return

	# Démarrer
	if start_first_on_ready:
		call_deferred("_start_or_intro")



func _init_camera() -> void:
	if camera_path != NodePath(""):
		camera = get_node_or_null(camera_path)
	if camera == null:
		camera = get_tree().get_first_node_in_group("player_camera")
	if camera == null:
		camera = get_tree().get_first_node_of_type(Camera2D)
	if camera == null:
		push_warning("[LD2] ❌ Aucune caméra trouvée.")


func _load_waves() -> void:
	waves.clear()

	for p in wave_paths:
		var w := get_node_or_null(p)
		if not w:
			push_warning("[LD2] Vague introuvable : %s" % [p])
			continue

		# Désactive tout autostart éventuel
		if "autostart" in w:
			w.autostart = false

		# Support des 2 conventions (WaveSequence = wave_sequence_finished / Spawner = wave_cleared)
		if w.has_signal("wave_sequence_finished"):
			if not w.wave_sequence_finished.is_connected(_on_wave_finished):
				w.wave_sequence_finished.connect(_on_wave_finished.bind(w))
		elif w.has_signal("wave_cleared"):
			if not w.wave_cleared.is_connected(_on_wave_finished):
				w.wave_cleared.connect(_on_wave_finished.bind(w))
		else:
			push_warning("[LD2] Aucun signal de fin pour %s" % [w.name])

		waves.append(w)


## ==========================================================
##                 INTRO OU DÉMARRAGE
## ==========================================================
func _start_or_intro() -> void:
	if story and story.has_method("play_intro_then"):
		story.call("play_intro_then", Callable(self, "_on_intro_finished"))
	else:
		_prepare_wave(0)

func _on_intro_finished() -> void:
	# Sécurité caméra après story
	if camera:
		if camera.has_method("reset_after_story"):
			camera.reset_after_story()
		else:
			camera.make_current()
	_prepare_wave(0)


## ==========================================================
##            PRÉPARATION DE CHAQUE VAGUE
## ==========================================================
func _prepare_wave(index: int) -> void:
	if index < 0 or index >= waves.size():
		push_warning("[LD2] Index vague invalide : %s" % str(index))
		return

	current_idx = index
	var wave := waves[index]

	# Liaison HUD -> premier spawner de la wave (pour afficher timer/next, etc.)
	var first_spawner := _get_first_spawner_in_wave(wave)
	if first_spawner and hud and hud.has_method("set_spawner"):
		hud.call("set_spawner", first_spawner)

	# Inter-delay
	_skip_inter_delay = false
	_inter_left = inter_level_delay

	# Bouton NEXT du HUD (mode “piloté par director”)
	if hud and hud.has_signal("next_clicked"):
		if not hud.next_clicked.is_connected(_on_hud_next_clicked):
			hud.next_clicked.connect(_on_hud_next_clicked, CONNECT_ONE_SHOT)

	if hud and hud.has_method("director_countdown_start"):
		hud.call("director_countdown_start", inter_level_delay)

	while _inter_left > 0.0 and not _skip_inter_delay:
		await get_tree().create_timer(0.1).timeout
		_inter_left = max(_inter_left - 0.1, 0.0)
		if hud and hud.has_method("director_countdown_tick"):
			hud.call("director_countdown_tick", _inter_left)

	if hud and hud.has_method("director_countdown_done"):
		hud.call("director_countdown_done")

	# Démarrer la wave
	if "begin" in wave:
		wave.begin(0.0, index)
	else:
		push_warning("[LD2] ⚠️ %s n’a pas begin()" % wave.name)


func _on_hud_next_clicked() -> void:
	# Skip = reward en PO (gold) (même logique que niveau 1)
	var reward := 0
	if Game and Game.has_method("compute_wave_skip_reward"):
		reward = int(Game.compute_wave_skip_reward(_inter_left))
	else:
		reward = int(ceil(max(_inter_left, 0.0))) # fallback

	if reward > 0 and "add_gold" in Game:
		Game.add_gold(reward)
	_skip_inter_delay = true


## ==========================================================
##               FIN DES WAVES ET ENCHAÎNEMENT
## ==========================================================
func _on_wave_finished(_wave_index: int, finished_wave: Node) -> void:
	var idx := waves.find(finished_wave)
	if idx == -1:
		return

	var next_idx := idx + 1

	# Fin niveau -> victoire
	if next_idx >= waves.size():
		var earned := 0
		if Game and Game.has_method("get_run_crystals_total"):
			earned = int(Game.call("get_run_crystals_total"))
		elif "run_crystals" in Game:
			earned = int(Game.run_crystals)
		end_level_victory(earned)
		return

	# Between-story optionnelle
	if story and story.has_method("has_between_for_wave") and story.call("has_between_for_wave", next_idx):
		story.call("play_between_then", next_idx, Callable(self, "_prepare_wave").bind(next_idx))
	else:
		_prepare_wave(next_idx)


func _get_first_spawner_in_wave(wave: Node) -> Node:
	if wave == null:
		return null
	if "events" in wave and wave.events.size() > 0:
		var e = wave.events[0]
		if e and e.path != NodePath(""):
			return wave.get_node_or_null(e.path)
	return null


## ==========================================================
##          DEFEAT : Drill + Ship (robuste)
## ==========================================================
func _connect_defeat_objectives_late() -> void:
	await get_tree().process_frame
	_connect_defeat_objectives_once()

	if not get_tree().node_added.is_connected(_on_node_added_for_defeat):
		get_tree().node_added.connect(_on_node_added_for_defeat)

	if DBG_DEFEAT:
		print("[LD2/DEFEAT] hooks armed (late + node_added)")


func _connect_defeat_objectives_once() -> void:
	if _defeat_shown:
		return

	var drill := get_tree().get_first_node_in_group("Drill")
	if drill and drill.has_signal("drill_destroyed"):
		if not drill.drill_destroyed.is_connected(_on_objective_destroyed):
			drill.drill_destroyed.connect(_on_objective_destroyed)
			if DBG_DEFEAT: print("[LD2/DEFEAT] connected Drill ->", drill.name)

	var ship := get_tree().get_first_node_in_group("Ship")
	if ship and ship.has_signal("ship_destroyed"):
		if not ship.ship_destroyed.is_connected(_on_objective_destroyed):
			ship.ship_destroyed.connect(_on_objective_destroyed)
			if DBG_DEFEAT: print("[LD2/DEFEAT] connected Ship ->", ship.name)


func _on_node_added_for_defeat(n: Node) -> void:
	if _defeat_shown or n == null or not is_instance_valid(n):
		return

	if n.is_in_group("Drill") and n.has_signal("drill_destroyed"):
		if not n.drill_destroyed.is_connected(_on_objective_destroyed):
			n.drill_destroyed.connect(_on_objective_destroyed)
			if DBG_DEFEAT: print("[LD2/DEFEAT] (late) connected Drill ->", n.name)

	if n.is_in_group("Ship") and n.has_signal("ship_destroyed"):
		if not n.ship_destroyed.is_connected(_on_objective_destroyed):
			n.ship_destroyed.connect(_on_objective_destroyed)
			if DBG_DEFEAT: print("[LD2/DEFEAT] (late) connected Ship ->", n.name)


func _on_objective_destroyed(obj: Node) -> void:
	if DBG_DEFEAT:
		print("[LD2/DEFEAT] objective destroyed ->", obj.name, " => defeat")
	end_level_defeat()


## ==========================================================
##   FIN DE JEU : VICTOIRE
## ==========================================================
func end_level_victory(crystals_earned: int) -> void:
	if _victory_ui != null and is_instance_valid(_victory_ui):
		return

	_last_victory_crystals_earned = crystals_earned
	get_tree().paused = true

	if victory_overlay_scene == null:
		push_warning("[LD2] victory_overlay_scene non assignée.")
		return

	_victory_ui = victory_overlay_scene.instantiate() as CanvasLayer
	_victory_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_victory_ui)

	if _victory_ui.has_method("set_crystals"):
		_victory_ui.call("set_crystals", crystals_earned)

	if _victory_ui.has_signal("continue_pressed") and not _victory_ui.continue_pressed.is_connected(_on_victory_continue):
		_victory_ui.continue_pressed.connect(_on_victory_continue)
	if _victory_ui.has_signal("menu_pressed") and not _victory_ui.menu_pressed.is_connected(_on_victory_labo):
		_victory_ui.menu_pressed.connect(_on_victory_labo)
	if _victory_ui.has_signal("quit_pressed") and not _victory_ui.quit_pressed.is_connected(_on_victory_quit_to_main):
		_victory_ui.quit_pressed.connect(_on_victory_quit_to_main)

	_victory_reward_applied = false


func _close_victory_overlay() -> void:
	if _victory_ui != null and is_instance_valid(_victory_ui):
		_victory_ui.queue_free()
	_victory_ui = null


func _commit_victory_once() -> void:
	if _victory_reward_applied:
		return
	_victory_reward_applied = true

	if "commit_run_crystals_to_bank" in Game:
		Game.commit_run_crystals_to_bank()
	else:
		if "add_bank_crystals" in Game:
			Game.add_bank_crystals(_last_victory_crystals_earned)


func _on_victory_continue() -> void:
	get_tree().paused = false
	_close_victory_overlay()
	# pas de commit, pas de change_scene


func _on_victory_labo() -> void:
	get_tree().paused = false
	_commit_victory_once()
	_close_victory_overlay()

	if labo_scene_path != "":
		get_tree().call_deferred("change_scene_to_file", labo_scene_path)
	else:
		push_warning("[LD2] labo_scene_path est vide.")


func _on_victory_quit_to_main() -> void:
	get_tree().paused = false
	_commit_victory_once()
	_close_victory_overlay()

	if main_menu_scene_path != "":
		get_tree().call_deferred("change_scene_to_file", main_menu_scene_path)
	else:
		push_warning("[LD2] main_menu_scene_path est vide.")


## ==========================================================
##   FIN DE JEU : DÉFAITE
## ==========================================================
func end_level_defeat() -> void:
	if _defeat_shown:
		return
	_defeat_shown = true

	# ferme victoire si jamais (sécurité)
	if _victory_ui and is_instance_valid(_victory_ui):
		_victory_ui.queue_free()
	_victory_ui = null

	get_tree().paused = true

	if defeat_overlay_scene == null:
		push_warning("[LD2] defeat_overlay_scene non assignée.")
		return

	_defeat_ui = defeat_overlay_scene.instantiate() as CanvasLayer
	_defeat_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_defeat_ui)

	if _defeat_ui.has_signal("continue_pressed") and not _defeat_ui.continue_pressed.is_connected(_on_defeat_continue):
		_defeat_ui.continue_pressed.connect(_on_defeat_continue)
	if _defeat_ui.has_signal("menu_pressed") and not _defeat_ui.menu_pressed.is_connected(_on_defeat_menu):
		_defeat_ui.menu_pressed.connect(_on_defeat_menu)
	if _defeat_ui.has_signal("quit_pressed") and not _defeat_ui.quit_pressed.is_connected(_on_defeat_quit):
		_defeat_ui.quit_pressed.connect(_on_defeat_quit)


func _on_defeat_continue() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_defeat_menu() -> void:
	get_tree().paused = false
	if main_menu_scene_path != "":
		get_tree().change_scene_to_file(main_menu_scene_path)


func _on_defeat_quit() -> void:
	get_tree().quit()
