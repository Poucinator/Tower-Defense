# res://scene/tower/barracks_tower.gd
extends StaticBody2D

# --- Marines ---
@export var marine_scene: PackedScene
@export var marine_count: int = 3
@export var ring_radius: float = 44.0
@export var move_speed: float = 100.0

# --- Respawn ---
@export var respawn_delay: float = 5.0
var respawn_timer: Timer
var _pending_respawns: int = 0

# --- Upgrade ---
@export var upgrade_scene: PackedScene
@export var upgrade_cost: int = 100
@export var upgrade_icon: Texture2D
@export var tower_tier: int = 1   # MK1=1, MK2=2, MK3=3...

# ============================================================
#        BARRACKS AURA BUFF (labo) : runtime in-level
# ============================================================
@export var aura_radius: float = 520.0
@export var aura_target_count: int = 3
@export_range(0.1, 5.0, 0.1) var aura_refresh_interval: float = 0.6
@export_range(0.2, 5.0, 0.1) var aura_preview_duration: float = 2.0

# Source id UNIQUE par instance (sinon plusieurs barracks se remplacent)
var _aura_source_id: StringName
# Nom de node ring UNIQUE (sinon 2 barracks peuvent se marcher dessus visuellement)
var _ring_node_name: String

var _aura_timer: Timer
var _buffed_targets: Array[Node] = []

# --- Réception buff (si une autre barracks buff celle-ci) ---
var _damage_mult_sources: Dictionary = {} # source_id -> float

# --- Références ---
@onready var rally: Node2D = null
var _marines: Array[Node] = []
var path_node: Path2D = null

# --- Sélection ---
var selected: bool = false
@export var max_rally_distance: float = 200.0

# --- Feedback visuel ---
var select_circle: ColorRect

var _selected_marine: Node = null
# --- Menu ---
@export var click_cooldown_ms := 180
var _click_ready_at_ms := 0
var _menu_ref: Node = null


func _ready() -> void:
	add_to_group("Barracks")
	add_to_group("Tower") # ✅ pour être cible possible et cohérence globale
	input_pickable = true

	_click_ready_at_ms = Time.get_ticks_msec() + click_cooldown_ms

	# ✅ ids uniques par instance
	_aura_source_id = StringName("barracks_aura_%s" % str(get_instance_id()))
	_ring_node_name = "BuffAuraRing_%s" % str(get_instance_id())

	# Rally
	if has_node("Rally"):
		rally = $Rally
	else:
		rally = Node2D.new()
		rally.name = "Rally"
		add_child(rally)
		rally.position = Vector2.ZERO

	select_circle = ColorRect.new()
	select_circle.color = Color(0, 1, 0, 0.3)
	select_circle.size = Vector2(80, 80)
	select_circle.position = Vector2(-40, -40)
	select_circle.visible = false

	# ✅ CRITIQUE : ne doit JAMAIS capturer la souris, sinon la tour ne reçoit plus le clic
	select_circle.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(select_circle)

	if marine_scene == null:
		push_error("[Barracks] 'marine_scene' NON assignée")
		return

	# Respawn timer
	respawn_timer = Timer.new()
	respawn_timer.one_shot = true
	add_child(respawn_timer)
	respawn_timer.timeout.connect(_on_respawn_timer_timeout)

	# Aura timer
	_aura_timer = Timer.new()
	_aura_timer.one_shot = false
	_aura_timer.wait_time = aura_refresh_interval
	add_child(_aura_timer)
	_aura_timer.timeout.connect(_refresh_aura_buff)
	_aura_timer.start()

	call_deferred("_spawn_marines")
	set_process_unhandled_input(true)

	# ✅ cleanup robuste
	tree_exited.connect(_on_tree_exited)

	# Premier refresh après montage
	call_deferred("_refresh_aura_buff")


# ============================================================
#   ✅ UN SEUL CONTAINER POUR TOUS LES SPAWNS (spawn/respawn/revive)
# ============================================================
func _get_units_container() -> Node:
	var container: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	if container == null:
		container = self
	return container


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
	var container := _get_units_container()

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

	# ✅ applique immédiatement le buff courant (marines)
	_apply_buff_to_own_marines(_get_self_marines_mult())


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

	# ===========================
	#  VOICE : ordre de déplacement
	#  -> un seul marine parle (celui cliqué en dernier)
	# ===========================
	if _selected_marine and is_instance_valid(_selected_marine) and _marines.has(_selected_marine):
		if _selected_marine.has_method("play_move_line"):
			_selected_marine.play_move_line()

	# ===========================
	#  Déplacement du groupe
	# ===========================
	for m in _marines:
		if m == null or not is_instance_valid(m):
			continue

		# ✅ Important : caster en Node2D (sinon global_position est "unknown")
		var m2 := m as Node2D
		if m2 == null:
			continue

		var offset: Vector2 = m2.slot_offset
		var target: Vector2 = rally.global_position + offset

		m2.is_moving = true
		if m2.has_node("AnimatedSprite2D"):
			var a: AnimatedSprite2D = m2.get_node("AnimatedSprite2D")
			a.flip_h = target.x < m2.global_position.x
			a.play("walk")

		var dist: float = m2.global_position.distance_to(target)
		var duration: float = dist / float(move_speed)

		var tw := create_tween()
		tw.tween_property(m2, "global_position", target, duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)

		# (Optionnel) closure safe : capture une ref locale
		var m_ref := m2
		tw.finished.connect(func():
			if m_ref and is_instance_valid(m_ref):
				m_ref.is_moving = false
				if m_ref.has_node("AnimatedSprite2D"):
					var a2: AnimatedSprite2D = m_ref.get_node("AnimatedSprite2D")
					a2.play("idle")
		)

