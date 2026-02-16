extends Node

## =========================================================
##              CONFIGURATION EXPORT
## =========================================================
@export var hud_path: NodePath
@export var wave_paths: Array[NodePath] = []
@export var inter_level_delay: float = 30.0
@export var start_first_on_ready: bool = true

@export var story_director_path: NodePath
@export var camera_path: NodePath   # Optionnel

var story: Node = null

## =========================================================
##                 WEATHER / METEO
## =========================================================
@export var rain_particles_path: NodePath      # -> CanvasItem (ex: WeatherLayer/RainParticles)
@export var weather_dim_rect_path: NodePath    # -> ColorRect (ex: WeatherLayer/WeatherDim)

# À partir de quelle wave (index) on active pluie + assombrissement
@export var enable_weather_at_wave_index: int = 4

# Assombrissement cible (0..1)
@export_range(0.0, 1.0, 0.01) var dim_target_alpha: float = 0.18
@export_range(0.0, 2.0, 0.01) var weather_fade_time: float = 0.6

var _rain_particles: CanvasItem = null
var _dim_rect: ColorRect = null
var _weather_enabled: bool = false

## =========================================================
##                PHASE 2
## =========================================================
@export var phase2_paths: Array[NodePath] = []
@export var phase2_world_bottom: float = 1800.0
@export var phase2_world_top: float = -200.0
const PHASE2_SLOT_GROUP := "Phase2BuildSlot"

## =========================================================
##                INTERNES
## =========================================================
var hud: Node = null
var waves: Array[Node] = []
var current_idx := -1
var _skip_inter_delay := false
var _inter_left := 0.0
var camera: Camera2D = null

## =========================================================
##        DEBUG (uniquement lié à defeat hooks)
## =========================================================
const DBG_DEFEAT := true

## =========================================================
##                     VICTORY
## =========================================================
@export var victory_overlay_scene: PackedScene = preload("res://scene/Victory_Overlay.tscn")
@export var main_menu_scene_path: String = "res://scene/MainMenu.tscn"

@export var labo_scene_path: String = "res://scene/Vaisseau/Labo.tscn" # ajuste si besoin

var _victory_ui: CanvasLayer = null
var _victory_reward_applied := false
var _last_victory_crystals_earned: int = 0

## =========================================================
##                     DEFEAT
## =========================================================
@export var defeat_overlay_scene: PackedScene = preload("res://scene/defeat_overlay.tscn")

var _defeat_ui: CanvasLayer = null
var _defeat_shown := false


## =========================================================
##                     READY
## =========================================================
func _ready() -> void:
	add_to_group("LevelDirector")

	# HUD
	hud = get_node_or_null(hud_path)
	if hud == null:
		hud = get_tree().get_first_node_in_group("HUD")

	# Story
	story = get_node_or_null(story_director_path)

	# Caméra
	_init_camera()

	# Weather (optionnel)
	_rain_particles = get_node_or_null(rain_particles_path) as CanvasItem
	_dim_rect = get_node_or_null(weather_dim_rect_path) as ColorRect
	_prepare_weather_initial_state()

	# ✅ Defeat hooks (robuste, late + node_added)
	call_deferred("_connect_defeat_objectives_late")

	# Chargement des waves
	waves.clear()
	for p in wave_paths:
		var w := get_node_or_null(p)
		if not w:
			push_warning("[LD] Vague introuvable : %s" % [p])
			continue

		if "autostart" in w:
			w.autostart = false

		if w.has_signal("wave_sequence_finished"):
			if not w.wave_sequence_finished.is_connected(_on_wave_finished):
				w.wave_sequence_finished.connect(_on_wave_finished.bind(w))
		elif w.has_signal("wave_cleared"):
			if not w.wave_cleared.is_connected(_on_wave_finished):
				w.wave_cleared.connect(_on_wave_finished.bind(w))
		else:
			push_warning("[LD] Aucun signal de fin pour %s" % [w.name])

		waves.append(w)

	if waves.is_empty():
		push_error("[LevelDirector] Aucune WaveSequence configurée.")
		return

	if start_first_on_ready:
		call_deferred("_start_or_intro")

	# ✅ Reset progression tours pour ce niveau (MK1 au départ)
	if "reset_run_tower_progression" in Game:
		Game.reset_run_tower_progression()
	else:
		# fallback si jamais tu n'as pas encore ajouté la méthode
		if "max_tower_tier" in Game:
			Game.max_tower_tier = 1


