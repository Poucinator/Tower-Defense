# res://scene/tower/missile_tower.gd
extends StaticBody2D

# --- Tir ---
@export var fire_interval: float = 1.2
@export var missile_speed: float = 420.0
@export var rotation_speed: float = 4.5
@export var can_target_flying: bool = false   # 🚫 ne vise pas les volants

# --- Dégâts / Zone ---
@export var missile_damage: int = 30
@export var splash_radius: float = 72.0
@export var splash_falloff: float = 0.3

# --- Nœuds ---
@export var detector_path: NodePath
@export var muzzle_path: NodePath

# --- Upgrade ---
@export var upgrade_scene: PackedScene
@export var upgrade_cost: int = 70
@export var upgrade_icon: Texture2D
@export var tower_tier: int = 1

const MISSILE_SCN := preload("res://scene/projectile/missile.tscn")

var detector: Area2D
var muzzle: Node2D
var shoot_timer: Timer
var curr_targets: Array[Node2D] = []
var current_target: Node2D = null
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

@export var click_cooldown_ms := 180
var _click_ready_at_ms := 0
var _menu_ref: Node = null

# ============================================================
#                 BUFFS DÉGÂTS (Barracks aura)
# ============================================================
var _damage_mult_sources: Dictionary = {} # source_id -> float

func set_damage_buff(source_id: StringName, mult: float) -> void:
	if mult <= 1.0:
		_damage_mult_sources.erase(source_id)
	else:
		_damage_mult_sources[source_id] = mult

func get_damage_mult() -> float:
	var m := 1.0
	for v in _damage_mult_sources.values():
		m *= float(v)
	return m


func _ready() -> void:
	add_to_group("Tower") # ✅ pour être cible du buff de Barracks

	detector = get_node_or_null(detector_path)
	muzzle   = get_node_or_null(muzzle_path)

	input_pickable = true

	if anim:
		anim.play("idle")
		if not anim.animation_finished.is_connected(_on_anim_finished):
			anim.animation_finished.connect(_on_anim_finished)

	if detector:
		if detector.body_entered.is_connected(_on_tower_body_entered):
			detector.body_entered.disconnect(_on_tower_body_entered)
		detector.body_entered.connect(_on_tower_body_entered)

		if detector.body_exited.is_connected(_on_tower_body_exited):
			detector.body_exited.disconnect(_on_tower_body_exited)
		detector.body_exited.connect(_on_tower_body_exited)

	shoot_timer = Timer.new()
	shoot_timer.wait_time = fire_interval
	shoot_timer.one_shot = false
	shoot_timer.autostart = true
	add_child(shoot_timer)
	if not shoot_timer.timeout.is_connected(_on_shoot_timer_timeout):
		shoot_timer.timeout.connect(_on_shoot_timer_timeout)

	_click_ready_at_ms = Time.get_ticks_msec() + click_cooldown_ms


func _process(delta: float) -> void:
	if current_target and is_instance_valid(current_target) and current_target.is_inside_tree():
		var aim_angle := (current_target.global_position - global_position).angle()
		rotation = lerp_angle(rotation, aim_angle, rotation_speed * delta)
	elif anim and anim.animation != "idle":
		anim.play("idle")


# ---------- Filtrage des cibles ----------
func _is_valid_target(e: Node2D) -> bool:
	if e == null or not is_instance_valid(e):
		return false
	if ("is_flying" in e) and e.is_flying and not can_target_flying:
		return false
	return true


