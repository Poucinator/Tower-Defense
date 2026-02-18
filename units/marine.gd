extends Node2D

# --- Références ---
@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var hp_bar: Range = get_node_or_null("HealthBar")
@onready var aggro: Area2D = get_node_or_null("Aggro")
@onready var muzzle: AnimatedSprite2D = get_node_or_null("MuzzleFlash")

# ============================================================
#                 VOICE / PHRASES (WC3 / SC-like)
# ============================================================
@export var voice_bank: MarineVoiceBank

# Spam sélection
@export var spam_trigger_count: int = 5
@export_range(0.2, 5.0, 0.1) var spam_window_sec: float = 2.0

# --- Réutiliser un label EXISTANT (recommandé) ---
# Exemple: NodePath("/root/Main/HUD/WorldSpeechLabel") ou autre dans ta scène
@export var speech_label_global_path: NodePath

@export_range(80, 520, 10) var speech_max_width_px: int = 260
@export var speech_center_over_unit: bool = true


# --- Fallback local si tu ne veux pas de label global ---
@export var allow_auto_create_local_label: bool = true
@export var speech_label_path: NodePath = NodePath("SpeechLabel")

# Cadre / lisibilité
@export var speech_use_panel_frame: bool = true
@export_range(0.0, 20.0, 1.0) var speech_padding: int = 6

var _speech_label: Label = null
var _speech_panel: PanelContainer = null
var _speech_tween: Tween = null

var _select_streak: int = 0
var _select_streak_timer: Timer = null

# Spam séquentiel
var _spam_index: int = 0
var _spam_finished: bool = false

# --- Réglages ---
@export var max_hp: int = 12
@export var attack_damage: int = 2
@export var attack_interval: float = 0.6
@export var engage_radius: float = 64.0
@export var support_radius: float = 140.0
@export var face_target: bool = true
@export var muzzle_offset: float = 5.0
@export var regen_per_sec: float = 1.0   # regen HP/sec

var barrack: Node = null

# --- Données caserne ---
var rally: Node2D = null
var slot_offset: Vector2 = Vector2.ZERO

# --- État interne ---
var hp: int
var engaged_enemy: Node = null
var _attack_timer: Timer
var is_dead: bool = false
var is_moving: bool = false

# --- Invincibilité ---
var _invincible_time_left: float = 0.0

# --- Regen interne ---
var _regen_buffer: float = 0.0

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
	add_to_group("Marine")

	hp = max_hp
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp

	# Clic sur Area2D
	if has_node("Area2D"):
		$Area2D.input_pickable = true
		if not $Area2D.is_connected("input_event", Callable(self, "_on_input_event")):
			$Area2D.connect("input_event", Callable(self, "_on_input_event"))

	# Aggro
	if aggro:
		var cs := aggro.get_node_or_null("CollisionShape2D")
		if cs and cs.shape is CircleShape2D:
			(cs.shape as CircleShape2D).radius = engage_radius
		if not aggro.body_entered.is_connected(_on_body_entered):
			aggro.body_entered.connect(_on_body_entered)
		if not aggro.body_exited.is_connected(_on_body_exited):
			aggro.body_exited.connect(_on_body_exited)

	# Attack timer
	_attack_timer = Timer.new()
	_attack_timer.one_shot = false
	_attack_timer.wait_time = attack_interval
	add_child(_attack_timer)
	_attack_timer.timeout.connect(_do_attack)

	if anim:
		anim.play("idle")

	if muzzle:
		muzzle.stop()
		muzzle.frame = 0
		muzzle.visible = false

	if rally:
		global_position = rally.global_position + slot_offset

	# VOICE UI
	_setup_voice_ui()
	_setup_select_streak_timer()


