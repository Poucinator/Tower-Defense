# res://scripts/build_controller.gd
extends Node2D

@export var parent_for_towers_path: NodePath   # ex: Node2D "Towers"
@export var cursor_max_size: int = 128         # taille max (pixels) de l'icône curseur (<=256)

var parent_for_towers: Node

var is_placing := false
var ghost: Node2D
var tower_scn: PackedScene
var cost := 0

# --- Mode Vente ---
var sell_mode := false
var sell_cursor: Texture2D = preload("res://ui/cursor_sell.png")
var hud: Node = null

signal sell_mode_changed(active: bool)


func _ready() -> void:
	parent_for_towers = get_node_or_null(parent_for_towers_path)
	if parent_for_towers == null:
		parent_for_towers = get_parent()

	# On tente de retrouver le HUD automatiquement (utile pour le feedback visuel)
	hud = get_tree().get_first_node_in_group("HUD")

# ============================================================
#              MODE PLACEMENT DE TOUR
# ============================================================
func start_placing(scn: PackedScene, tower_cost: int) -> void:
	cancel()
	is_placing = true
	sell_mode = false
	tower_scn = scn
	cost = tower_cost

	# Ghost (non interactif)
	ghost = tower_scn.instantiate() as Node2D
	if ghost:
		ghost.modulate.a = 0.5
		add_child(ghost)
		_set_as_preview(ghost, true)

	# -------- Curseur sécurisé (redimension ≤ cursor_max_size) --------
	var tex := _extract_any_sprite_texture(ghost)
	if tex:
		tex = _fit_cursor_texture(tex)
		if tex:
			var hs := Vector2(tex.get_size()) * 0.5
			Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, hs)

	set_process(true)
	set_process_unhandled_input(true)

func cancel() -> void:
	is_placing = false
	tower_scn = null
	cost = 0

	if ghost and is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null

	Input.set_custom_mouse_cursor(null)
	set_process(false)
	set_process_unhandled_input(false)

func _process(_delta: float) -> void:
	if is_placing and ghost:
		ghost.global_position = get_global_mouse_position()

# ============================================================
#              MODE VENTE DE TOUR
# ============================================================
func start_sell_mode(active: bool = true) -> void:
	sell_mode = active
	is_placing = false
	Game.is_selling_mode = active

	if ghost and is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null

	if sell_mode:
		var tex := _fit_cursor_texture(sell_cursor)
		if tex:
			var hs := Vector2(tex.get_size()) * 0.5
			Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, hs)
		set_process_unhandled_input(true)
	else:
		Input.set_custom_mouse_cursor(null)
		set_process_unhandled_input(false)

	# ✅ broadcast to HUD
	emit_signal("sell_mode_changed", sell_mode)


func _unhandled_input(event: InputEvent) -> void:
	# --- Cas 1 : on place une tour ---
	if is_placing:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				cancel()
				return
			if event.button_index == MOUSE_BUTTON_LEFT:
				var slot := _pick_slot_at_mouse()
				if slot and slot.is_free():
					var price := cost
					if slot.price_override >= 0:
						price = slot.price_override
					if not _try_spend(price):
						print("[Build] Or insuffisant")
						return
					_place_on_slot(slot)
		return

	# --- Cas 2 : on vend une tour ---
	if sell_mode and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_sell_mode()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			var tower := _get_tower_under_cursor()
			if tower:
				_sell_tower(tower)

# ============================================================
#                 LOGIQUE DE VENTE
# ============================================================
func _get_tower_under_cursor() -> Node:
	var pos: Vector2 = get_global_mouse_position()
	var space_state := get_world_2d().direct_space_state

	var prm := PhysicsPointQueryParameters2D.new()
	prm.position = pos
	prm.collide_with_areas = true
	prm.collide_with_bodies = true
	prm.collision_mask = 0xFFFFFFFF

	var hits := space_state.intersect_point(prm, 16)
	for h in hits:
		var n: Node = h["collider"]
		if n == null:
			continue
		var t := _find_tower_root(n)
		if t:
			return t
	return null



func _find_tower_root(n: Node) -> Node:
	var cur := n
	var steps := 0
	while cur:
		# Si le node courant est une tour, on le renvoie
		if cur.is_in_group("Tower"):
			return cur

		# Si on a atteint un Node2D sans groupe Tower,
		# on continue à remonter, mais log pour debug
		if steps > 10:
			print("[Build] ⚠️ Impossible de trouver la racine Tower pour", n.name)
			break

		cur = cur.get_parent()
		steps += 1

	return null

