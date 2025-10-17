# res://scripts/build_controller.gd
extends Node2D

@export var parent_for_towers_path: NodePath   # ex: Node2D "Towers"
@export var cursor_max_size: int = 128         # taille max (pixels) de l'icône curseur (<=256)

var parent_for_towers: Node

var is_placing := false
var ghost: Node2D
var tower_scn: PackedScene
var cost := 0

func _ready() -> void:
	parent_for_towers = get_node_or_null(parent_for_towers_path)
	if parent_for_towers == null:
		parent_for_towers = get_parent()

func start_placing(scn: PackedScene, tower_cost: int) -> void:
	cancel()
	is_placing = true
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

func _unhandled_input(event: InputEvent) -> void:
	if not is_placing:
		return
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

# ---------- Pose réelle ----------
func _place_on_slot(slot: Node) -> void:
	if tower_scn == null:
		return
	var t := tower_scn.instantiate() as Node2D
	if t == null:
		return

	if parent_for_towers:
		parent_for_towers.add_child(t)
	else:
		add_child(t)

	t.global_position = (slot as Node2D).global_position
	if slot.has_method("set_occupied"):
		slot.set_occupied(t)

	# Quand la tour est supprimée, libérer le slot
	t.tree_exited.connect(func ():
		if is_instance_valid(slot) and slot.has_method("clear_if"):
			slot.call_deferred("clear_if", t)
	)

	cancel()

# --------- Picking ---------
func _pick_slot_at_mouse() -> Node:
	var pos: Vector2 = get_global_mouse_position()
	var space := get_world_2d().direct_space_state
	var prm := PhysicsPointQueryParameters2D.new()
	prm.position = pos
	prm.collide_with_areas = true
	prm.collide_with_bodies = true

	var hits := space.intersect_point(prm, 16)
	for h in hits:
		var n: Node = h.collider   # si tu préfères, tape Array[Dictionary] et fais: hit["collider"]
		# remonte au BuildSlot si on a touché l’Area2D enfant
		if n and n.is_in_group("BuildSlot"):
			return n
		if n and n.get_parent() and n.get_parent().is_in_group("BuildSlot"):
			return n.get_parent()
	return null

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

func _set_as_preview(n: Node, preview_on: bool) -> void:
	n.process_mode = Node.PROCESS_MODE_DISABLED if preview_on else Node.PROCESS_MODE_INHERIT
	if n is CollisionShape2D:
		(n as CollisionShape2D).disabled = preview_on
	elif n is Area2D:
		var a := n as Area2D
		a.monitoring     = not preview_on
		a.monitorable    = not preview_on
		a.input_pickable = false   # le ghost ne capte jamais la souris
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

# Redimensionne proprement la texture de curseur si elle dépasse `cursor_max_size`
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
	var scale: float = minf(sx, sy)   # <- IMPORTANT: float, pas Variant

	var new_w: int = int(round(float(sz.x) * scale))
	var new_h: int = int(round(float(sz.y) * scale))
	img.resize(new_w, new_h, Image.INTERPOLATE_LANCZOS)

	var out := ImageTexture.new()
	out.set_image(img)
	return out