func _process(delta: float) -> void:
	if is_dead:
		return

	# Invincibilité
	if _invincible_time_left > 0.0:
		_invincible_time_left = max(0.0, _invincible_time_left - delta)
		if _invincible_time_left == 0.0:
			_end_invincibility_visual()

	# Regen
	if hp < max_hp and regen_per_sec > 0:
		_regen_buffer += regen_per_sec * delta
		if _regen_buffer >= 1.0:
			var gain = int(_regen_buffer)
			_regen_buffer -= gain
			hp = clampi(hp + gain, 0, max_hp)
			if hp_bar:
				hp_bar.value = hp

	if is_moving:
		return

	if engaged_enemy and not is_instance_valid(engaged_enemy):
		engaged_enemy = null

	var tgt := _pick_target()

	if face_target and tgt and anim:
		anim.flip_h = (tgt.global_position.x < global_position.x)
		if muzzle:
			muzzle.flip_h = anim.flip_h
			muzzle.position.x = (-abs(muzzle_offset) if anim.flip_h else abs(muzzle_offset))

	if tgt:
		if _attack_timer.is_stopped():
			_attack_timer.start()
		if anim and anim.animation != "attack":
			anim.play("attack")
	else:
		if not _attack_timer.is_stopped():
			_attack_timer.stop()
		if anim and anim.animation != "idle":
			anim.play("idle")
		if muzzle:
			muzzle.stop()
			muzzle.frame = 0
			muzzle.visible = false


# =========================================================
#             Sélection des cibles
# =========================================================
func _pick_target() -> Node2D:
	if engaged_enemy:
		return engaged_enemy

	var engaged_nearby := _enemies_in_radius(support_radius).filter(func(e):
		return ("engaged_by" in e) and e.engaged_by != null)
	if not engaged_nearby.is_empty():
		return _closest_enemy(engaged_nearby)

	var all := _enemies_in_radius(support_radius)
	return _closest_enemy(all) if not all.is_empty() else null


# =========================================================
#                     Aggro
# =========================================================
func _on_body_entered(b: Node) -> void:
	if not b.is_in_group("Enemy"):
		return

	if b.has_signal("died"):
		if not b.died.is_connected(_on_enemy_died):
			b.died.connect(_on_enemy_died)

	if engaged_enemy == null:
		if b.has_method("request_engage") and b.call("request_engage", self):
			engaged_enemy = b


func _on_body_exited(b: Node) -> void:
	if b.has_signal("died") and b.died.is_connected(_on_enemy_died):
		b.died.disconnect(_on_enemy_died)


# =========================================================
#                        Combat
# =========================================================
func _do_attack() -> void:
	var tgt := _pick_target()
	if tgt == null or not is_instance_valid(tgt):
		return

	var dmg := int(round(float(attack_damage) * get_damage_mult()))
	if tgt.has_method("apply_damage"):
		tgt.call("apply_damage", dmg)

	if muzzle:
		muzzle.visible = true
		muzzle.play("flash")


# =========================================================
#                 Dégâts subis / mort
# =========================================================
func take_damage(amount: int) -> void:
	if _invincible_time_left > 0.0:
		return

	hp -= amount
	if hp_bar:
		hp_bar.value = clampi(hp, 0, max_hp)

	if hp <= 0:
		_die()
	else:
		_hit_flash()


func _hit_flash() -> void:
	if anim:
		var t := create_tween()
		t.tween_property(anim, "modulate", Color(1, 0.6, 0.6), 0.06)
		t.tween_property(anim, "modulate", Color(1, 1, 1), 0.06)


func _die() -> void:
	is_dead = true
	_attack_timer.stop()

	if engaged_enemy and is_instance_valid(engaged_enemy) and engaged_enemy.has_method("release_engage"):
		engaged_enemy.call("release_engage", self)
	engaged_enemy = null

	if muzzle:
		muzzle.stop()
		muzzle.frame = 0
		muzzle.visible = false

	if anim:
		anim.play("dead")

	if barrack and barrack.has_method("notify_marine_dead"):
		barrack.notify_marine_dead(self)

	await get_tree().create_timer(0.8).timeout
	queue_free()


func release_target_from_enemy(enemy: Node) -> void:
	if enemy == engaged_enemy:
		engaged_enemy = null


func _on_enemy_died(dead_enemy: Node) -> void:
	if engaged_enemy == dead_enemy:
		engaged_enemy = null
		if anim:
			anim.play("idle")
		if not _attack_timer.is_stopped():
			_attack_timer.stop()
		if muzzle:
			muzzle.stop()
			muzzle.visible = false


# =========================================================
#                 Outils utilitaires
# =========================================================
func _enemies_in_radius(radius: float) -> Array[Node2D]:
	var out: Array[Node2D] = []
	var r2 := radius * radius
	for e in get_tree().get_nodes_in_group("Enemy"):
		if e == null or not is_instance_valid(e):
			continue
		if global_position.distance_squared_to(e.global_position) <= r2:
			out.append(e)
	return out