# ========================
#   Respawn system
# ========================
func notify_marine_dead(marine: Node) -> void:
	_marines.erase(marine)
	_pending_respawns += 1
	if respawn_timer.is_stopped():
		respawn_timer.start(respawn_delay)

func _on_respawn_timer_timeout() -> void:
	if _pending_respawns > 0 and _marines.size() < marine_count:
		var container := _get_units_container()

		var spawn_origin := _get_spawn_point()
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * ring_radius

		var m := marine_scene.instantiate()
		if m:
			# ✅ IMPORTANT : même container que spawn/revive
			container.add_child(m)
			m.global_position = spawn_origin + offset
			if "rally" in m: m.rally = rally
			if "barrack" in m: m.barrack = self
			m.slot_offset = offset
			_marines.append(m)

			# ✅ applique buff au nouveau marine (marines)
			_apply_buff_to_own_marines(_get_self_marines_mult())

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
func select_group(clicked_marine: Node = null) -> void:
	for b in get_tree().get_nodes_in_group("Barracks"):
		if b != self:
			b.deselect_group()

	selected = true
	select_circle.visible = true

	# ✅ On mémorise le marine cliqué pour les "move lines"
	if clicked_marine and is_instance_valid(clicked_marine):
		_selected_marine = clicked_marine
		
func deselect_group() -> void:
	selected = false
	select_circle.visible = false
	_selected_marine = null


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
	# 👁️ Preview : montre quelles tours reçoivent le buff actuel
	_preview_buff_targets()

	if upgrade_scene == null:
		return

	var next_tier := tower_tier + 1
	var tower_id: StringName = &"barracks"

	if Game and Game.has_method("can_upgrade_tower_to"):
		if not Game.can_upgrade_tower_to(tower_id, next_tier):
			print("[Barracks] Upgrade vers MK%d verrouillé (run=%d / labo[%s]=%d)" % [
				next_tier,
				Game.max_tower_tier,
				String(tower_id),
				Game.get_tower_unlocked_tier(tower_id)
			])
			return
	else:
		if "max_tower_tier" in Game and next_tier > Game.max_tower_tier:
			print("[Barracks] Upgrade vers MK%d encore verrouillé." % next_tier)
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

	for m in _marines:
		if m and is_instance_valid(m):
			m.queue_free()
	_marines.clear()

	_clear_aura_buffs()

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
		if n and n.is_in_group("BuildSlot"):
			return n
		if n and n.get_parent() and n.get_parent().is_in_group("BuildSlot"):
			return n.get_parent()
	return null


# ============================================================
#          AUTO-CLEANUP : suppression des marines + buffs
# ============================================================
func _on_tree_exited() -> void:
	_clear_aura_buffs()

	for m in _marines:
		if m and is_instance_valid(m):
			m.queue_free()
	_marines.clear()


# ============================================================
#        AURA BUFF : réception (si une autre barracks me buff)
# ============================================================
func set_damage_buff(source_id: StringName, mult: float) -> void:
	if mult <= 1.0:
		_damage_mult_sources.erase(source_id)
	else:
		_damage_mult_sources[source_id] = mult

	_apply_buff_to_own_marines(_get_self_marines_mult())


func get_damage_mult() -> float:
	var m := 1.0
	for v in _damage_mult_sources.values():
		m *= float(v)
	return m


# ============================================================
#  AURA BUFF : séparation "bonus labo" vs "buffs reçus"
# ============================================================
func _get_aura_bonus_mult() -> float:
	if Game and Game.has_method("get_barracks_aura_level") and Game.has_method("get_barracks_aura_bonus"):
		var lvl: int = Game.get_barracks_aura_level()
		if lvl > 0:
			return 1.0 + float(Game.get_barracks_aura_bonus(lvl))
	return 1.0

func _get_self_marines_mult() -> float:
	return get_damage_mult() * _get_aura_bonus_mult()


