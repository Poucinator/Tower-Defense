# res://effects/fire_zone.gd
extends Area2D
class_name FireZone

@export var tick_interval: float = 1.0
@export var end_anim_time: float = 0.25          # durée approx de l'anim "end"
@export var base_visual_radius_px: float = 64.0  # rayon visuel à scale=1 (à ajuster)

# ✅ Pour tester en posant la zone "à la main" dans une scène
@export var auto_start: bool = false
@export var auto_radius: float = 96.0
@export var auto_dps: int = 5
@export var auto_total_duration: float = 2.0

@export var debug_print_enter_exit: bool = false

@onready var vfx: AnimatedSprite2D = $Vfx
@onready var col: CollisionShape2D = $CollisionShape2D
@onready var tick_timer: Timer = $TickTimer
@onready var end_timer: Timer = $EndTimer

var _targets: Array[Node] = []
var _dps: int = 0
var _radius: float = 96.0
var _total_duration: float = 2.0
var _started := false

func _ready() -> void:
	# sécurité signaux
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	# timers
	if tick_timer:
		tick_timer.one_shot = false
		tick_timer.wait_time = tick_interval
		if not tick_timer.timeout.is_connected(_on_tick):
			tick_timer.timeout.connect(_on_tick)

	if end_timer:
		end_timer.one_shot = true
		if not end_timer.timeout.is_connected(_start_end_phase):
			end_timer.timeout.connect(_start_end_phase)

	# vfx
	if vfx:
		vfx.play("start")
		if not vfx.animation_finished.is_connected(_on_anim_finished):
			vfx.animation_finished.connect(_on_anim_finished)

	# ✅ Auto-start (pour test “posé dans la map”)
	if auto_start and not _started:
		setup(auto_radius, auto_dps, auto_total_duration)

# API simple : à appeler au spawn (missile impact)
func setup(radius: float, dps: int, total_duration: float) -> void:
	_started = true

	_radius = radius
	_dps = maxi(dps, 0)
	_total_duration = maxf(total_duration, 0.1)

	_apply_radius(_radius)
	_run_sequence()

func _apply_radius(r: float) -> void:
	# collision
	if col and col.shape is CircleShape2D:
		(col.shape as CircleShape2D).radius = r
	else:
		# si tu as oublié de mettre une CircleShape2D
		push_warning("[FireZone] CollisionShape2D doit avoir une CircleShape2D pour régler le radius.")

	# visuel (scale)
	if vfx and base_visual_radius_px > 1.0:
		var s: float = r / base_visual_radius_px
		vfx.scale = Vector2(s, s)

func _run_sequence() -> void:
	# si pas de vfx => on fait simple
	if not vfx:
		if tick_timer: tick_timer.start()
		if end_timer: end_timer.start(maxf(0.05, _total_duration))
		return

	# phase 1 : start
	vfx.play("start")
	# (la suite se fait dans _on_anim_finished)

func _get_anim_duration(anim_name: StringName) -> float:
	if not vfx:
		return 0.0
	var sf := vfx.sprite_frames
	if not sf or not sf.has_animation(anim_name):
		return 0.0
	var fps := sf.get_animation_speed(anim_name)
	if fps <= 0.0:
		return 0.0
	var frames := sf.get_frame_count(anim_name)
	return float(frames) / float(fps)

func _on_anim_finished() -> void:
	if not vfx:
		return

	if vfx.animation == "start":
		# phase 2 : burn (loop)
		vfx.play("burn")
		if tick_timer: tick_timer.start()

		# burn_duration = total - start_duration - end_anim_time
		var start_time := _get_anim_duration(&"start")
		var burn_time: float = maxf(0.0, _total_duration - start_time - end_anim_time)
		if end_timer: end_timer.start(burn_time)

	elif vfx.animation == "end":
		queue_free()

func _start_end_phase() -> void:
	# stop les ticks quand ça commence à se dissiper
	if tick_timer and not tick_timer.is_stopped():
		tick_timer.stop()

	if vfx:
		vfx.play("end")
	else:
		queue_free()

func _on_tick() -> void:
	if _dps <= 0:
		return

	# nettoyage invalides
	for i in range(_targets.size() - 1, -1, -1):
		var t := _targets[i]
		if t == null or not is_instance_valid(t) or not t.is_inside_tree():
			_targets.remove_at(i)

	# dégâts
	for t in _targets:
		if t and is_instance_valid(t) and t.has_method("apply_damage"):
			t.apply_damage(_dps)

func _on_body_entered(b: Node) -> void:
	if debug_print_enter_exit:
		print("[FireZone] body_entered:", b)

	if b and b.is_in_group("Enemy"):
		if not _targets.has(b):
			_targets.append(b)

func _on_body_exited(b: Node) -> void:
	if debug_print_enter_exit:
		print("[FireZone] body_exited:", b)

	_targets.erase(b)