func _closest_enemy(enemies: Array[Node2D]) -> Node2D:
	var best: Node2D = null
	var best_d2 := INF
	for e in enemies:
		var d2 := global_position.distance_squared_to(e.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = e
	return best


# =========================================================
#              Sélection via clic
# =========================================================
func _on_input_event(_vp, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		play_select_line()

	if barrack and barrack.has_method("select_group"):
		# On passe le marine cliqué -> la barrack saura qui est le "speaker"
		barrack.select_group(self)


# =========================================================
#              Invincibilité temporaire
# =========================================================
func set_invincible_for(duration: float) -> void:
	_invincible_time_left = max(_invincible_time_left, duration)
	_start_invincibility_visual()


func _start_invincibility_visual() -> void:
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.modulate = Color(1, 1, 1, 0.5)


func _end_invincibility_visual() -> void:
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.modulate = Color(1, 1, 1, 1.0)


# ============================================================
#                 VOICE / UI helpers
# ============================================================
func _setup_voice_ui() -> void:
	# 1) Priorité : label GLOBAL fourni
	if speech_label_global_path != NodePath():
		var n := get_node_or_null(speech_label_global_path)
		if n and n is Label:
			_speech_label = n as Label

	# 2) Sinon : label local existant
	if _speech_label == null:
		_speech_label = get_node_or_null(speech_label_path) as Label

	# 3) Sinon : auto-création locale (optionnel)
	if _speech_label == null and allow_auto_create_local_label:
		_speech_label = Label.new()
		_speech_label.name = "SpeechLabel"
		add_child(_speech_label)
		_speech_label.z_index = 50

	if _speech_label == null:
		return

	# Settings lisibilité (outline + shadow = “cadre” léger)
	_apply_speech_label_style(_speech_label)

	# Panel frame optionnel (cadre + padding)
	if speech_use_panel_frame:
		_wrap_label_in_panel_if_needed()

	_hide_speech_immediate()


func _apply_speech_label_style(lbl: Label) -> void:
	var ls := lbl.label_settings
	if ls == null:
		ls = LabelSettings.new()
	lbl.label_settings = ls

	# Contour (effet "cadre" autour des glyphes)
	ls.outline_size = 2
	ls.outline_color = Color(0, 0, 0, 0.95)

	# Ombre légère
	ls.shadow_size = 2
	ls.shadow_color = Color(0, 0, 0, 0.6)
	ls.shadow_offset = Vector2(1, 1)

	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _wrap_label_in_panel_if_needed() -> void:
	# Si le label est déjà dans un PanelContainer, on ne refait pas.
	if _speech_label.get_parent() is PanelContainer:
		_speech_panel = _speech_label.get_parent() as PanelContainer
		return

	# On wrappe dans un PanelContainer
	var parent := _speech_label.get_parent()
	if parent == null:
		return

	_speech_panel = PanelContainer.new()
	_speech_panel.name = "SpeechPanel"
	_speech_panel.z_index = _speech_label.z_index
	_speech_panel.visible = false

	# Le panel doit reprendre la place du label
	_speech_panel.position = _speech_label.position

	# MarginContainer pour padding
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", speech_padding)
	margin.add_theme_constant_override("margin_right", speech_padding)
	margin.add_theme_constant_override("margin_top", speech_padding)
	margin.add_theme_constant_override("margin_bottom", speech_padding)

	# On reparent : parent -> panel -> margin -> label
	parent.add_child(_speech_panel)
	_speech_panel.add_child(margin)

	parent.remove_child(_speech_label)
	margin.add_child(_speech_label)

	# Reset position du label dans le container
	_speech_label.position = Vector2.ZERO

	# Un style simple de fond (si tu n’as pas de Theme)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.45)
	sb.border_color = Color(1, 1, 1, 0.15)
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	_speech_panel.add_theme_stylebox_override("panel", sb)


func _setup_select_streak_timer() -> void:
	_select_streak_timer = Timer.new()
	_select_streak_timer.one_shot = true
	add_child(_select_streak_timer)
	_select_streak_timer.timeout.connect(_on_select_streak_timeout)


func _on_select_streak_timeout() -> void:
	_select_streak = 0


# ============================================================
#                 VOICE : API
# ============================================================
func play_select_line() -> void:
	if voice_bank == null:
		return

	# Fenêtre de spam
	if _select_streak_timer.is_stopped():
		_select_streak = 0
	_select_streak += 1
	_select_streak_timer.start(spam_window_sec)

	# Spam “une fois”, séquentiel, puis retour à select normal
	if _select_streak >= spam_trigger_count and not _spam_finished and not voice_bank.spam_select_lines.is_empty():
		_play_spam_sequential()
		return

	# Select normal : aléatoire
	_play_random_from_bank(voice_bank.select_lines)


func play_move_line() -> void:
	if voice_bank == null:
		return

	# Déplacement casse le streak
	_select_streak = 0
	if _select_streak_timer and not _select_streak_timer.is_stopped():
		_select_streak_timer.stop()

	_play_random_from_bank(voice_bank.move_lines)


# ============================================================
#                 VOICE : internals
# ============================================================
func _play_spam_sequential() -> void:
	var lines := voice_bank.spam_select_lines
	if lines.is_empty():
		return

	# Déroule dans l'ordre
	var idx := clampi(_spam_index, 0, lines.size() - 1)
	_show_speech(lines[idx], voice_bank.display_duration)

	_spam_index += 1
	if _spam_index >= lines.size():
		# Fin du pack spam : on repasse aux select_lines ensuite
		_spam_finished = true
		_spam_index = 0


func _play_random_from_bank(lines: Array[String]) -> void:
	if voice_bank == null:
		return
	if lines.is_empty():
		return

	var text := lines[randi() % lines.size()]
	_show_speech(text, voice_bank.display_duration)


func _show_speech(text: String, duration: float) -> void:
	if _speech_label == null:
		return

	# Texte
	_speech_label.text = text

	# ✅ Force une largeur raisonnable (sinon 1 char de large -> texte vertical)
	_speech_label.custom_minimum_size.x = float(speech_max_width_px)

	# Wrapping + align (au cas où)
	_speech_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speech_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Si on a un panel, il doit aussi "contenir" la largeur
	if _speech_panel:
		_speech_panel.custom_minimum_size.x = float(speech_max_width_px)
		_show_speech_container()

		# Position au-dessus (local) si pas label global
		if speech_label_global_path == NodePath():
			var y := (voice_bank.y_offset if voice_bank else -28.0)
			_speech_panel.position = Vector2(0.0, y)

		# Centrage par rapport au marine
		if speech_center_over_unit:
			# PanelContainer se place avec son top-left : on recentre
			_speech_panel.position.x = -_speech_panel.size.x * 0.5
	else:
		_show_speech_container()

		# Position au-dessus (local) si pas label global
		if speech_label_global_path == NodePath():
			var y2 := (voice_bank.y_offset if voice_bank else -28.0)
			_speech_label.position = Vector2(0.0, y2)

		if speech_center_over_unit:
			_speech_label.position.x = -_speech_label.size.x * 0.5

	# Stop tween précédent
	if _speech_tween and _speech_tween.is_running():
		_speech_tween.kill()

	# Fade-out
	_speech_tween = create_tween()
	_speech_tween.tween_interval(max(0.0, duration - 0.25))

	if _speech_panel:
		_speech_panel.modulate = Color(1, 1, 1, 1)
		_speech_tween.tween_property(_speech_panel, "modulate", Color(1, 1, 1, 0), 0.25)
	else:
		_speech_label.modulate = Color(1, 1, 1, 1)
		_speech_tween.tween_property(_speech_label, "modulate", Color(1, 1, 1, 0), 0.25)

	_speech_tween.finished.connect(_on_speech_tween_finished)


func _on_speech_tween_finished() -> void:
	_hide_speech_immediate()


func _hide_speech_immediate() -> void:
	if _speech_panel:
		_speech_panel.visible = false
	else:
		_speech_label.visible = false


func _show_speech_container() -> void:
	if _speech_panel:
		_speech_panel.visible = true
		_speech_panel.modulate = Color(1, 1, 1, 1)
	else:
		_speech_label.visible = true
		_speech_label.modulate = Color(1, 1, 1, 1)
