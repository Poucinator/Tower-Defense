extends Node

## ==========================================================
##              CONFIGURATION EXPORT
## ==========================================================
@export var hud_path: NodePath
@export var wave_paths: Array[NodePath] = []
@export var inter_level_delay: float = 30.0
@export var start_first_on_ready: bool = true

@export var story_director_path: NodePath
@export var camera_path: NodePath   # Optionnel

var story: Node = null

## ==========================================================
##                PHASE 2 
## ==========================================================

@export var phase2_paths: Array[NodePath] = []   # Tous les TileMaps de la nouvelle zone
@export var phase2_world_bottom: float = 1800.0  # Nouvelle limite bas de la caméra



## ==========================================================
##                INTERNES
## ==========================================================
var hud: Node = null
var waves: Array[Node] = []
var current_idx := -1
var _skip_inter_delay := false
var _inter_left := 0.0
var camera: Camera2D = null

const DBG := true


## ==========================================================
##                     READY
## ==========================================================
func _ready() -> void:
	# HUD
	hud = get_node_or_null(hud_path)
	if hud == null:
		hud = get_tree().get_first_node_in_group("HUD")

	# Story
	story = get_node_or_null(story_director_path)

	# Caméra
	_init_camera()

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


## ==========================================================
##     INIT CAMERA (robuste)
## ==========================================================
func _init_camera() -> void:
	# 1) Assignée dans l'éditeur ?
	if camera_path != NodePath(""):
		camera = get_node_or_null(camera_path)

	# 2) Sinon via groupe
	if camera == null:
		camera = get_tree().get_first_node_in_group("player_camera")

	# 3) Sinon première Camera2D trouvée
	if camera == null:
		camera = get_tree().get_first_node_of_type(Camera2D)

	if camera == null:
		push_warning("[LD] ❌ Aucune caméra trouvée.")
	elif DBG:
		print("[LD] 🎥 Caméra trouvée :", camera.name)


## ==========================================================
##                 INTRO OU DÉMARRAGE
## ==========================================================
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

## ==========================================================
##            PRÉPARATION DE CHAQUE VAGUE
## ==========================================================
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

	# Déblocages HUD / pouvoirs
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
		push_warning("[LD] ⚠️ ", wave.name, " n’a pas begin()")


## ==========================================================
##          CLICK NEXT (+X PO)
## ==========================================================
func _on_hud_next_clicked() -> void:
	var reward := int(ceil(max(_inter_left, 0.0)))
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

	if next_idx >= waves.size():
		if hud and hud.has_method("show_victory"):
			hud.call("show_victory")
		return

	if story and story.has_method("has_between_for_wave") and story.call("has_between_for_wave", next_idx):
		story.call("play_between_then", next_idx, Callable(self, "_prepare_wave").bind(next_idx))
	else:
		_prepare_wave(next_idx)


## ==========================================================
##                   HELPERS
## ==========================================================
func _get_first_spawner_in_wave(wave: Node) -> Node:
	if wave == null:
		return null

	if "events" in wave and wave.events.size() > 0:
		var e = wave.events[0]
		if e and e.path != NodePath(""):
			return wave.get_node_or_null(e.path)

	return null

## ==========================================================
##                   Phases 2 
## ==========================================================

func _reveal_phase2_zone() -> void:
	# 1) Afficher les TileMaps de la phase 2
	for p in phase2_paths:
		var n := get_node_or_null(p) as Node2D
		if n:
			n.visible = true
			if DBG:
				print("[LD] Phase2 visible :", n.name)
		else:
			push_warning("[LD] Phase2 introuvable pour le path : %s" % [p])

	# 2) Descendre la limite bas de la caméra
	if camera:
		if "world_bottom" in camera:
			camera.world_bottom = phase2_world_bottom
			if DBG:
				print("[LD] Camera world_bottom ->", camera.world_bottom)
		else:
			push_warning("[LD] La caméra n'a pas de propriété 'world_bottom' (check camera_2d.gd)")

const PHASE2_SLOT_GROUP := "Phase2BuildSlot"

## ==========================================================
##     🔓 Débloquage HUD + progression
## ==========================================================
func _unlock_progression(index: int) -> void:
	# --- Débloquage global des niveaux d'upgrade ---
	if index == 4:
		# On autorise les upgrades vers MK2 (mais pas MK3,4,5...)
		if "max_tower_tier" in Game:
			Game.max_tower_tier = max(Game.max_tower_tier, 2)
			if DBG:
				print("[LD] max_tower_tier ->", Game.max_tower_tier)

	# --- Révélation de la nouvelle zone en 5 ---
	if index == 5:
		_reveal_phase2_zone()          # ta fonction existante
		_unlock_phase2_buildslots()    # 👉 fait apparaître les 2 nouveaux slots

	# --- Déblocage HUD ---
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
			# éventuellement un message HUD "Nouvelle zone débloquée !" si tu veux
			if hud.has_method("show_phase2_unlocked"):
				hud.call("show_phase2_unlocked")
			if hud:
				print("[LD] index 5 => unlock crystals")
				hud.unlock_element("crystals")
			if hud.has_method("show_phase2_unlocked"):
				hud.call("show_phase2_unlocked")

## ==========================================================
##   Phase 2 : BuildSlots supplémentaires
## ==========================================================
func _hide_phase2_buildslots_on_start() -> void:
	# À appeler au démarrage si jamais certains slots sont visibles dans la scène
	for slot in get_tree().get_nodes_in_group(PHASE2_SLOT_GROUP):
		if slot is CanvasItem:
			slot.visible = false

func _unlock_phase2_buildslots() -> void:
	for slot in get_tree().get_nodes_in_group(PHASE2_SLOT_GROUP):
		if slot is CanvasItem:
			slot.visible = true

		# Si ton script de slot a une méthode d’activation, on la déclenche
		if slot.has_method("enable"):
			slot.enable()

	if DBG:
		print("[LD] Phase 2 : buildslots débloqués")
