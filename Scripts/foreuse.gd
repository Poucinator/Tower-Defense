extends Node2D

# --- Références ---
@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var hp_bar: Range          = get_node_or_null("HealthBar")
@onready var aggro: Area2D          = get_node_or_null("Aggro")

const EXPLOSION_SCENE: PackedScene = preload("res://fx/explosion_small.tscn")

# --- Réglages ---
@export var max_hp: int = 40
@export var engage_radius: float = 96.0

var hp: int
var is_dead: bool = false

signal drill_destroyed(drill: Node)

# --- Extraction / départ ---
@export var leave_threshold: int = 100
const DBG_EXIT := true

@onready var exit_area: Area2D = get_node_or_null("ExitArea")
@onready var exit_sprite: Sprite2D = get_node_or_null("ExitArea/ExitSprite")

var _exit_unlocked := false

# --- FX (pulse / glow / float) ---
@export var exit_pulse_scale: float = 1.08
@export var exit_pulse_time: float = 0.6
@export var exit_glow_strength: float = 1.25
@export var exit_float_pixels: float = 4.0

var _exit_tween: Tween = null
var _exit_base_scale: Vector2 = Vector2.ONE
var _exit_base_modulate: Color = Color(1, 1, 1, 1)
var _exit_base_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("Drill")

	# HP init
	hp = max_hp
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
		hp_bar.visible = true

	# Aggro
	if aggro:
		var cs := aggro.get_node_or_null("CollisionShape2D")
		if cs and cs.shape is CircleShape2D:
			(cs.shape as CircleShape2D).radius = engage_radius

		if not aggro.body_entered.is_connected(_on_body_entered):
			aggro.body_entered.connect(_on_body_entered)
		if not aggro.body_exited.is_connected(_on_body_exited):
			aggro.body_exited.connect(_on_body_exited)

	# Anim
	if anim:
		anim.play("idle")

	# Exit button init
	_setup_exit_button()

	# État initial selon cristaux actuels
	var init_crystals := 0
	if "crystals" in Game:
		init_crystals = int(Game.get("crystals"))
	_on_crystals_changed(init_crystals)

	# Écoute l'évolution des cristaux
	if Game.has_signal("crystals_changed"):
		if not Game.crystals_changed.is_connected(_on_crystals_changed):
			Game.crystals_changed.connect(_on_crystals_changed)
			if DBG_EXIT:
				print("[DRILL/EXIT] connected Game.crystals_changed")
	else:
		if DBG_EXIT:
			print("[DRILL/EXIT] WARNING: Game has no signal crystals_changed")


func _setup_exit_button() -> void:
	if exit_area:
		exit_area.visible = false
		exit_area.monitoring = true
		exit_area.input_pickable = true

		if not exit_area.input_event.is_connected(_on_exit_input_event):
			exit_area.input_event.connect(_on_exit_input_event)

		if DBG_EXIT:
			print("[DRILL/EXIT] ExitArea ready. visible=false threshold=", leave_threshold)
	else:
		if DBG_EXIT:
			print("[DRILL/EXIT] WARNING: ExitArea node not found (check node name)")

	# Base values pour FX (même si exit_area existe, on peut initialiser)
	if exit_sprite:
		_exit_base_scale = exit_sprite.scale
		_exit_base_modulate = exit_sprite.modulate
		_exit_base_pos = exit_sprite.position
		if DBG_EXIT:
			print("[DRILL/EXIT] ExitSprite found. base_scale=", _exit_base_scale, " base_pos=", _exit_base_pos)
	else:
		if DBG_EXIT:
			print("[DRILL/EXIT] WARNING: ExitSprite not found (check ExitArea/ExitSprite)")


# =========================================================
#             Cristaux -> déblocage du départ
# =========================================================
func _on_crystals_changed(v: int) -> void:
	if DBG_EXIT:
		print("[DRILL/EXIT] crystals=", v, " unlocked=", _exit_unlocked)

	if _exit_unlocked:
		return

	if v >= leave_threshold:
		_exit_unlocked = true
		if exit_area:
			exit_area.visible = true
			_start_exit_fx()
			if DBG_EXIT:
				print("[DRILL/EXIT] ✅ Extraction unlocked! ExitArea visible=", exit_area.visible)
		else:
			if DBG_EXIT:
				print("[DRILL/EXIT] ERROR: unlocked but exit_area is null")


func _on_exit_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if is_dead:
		return
	if not _exit_unlocked:
		if DBG_EXIT:
			print("[DRILL/EXIT] click ignored (not unlocked)")
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if DBG_EXIT:
			print("[DRILL/EXIT] 🖱️ Exit clicked -> request end level")
		_request_end_level()