## =========================================================
##     INIT CAMERA (robuste)
## =========================================================
func _init_camera() -> void:
	if camera_path != NodePath(""):
		camera = get_node_or_null(camera_path) as Camera2D

	# ✅ Sinon uniquement la caméra gameplay
	if camera == null:
		camera = get_tree().get_first_node_in_group("player_camera") as Camera2D

	# ❌ On évite get_first_node_of_type(Camera2D) (risque d'attraper une caméra d'UI/overlay)
	if camera == null:
		push_warning("[LD] ❌ Aucune caméra trouvée (groupe 'player_camera' introuvable).")
		return

	camera.make_current()


## =========================================================
##          WEATHER
## =========================================================
func _prepare_weather_initial_state() -> void:
	_weather_enabled = false

	# Pluie : au départ invisible (tu l'as déjà fait)
	if _rain_particles:
		# On laisse l'état tel quel si tu préfères le contrôler dans l'éditeur,
		# mais on sécurise : invisible au start.
		_rain_particles.visible = false

	# Dim : invisible + alpha 0 (sinon tu peux “salir” l'écran)
	if _dim_rect:
		_dim_rect.visible = false
		var c := _dim_rect.color
		c.a = 0.0
		_dim_rect.color = c

func _enable_weather_once() -> void:
	if _weather_enabled:
		return
	_weather_enabled = true

	# 1) Pluie
	if _rain_particles:
		_rain_particles.visible = true
	else:
		push_warning("[LD] rain_particles_path non assigné ou invalide (pluie ignorée).")

	# 2) Assombrissement
	if _dim_rect:
		_fade_dim_to(dim_target_alpha, weather_fade_time)
	else:
		push_warning("[LD] weather_dim_rect_path non assigné (assombrissement ignoré).")

func _fade_dim_to(target_alpha: float, duration: float) -> void:
	if not _dim_rect:
		return

	_dim_rect.visible = true

	var c := _dim_rect.color
	var end_a := clampf(target_alpha, 0.0, 1.0)

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(_dim_rect, "color", Color(c.r, c.g, c.b, end_a), max(duration, 0.01))


## =========================================================
##          DEFEAT : branche Drill + Ship (robuste)
## =========================================================
func _connect_defeat_objectives_late() -> void:
	# laisse Godot finir de monter la scène
	await get_tree().process_frame

	_connect_defeat_objectives_once()

	# si un objectif arrive après (instanciation / load tardif), on le catch
	if not get_tree().node_added.is_connected(_on_node_added_for_defeat):
		get_tree().node_added.connect(_on_node_added_for_defeat)

	if DBG_DEFEAT:
		print("[LD/DEFEAT] hooks armed (late + node_added)")


func _connect_defeat_objectives_once() -> void:
	if _defeat_shown:
		return

	# Foreuse
	var drill := get_tree().get_first_node_in_group("Drill")
	if drill and drill.has_signal("drill_destroyed"):
		if not drill.drill_destroyed.is_connected(_on_objective_destroyed):
			drill.drill_destroyed.connect(_on_objective_destroyed)
			if DBG_DEFEAT:
				print("[LD/DEFEAT] connected Drill.drill_destroyed ->", drill.name)
	else:
		if DBG_DEFEAT:
			print("[LD/DEFEAT] Drill not found yet (group=Drill)")

	# Vaisseau
	var ship := get_tree().get_first_node_in_group("Ship")
	if ship and ship.has_signal("ship_destroyed"):
		if not ship.ship_destroyed.is_connected(_on_objective_destroyed):
			ship.ship_destroyed.connect(_on_objective_destroyed)
			if DBG_DEFEAT:
				print("[LD/DEFEAT] connected Ship.ship_destroyed ->", ship.name)
	else:
		if DBG_DEFEAT:
			print("[LD/DEFEAT] Ship not found yet (group=Ship)")


func _on_node_added_for_defeat(n: Node) -> void:
	if _defeat_shown:
		return
	if n == null or not is_instance_valid(n):
		return

	# Foreuse
	if n.is_in_group("Drill") and n.has_signal("drill_destroyed"):
		if not n.drill_destroyed.is_connected(_on_objective_destroyed):
			n.drill_destroyed.connect(_on_objective_destroyed)
			if DBG_DEFEAT:
				print("[LD/DEFEAT] (late) connected Drill.drill_destroyed ->", n.name)

	# Vaisseau
	if n.is_in_group("Ship") and n.has_signal("ship_destroyed"):
		if not n.ship_destroyed.is_connected(_on_objective_destroyed):
			n.ship_destroyed.connect(_on_objective_destroyed)
			if DBG_DEFEAT:
				print("[LD/DEFEAT] (late) connected Ship.ship_destroyed ->", n.name)


