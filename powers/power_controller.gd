extends Node2D
class_name PowerController

# =========================================================
#                 EXPORTS : POUVOIRS EXISTANTS
# =========================================================
@export var freeze_zone_scene: PackedScene = preload("res://powers/freeze_zone.tscn")
@export_range(1.0, 120.0, 0.5, "suffix:s") var freeze_cooldown: float = 10.0
@export var ghost_radius: float = 96.0

@export_range(1.0, 120.0, 0.5, "suffix:s") var heal_cooldown: float = 20.0

# =========================================================
#                 EXPORTS : NOUVEAU POUVOIR
# =========================================================
@export var summon_zone_scene: PackedScene = preload("res://powers/summon_zone.tscn")
@export var summon_cooldown: float = 25.0
@export var summon_marine_scene: PackedScene = preload("res://units/marine.tscn")
@export var summon_marine_count: int = 3
@export var summon_duration: float = 10.0
@export_range(0.0, 10.0, 0.5, "suffix:s") var heal_invincible_duration: float = 3.0



# =========================================================
#                     VARIABLES INTERNES
# =========================================================
var _placing_freeze := false
var _placing_summon := false
var _cooldown_left := 0.0
var _heal_cooldown_left := 0.0
var _summon_cooldown_left := 0.0
var _ghost: Node2D

# =========================================================
#                     READY
# =========================================================
func _ready() -> void:
	set_process(true)
	set_process_unhandled_input(true)

	# Création du fantôme pour le pouvoir de gel
	_ghost = Node2D.new()
	_ghost.set_script(load("res://powers/freeze_ghost.gd"))
	add_child(_ghost)
	_ghost.visible = false
	if _ghost.has_method("set_radius"):
		_ghost.call("set_radius", ghost_radius)

# =========================================================
#                    PROCESS
# =========================================================
func _process(delta: float) -> void:
	# --- Cooldowns
	if _cooldown_left > 0.0:
		_cooldown_left = max(0.0, _cooldown_left - delta)

	if _heal_cooldown_left > 0.0:
		_heal_cooldown_left = max(0.0, _heal_cooldown_left - delta)

	if _summon_cooldown_left > 0.0:
		_summon_cooldown_left = max(0.0, _summon_cooldown_left - delta)

	# --- Placement fantôme du pouvoir Gel
	if _placing_freeze and _ghost:
		_ghost.global_position = get_global_mouse_position()

# =========================================================
#                     INPUT GÉNÉRAL
# =========================================================
func _unhandled_input(event: InputEvent) -> void:
	# ---------- GEL ----------
	if _placing_freeze:
		if event is InputEventMouseButton and event.pressed:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_place_freeze_at(get_global_mouse_position())
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				_cancel_place()
				get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_cancel_place()
			get_viewport().set_input_as_handled()

	# ---------- INVOCATION ----------
	if _placing_summon:
		if event is InputEventMouseButton and event.pressed:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_place_summon_at(get_global_mouse_position())
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				_cancel_summon_place()
				get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_cancel_summon_place()
			get_viewport().set_input_as_handled()

# =========================================================
#                     GEL DE ZONE
# =========================================================
func start_place_freeze() -> void:
	if _cooldown_left > 0.0 or _placing_freeze:
		return
	_placing_freeze = true
	if _ghost:
		_ghost.visible = true
	print("[Power] Placement d'une zone de gel...")

func _place_freeze_at(pos: Vector2) -> void:
	if not freeze_zone_scene:
		_cancel_place()
		return
	var z := freeze_zone_scene.instantiate()
	z.global_position = pos
	get_tree().current_scene.add_child(z)
	print("[Power] Zone de gel activée à ", pos)
	_cancel_place()
	_cooldown_left = freeze_cooldown

func _cancel_place() -> void:
	_placing_freeze = false
	if _ghost:
		_ghost.visible = false

func get_freeze_cooldown_left() -> float:
	return _cooldown_left

func is_freeze_ready() -> bool:
	return _cooldown_left <= 0.0

func set_freeze_cooldown(v: float) -> void:
	freeze_cooldown = v

# =========================================================
#                     SOIN GLOBAL
# =========================================================
func activate_heal_all() -> void:
	if _heal_cooldown_left > 0.0:
		return
	_heal_cooldown_left = heal_cooldown

	for m in get_tree().get_nodes_in_group("Marine"):
		if m and is_instance_valid(m) and "hp" in m and "max_hp" in m:
			# Soins
			m.hp = m.max_hp
			if m.hp_bar:
				m.hp_bar.value = m.max_hp
			if m.has_node("AnimatedSprite2D"):
				var anim = m.get_node("AnimatedSprite2D")
				if anim.animation != "idle":
					anim.play("idle")

			# ---- INVINCIBILITÉ TEMPORAIRE ----
			if heal_invincible_duration > 0.0 and m.has_method("set_invincible_for"):
				m.set_invincible_for(heal_invincible_duration)

	print("[Power] Tous les marines ont été soignés et sont invincibles pendant %s s !" % heal_invincible_duration)

func get_heal_cooldown_left() -> float:
	return _heal_cooldown_left

func is_heal_ready() -> bool:
	return _heal_cooldown_left <= 0.0

func set_heal_cooldown(v: float) -> void:
	heal_cooldown = v


# =========================================================
#                     INVOCATION DE MARINES
# =========================================================
func start_place_summon() -> void:
	if _summon_cooldown_left > 0.0 or _placing_summon:
		return
	_placing_summon = true
	print("[Power] Placement de marines tactiques...")

func _place_summon_at(pos: Vector2) -> void:
	if not summon_zone_scene:
		_cancel_summon_place()
		return

	var z := summon_zone_scene.instantiate()
	z.global_position = pos
	z.marine_scene = summon_marine_scene
	z.marine_count = summon_marine_count
	z.lifetime = summon_duration

	get_tree().current_scene.add_child(z)
	print("[Power] Marines déployés à ", pos)

	_cancel_summon_place()
	_summon_cooldown_left = summon_cooldown

func _cancel_summon_place() -> void:
	_placing_summon = false

func get_summon_cooldown_left() -> float:
	return _summon_cooldown_left

func is_summon_ready() -> bool:
	return _summon_cooldown_left <= 0.0

func set_summon_cooldown(v: float) -> void:
	summon_cooldown = v
