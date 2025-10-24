extends Node

## ==========================================================
##              CONFIGURATION EXPORT
## ==========================================================
@export var hud_path: NodePath
@export var wave_paths: Array[NodePath] = []     # Liste des WaveSequence ou PathSpawnerMulti
@export var inter_level_delay: float = 30.0
@export var start_first_on_ready: bool = true

# Story optionnelle
@export var story_director_path: NodePath
var story: Node = null

## ==========================================================
##                INTERNES
## ==========================================================
var hud: Node = null
var waves: Array[Node] = []
var current_idx: int = -1
var _skip_inter_delay := false
var _inter_left: float = 0.0          # ⬅️ stocke le temps restant (pour la récompense)
const DBG := true


## ==========================================================
##                     READY
## ==========================================================
func _ready() -> void:
	hud = get_node_or_null(hud_path)
	if hud == null:
		hud = get_tree().get_first_node_in_group("HUD")

	story = get_node_or_null(story_director_path)

	waves.clear()
	for p in wave_paths:
		var w := get_node_or_null(p)
		if not w:
			push_warning("[LD] Vague introuvable : %s" % [p])
			continue

		# Neutralise tout autostart
		if "autostart" in w:
			w.autostart = false

		# Connexion signaux
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
##                 INTRO OU DÉMARRAGE
## ==========================================================
func _start_or_intro() -> void:
	if story and story.has_method("play_intro_then"):
		if DBG: print("[LD] 🎬 Intro demandée au StoryDirector")
		story.call("play_intro_then", Callable(self, "_on_intro_finished"))
	else:
		if DBG: print("[LD] Pas de StoryDirector → on prépare la première vague")
		_prepare_wave(0)

func _on_intro_finished() -> void:
	if DBG: print("[LD] ✅ Intro terminée → préparation de la première vague")
	_prepare_wave(0)


## ==========================================================
##          DÉCLENCHEMENT DU COMPTE À REBOURS
## ==========================================================
func _prepare_wave(index: int) -> void:
	if index < 0 or index >= waves.size():
		push_warning("[LD] Index de vague invalide : " + str(index))
		return

	current_idx = index
	var wave := waves[index]

	# --- Lie le HUD au premier spawner interne ---
	var first_spawner := _get_first_spawner_in_wave(wave)
	if first_spawner and hud and hud.has_method("set_spawner"):
		hud.call("set_spawner", first_spawner)
		if DBG: print("[LD] HUD lié à ", first_spawner.name)

	# --- Compte à rebours inter-vague ---
	_skip_inter_delay = false
	_inter_left = inter_level_delay

	if hud and hud.has_signal("next_clicked"):
		# On connecte avec récompense intégrée
		if not hud.next_clicked.is_connected(_on_hud_next_clicked):
			hud.next_clicked.connect(_on_hud_next_clicked, CONNECT_ONE_SHOT)

	if hud and hud.has_method("director_countdown_start"):
		hud.call("director_countdown_start", inter_level_delay)

	# 🔓 AJOUT : débloquer dès le début du compte à rebours
	_unlock_progression(index)

	while _inter_left > 0.0 and not _skip_inter_delay:
		await get_tree().create_timer(0.1).timeout
		_inter_left = max(0.0, _inter_left - 0.1)
		if hud and hud.has_method("director_countdown_tick"):
			hud.call("director_countdown_tick", _inter_left)

	if hud and hud.has_method("director_countdown_done"):
		hud.call("director_countdown_done")

	# --- Démarre la WaveSequence ---
	if DBG: print("[LD] ▶️ Lancement WaveSequence ", wave.name)
	if "begin" in wave:
		wave.begin(0.0, index)
	else:
		push_warning("[LD] ⚠️ ", wave.name, " n’a pas de méthode begin()")



## ==========================================================
##          GESTION DU BOUTON "LANCER (+X PO)"
## ==========================================================
func _on_hud_next_clicked() -> void:
	# ✅ Donne la récompense basée sur le temps restant du compte à rebours
	var reward := int(ceil(max(_inter_left, 0.0)))
	if reward > 0 and "add_gold" in Game:
		Game.add_gold(reward)

	_skip_inter_delay = true


## ==========================================================
##          ENCHAÎNEMENT ENTRE LES WAVESEQUENCES
## ==========================================================
func _on_wave_finished(_wave_index: int, finished_wave: Node) -> void:
	var idx := waves.find(finished_wave)
	if idx == -1:
		return

	if DBG: print("[LD] ✅ Fin de ", finished_wave.name)

	var next_idx := idx + 1
	if next_idx >= waves.size():
		if hud and hud.has_method("show_victory"):
			hud.call("show_victory")
		if DBG: print("[LD] 🏁 Toutes les vagues sont terminées 🎉")
		return

	# --- Story inter-WaveSequence éventuelle ---
	if story and story.has_method("has_between_for_wave") and story.call("has_between_for_wave", next_idx):
		if DBG: print("[LD] 📖 Story avant WaveSequence ", next_idx)
		story.call("play_between_then", next_idx,
			Callable(self, "_prepare_wave").bind(next_idx))
	else:
		if DBG: print("[LD] ⏱️ Transition classique vers WaveSequence ", next_idx)
		_prepare_wave(next_idx)


## ==========================================================
##                  HELPERS
## ==========================================================
func _get_first_spawner_in_wave(wave: Node) -> Node:
	if wave == null:
		return null
	if "events" in wave and wave.events.size() > 0:
		var first_event = wave.events[0]
		if first_event and first_event.path != NodePath(""):
			var spawner := wave.get_node_or_null(first_event.path)
			return spawner
	return null


# ==========================================================
#     🔓 Déblocage des tours/pouvoirs par numéro de vague
# ==========================================================
func _unlock_progression(index: int) -> void:
	# On débloque au début de la WaveSequence N (index N)
	# Mapping souhaité (index 0 = 1ère wave) :
	# 1 → snipe, 2 → freeze, 3 → missile, 4 → heal+summon, 5 → barrack_mk2
	if hud == null or not hud.has_method("unlock_element"):
		return

	match index:
		1:
			hud.call("unlock_element", "snipe")
		2:
			hud.call("unlock_element", "freeze")
		3:
			hud.call("unlock_element", "missile")
		4:
			hud.call("unlock_element", "heal")
			hud.call("unlock_element", "summon")
		5:
			hud.call("unlock_element", "barrack_mk2")
		_:
			pass