func _on_objective_destroyed(obj: Node) -> void:
	if DBG_DEFEAT:
		print("[LD/DEFEAT] objective destroyed ->", obj.name, " => defeat")
	end_level_defeat()


## =========================================================
##                 INTRO OU DÉMARRAGE
## =========================================================
func _start_or_intro() -> void:
	if story and story.has_method("play_intro_then"):
		story.call("play_intro_then", Callable(self, "_on_intro_finished"))
	else:
		_prepare_wave(0)

func _on_intro_finished() -> void:
	if camera:
		if camera.has_method("reset_after_story"):
			camera.reset_after_story()
		else:
			camera.make_current()
	_prepare_wave(0)


## =========================================================
##            PRÉPARATION DE CHAQUE VAGUE
## =========================================================
func _prepare_wave(index: int) -> void:
	if index < 0 or index >= waves.size():
		push_warning("[LD] Index vague invalide : " + str(index))
		return

	current_idx = index
	var wave := waves[index]

	# Liaison HUD
	var first_spawner := _get_first_spawner_in_wave(wave)
	if first_spawner and hud and hud.has_method("set_spawner"):
		hud.call("set_spawner", first_spawner)

	_skip_inter_delay = false
	_inter_left = inter_level_delay

	if hud and hud.has_signal("next_clicked"):
		if not hud.next_clicked.is_connected(_on_hud_next_clicked):
			hud.next_clicked.connect(_on_hud_next_clicked, CONNECT_ONE_SHOT)

	if hud and hud.has_method("director_countdown_start"):
		hud.call("director_countdown_start", inter_level_delay)

	_unlock_progression(index)

	while _inter_left > 0.0 and not _skip_inter_delay:
		await get_tree().create_timer(0.1).timeout
		_inter_left = max(_inter_left - 0.1, 0.0)
		if hud and hud.has_method("director_countdown_tick"):
			hud.call("director_countdown_tick", _inter_left)

	if hud and hud.has_method("director_countdown_done"):
		hud.call("director_countdown_done")

	if "begin" in wave:
		wave.begin(0.0, index)
	else:
		push_warning("[LD] ⚠️ %s n’a pas begin()" % wave.name)


## =========================================================
##          CLICK NEXT (+X PO)
## =========================================================
func _on_hud_next_clicked() -> void:
	var reward := int(ceil(max(_inter_left, 0.0)))
	if reward > 0 and "add_gold" in Game:
		Game.add_gold(reward)
	_skip_inter_delay = true


## =========================================================
##               FIN DES WAVES ET ENCHAÎNEMENT
## =========================================================
func _on_wave_finished(_wave_index: int, finished_wave: Node) -> void:
	var idx := waves.find(finished_wave)
	if idx == -1:
		return

	var next_idx := idx + 1

	if next_idx >= waves.size():
		if hud and hud.has_method("show_victory"):
			hud.call("show_victory")
		return

	if story and story.has_method("has_between_for_wave") and story.call("has_between_for_wave", next_idx):
		story.call("play_between_then", next_idx, Callable(self, "_prepare_wave").bind(next_idx))
	else:
		_prepare_wave(next_idx)


## =========================================================
##                   HELPERS
## =========================================================
func _get_first_spawner_in_wave(wave: Node) -> Node:
	if wave == null:
		return null

	if "events" in wave and wave.events.size() > 0:
		var e = wave.events[0]
		if e and e.path != NodePath(""):
			return wave.get_node_or_null(e.path)

	return null


## =========================================================
##                   PHASE 2
## =========================================================
func _reveal_phase2_zone() -> void:
	for p in phase2_paths:
		var n := get_node_or_null(p) as Node2D
		if n:
			n.visible = true

	if camera:
		# ✅ Nouvelle caméra (ton script) : propriétés world_bottom / world_top
		if ("world_bottom" in camera) and ("world_top" in camera):
			camera.world_bottom = phase2_world_bottom
			camera.world_top = phase2_world_top

		# ✅ Compat fallback : si ta caméra utilise les limites Camera2D natives
		elif camera is Camera2D:
			camera.limit_bottom = int(phase2_world_bottom)
			camera.limit_top = int(phase2_world_top)
		else:
			push_warning("[LD] La caméra n'a ni world_bottom/world_top ni limites Camera2D.")


