extends Node

# --------- Réglages globaux ----------
@export var first_wave_delay: float = 10.0
@export var lanes: Array[SpawnLane] = []
@export var autostart: bool = true

# Timer global (enfant)
@onready var countdown_timer: Timer = $Timer

# ---------- Signaux ----------
signal countdown_started(total: float)
signal countdown_tick(left: float)
signal countdown_done()
signal wave_started(index: int, total_count: int)
signal wave_finished(index: int)      # fin des spawns
signal wave_cleared(index: int)       # plus aucun mob vivant sur aucune lane

# ---------- États internes ----------
var _wave_index: int = 1
var _countdown_left: float = 0.0
var _lanes: Array = []
var _ui_tick_timer: Timer = null
var _running: bool = false
var _cleared_emitted: bool = false
var _spawns_done: bool = false
var _active_mobs: int = 0
var _lane_mob_counts: Dictionary = {}   # { lane_id: nb_mobs_actifs }

const DBG := true


# =========================================================
#                      READY
# =========================================================
func _ready() -> void:
	countdown_timer.autostart = false
	countdown_timer.one_shot = true
	if countdown_timer.timeout.is_connected(_on_countdown_done):
		countdown_timer.timeout.disconnect(_on_countdown_done)
	countdown_timer.timeout.connect(_on_countdown_done)

	_setup_lanes()

	if autostart and not Engine.is_editor_hint():
		autostart = false
		if DBG:
			print("[SpawnerMulti] ⚠️ Autostart désactivé (piloté par LevelDirector)")


# =========================================================
#            DÉTECTION DE FIN DE VAGUE (MULTI-LANE)
# =========================================================
func _maybe_finish_wave() -> void:
	if DBG:
		print("[DEBUG] maybe_finish → active:", _active_mobs,
			  " spawns_done:", _spawns_done,
			  " cleared:", _cleared_emitted,
			  " lanes_alive:", _lane_mob_counts)

	if not _spawns_done:
		return  # il reste encore des spawns en cours

	var mobs_total_alive := 0
	for c in _lane_mob_counts.values():
		mobs_total_alive += c

	if mobs_total_alive > 0:
		return  # encore des mobs vivants quelque part

	if _cleared_emitted:
		return  # déjà émis

	_cleared_emitted = true
	await get_tree().process_frame
	print("[Spawner:%s] ✅ Toutes les lanes cleared → EMIT wave_cleared" % name)
	emit_signal("wave_cleared", _wave_index)


# =========================================================
#                     API publique
# =========================================================
func begin(delay: float = -1.0) -> void:
	_cleared_emitted = false
	_running = false
	stop_all()
	_active_mobs = 0
	_spawns_done = false
	_lane_mob_counts.clear()
	if DBG:
		print("[Spawner:", name, "] begin() called. delay=", delay)

	var d := delay if delay >= 0.0 else first_wave_delay
	_start_countdown(d)


func stop_all() -> void:
	_running = false
	countdown_timer.stop()
	if _ui_tick_timer:
		_ui_tick_timer.stop()
		_ui_tick_timer.queue_free()
		_ui_tick_timer = null
	for lane in _lanes:
		lane.timer.stop()


# =========================================================
#                    Préparation des voies
# =========================================================
func _setup_lanes() -> void:
	_lanes.clear()
	for cfg in lanes:
		var lane := {
			"cfg": cfg,
			"path2d": null,
			"stage_instance": null,
			"spawn_left": 0,
			"timer": null
		}

		# A) Path2D direct
		if cfg.path2d_path != NodePath(""):
			var n := get_node_or_null(cfg.path2d_path)
			if n is Path2D:
				lane.path2d = n

		# B) Sinon, instance une scène de type Path2D
		if lane.path2d == null and cfg.stage_scene:
			lane.stage_instance = cfg.stage_scene.instantiate()
			add_child(lane.stage_instance)
			if lane.stage_instance is Path2D:
				lane.path2d = lane.stage_instance
			else:
				push_error("[SpawnerMulti] La racine de stage_scene n’est pas un Path2D.")
				continue

		if lane.path2d == null:
			push_error("[SpawnerMulti] Lane sans Path2D.")
			continue

		# Timer de spawn
		var t := Timer.new()
		t.one_shot = false
		t.autostart = false
		add_child(t)
		t.timeout.connect(_on_lane_spawn_timeout.bind(lane))
		lane.timer = t

		_lanes.append(lane)

	if _lanes.is_empty():
		push_error("[SpawnerMulti] Aucune voie configurée.")