func _request_end_level() -> void:
	var amount := 0
	if "crystals" in Game:
		amount = int(Game.get("crystals"))

	if DBG_EXIT:
		print("[DRILL/EXIT] end requested, crystals=", amount)

	var ld := get_tree().get_first_node_in_group("LevelDirector")
	if ld and ld.has_method("end_level_victory"):
		ld.call("end_level_victory", amount)
	else:
		push_warning("[DRILL/EXIT] LevelDirector introuvable ou méthode end_level_victory manquante.")


# =========================================================
#                 FX Exit
# =========================================================
func _start_exit_fx() -> void:
	if not exit_sprite:
		if DBG_EXIT:
			print("[DRILL/EXIT] FX aborted: exit_sprite is null")
		return

	# éviter double tween
	if _exit_tween and _exit_tween.is_valid():
		_exit_tween.kill()

	# reset propre
	exit_sprite.scale = _exit_base_scale
	exit_sprite.modulate = _exit_base_modulate
	exit_sprite.position = _exit_base_pos

	var up_scale := _exit_base_scale * exit_pulse_scale
	var up_color := _exit_base_modulate * exit_glow_strength
	var up_pos := _exit_base_pos + Vector2(0, -exit_float_pixels)

	_exit_tween = create_tween()
	_exit_tween.set_loops()
	_exit_tween.set_trans(Tween.TRANS_SINE)
	_exit_tween.set_ease(Tween.EASE_IN_OUT)

	# UP
	_exit_tween.tween_property(exit_sprite, "position", up_pos, exit_pulse_time)
	_exit_tween.parallel().tween_property(exit_sprite, "scale", up_scale, exit_pulse_time)
	_exit_tween.parallel().tween_property(exit_sprite, "modulate", up_color, exit_pulse_time)

	# DOWN
	_exit_tween.tween_property(exit_sprite, "position", _exit_base_pos, exit_pulse_time)
	_exit_tween.parallel().tween_property(exit_sprite, "scale", _exit_base_scale, exit_pulse_time)
	_exit_tween.parallel().tween_property(exit_sprite, "modulate", _exit_base_modulate, exit_pulse_time)

	if DBG_EXIT:
		print("[DRILL/EXIT] FX started")


func _stop_exit_fx() -> void:
	if _exit_tween and _exit_tween.is_valid():
		_exit_tween.kill()
	_exit_tween = null

	if exit_sprite:
		exit_sprite.scale = _exit_base_scale
		exit_sprite.modulate = _exit_base_modulate
		exit_sprite.position = _exit_base_pos

	if DBG_EXIT:
		print("[DRILL/EXIT] FX stopped")


# =========================================================
#                 Dégâts subis / mort
# =========================================================
func take_damage(amount: int) -> void:
	if is_dead:
		return

	hp -= amount
	if hp_bar:
		hp_bar.value = clampi(hp, 0, max_hp)

	if hp <= 0:
		_die()
	else:
		_hit_flash()


func _hit_flash() -> void:
	if anim:
		var t := create_tween()
		t.tween_property(anim, "modulate", Color(1, 0.7, 0.7), 0.06)
		t.tween_property(anim, "modulate", Color(1, 1, 1), 0.06)


func _play_death_explosions() -> void:
	var offsets: Array[Vector2] = [
		Vector2(0, 0),
		Vector2(0, 20),
		Vector2(18, -10),
		Vector2(-18, -10)
	]
	var delay := 0.5
	var radius := 80.0

	for offset in offsets:
		var e = EXPLOSION_SCENE.instantiate()
		if e:
			if get_parent():
				get_parent().add_child(e)
			else:
				add_child(e)

			e.global_position = global_position + offset
			if e.has_method("play"):
				e.call("play", radius)

		await get_tree().create_timer(delay).timeout


func _die() -> void:
	if is_dead:
		return
	is_dead = true

	_stop_exit_fx()

	if exit_area:
		exit_area.visible = false

	# Libérer les ennemis engagés
	for e in get_tree().get_nodes_in_group("Enemy"):
		if e == null or not is_instance_valid(e):
			continue
		if e.has_method("release_engage") and "engaged_by" in e and e.engaged_by == self:
			e.call("release_engage", self)

	if anim:
		anim.play("dead")

	# ✅ Explosions d'abord
	await _play_death_explosions()

	# ✅ petite attente cinématique
	await get_tree().create_timer(1.0).timeout

	# ✅ Seulement maintenant on déclenche la défaite
	emit_signal("drill_destroyed", self)

	queue_free()


# =========================================================
#                 Gestion des ennemis proches
# =========================================================
func _on_body_entered(b: Node) -> void:
	if is_dead:
		return
	if not b.is_in_group("Enemy"):
		return

	if b.has_method("request_engage"):
		b.call("request_engage", self)

func _on_body_exited(_b: Node) -> void:
	pass
