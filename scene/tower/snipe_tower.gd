# res://scene/tower/snipe_tower.gd
extends StaticBody2D

# --------- Tir / réglages snip ---------
@export var fire_interval: float = 1.4       # cadence plus lente
@export var bullet_speed: float = 520.0      # vitesse balle (si tu l'utilises dans la bullet)
@export var rotation_speed: float = 6.0
@export var bullet_damage: int = 30          # ✅ dégâts transmis à la balle (monte en MK2/MK3)

@export var detector_path: NodePath
@export var muzzle_path: NodePath

# --------- Upgrade (scalable) ---------
@export var upgrade_scene: PackedScene
@export var upgrade_cost: int = 60
@export var upgrade_icon: Texture2D

const BULLET_SCN := preload("res://scene/tower/snipe_bullet.tscn")

var detector: Area2D
var muzzle: Node2D
var shoot_timer: Timer
var curr_targets: Array[Node2D] = []
var current_target: Node2D = null
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

@export var click_cooldown_ms := 180
var _click_ready_at_ms := 0
var _menu_ref: Node = null

func _ready() -> void:
	detector = get_node_or_null(detector_path)
	muzzle   = get_node_or_null(muzzle_path)

	# Important pour que la tour soit cliquable
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
		var aim := (current_target.global_position - global_position).angle()
		rotation = lerp_angle(rotation, aim, rotation_speed * delta)
	elif anim and anim.animation != "idle":
		anim.play("idle")


# ---------- Clic : ouvrir le menu ----------
func _input_event(_vp, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Time.get_ticks_msec() < _click_ready_at_ms:
			return
		_open_upgrade_menu()


func _open_upgrade_menu() -> void:
	if upgrade_scene == null:
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




# --------- détection / tir ----------
func _on_tower_body_entered(b: Node2D) -> void:
	if b.is_in_group("Enemy"):
		curr_targets.append(b)

func _on_tower_body_exited(b: Node2D) -> void:
	if b.is_in_group("Enemy"):
		curr_targets.erase(b)
		if b == current_target:
			current_target = null

func _on_shoot_timer_timeout() -> void:
	if current_target == null or not is_instance_valid(current_target) or not (current_target in curr_targets):
		current_target = _choose_target()
	if current_target:
		_shoot_at(current_target)

func _choose_target() -> Node2D:
	var list: Array[Node2D] = []
	for e in curr_targets:
		if is_instance_valid(e) and e.is_inside_tree():
			list.append(e)
	if list.is_empty():
		return null

	# cible la plus avancée
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

	var spawn: Vector2 = global_position
	if muzzle != null:
		spawn = muzzle.global_position
	b.global_position = spawn
	get_parent().add_child(b)

	# ✅ On transmet les dégâts à la balle
	if b.has_method("fire_at"):
		# Convention : fire_at(target_pos: Vector2, override_damage: int = -1)
		b.call("fire_at", target.global_position, bullet_damage)
	elif "damage" in b:
		# fallback si ta balle n'a pas de fire_at optionnel
		b.damage = bullet_damage
		if b.has_method("set_direction_to"):
			b.call("set_direction_to", target.global_position)


func _on_anim_finished() -> void:
	if anim and anim.animation == "shoot":
		anim.play("idle")


# --------- utils ----------
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
