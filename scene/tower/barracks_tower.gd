extends StaticBody2D

# --- Marines ---
@export var marine_scene: PackedScene
@export var marine_count: int = 3
@export var ring_radius: float = 44.0
@export var move_speed: float = 100.0

# --- Respawn (NEW) ---
@export var respawn_delay: float = 5.0
var respawn_timer: Timer
var _pending_respawns: int = 0

# --- Upgrade ---
@export var upgrade_scene: PackedScene
@export var upgrade_cost: int = 100
@export var upgrade_icon: Texture2D

# --- Références ---
@onready var rally: Node2D = null
var _marines: Array[Node] = []
var path_node: Path2D = null

# --- Sélection ---
var selected: bool = false
@export var max_rally_distance: float = 200.0

# --- Feedback visuel ---
var select_circle: ColorRect

# --- Menu ---
@export var click_cooldown_ms := 180
var _click_ready_at_ms := 0
var _menu_ref: Node = null

func _ready() -> void:
	add_to_group("Barracks")
	_click_ready_at_ms = Time.get_ticks_msec() + click_cooldown_ms

	if has_node("Rally"):
		rally = $Rally
	else:
		rally = Node2D.new()
		rally.name = "Rally"
		add_child(rally)
		rally.position = Vector2.ZERO

	select_circle = ColorRect.new()
	select_circle.color = Color(0,1,0,0.3)
	select_circle.size = Vector2(80,80)
	select_circle.position = Vector2(-40,-40)
	select_circle.visible = false
	add_child(select_circle)

	if marine_scene == null:
		push_error("[Barracks] 'marine_scene' NON assignée")
		return

	# NEW : respawn timer
	respawn_timer = Timer.new()
	respawn_timer.one_shot = true
	add_child(respawn_timer)
	respawn_timer.timeout.connect(_on_respawn_timer_timeout)

	call_deferred("_spawn_marines")
	set_process_unhandled_input(true)
	tree_exited.connect(_on_tree_exited)  # ✅ auto cleanup quand la tour quitte la scène
# ========================
#       PATH
# ========================
func set_path(p: Path2D) -> void:
	path_node = p
	print("[Barracks] Path reçu =", path_node)

func _get_spawn_point() -> Vector2:
	if path_node and path_node.curve:
		var local: Vector2 = path_node.curve.get_closest_point(global_position)
		return path_node.global_transform * local
	return global_position

func _spawn_marines() -> void:
	var container: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	if container == null:
		container = self

	var spawn_origin := _get_spawn_point()
	var offsets: Array[Vector2] = []
	for i in marine_count:
		var ang := TAU * float(i) / float(max(1, marine_count))
		offsets.append(Vector2.RIGHT.rotated(ang) * ring_radius)

	for off in offsets:
		var m := marine_scene.instantiate()
		if m:
			container.add_child(m)
			if "rally" in m: m.rally = rally
			if "barrack" in m: m.barrack = self
			m.slot_offset = off
			m.global_position = spawn_origin + off
			_marines.append(m)

# ========================
#       RALLY MOVE
# ========================
func set_rally_position(world_pos: Vector2) -> void:
	var pos := world_pos
	if path_node and path_node.curve:
		var local: Vector2 = path_node.curve.get_closest_point(world_pos)
		pos = path_node.global_transform * local

	if global_position.distance_to(pos) > max_rally_distance:
		print("[Barracks] Trop loin !")
		return

	rally.global_position = pos

	for m in _marines:
		if m and is_instance_valid(m):
			var offset: Vector2 = m.slot_offset
			var target: Vector2 = rally.global_position + offset

			m.is_moving = true
			if m.has_node("AnimatedSprite2D"):
				var anim = m.get_node("AnimatedSprite2D")
				anim.flip_h = target.x < m.global_position.x
				anim.play("walk")

			var dist = m.global_position.distance_to(target)
			var duration = dist / move_speed
			var tw := create_tween()
			tw.tween_property(m, "global_position", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.finished.connect(func ():
				if m and is_instance_valid(m):
					m.is_moving = false
					if m.has_node("AnimatedSprite2D"):
						var anim = m.get_node("AnimatedSprite2D")
						anim.play("idle")
			)

# ========================
#   Respawn system (NEW)
# ========================
func notify_marine_dead(marine: Node) -> void:
	_marines.erase(marine)
	_pending_respawns += 1
	if respawn_timer.is_stopped():
		respawn_timer.start(respawn_delay)

func _on_respawn_timer_timeout() -> void:
	if _pending_respawns > 0 and _marines.size() < marine_count:
		var spawn_origin := _get_spawn_point()
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * ring_radius

		var m := marine_scene.instantiate()
		if m:
			get_parent().add_child(m)
			m.global_position = spawn_origin + offset
			if "rally" in m: m.rally = rally
			if "barrack" in m: m.barrack = self
			m.slot_offset = offset
			_marines.append(m)

		_pending_respawns -= 1

	if _pending_respawns > 0:
		respawn_timer.start(respawn_delay)

# ========================
#       INPUT
# ========================
func _unhandled_input(event: InputEvent) -> void:
	if selected:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			set_rally_position(get_global_mouse_position())
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			deselect_group()

# ========================
#   SELECTION VISUELLE
# ========================
func select_group() -> void:
	for b in get_tree().get_nodes_in_group("Barracks"):
		if b != self:
			b.deselect_group()
	selected = true
	select_circle.visible = true

func deselect_group() -> void:
	selected = false
	select_circle.visible = false

func _input_event(_vp, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Anti-clic immédiat après la pose
		if Time.get_ticks_msec() < _click_ready_at_ms:
			return
		_open_upgrade_menu()


# ========================
#       UPGRADE
# ========================
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

	# Nettoyer les anciens marines avant la transition
	for m in _marines:
		if m and is_instance_valid(m):
			m.queue_free()
	_marines.clear()

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
		if n and n.is_in_group("BuildSlot"): return n
		if n and n.get_parent() and n.get_parent().is_in_group("BuildSlot"):
			return n.get_parent()
	return null

# ============================================================
#          AUTO-CLEANUP : suppression des marines
# ============================================================
func _on_tree_exited() -> void:
	# Si la tour est retirée de la scène (vente, destruction, etc.)
	if _marines.is_empty():
		return
	for m in _marines:
		if m and is_instance_valid(m):
			m.queue_free()
	_marines.clear()