func _unlock_progression(index: int) -> void:
	# ✅ Météo à partir de la wave souhaitée
	if index == enable_weather_at_wave_index:
		_enable_weather_once()

	if index == 4:
		if "max_tower_tier" in Game:
			Game.max_tower_tier = max(Game.max_tower_tier, 2)

	if index == 5:
		_reveal_phase2_zone()
		_unlock_phase2_buildslots()

	if hud == null or not hud.has_method("unlock_element"):
		return

	match index:
		1:
			hud.unlock_element("snipe")
		2:
			hud.unlock_element("freeze")
		3:
			hud.unlock_element("missile")
		4:
			hud.unlock_element("summon")
			hud.unlock_element("heal")
			hud.unlock_element("blue_mk2")
			hud.unlock_element("snipe_mk2")
			hud.unlock_element("missile_mk2")
			hud.unlock_element("barrack_mk2")
		5:
			hud.unlock_element("crystals")
			if hud.has_method("show_phase2_unlocked"):
				hud.call("show_phase2_unlocked")


func _hide_phase2_buildslots_on_start() -> void:
	for slot in get_tree().get_nodes_in_group(PHASE2_SLOT_GROUP):
		if slot is CanvasItem:
			slot.visible = false


func _unlock_phase2_buildslots() -> void:
	for slot in get_tree().get_nodes_in_group(PHASE2_SLOT_GROUP):
		if slot is CanvasItem:
			slot.visible = true
		if slot.has_method("enable"):
			slot.enable()


## =========================================================
##   FIN DE JEU : VICTOIRE
## =========================================================
func end_level_victory(crystals_earned: int) -> void:
	# Empêche de spawn plusieurs overlays
	if _victory_ui != null and is_instance_valid(_victory_ui):
		return

	_last_victory_crystals_earned = crystals_earned
	get_tree().paused = true

	if victory_overlay_scene == null:
		push_warning("[LD] victory_overlay_scene non assignée dans l'inspector.")
		return

	_victory_ui = victory_overlay_scene.instantiate() as CanvasLayer
	_victory_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_victory_ui)

	# Affichage du gain sur l'overlay
	if _victory_ui.has_method("set_crystals"):
		_victory_ui.call("set_crystals", crystals_earned)

	# Connexions boutons
	if _victory_ui.has_signal("continue_pressed") and not _victory_ui.continue_pressed.is_connected(_on_victory_continue):
		_victory_ui.continue_pressed.connect(_on_victory_continue)
	if _victory_ui.has_signal("menu_pressed") and not _victory_ui.menu_pressed.is_connected(_on_victory_labo):
		_victory_ui.menu_pressed.connect(_on_victory_labo)
	if _victory_ui.has_signal("quit_pressed") and not _victory_ui.quit_pressed.is_connected(_on_victory_quit_to_main):
		_victory_ui.quit_pressed.connect(_on_victory_quit_to_main)

	# ✅ IMPORTANT : on NE crédite PAS la banque ici.
	_victory_reward_applied = false


func _close_victory_overlay() -> void:
	if _victory_ui != null and is_instance_valid(_victory_ui):
		_victory_ui.queue_free()
	_victory_ui = null


func _commit_victory_once() -> void:
	if _victory_reward_applied:
		return
	_victory_reward_applied = true

	# ✅ Commit des cristaux de RUN vers la banque
	if "commit_run_crystals_to_bank" in Game:
		Game.commit_run_crystals_to_bank()
	else:
		# Fallback
		Game.add_bank_crystals(_last_victory_crystals_earned)


## =========================================================
##   BOUTONS OVERLAY
## =========================================================
func _on_victory_continue() -> void:
	get_tree().paused = false
	_close_victory_overlay()
	# IMPORTANT : on ne recharge pas la scène


func _on_victory_labo() -> void:
	get_tree().paused = false
	_commit_victory_once()
	_close_victory_overlay()

	if labo_scene_path != "":
		get_tree().call_deferred("change_scene_to_file", labo_scene_path)
	else:
		push_warning("[LD] labo_scene_path est vide.")


func _on_victory_quit_to_main() -> void:
	get_tree().paused = false
	_commit_victory_once()
	_close_victory_overlay()

	if main_menu_scene_path != "":
		get_tree().call_deferred("change_scene_to_file", main_menu_scene_path)
	else:
		push_warning("[LD] main_menu_scene_path est vide.")


## =========================================================
##   FIN DE JEU : DÉFAITE
## =========================================================
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
		push_warning("[LD] defeat_overlay_scene non assignée dans l'inspector.")
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
	# ✅ Relancer le niveau
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_defeat_menu() -> void:
	get_tree().paused = false
	if main_menu_scene_path != "":
		get_tree().change_scene_to_file(main_menu_scene_path)
	else:
		push_warning("[LD] main_menu_scene_path est vide.")


func _on_defeat_quit() -> void:
	get_tree().quit()