# ============================================================
#        AURA BUFF : émission (je buff les 3 tours proches)
# ============================================================
func _refresh_aura_buff() -> void:
	if not Game or not Game.has_method("get_barracks_aura_level") or not Game.has_method("get_barracks_aura_bonus"):
		_clear_aura_buffs()
		_apply_buff_to_own_marines(get_damage_mult())
		return

	var level: int = Game.get_barracks_aura_level()
	if level <= 0:
		_clear_aura_buffs()
		_apply_buff_to_own_marines(get_damage_mult())
		return

	var mult_out := _get_aura_bonus_mult()
	var mult_marines := _get_self_marines_mult()

	var new_targets := _find_nearest_towers(aura_target_count, aura_radius)

	for old in _buffed_targets:
		if old and is_instance_valid(old) and not new_targets.has(old):
			_apply_damage_buff(old, 1.0)

	for t in new_targets:
		if t and is_instance_valid(t):
			_apply_damage_buff(t, mult_out)

	_buffed_targets = new_targets

	_apply_buff_to_own_marines(mult_marines)


func _clear_aura_buffs() -> void:
	for t in _buffed_targets:
		if t and is_instance_valid(t):
			_apply_damage_buff(t, 1.0)
			_detach_preview_ring(t)
	_buffed_targets.clear()


func _find_nearest_towers(count: int, radius: float) -> Array[Node]:
	var candidates: Array[Node] = []

	for n in get_tree().get_nodes_in_group("Tower"):
		if n == self:
			continue
		if not (n is Node2D):
			continue
		var d := (n as Node2D).global_position.distance_to(global_position)
		if d <= radius:
			candidates.append(n)

	candidates.sort_custom(func(a: Node, b: Node) -> bool:
		var da := (a as Node2D).global_position.distance_to(global_position)
		var db := (b as Node2D).global_position.distance_to(global_position)
		return da < db
	)

	var out: Array[Node] = []
	for i in range(min(count, candidates.size())):
		out.append(candidates[i])
	return out


func _apply_damage_buff(target: Node, mult: float) -> void:
	if target and is_instance_valid(target) and target.has_method("set_damage_buff"):
		target.call("set_damage_buff", _aura_source_id, mult)


func _apply_buff_to_own_marines(mult: float) -> void:
	for m in _marines:
		if m and is_instance_valid(m):
			if m.has_method("set_damage_buff"):
				m.call("set_damage_buff", _aura_source_id, mult)
			elif "damage_mult" in m:
				m.damage_mult = mult


# ============================================================
#        PREVIEW VISUEL (aura jaune sur les cibles)
# ============================================================
func _preview_buff_targets() -> void:
	for t in _buffed_targets:
		if t and is_instance_valid(t):
			_attach_preview_ring(t)

	get_tree().create_timer(aura_preview_duration).timeout.connect(func():
		for t in _buffed_targets:
			if t and is_instance_valid(t):
				_detach_preview_ring(t)
	)

func _attach_preview_ring(t: Node) -> void:
	if not (t is Node2D):
		return
	var t2 := t as Node2D
	if t2.has_node(_ring_node_name):
		return

	var ring := BuffAuraRing.new()
	ring.name = _ring_node_name
	ring.radius = 38.0
	t2.add_child(ring)

func _detach_preview_ring(t: Node) -> void:
	if not (t is Node2D):
		return
	var t2 := t as Node2D
	var n := t2.get_node_or_null(_ring_node_name)
	if n:
		n.queue_free()


# ============================================================
#   HEAL POWER : Revive missing marines (spawn immédiat)
#   - spawn seulement si il manque des marines EN CE MOMENT
#   - consomme les respawns déjà planifiés pour ne pas dépasser marine_count
# ============================================================
func revive_missing(extra: int, invincible_duration: float = 0.0) -> void:
	extra = maxi(0, extra)
	if extra <= 0:
		return

	# ✅ Manquants "réels" (présents dans la scène), sans compter le pending
	var missing_now := marine_count - _marines.size()
	if missing_now <= 0:
		return

	var spawn_now := mini(extra, missing_now)
	if spawn_now <= 0:
		return

	# ✅ Si des respawns étaient déjà prévus, on les consomme
	# (sinon plus tard le timer te ferait dépasser le max)
	var consume := mini(_pending_respawns, spawn_now)
	_pending_respawns -= consume

	# Si plus rien à respawn via timer, on peut l'arrêter
	if _pending_respawns <= 0 and respawn_timer and not respawn_timer.is_stopped():
		respawn_timer.stop()

	var container := _get_units_container()
	var spawn_origin := _get_spawn_point()

	for i in range(spawn_now):
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * ring_radius
		var m := marine_scene.instantiate()
		if not m:
			continue

		container.add_child(m)
		m.global_position = spawn_origin + offset

		if "rally" in m: m.rally = rally
		if "barrack" in m: m.barrack = self
		m.slot_offset = offset
		_marines.append(m)
		if invincible_duration > 0.0 and m.has_method("set_invincible_for"):
			m.set_invincible_for(invincible_duration)

		# ✅ buff au nouveau marine
		_apply_buff_to_own_marines(_get_self_marines_mult())
