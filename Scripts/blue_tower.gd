# res://scene/tower/blue_tower.gd
extends StaticBody2D

# ---------- Réglages tir ----------
@export var fire_interval: float = 0.5
@export var bullet_speed: float = 300.0
@export var rotation_speed: float = 5.0
@export var can_target_flying: bool = true   # Blue Tower peut viser les volants

# ✅ Dégâts gérés ICI (plus simple à équilibrer par MK / buffs)
@export var bullet_damage: int = 6

# ---------- Préparation pouvoir futur : slow ----------
# (désactivé par défaut -> pas de régression)
@export var slow_enabled: bool = false
@export_range(0.05, 0.95, 0.05) var slow_factor: float = 0.85   # 0.85 = -15% vitesse
@export_range(0.1, 10.0, 0.1) var slow_duration: float = 1.2    # en secondes
const SLOW_SOURCE_ID: StringName = &"gun_slow"

# ---------- Nœuds ----------
@export var detector_path: NodePath
@export var muzzle_path: NodePath

# ---------- Upgrade ----------
@export var upgrade_scene: PackedScene
@export var upgrade_cost: int = 40
@export var upgrade_icon: Texture2D

# Tier de la tour (MK1=1, MK2=2, MK3=3...)
@export var tower_tier: int = 1

const BULLET_SCN := preload("res://scene/tower/bluebullet.tscn")

var detector: Area2D
var muzzle: Node2D
var shoot_timer: Timer

var curr_targets: Array[Node2D] = []
var current_target: Node2D = null

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

# Anti-clic immédiatement après la pose
@export var click_cooldown_ms := 180
var _click_ready_at_ms := 0

# Référence sur un menu déjà ouvert (pour éviter les doublons)
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
	add_to_group("Tower") # ✅ nécessaire pour que Barracks puisse me choisir dans les 3 proches
	input_pickable = true # ✅ important : rendre la tour cliquable

	detector = get_node_or_null(detector_path)
	muzzle   = get_node_or_null(muzzle_path)

	
	if Game and Game.has_method("has_gun_slow"):
		slow_enabled = Game.has_gun_slow()
	if Game and Game.has_method("get_gun_slow_factor"):
		slow_factor = Game.get_gun_slow_factor()
	if Game and Game.has_method("get_gun_slow_duration"):
		slow_duration = Game.get_gun_slow_duration()

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


func _is_valid_target(e: Node2D) -> bool:
	if e == null or not is_instance_valid(e):
		return false
	if ("is_flying" in e) and e.is_flying and not can_target_flying:
		return false
	return true


# ---------- Clic : ouvrir le menu ----------
func _input_event(_vp, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Time.get_ticks_msec() < _click_ready_at_ms:
			return
		_open_upgrade_menu()


func _open_upgrade_menu() -> void:
	if upgrade_scene == null:
		return

	var next_tier := tower_tier + 1
	var tower_id: StringName = &"gun"

	if Game and Game.has_method("can_upgrade_tower_to"):
		if not Game.can_upgrade_tower_to(tower_id, next_tier):
			print("[BlueTower] Upgrade vers MK%d verrouillé (run=%d / labo[%s]=%d)" % [
				next_tier,
				Game.max_tower_tier,
				String(tower_id),
				Game.get_tower_unlocked_tier(tower_id)
			])
			return
	else:
		if "max_tower_tier" in Game and next_tier > Game.max_tower_tier:
			print("[BlueTower] Upgrade vers MK%d verrouillé (max_tower_tier=%d)" % [next_tier, Game.max_tower_tier])
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

	queue_free()


# ---------- Détection / tir ----------
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

	var b := BULLET_SCN.instantiate() as CharacterBody2D
	if b == null:
		return

	var spawn_pos := global_position
	if muzzle != null:
		spawn_pos = muzzle.global_position
	elif detector != null:
		spawn_pos = detector.global_position

	b.global_position = spawn_pos
	get_parent().add_child(b)

	# ✅ calc dégâts avec buffs (Barracks aura etc.)
	var dmg := int(round(float(bullet_damage) * get_damage_mult()))

	# ✅ on transmet tout à la bullet : vitesse / dégâts / slow (préparé)
	if b.has_method("configure"):
		b.call("configure", bullet_speed, dmg, slow_enabled, slow_factor, slow_duration, SLOW_SOURCE_ID)
		b.call("fire_at", target.global_position) # configure puis fire_at simple
	elif b.has_method("fire_at"):
		b.call("fire_at", target.global_position, dmg, bullet_speed, slow_enabled, slow_factor, slow_duration, SLOW_SOURCE_ID)
	else:
		if "speed" in b: b.speed = bullet_speed
		if "damage" in b: b.damage = dmg
		if "slow_enabled" in b: b.slow_enabled = slow_enabled
		if "slow_factor" in b: b.slow_factor = slow_factor
		if "slow_duration" in b: b.slow_duration = slow_duration
		if "slow_source_id" in b: b.slow_source_id = SLOW_SOURCE_ID
		if b.has_method("set_direction"):
			b.call("set_direction", (target.global_position - spawn_pos).normalized(), bullet_speed)


func _on_anim_finished() -> void:
	if anim and anim.animation == "shoot":
		anim.play("idle")


# ---------- Utilitaires ----------
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