# -------- Clic -> menu upgrade --------
func _input_event(_vp, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Time.get_ticks_msec() < _click_ready_at_ms:
			return
		_open_upgrade_menu()


func _open_upgrade_menu() -> void:
	if upgrade_scene == null:
		return

	var next_tier := tower_tier + 1
	var tower_id: StringName = &"missile"

	if Game and Game.has_method("can_upgrade_tower_to"):
		if not Game.can_upgrade_tower_to(tower_id, next_tier):
			print("[MissileTower] Upgrade vers MK%d verrouillé (run=%d / labo[%s]=%d)" % [
				next_tier,
				Game.max_tower_tier,
				String(tower_id),
				Game.get_tower_unlocked_tier(tower_id)
			])
			return
	else:
		if "max_tower_tier" in Game and next_tier > Game.max_tower_tier:
			print("[MissileTower] Upgrade vers MK%d verrouillé (max_tower_tier=%d)" % [next_tier, Game.max_tower_tier])
			return

	if _menu_ref and is_instance_valid(_menu_ref):
		_menu_ref.queue_free()
		_menu_ref = null

	var menu := preload("res://ui/tower_menu.tscn").instantiate()
	get_tree().current_scene.add_child(menu)
	menu.setup(upgrade_icon, upgrade_cost, global_position, self)
	menu.option_chosen.connect(_on_upgrade_clicked, CONNECT_ONE_SHOT)
	_menu_ref = menu


func _on_upgrade_clicked() -> void:
	if "is_selling_mode" in Game and Game.is_selling_mode:
		return
	if not _try_spend(upgrade_cost) or upgrade_scene == null:
		return

	var parent := get_parent()
	var new_tower := upgrade_scene.instantiate() as Node2D
	if new_tower == null:
		return

	var slot := _find_build_slot_under_me()
	if slot:
		if slot.has_method("clear_if"):
			slot.call("clear_if", self)
		if slot.has_method("set_occupied"):
			slot.call("set_occupied", new_tower)

	parent.add_child(new_tower)
	new_tower.global_position = global_position
	new_tower.rotation = rotation

	if "_click_ready_at_ms" in new_tower:
		new_tower._click_ready_at_ms = Time.get_ticks_msec() + click_cooldown_ms

	queue_free()


# -------- Détection / Tir --------
func _on_tower_body_entered(b: Node2D) -> void:
	if b.is_in_group("Enemy") and _is_valid_target(b):
		curr_targets.append(b)

func _on_tower_body_exited(b: Node2D) -> void:
	if b.is_in_group("Enemy"):
		curr_targets.erase(b)
		if b == current_target:
			current_target = null

func _on_shoot_timer_timeout() -> void:
	if current_target == null \
			or not is_instance_valid(current_target) \
			or not (current_target in curr_targets) \
			or not _is_valid_target(current_target):
		current_target = _choose_target()
	if current_target:
		_shoot_at(current_target)

func _choose_target() -> Node2D:
	var list: Array[Node2D] = []
	for e in curr_targets:
		if is_instance_valid(e) and e.is_inside_tree() and _is_valid_target(e):
			list.append(e)
	if list.is_empty():
		return null

	var best := list[0]
	var best_prog := _progress_of(best)
	for e in list:
		var p := _progress_of(e)
		if p > best_prog:
			best = e
			best_prog = p
	return best

func _progress_of(enemy: Node2D) -> float:
	var pf := enemy.get_parent()
	if pf is PathFollow2D:
		return (pf as PathFollow2D).progress
	return 0.0


func _shoot_at(target: Node2D) -> void:
	if anim:
		anim.play("shoot")

	var m := MISSILE_SCN.instantiate() as CharacterBody2D
	if m == null:
		return

	# spawn
	var spawn_pos: Vector2 = global_position
	if muzzle != null:
		spawn_pos = muzzle.global_position
	m.global_position = spawn_pos

	get_parent().add_child(m)

	# pousser réglages généraux
	if "speed" in m:
		m.speed = missile_speed
	if "splash_falloff" in m:
		m.splash_falloff = splash_falloff

	# ✅ dégâts buffés par l'aura Barracks (et autres sources futures)
	var dmg := int(round(float(missile_damage) * get_damage_mult()))

	# fire
	if m.has_method("fire_at"):
		# fire_at(target_pos, damage_override, radius_override)
		m.call("fire_at", target.global_position, dmg, splash_radius)
	elif m.has_method("configure"):
		# (si un jour tu ajoutes un configure)
		m.call("configure", missile_speed, dmg, splash_radius, splash_falloff)
		m.call("fire_at", target.global_position)


func _on_anim_finished() -> void:
	if anim and anim.animation == "shoot":
		anim.play("idle")


# -------- Utils --------
func _try_spend(amount: int) -> bool:
	if "try_spend" in Game:
		return Game.try_spend(amount)
	if "gold" in Game and Game.gold >= amount:
		Game.gold -= amount
		if Game.has_signal("gold_changed"):
			Game.gold_changed.emit(Game.gold)
		return true
	return false


func _find_build_slot_under_me() -> Node:
	var space := get_world_2d().direct_space_state
	var prm := PhysicsPointQueryParameters2D.new()
	prm.position = global_position
	prm.collide_with_areas = true
	prm.collide_with_bodies = true
	var hits: Array[Dictionary] = space.intersect_point(prm, 16)
	for hit in hits:
		var n: Node = hit.get("collider") as Node
		if n and n.is_in_group("BuildSlot"):
			return n
		if n:
			var p: Node = n.get_parent()
			if p and p.is_in_group("BuildSlot"):
				return p
	return null
