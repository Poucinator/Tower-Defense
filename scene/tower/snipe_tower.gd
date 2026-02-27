# res://scene/tower/snipe_tower.gd
extends StaticBody2D

# --------- Tir / réglages snipe ---------
@export var fire_interval: float = 1.4
@export var bullet_speed: float = 520.0
@export var rotation_speed: float = 6.0

# ✅ Dégâts de base (MK1/MK2/MK3) - les buffs s'appliquent dessus
@export var bullet_damage: int = 30

@export var detector_path: NodePath
@export var muzzle_path: NodePath
@export var can_target_flying: bool = false

# --------- Upgrade (scalable) ---------
@export var upgrade_scene: PackedScene
@export var upgrade_cost: int = 60
@export var upgrade_icon: Texture2D
@export var tower_tier: int = 1

const BULLET_SCN := preload("res://scene/tower/snipe_bullet.tscn")

var detector: Area2D
var muzzle: Node2D
var shoot_timer: Timer

var curr_targets: Array[Node2D] = []
var current_target: Node2D = null

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

# Anti-clic immédiatement après la pose
@export var click_cooldown_ms := 180
var _click_ready_at_ms := 0

# Menu + preview portée
var _menu_ref: Node = null
var _range_ring: RangeRing = null
var _range_watch_timer: Timer = null

# ============================================================
#                 BUFFS DÉGÂTS (Barracks aura)
# ============================================================
var _damage_mult_sources: Dictionary = {} # source_id -> float

func set_damage_buff(source_id: StringName, mult: float) -> void:
	# mult <= 1.0 => retire/neutralise cette source
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
	add_to_group("Tower") # ✅ pour que la Barracks puisse me choisir
	input_pickable = true
	set_process_input(true) # ✅ reçoit les clics même si l’UI les consomme ensuite

	detector = get_node_or_null(detector_path)
	muzzle   = get_node_or_null(muzzle_path)

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


# ---------- Filtrage des cibles ----------
func _is_valid_target(e: Node2D) -> bool:
	if e == null or not is_instance_valid(e):
		return false
	if ("is_flying" in e) and e.is_flying and not can_target_flying:
		return false
	return true


