extends Node2D
class_name WaveSequence

@export var events: Array[SpawnEvent] = []
@export var first_delay: float = 0.0
@export var auto_trigger_next: bool = true
@export_range(0.1, 60.0, 0.1, "suffix:s")
var fallback_timeout: float = 8.0   # délai max avant d’enchaîner même sans signal

signal wave_sequence_started(total_events: int)
signal wave_sequence_finished(index: int)

var _active := false
var _index_in_level := 0
var _fail_timers := {}         # event_idx -> Timer
var _event_done := {}          # event_idx -> bool (évite double-tir)
const DBG := true


func _ready() -> void:
	for c in get_children():
		if "autostart" in c:
			c.autostart = false


func begin(delay: float = -1.0, index_in_level: int = 0) -> void:
	if _active: return
	_active = true
	_index_in_level = index_in_level
	var d: float = (first_delay if delay < 0.0 else delay)
	if DBG: print("[WaveSequence] >>> BEGIN ", name, " (events=", events.size(), ", delay=", d, "s)")
	emit_signal("wave_sequence_started", events.size())
	call_deferred("_run_next_event", 0, d)


func _run_next_event(event_idx: int, delay: float = 0.0) -> void:
	if event_idx >= events.size():
		_sequence_complete()
		return

	_event_done.erase(event_idx)
	var ev: SpawnEvent = events[event_idx]
	if DBG: print("[WaveSequence] ▶ Event ", event_idx+1, "/", events.size(),
		" path=", ev.path, " delay=", ev.delay, " wait_clear=", ev.wait_clear)

	var total_delay: float = max(0.0, float(delay) + float(ev.delay))
	if total_delay > 0.0:
		await get_tree().create_timer(total_delay).timeout

	var spawner: Node = get_node_or_null(ev.path)
	if spawner == null:
		push_warning("[WaveSequence] ⚠️ Spawner introuvable: " + str(ev.path))
		call_deferred("_run_next_event", event_idx + 1, 0.0)
		return

	# Reset spawner
	if "autostart" in spawner: spawner.autostart = false
	if spawner.has_method("stop_all"): spawner.stop_all()
	elif "_running" in spawner: spawner._running = false

	# Brancher HUD
	var hud := get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("set_spawner"):
		hud.call("set_spawner", spawner)

	# Signal à écouter
	var signal_name := ""
	var is_last_event := (event_idx == events.size() - 1)

	# Dernier event → toujours attendre wave_cleared ; sinon respecter wait_clear
	if (ev.wait_clear or is_last_event) and spawner.has_signal("wave_cleared"):
		signal_name = "wave_cleared"
	elif spawner.has_signal("wave_finished"):
		signal_name = "wave_finished"

	var on_signal := Callable(self, "_on_spawner_done").bind(event_idx, spawner.name)
	if signal_name != "":
		spawner.connect(signal_name, on_signal, CONNECT_ONE_SHOT)
	else:
		push_warning("[WaveSequence] ⚠️ Aucun signal sur " + spawner.name + " → on utilisera seulement le timeout")

	# Timer de secours UNIQUEMENT si on n'attend pas la mort des mobs
	if not ev.wait_clear and not is_last_event:
		var t := Timer.new()
		t.one_shot = true
		t.wait_time = max(0.1, fallback_timeout)
		add_child(t)
		_fail_timers[event_idx] = t
		t.timeout.connect(Callable(self, "_on_event_timeout").bind(event_idx, spawner.name), CONNECT_ONE_SHOT)
		t.start()

	# log propre sans référencer 't' hors scope
	var failover_info := "disabled"
	if _fail_timers.has(event_idx):
		var tt: Timer = _fail_timers[event_idx]
		if is_instance_valid(tt):
			failover_info = str(tt.wait_time) + "s"

	if DBG: print("[WaveSequence] 🚀 begin ", spawner.name, " (signal=", (signal_name if signal_name != "" else "none"),
		", failover=", failover_info, ")")
	spawner.begin(0.0)


func _on_spawner_done(_sig_idx_from_spawner: int, event_idx: int, spawner_name: String) -> void:
	if _mark_event_done(event_idx):
		if DBG: print("[WaveSequence] 🟢 Signal reçu de ", spawner_name, " → next")
		call_deferred("_run_next_event", event_idx + 1, 0.0)


func _on_event_timeout(event_idx: int, spawner_name: String) -> void:
	if _mark_event_done(event_idx):
		push_warning("[WaveSequence] ⏳ Timeout sur " + spawner_name + " → on enchaîne quand même")
		call_deferred("_run_next_event", event_idx + 1, 0.0)


func _mark_event_done(event_idx: int) -> bool:
	if _event_done.get(event_idx, false):
		return false
	_event_done[event_idx] = true
	if _fail_timers.has(event_idx):
		var t: Timer = _fail_timers[event_idx]
		if is_instance_valid(t):
			t.stop()
			t.queue_free()
		_fail_timers.erase(event_idx)
	return true


func _sequence_complete() -> void:
	if DBG: print("[WaveSequence] 🎯 Séquence complète ", name)
	_active = false
	emit_signal("wave_sequence_finished", _index_in_level)
