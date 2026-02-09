extends Node2D
class_name PowerController

# =========================================================
#                 EXPORTS : POUVOIRS EXISTANTS
# =========================================================
@export var freeze_zone_scene: PackedScene = preload("res://powers/freeze_zone.tscn")
@export_range(1.0, 120.0, 0.5, "suffix:s") var freeze_cooldown: float = 20.0
@export var ghost_radius: float = 96.0

@export_range(1.0, 120.0, 0.5, "suffix:s") var heal_cooldown: float = 20.0

# =========================================================
#                 EXPORTS : NOUVEAU POUVOIR
# =========================================================
@export var summon_zone_scene: PackedScene = preload("res://powers/summon_zone.tscn")
@export var summon_cooldown: float = 20.0
@export var summon_marine_scene: PackedScene = preload("res://units/marine.tscn")
@export var summon_marine_count: int = 3
@export var summon_duration: float = 20.0
@export_range(0.0, 10.0, 0.5, "suffix:s") var heal_invincible_duration: float = 5.0
# Summon : tier MK des marines invoqués (1 = MK1)
@export var summon_marine_tier: int = 1
@export var heal_revive_bonus_per_barracks: int = 0



# =========================================================
#                     VARIABLES INTERNES
# =========================================================
var _placing_freeze := false
var _placing_summon := false

# --- FREEZE : N charges (un cooldown par slot) ---
var _freeze_cooldowns: Array[float] = [] # taille = nb de charges, chaque entrée = cooldown restant
var _heal_cooldown_left := 0.0
var _summon_cooldown_left := 0.0
var _ghost: Node2D
func set_summon_count(v: int) -> void:
	summon_marine_count = maxi(1, v)

func set_summon_marine_tier(v: int) -> void:
	summon_marine_tier = maxi(1, v)

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

	# ✅ FREEZE : init des charges depuis le Labo
	var slots := 1
	if Game and Game.has_method("get_freeze_max_concurrent"):
		slots = int(Game.get_freeze_max_concurrent())
	_ensure_freeze_slots(slots)


# =========================================================
#                    PROCESS
# =========================================================
func _process(delta: float) -> void:
	# --- Cooldowns FREEZE (N slots)
	for i in _freeze_cooldowns.size():
		if _freeze_cooldowns[i] > 0.0:
			_freeze_cooldowns[i] = max(0.0, _freeze_cooldowns[i] - delta)


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
	# On ne peut placer que si au moins une charge est prête
	if _placing_freeze:
		return
	if not _has_freeze_ready():
		return

	_placing_freeze = true
	if _ghost:
		_ghost.visible = true
	print("[Power] Placement d'une zone de gel...")


func _place_freeze_at(pos: Vector2) -> void:
	if not freeze_zone_scene:
		_cancel_place()
		return

	# Consommer une charge dispo AU MOMENT du placement
	var slot := _get_ready_freeze_slot_index()
	if slot == -1:
		_cancel_place()
		return

	var z := freeze_zone_scene.instantiate()
	z.global_position = pos
	get_tree().current_scene.add_child(z)

	print("[Power] Zone de gel activée à ", pos, " (slot ", slot + 1, ")")

	_cancel_place()
	_freeze_cooldowns[slot] = freeze_cooldown


func _cancel_place() -> void:
	_placing_freeze = false
	if _ghost:
		_ghost.visible = false

# --- API compat (ancien HUD) : temps avant la prochaine charge dispo ---
func get_freeze_cooldown_left() -> float:
	return _time_until_next_freeze_ready()

# --- Nouveau : liste des cooldowns (1 par charge) ---
func get_freeze_cooldown_lefts() -> Array[float]:
	return _freeze_cooldowns.duplicate()

func is_freeze_ready() -> bool:
	return _has_freeze_ready()

func set_freeze_cooldown(v: float) -> void:
	freeze_cooldown = v