func _sell_tower(any_node: Node) -> void:
	if any_node == null:
		return

	var tower := _find_tower_root(any_node)
	if tower == null:
		print("[Build] ❌ Impossible de trouver la tour à vendre")
		_cancel_sell_mode()
		return

	# 💰 Calcul du remboursement
	var refund := _calculate_refund(tower)
	if refund > 0 and "add_gold" in Game:
		Game.add_gold(refund)
	print("💸 Tour vendue pour ", refund, " PO")

	# 🔓 Libère explicitement le slot
	var slot := _find_slot_for_tower(tower)
	if slot and slot.has_method("clear_if"):
		slot.call_deferred("clear_if", tower)

	# 🪦 Suppression de la tour
	tower.queue_free()

	# 🛑 Sortie du mode vente
	_cancel_sell_mode()



func _calculate_refund(tower: Node) -> int:
	var refund := 0
	var base_price := 0

	# Sécurité
	if tower == null:
		return 0

	# On prend des infos sur le node
	var name_lower := tower.name.to_lower()
	var scene_name := ""
	if tower.scene_file_path != "":
		scene_name = tower.scene_file_path.get_file().to_lower()

	print("[Refund] 🔍 Analyse de la tour :", tower.name, "| scene:", scene_name)

	# ============================================================
	# 🔵 BLUE TOWERS (MK1 / MK2 / MK3)
	# ============================================================
	if "blue_tower" in scene_name or "blue" in name_lower:
		if "mk3" in scene_name or "mk3" in name_lower:
			base_price = 300
		elif "mk2" in scene_name or "mk2" in name_lower:
			base_price = 200
		else:
			base_price = 100

	# ============================================================
	# 🎯 SNIPE TOWERS (MK1 / MK2 / MK3)
	# ============================================================
	elif "snipe_tower" in scene_name or "snipe" in name_lower:
		if "mk3" in scene_name or "mk3" in name_lower:
			base_price = 400
		elif "mk2" in scene_name or "mk2" in name_lower:
			base_price = 300
		else:
			base_price = 200

	# ============================================================
	# 💣 MISSILE TOWERS (MK1 / MK2 / MK3)
	# ============================================================
	elif "missile_tower" in scene_name or "missile" in name_lower:
		if "mk3" in scene_name or "mk3" in name_lower:
			base_price = 500
		elif "mk2" in scene_name or "mk2" in name_lower:
			base_price = 400
		else:
			base_price = 300

	# ============================================================
	# 🪖 BARRACKS TOWERS (MK1 / MK2 / MK3)
	# ============================================================
	elif "barracks_tower" in scene_name or "barrack" in name_lower:
		if "mk3" in scene_name or "MK3" in name_lower:
			base_price = 150
		elif "mk2" in scene_name or "MK2" in name_lower:
			base_price = 300
		elif "mk4" in scene_name or "MK4" in name_lower:
			base_price = 500
		elif "mk5" in scene_name or "MK5" in name_lower:
			base_price = 1000		
		else:
			base_price = 50

	# ============================================================
	# 🧩 Cas inconnu
	# ============================================================
	else:
		print("[Refund] ❌ Type de tour inconnu :", tower.name, "| scene:", scene_name)
		return 0

	# ============================================================
	# 💰 Calcul du remboursement
	# ============================================================
	refund = int(round(base_price * 0.75))
	print("[Refund] 💰 Base =", base_price, "→ remboursement =", refund)
	return refund




func _cancel_sell_mode() -> void:
	sell_mode = false
	Game.is_selling_mode = false
	Input.set_custom_mouse_cursor(null)
	emit_signal("sell_mode_changed", false)  # ✅ keep HUD in sync


# ============================================================
#                   POSE RÉELLE
# ============================================================
func _place_on_slot(slot: Node) -> void:
	if tower_scn == null:
		return

	var t := tower_scn.instantiate() as Node2D
	if t == null:
		return

	# ✅ Enregistre le coût dans la tour pour pouvoir la revendre plus tard