# ============================================================
#  INPUT : clic sur la tour -> menu + portée
# ============================================================
func _input_event(_vp, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Time.get_ticks_msec() < _click_ready_at_ms:
			return
		_open_upgrade_menu()


# ✅ Clic ailleurs : ferme cercle + menu si besoin (même si l'UI consomme le clic)
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var ring_visible := (_range_ring != null and is_instance_valid(_range_ring) and _range_ring.visible)
	var menu_alive := (_menu_ref != null and is_instance_valid(_menu_ref) and (_menu_ref as Node).is_inside_tree())
	if not ring_visible and not menu_alive:
		return

	var mouse_pos := get_global_mouse_position()

	# Si un menu est ouvert : on ferme SEULEMENT si clic hors "contenu menu" ET hors tour
	if menu_alive:
		if not _is_click_on_menu(mouse_pos) and not _is_click_on_self(mouse_pos):
			_hide_range_and_cleanup()
		return

	# Pas de menu (ex: MK3 / upgrade verrouillé / upgrade_scene null)
	if ring_visible and not _is_click_on_self(mouse_pos):
		_hide_range_and_cleanup()


# ============================================================
#  API "soft" pour forcer la fermeture depuis une autre tour
# ============================================================
func close_upgrade_ui() -> void:
	_hide_range_and_cleanup()

func hide_range_preview() -> void:
	_show_range(false)


# ============================================================
#  MENU + PORTÉE
# ============================================================
func _open_upgrade_menu() -> void:
	# ✅ Un seul cercle/menu à la fois : on ferme tous les autres "Tower"
	for t in get_tree().get_nodes_in_group("Tower"):
		if t == self or t == null or not is_instance_valid(t):
			continue
		if t.has_method("close_upgrade_ui"):
			t.call("close_upgrade_ui")
		elif t.has_method("hide_range_preview"):
			t.call("hide_range_preview")

	# Ferme proprement un ancien menu local
	_close_menu_only()

	# Affiche portée
	_show_range(true)

	# Si pas d'upgrade possible : portée seule
	if upgrade_scene == null:
		return

	var next_tier := tower_tier + 1
	var tower_id: StringName = &"snipe"

	if Game and Game.has_method("can_upgrade_tower_to"):
		if not Game.can_upgrade_tower_to(tower_id, next_tier):
			print("[SnipeTower] Upgrade vers MK%d verrouillé (run=%d / labo[%s]=%d)" % [
				next_tier,
				Game.max_tower_tier,
				String(tower_id),
				Game.get_tower_unlocked_tier(tower_id)
			])
			return
	else:
		if "max_tower_tier" in Game and next_tier > Game.max_tower_tier:
			print("[SnipeTower] Upgrade vers MK%d verrouillé (max_tower_tier=%d)" % [next_tier, Game.max_tower_tier])
			return

	var menu := preload("res://ui/tower_menu.tscn").instantiate()
	get_tree().current_scene.add_child(menu)
	menu.setup(upgrade_icon, upgrade_cost, global_position, self)
	menu.option_chosen.connect(_on_upgrade_clicked, CONNECT_ONE_SHOT)
	_menu_ref = menu

	_start_range_watch()


func _close_menu_only() -> void:
	if _range_watch_timer and is_instance_valid(_range_watch_timer):
		_range_watch_timer.stop()
		_range_watch_timer.queue_free()
		_range_watch_timer = null

	if _menu_ref and is_instance_valid(_menu_ref):
		_menu_ref.queue_free()
	_menu_ref = null


func _hide_range_and_cleanup() -> void:
	_close_menu_only()
	_show_range(false)


func _is_menu_visible() -> bool:
	if _menu_ref == null or not is_instance_valid(_menu_ref):
		return false
	if not (_menu_ref as Node).is_inside_tree():
		return false
	# Le menu peut se "cacher" par modulate/scale -> visible peut rester true.
	# Filet de sécurité uniquement.
	if _menu_ref is CanvasItem:
		return (_menu_ref as CanvasItem).visible
	return true


func _start_range_watch() -> void:
	if _range_watch_timer and is_instance_valid(_range_watch_timer):
		_range_watch_timer.stop()
		_range_watch_timer.queue_free()

	_range_watch_timer = Timer.new()
	_range_watch_timer.one_shot = false
	_range_watch_timer.wait_time = 0.1
	add_child(_range_watch_timer)

	_range_watch_timer.timeout.connect(func():
		if not _is_menu_visible():
			_hide_range_and_cleanup()
	)

	_range_watch_timer.start()


# ============================================================
#  PORTÉE : ring
# ============================================================
func _show_range(enable: bool) -> void:
	if enable:
		_ensure_range_ring()
		if _range_ring:
			_range_ring.visible = true
			_range_ring.queue_redraw()
	else:
		if _range_ring:
			_range_ring.visible = false


func _ensure_range_ring() -> void:
	if _range_ring and is_instance_valid(_range_ring):
		return

	var r := _get_detector_radius()
	if r <= 0.0:
		return

	_range_ring = RangeRing.new()
	_range_ring.radius = r
	_range_ring.z_index = -1
	_range_ring.visible = false
	add_child(_range_ring)


func _get_detector_radius() -> float:
	# 1) Priorité : detector exporté
	if detector and detector is Area2D:
		var cs := (detector as Area2D).get_node_or_null("CollisionShape2D") as CollisionShape2D
		if cs and cs.shape is CircleShape2D:
			return (cs.shape as CircleShape2D).radius

	# 2) Fallback : node nommé "Tower" (convention)
	var tower_area := get_node_or_null("Tower") as Area2D
	if tower_area:
		var cs2 := tower_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if cs2 and cs2.shape is CircleShape2D:
			return (cs2.shape as CircleShape2D).radius

	return 0.0


func _is_click_on_self(world_pos: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var prm := PhysicsPointQueryParameters2D.new()
	prm.position = world_pos
	prm.collide_with_areas = true
	prm.collide_with_bodies = true

	var hits: Array[Dictionary] = space.intersect_point(prm, 16)
	for hit: Dictionary in hits:
		var col: Object = hit.get("collider") as Object
		if col == self:
			return true

	return false


# ✅ "Dans le menu" = dans le contenu (panel/bouton), pas juste le root fullscreen transparent
func _is_click_on_menu(world_pos: Vector2) -> bool:
	if _menu_ref == null or not is_instance_valid(_menu_ref):
		return false
	if not (_menu_ref as Node).is_inside_tree():
		return false
	if not (_menu_ref is Control):
		return (_menu_ref is CanvasItem and (_menu_ref as CanvasItem).visible)

	var root: Control = _menu_ref as Control
	if not root.visible:
		return false

	var best: Control = _find_smallest_hit_control(root, world_pos)
	if best == null:
		return false
	if best == root:
		return false

	return true


func _find_smallest_hit_control(root: Control, world_pos: Vector2) -> Control:
	var stack: Array[Control] = [root]
	var best: Control = null
	var best_area: float = INF

	while not stack.is_empty():
		var c: Control = stack.pop_back() as Control
		if c == null or not is_instance_valid(c) or not c.visible:
			continue

		var rect: Rect2 = c.get_global_rect()
		if rect.has_point(world_pos):
			var area: float = rect.size.x * rect.size.y
			if area < best_area:
				best = c
				best_area = area

		for child in c.get_children():
			if child is Control:
				stack.append(child as Control)

	return best


class RangeRing extends Node2D:
	var radius: float = 64.0

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, Color(0.35, 0.65, 1.0, 0.12))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, Color(0.35, 0.65, 1.0, 0.35), 2.0)


# ============================================================
#  Upgrade
# ============================================================
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


# ============================================================
#  Tir
# ============================================================
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

	var spawn: Vector2 = global_position
	if muzzle != null:
		spawn = muzzle.global_position

	b.global_position = spawn
	get_parent().add_child(b)

	var dmg := int(round(float(bullet_damage) * get_damage_mult()))

	var extra_hits := 0
	if Game and Game.has_method("get_snipe_break_extra_hits"):
		extra_hits = int(Game.get_snipe_break_extra_hits())

	if b.has_method("configure"):
		b.call("configure", bullet_speed, dmg, extra_hits)
		if b.has_method("fire_at"):
			b.call("fire_at", target.global_position)
	elif b.has_method("fire_at"):
		b.call("fire_at", target.global_position, dmg, bullet_speed)
		if "extra_hits" in b:
			b.extra_hits = extra_hits
	else:
		if "damage" in b: b.damage = dmg
		if "speed" in b: b.speed = bullet_speed
		if "extra_hits" in b: b.extra_hits = extra_hits
		if b.has_method("set_direction_to"):
			b.call("set_direction_to", target.global_position)
		elif b.has_method("set_direction"):
			b.call("set_direction", (target.global_position - spawn).normalized(), bullet_speed)


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