# ✅ Nouveau : nombre de charges (slots)
func set_freeze_max_concurrent(count: int) -> void:
	_ensure_freeze_slots(count)

# =========================================================
#                     SOIN GLOBAL
# =========================================================
func activate_heal_all() -> void:
	if _heal_cooldown_left > 0.0:
		return
	_heal_cooldown_left = heal_cooldown

	# 1) Heal + invincibilité (barracks + summon)
	for m in get_tree().get_nodes_in_group("Marine"):
		if m and is_instance_valid(m) and "hp" in m and "max_hp" in m:
			m.hp = m.max_hp
			if "hp_bar" in m and m.hp_bar:
				m.hp_bar.value = m.max_hp
			if m.has_node("AnimatedSprite2D"):
				var anim = m.get_node("AnimatedSprite2D")
				if anim.animation != "idle":
					anim.play("idle")

			if heal_invincible_duration > 0.0 and m.has_method("set_invincible_for"):
				m.set_invincible_for(heal_invincible_duration)

	# 2) Revive des marines morts des barracks (sans dépasser le max de la barracks)
	_revive_barracks_marines()

	print("[Power] Heal : soin + invincibilité %ss + revive barracks +%d" % [heal_invincible_duration, heal_revive_bonus_per_barracks])


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

	# ✅ NOUVEAU : tier MK transmis à la zone
	if "marine_tier" in z:
		z.marine_tier = summon_marine_tier
	elif z.has_method("set_marine_tier"):
		z.call("set_marine_tier", summon_marine_tier)

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


# =========================================================
#              FREEZE : helpers N charges
# =========================================================
func _ensure_freeze_slots(count: int) -> void:
	count = maxi(1, count)
	if _freeze_cooldowns.size() == count:
		return

	if _freeze_cooldowns.is_empty():
		_freeze_cooldowns.resize(count)
		for i in count:
			_freeze_cooldowns[i] = 0.0
		return

	# Si on augmente : on ajoute des slots prêts (0.0)
	if _freeze_cooldowns.size() < count:
		var old := _freeze_cooldowns.size()
		_freeze_cooldowns.resize(count)
		for i in range(old, count):
			_freeze_cooldowns[i] = 0.0
		return

	# Si on diminue (peu probable car upgrade) : on tronque
	_freeze_cooldowns.resize(count)


func _get_ready_freeze_slot_index() -> int:
	for i in _freeze_cooldowns.size():
		if _freeze_cooldowns[i] <= 0.0:
			return i
	return -1


func _time_until_next_freeze_ready() -> float:
	# Retourne le plus petit cooldown > 0 (temps avant qu’un slot redevienne dispo)
	var best := INF
	for cd in _freeze_cooldowns:
		if cd > 0.0 and cd < best:
			best = cd
	return 0.0 if best == INF else best


func _has_freeze_ready() -> bool:
	return _get_ready_freeze_slot_index() != -1
	
func set_heal_invincible_duration(v: float) -> void:
	heal_invincible_duration = max(0.0, v)

func set_heal_revive_bonus_per_barracks(v: int) -> void:
	heal_revive_bonus_per_barracks = maxi(0, v)
	
func _revive_barracks_marines() -> void:
	if heal_revive_bonus_per_barracks <= 0:
		return

	# ⚠️ IMPORTANT : mets tes barracks dans un groupe (ex: "Barracks")
	# et donne-leur une méthode revive_missing(count:int) ou equivalent.
	for b in get_tree().get_nodes_in_group("Barracks"):
		if not is_instance_valid(b):
			continue

		# Option A (recommandée) : la barracks sait gérer son max
		if b.has_method("revive_missing"):
			b.revive_missing(heal_revive_bonus_per_barracks)
			continue

		# Option B : autre nom éventuel (si tu as déjà une méthode)
		if b.has_method("spawn_missing_marines"):
			b.spawn_missing_marines(heal_revive_bonus_per_barracks)
			continue