# ✅ Enregistre le coût dans la tour (même si la propriété n'existe pas encore)
	if t.has_method("set"):
		t.set("cost", cost)
	else:
		t.cost = cost


	# ✅ Ajoute la tour au bon parent
	if parent_for_towers:
		parent_for_towers.add_child(t)
	else:
		add_child(t)

	# ✅ Positionne la tour sur le slot
	t.global_position = (slot as Node2D).global_position

	# ✅ Lie la tour à son slot
	if slot.has_method("set_occupied"):
		slot.set_occupied(t)

	# ✅ Quand la tour est supprimée, libérer le slot
# Quand la tour est supprimée, libérer le slot
	t.tree_exited.connect(func ():
		if not is_instance_valid(slot):
			return
		if not slot.has_method("clear_if"):
			return

	# ✅ Appel différé SANS argument, plus d’erreur
		slot.call_deferred("clear_if")
)



	cancel()



# ============================================================
#                 PICKING SLOT
# ============================================================
func _pick_slot_at_mouse() -> Node:
	var pos: Vector2 = get_global_mouse_position()
	var space := get_world_2d().direct_space_state

	var prm := PhysicsPointQueryParameters2D.new()
	prm.position = pos
	prm.collide_with_areas = true
	prm.collide_with_bodies = true
	prm.collision_mask = 0xFFFFFFFF

	var hits := space.intersect_point(prm, 16)
	for h in hits:
		var n: Node = h["collider"]
		if n and n.is_in_group("BuildSlot"):
			return n
		if n and n.get_parent() and n.get_parent().is_in_group("BuildSlot"):
			return n.get_parent()
	return null


# ============================================================
#                 UTILITAIRES
# ============================================================
func _try_spend(amount: int) -> bool:
	if "try_spend" in Game:
		return Game.try_spend(amount)
	if "gold" in Game and Game.gold >= amount:
		Game.gold -= amount
		if Game.has_signal("gold_changed"):
			Game.gold_changed.emit(Game.gold)
		return true
	return false

func _set_as_preview(n: Node, preview_on: bool) -> void:
	n.process_mode = Node.PROCESS_MODE_DISABLED if preview_on else Node.PROCESS_MODE_INHERIT
	if n is CollisionShape2D:
		(n as CollisionShape2D).disabled = preview_on
	elif n is Area2D:
		var a := n as Area2D
		a.monitoring     = not preview_on
		a.monitorable    = not preview_on
		a.input_pickable = false
	elif n is Timer:
		if preview_on:
			(n as Timer).stop()
	for c in n.get_children():
		_set_as_preview(c, preview_on)

func _extract_any_sprite_texture(n: Node) -> Texture2D:
	if n is Sprite2D and (n as Sprite2D).texture:
		return (n as Sprite2D).texture
	if n is AnimatedSprite2D:
		var a := n as AnimatedSprite2D
		if a.sprite_frames and a.sprite_frames.get_animation_names().size() > 0:
			var anim := a.sprite_frames.get_animation_names()[0]
			var tex := a.sprite_frames.get_frame_texture(anim, 0)
			if tex:
				return tex
	for c in n.get_children():
		var t := _extract_any_sprite_texture(c)
		if t:
			return t
	return null

func _fit_cursor_texture(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var sz: Vector2i = tex.get_size()
	if sz.x <= cursor_max_size and sz.y <= cursor_max_size:
		return tex
	var img: Image = tex.get_image()
	if img == null:
		return tex
	var sx: float = float(cursor_max_size) / float(sz.x)
	var sy: float = float(cursor_max_size) / float(sz.y)
	var scale: float = minf(sx, sy)
	var new_w: int = int(round(float(sz.x) * scale))
	var new_h: int = int(round(float(sz.y) * scale))
	img.resize(new_w, new_h, Image.INTERPOLATE_LANCZOS)
	var out := ImageTexture.new()
	out.set_image(img)
	return out
	
# ============================================================
#               Trouver le slot d'une tour
# ============================================================
func _find_slot_for_tower(tower: Node) -> Node:
	var slots := get_tree().get_nodes_in_group("BuildSlot")
	for s in slots:
		# Si ton slot stocke la tour dans une variable "occupied"
		if "occupied" in s:
			var occ = s.occupied
			if occ != null and occ is Node and occ == tower:
				return s

		# Ou si ton slot a une méthode pour la récupérer
		if s.has_method("get_occupied"):
			var occ2 = s.call("get_occupied")
			if occ2 != null and occ2 is Node and occ2 == tower:
				return s

	return null