# =========================================================
#                   Compte à rebours
# =========================================================
func _start_countdown(seconds: float) -> void:
	if _lanes.is_empty(): return

	_countdown_left = max(0.05, seconds)
	emit_signal("countdown_started", _countdown_left)
	emit_signal("countdown_tick", _countdown_left)

	countdown_timer.wait_time = _countdown_left
	countdown_timer.start()

	if _ui_tick_timer:
		_ui_tick_timer.stop()
		_ui_tick_timer.queue_free()

	_ui_tick_timer = Timer.new()
	_ui_tick_timer.wait_time = 0.1
	_ui_tick_timer.one_shot = false
	add_child(_ui_tick_timer)
	_ui_tick_timer.timeout.connect(func ():
		if countdown_timer.is_stopped():
			_ui_tick_timer.stop()
			_ui_tick_timer.queue_free()
			_ui_tick_timer = null
			return
		_countdown_left = max(0.0, _countdown_left - _ui_tick_timer.wait_time)
		emit_signal("countdown_tick", _countdown_left)
	)
	_ui_tick_timer.start()

	if DBG: print("[SpawnerMulti] Countdown ", _countdown_left, "s")


func _on_countdown_done() -> void:
	if DBG: print("[Spawner:", name, "] countdown_done → start wave")
	emit_signal("countdown_done")
	_start_wave()


# =========================================================
#                    Démarrage de vague
# =========================================================
func _start_wave() -> void:
	if DBG: print("[Spawner:", name, "] _start_wave()")
	var total_to_spawn := 0
	_active_mobs = 0
	_spawns_done = false
	_running = true
	_lane_mob_counts.clear()

	for i in range(_lanes.size()):
		var lane = _lanes[i]
		var cfg: SpawnLane = lane.cfg
		lane.spawn_left = cfg.count
		total_to_spawn += cfg.count
		lane.timer.wait_time = max(0.05, cfg.interval)
		lane.timer.start()
		_lane_mob_counts[i] = 0

	emit_signal("wave_started", _wave_index, total_to_spawn)


# =========================================================
#                 Tick d’une voie
# =========================================================
func _on_lane_spawn_timeout(lane: Dictionary) -> void:
	if lane.spawn_left <= 0:
		lane.timer.stop()
		_check_spawns_finished()
		return
	_spawn_one_on_lane(lane)
	lane.spawn_left -= 1


func _spawn_one_on_lane(lane: Dictionary) -> void:
	var cfg: SpawnLane = lane.cfg
	var path2d: Path2D = lane.path2d
	if path2d == null or cfg.mob_scene == null:
		return

	var pf := PathFollow2D.new()
	path2d.add_child(pf)
	pf.loop = cfg.loop
	pf.rotates = cfg.rotates
	await get_tree().process_frame
	pf.progress_ratio = 0.0

	var mob := cfg.mob_scene.instantiate()
	pf.add_child(mob)
	mob.position = Vector2.ZERO

	# --- suivi des mobs ---
	var lane_index := _lanes.find(lane)
	if lane_index != -1:
		_lane_mob_counts[lane_index] += 1
	_active_mobs += 1

	# ✅ Connexions robustes (Godot 4) : on BIND les extras sur le Callable
	if mob.has_signal("died"):
		mob.died.connect(Callable(self, "_on_mob_gone").bind(lane_index), CONNECT_DEFERRED)
	if mob.has_signal("reached_end"):
		mob.reached_end.connect(Callable(self, "_on_mob_gone").bind(lane_index), CONNECT_DEFERRED)
	# tree_exited n’envoie aucun argument → on bind un faux "mob" = null PUIS lane_index
	mob.tree_exited.connect(Callable(self, "_on_mob_gone").bind(null).bind(lane_index), CONNECT_DEFERRED)


# =========================================================
#       Fin des spawns vs vague complètement vidée
# =========================================================
func _check_spawns_finished() -> void:
	var all_done := true
	for lane in _lanes:
		if lane.spawn_left > 0 or not lane.timer.is_stopped():
			all_done = false
	if not all_done:
		return

	_spawns_done = true
	emit_signal("wave_finished", _wave_index)
	_running = false
	_maybe_finish_wave()


# =========================================================
#   Tolérante au format d'arguments envoyé par les mobs
#   - died/reached_end : (mob) → + bind(lane_index) => (mob, lane_index)
#   - tree_exited      : ()    → + bind(null).bind(lane_index) => (null, lane_index)
# =========================================================
func _on_mob_gone(_mob, lane_index, _extra1 = null, _extra2 = null) -> void:
	_active_mobs = max(0, _active_mobs - 1)
	if _lane_mob_counts.has(lane_index):
		_lane_mob_counts[lane_index] = max(0, _lane_mob_counts[lane_index] - 1)
	if DBG:
		print("[DEBUG] mob gone → active:", _active_mobs, " lanes:", _lane_mob_counts)
	_maybe_finish_wave()


# =========================================================
#                      Helpers HUD
# =========================================================
func is_countdown_running() -> bool:
	return countdown_timer != null and is_instance_valid(countdown_timer) and not countdown_timer.is_stopped()

func get_countdown_left() -> float:
	if is_countdown_running():
		return max(0.0, _countdown_left)
	return 0.0

func skip_countdown_and_start() -> void:
	if countdown_timer != null and is_instance_valid(countdown_timer):
		if not countdown_timer.is_stopped():
			countdown_timer.stop()
	_on_countdown_done()
