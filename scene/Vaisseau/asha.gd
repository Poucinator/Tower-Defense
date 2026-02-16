# res://ui/interlevel/interlevel_economy_ui.gd
extends Control
class_name InterLevelEconomyUI

@export_file("*.tscn") var previous_scene_path: String
@export_file("*.tscn") var next_scene_path: String

@export var crystal_counter_path: NodePath
@export var confirm_overlay_path: NodePath

@export var start_gold_btn_path: NodePath
@export var wave_gold_btn_path: NodePath
@export var building_hp_btn_path: NodePath

@export var next_btn_path: NodePath
@export var previous_btn_path: NodePath

# Panel anim
@export_range(0.05, 1.0, 0.01) var ov_open_duration: float = 0.22
@export_range(0.05, 1.0, 0.01) var ov_open_fade_duration: float = 0.14
@export_range(0.05, 1.0, 0.01) var ov_close_duration: float = 0.18
@export_range(0.05, 1.0, 0.01) var ov_close_fade_duration: float = 0.12
@export var ov_closed_scale: float = 0.90

# Dimmer anim
@export_range(0.05, 1.0, 0.01) var dimmer_open_duration: float = 0.22
@export_range(0.05, 1.0, 0.01) var dimmer_fade_duration: float = 0.14
@export var dimmer_start_scale_y: float = 0.15

@onready var crystal_counter: Node = get_node_or_null(crystal_counter_path)
@onready var confirm_overlay: Control = get_node_or_null(confirm_overlay_path) as Control

@onready var start_gold_btn: BaseButton = get_node_or_null(start_gold_btn_path) as BaseButton
@onready var wave_gold_btn: BaseButton = get_node_or_null(wave_gold_btn_path) as BaseButton
@onready var building_hp_btn: BaseButton = get_node_or_null(building_hp_btn_path) as BaseButton

@onready var next_btn: BaseButton = get_node_or_null(next_btn_path) as BaseButton
@onready var previous_btn: BaseButton = get_node_or_null(previous_btn_path) as BaseButton

@onready var _ov_dimmer: Control = _n("Dimmer") as Control
@onready var _ov_title: Label = _n("Panel/VBoxContainer/TitleLabel") as Label
@onready var _ov_desc: Label = _n("Panel/VBoxContainer/DescLabel") as Label
@onready var _ov_cost: Label = _n("Panel/VBoxContainer/CostLabel") as Label
@onready var _ov_cancel: BaseButton = _n("Panel/HBoxContainer/CancelBtn") as BaseButton
@onready var _ov_confirm: BaseButton = _n("Panel/HBoxContainer/ConfirmBtn") as BaseButton

@onready var _ov_dimmer_rect: Control = _n("Dimmer") as Control
@onready var _ov_panel: Control = _n("Panel") as Control

const U_START_GOLD: StringName = &"start_gold"
const U_WAVE_SKIP_GOLD: StringName = &"wave_skip_gold"
const U_BUILDING_HP: StringName = &"building_hp"

const MAX_LEVEL := 5

# Base (niveau 0)
const BASE_START_GOLD := 300

# ✅ Coûts identiques pour les 3 upgrades (niveau 1..5)
const COSTS_COMMON := [50, 200, 500, 2000, 5000]

# ✅ Effets
# - Start gold = bonus additif
const VALUES_START_GOLD_BONUS := [100, 300, 500, 800, 1200]

# - Wave gold = multiplicateur (x1.0 au niveau 0)
const VALUES_WAVE_GOLD_MULT := [1.5, 2.0, 3.0, 4.0, 5.0]

# - Building HP = multiplicateur (x1.0 au niveau 0)
const VALUES_BUILDING_HP_MULT := [1.5, 2.0, 3.0, 4.0, 5.0]

enum PendingMode { NONE, PURCHASE, NEXT_CONFIRM }
var _pending_mode: PendingMode = PendingMode.NONE
var _pending_upgrade_id: StringName = &""
var _pending_cost: int = 0

var _ov_tween: Tween
var _overlay_open := false

const MAX_GRAY_ALPHA := 0.45

func _ready() -> void:
	if start_gold_btn:
		start_gold_btn.pressed.connect(func(): _request_upgrade(U_START_GOLD))
	else:
		push_warning("[InterLevelEconomyUI] start_gold_btn introuvable")

	if wave_gold_btn:
		wave_gold_btn.pressed.connect(func(): _request_upgrade(U_WAVE_SKIP_GOLD))
	else:
		push_warning("[InterLevelEconomyUI] wave_gold_btn introuvable")

	if building_hp_btn:
		building_hp_btn.pressed.connect(func(): _request_upgrade(U_BUILDING_HP))
	else:
		push_warning("[InterLevelEconomyUI] building_hp_btn introuvable")

	if previous_btn:
		previous_btn.pressed.connect(_on_previous_pressed)
	else:
		push_warning("[InterLevelEconomyUI] previous_btn introuvable (previous_btn_path)")

	if next_btn:
		next_btn.pressed.connect(_on_next_pressed)
	else:
		push_warning("[InterLevelEconomyUI] next_btn introuvable (next_btn_path)")

	_bind_overlay()
	_close_overlay()
	_refresh_buttons_state()


func _n(rel_path: String) -> Node:
	if confirm_overlay == null:
		return null
	return confirm_overlay.get_node_or_null(rel_path)


func _bind_overlay() -> void:
	if confirm_overlay == null:
		push_warning("[InterLevelEconomyUI] confirm_overlay introuvable")
		return

	if _ov_cancel:
		_ov_cancel.pressed.connect(_on_overlay_cancel)
	else:
		push_warning("[InterLevelEconomyUI] CancelBtn introuvable dans ConfirmOverlay")

	if _ov_confirm:
		_ov_confirm.pressed.connect(_on_overlay_confirm)
	else:
		push_warning("[InterLevelEconomyUI] ConfirmBtn introuvable dans ConfirmOverlay")

	if _ov_dimmer:
		_ov_dimmer.gui_input.connect(_on_dimmer_gui_input)


func _on_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_overlay_cancel()


func _meta_key(upgrade_id: StringName) -> StringName:
	return StringName("meta_upgrade_level_%s" % String(upgrade_id))


func _get_level(upgrade_id: StringName) -> int:
	if Game == null:
		return 0
	return int(Game.get_meta(_meta_key(upgrade_id), 0))


func _set_level(upgrade_id: StringName, level: int) -> void:
	if Game == null:
		return
	Game.set_meta(_meta_key(upgrade_id), clampi(level, 0, MAX_LEVEL))


func _refresh_buttons_state() -> void:
	_refresh_one_button(start_gold_btn, U_START_GOLD)
	_refresh_one_button(wave_gold_btn, U_WAVE_SKIP_GOLD)
	_refresh_one_button(building_hp_btn, U_BUILDING_HP)


func _refresh_one_button(btn: BaseButton, upgrade_id: StringName) -> void:
	if btn == null:
		return

	var level := _get_level(upgrade_id)
	var is_max := level >= MAX_LEVEL

	var next_cost := 0
	if not is_max:
		next_cost = _get_cost_for_next_level(level)

	var can_buy := (not is_max) and (Game != null) and Game.can_spend_bank_crystals(next_cost)

	# ✅ IMPORTANT :
	# - si MAX : on laisse cliquable (disabled=false) mais on grise
	# - si pas MAX : disabled seulement si pas achetable
	if is_max:
		btn.disabled = false
		btn.modulate.a = MAX_GRAY_ALPHA
	else:
		btn.disabled = not can_buy
		btn.modulate.a = 1.0

	btn.tooltip_text = _build_tooltip_text(upgrade_id, level, next_cost, is_max)


func _request_upgrade(upgrade_id: StringName) -> void:
	var level := _get_level(upgrade_id)

	# ✅ Si MAX : on ouvre quand même l'overlay avec les infos chiffrées
	if level >= MAX_LEVEL:
		var title := _get_title(upgrade_id)
		var desc := _get_desc(upgrade_id)

		var details := "Niveau actuel : %d/%d\n%s\n\n(MAX)" % [
			level, MAX_LEVEL, _effect_line(upgrade_id, level)
		]

		# overlay info (pas d'achat)
		_open_info("%s (MAX)" % title, desc + "\n\n" + details)
		return

	# ✅ Sinon : overlay achat classique
	var title := _get_title(upgrade_id)
	var desc := _get_desc(upgrade_id)
	var cost := _get_cost_for_next_level(level)

	_pending_mode = PendingMode.PURCHASE
	_pending_upgrade_id = upgrade_id
	_pending_cost = cost

	var details := _build_purchase_details(upgrade_id, level, cost)
	_open_purchase(title, desc + "\n\n" + details, cost)


func _apply_pending_purchase() -> void:
	if _pending_upgrade_id == &"":
		return
	if Game == null:
		push_warning("[InterLevelEconomyUI] Autoload Game introuvable")
		return

	var upgrade_id := _pending_upgrade_id
	var level := _get_level(upgrade_id)
	if level >= MAX_LEVEL:
		return

	if not Game.try_spend_bank_crystals(_pending_cost):
		_open_info("Pas assez de cristaux", "Tu n'as pas assez de cristaux en banque pour acheter cette amélioration.")
		return

	_set_level(upgrade_id, level + 1)
	_refresh_buttons_state()


func _open_purchase(title: String, desc: String, cost: int) -> void:
	if _ov_confirm:
		_ov_confirm.disabled = false
	if confirm_overlay == null:
		return

	_open_overlay_animated()
	if _ov_title: _ov_title.text = title
	if _ov_desc: _ov_desc.text = desc
	if _ov_cost:
		_ov_cost.visible = true
		_ov_cost.text = "Coût : %d cristaux" % cost


func _open_info(title: String, desc: String, clear_pending: bool = true, confirm_enabled: bool = false) -> void:
	if clear_pending:
		_pending_mode = PendingMode.NONE
		_pending_upgrade_id = &""
		_pending_cost = 0

	if _ov_confirm:
		_ov_confirm.disabled = not confirm_enabled

	if confirm_overlay == null:
		return

	_open_overlay_animated()
	if _ov_title: _ov_title.text = title
	if _ov_desc: _ov_desc.text = desc
	if _ov_cost: _ov_cost.visible = false


func _close_overlay() -> void:
	_pending_mode = PendingMode.NONE
	_pending_upgrade_id = &""
	_pending_cost = 0
	_close_overlay_animated()


func _on_overlay_cancel() -> void:
	_close_overlay()


func _on_overlay_confirm() -> void:
	match _pending_mode:
		PendingMode.PURCHASE:
			_apply_pending_purchase()
			_close_overlay()
		PendingMode.NEXT_CONFIRM:
			_close_overlay()
			_change_to_next_scene()
		_:
			_close_overlay()


func _on_previous_pressed() -> void:
	if not previous_scene_path.is_empty():
		get_tree().change_scene_to_file(previous_scene_path)
	else:
		push_warning("[InterLevelEconomyUI] previous_scene_path non assigné")


func _on_next_pressed() -> void:
	_pending_mode = PendingMode.NEXT_CONFIRM
	_pending_upgrade_id = &""
	_pending_cost = 0
	_open_info("Lancer le niveau", "Es-tu sûr de vouloir commencer le prochain niveau ?", false, true)


func _change_to_next_scene() -> void:
	if not next_scene_path.is_empty():
		get_tree().change_scene_to_file(next_scene_path)
	else:
		push_warning("[InterLevelEconomyUI] next_scene_path non assigné")


func _get_title(upgrade_id: StringName) -> String:
	match upgrade_id:
		U_START_GOLD: return "Or de départ"
		U_WAVE_SKIP_GOLD: return "Bonus d'or entre vagues"
		U_BUILDING_HP: return "Solidité des bâtiments"
		_: return "Amélioration"


func _get_desc(upgrade_id: StringName) -> String:
	match upgrade_id:
		U_START_GOLD:
			return "Ajoute de l'or au début du niveau."
		U_WAVE_SKIP_GOLD:
			return "Multiplie l'or reçu quand tu abrèges le temps entre les vagues."
		U_BUILDING_HP:
			return "Multiplie les points de vie de tes bâtiments."
		_:
			return ""


func _get_cost_for_next_level(current_level: int) -> int:
	# current_level = 0..4 pour un achat -> index direct
	return COSTS_COMMON[current_level]


# ---------------------------
# Effets (nouvelle logique)
# ---------------------------
func _start_gold_total(level: int) -> int:
	# niveau 0: 300
	# niveau 1: 300 + 100 = 400
	# niveau 2: 300 + 300 = 600
	if level <= 0:
		return BASE_START_GOLD
	var idx := clampi(level - 1, 0, 4)
	return BASE_START_GOLD + int(VALUES_START_GOLD_BONUS[idx])


func _multiplier_for(level: int, values: Array) -> float:
	# niveau 0: x1.0
	# niveau 1: values[0] (1.5)
	if level <= 0:
		return 1.0
	var idx := clampi(level - 1, 0, 4)
	return float(values[idx])


func _effect_line(upgrade_id: StringName, level: int) -> String:
	match upgrade_id:
		U_START_GOLD:
			var total := _start_gold_total(level)
			var bonus := total - BASE_START_GOLD
			return "Or de départ : %d  (bonus +%d)" % [total, bonus]
		U_WAVE_SKIP_GOLD:
			return "Multiplicateur : x%.1f" % _multiplier_for(level, VALUES_WAVE_GOLD_MULT)
		U_BUILDING_HP:
			return "Multiplicateur PV : x%.1f" % _multiplier_for(level, VALUES_BUILDING_HP_MULT)
		_:
			return ""


func _get_effect_text(upgrade_id: StringName, level: int) -> String:
	# version courte pour tooltips
	match upgrade_id:
		U_START_GOLD:
			return "%d or" % _start_gold_total(level)
		U_WAVE_SKIP_GOLD:
			return "x%.1f" % _multiplier_for(level, VALUES_WAVE_GOLD_MULT)
		U_BUILDING_HP:
			return "x%.1f" % _multiplier_for(level, VALUES_BUILDING_HP_MULT)
		_:
			return ""


func _build_purchase_details(upgrade_id: StringName, current_level: int, cost: int) -> String:
	var next_level := current_level + 1
	return "Niveau actuel : %d/%d\n%s\n\nAprès achat : %d/%d\n%s\n\nCoût : %d cristaux" % [
		current_level, MAX_LEVEL, _effect_line(upgrade_id, current_level),
		next_level, MAX_LEVEL, _effect_line(upgrade_id, next_level),
		cost
	]


func _build_tooltip_text(upgrade_id: StringName, level: int, next_cost: int, is_max: bool) -> String:
	var title := _get_title(upgrade_id)

	if is_max:
		return "%s\nNiveau %d/%d\nEffet : %s\n(MAX)" % [
			title, level, MAX_LEVEL, _get_effect_text(upgrade_id, level)
		]

	var can_buy := (Game != null) and Game.can_spend_bank_crystals(next_cost)
	var status := "OK" if can_buy else "Pas assez de cristaux"

	return "%s\nNiveau %d/%d\nActuel : %s\nProchain : %s\nCoût : %d (%s)" % [
		title, level, MAX_LEVEL,
		_get_effect_text(upgrade_id, level),
		_get_effect_text(upgrade_id, level + 1),
		next_cost, status
	]


# ---------------------------
# Overlay anim (safe)
# ---------------------------
func _kill_ov_tween() -> void:
	if _ov_tween and _ov_tween.is_valid():
		_ov_tween.kill()
	_ov_tween = null


func _open_overlay_animated() -> void:
	if confirm_overlay == null:
		return

	_overlay_open = true
	confirm_overlay.visible = true
	_kill_ov_tween()

	if _ov_dimmer_rect:
		_ov_dimmer_rect.modulate.a = 0.0
		_ov_dimmer_rect.scale = Vector2(1.0, dimmer_start_scale_y)

	if _ov_panel:
		_ov_panel.modulate.a = 0.0
		_ov_panel.scale = Vector2(ov_closed_scale, ov_closed_scale)

	_ov_tween = create_tween()
	_ov_tween.set_parallel(true)

	if _ov_dimmer_rect:
		_ov_tween.tween_property(_ov_dimmer_rect, "modulate:a", 1.0, dimmer_fade_duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_ov_tween.tween_property(_ov_dimmer_rect, "scale:y", 1.0, dimmer_open_duration)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if _ov_panel:
		_ov_tween.tween_property(_ov_panel, "scale", Vector2.ONE, ov_open_duration)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_ov_tween.tween_property(_ov_panel, "modulate:a", 1.0, ov_open_fade_duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _close_overlay_animated() -> void:
	if confirm_overlay == null:
		return
	if not _overlay_open:
		confirm_overlay.visible = false
		return

	_overlay_open = false
	_kill_ov_tween()

	if _ov_panel == null and _ov_dimmer_rect == null:
		confirm_overlay.visible = false
		return

	_ov_tween = create_tween()
	_ov_tween.set_parallel(true)

	if _ov_dimmer_rect:
		_ov_tween.tween_property(_ov_dimmer_rect, "modulate:a", 0.0, dimmer_fade_duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_ov_tween.tween_property(_ov_dimmer_rect, "scale:y", dimmer_start_scale_y, dimmer_open_duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if _ov_panel:
		_ov_tween.tween_property(_ov_panel, "scale", Vector2(ov_closed_scale, ov_closed_scale), ov_close_duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_ov_tween.tween_property(_ov_panel, "modulate:a", 0.0, ov_close_fade_duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if _ov_tween:
		if _ov_tween.finished.is_connected(_on_overlay_tween_finished):
			_ov_tween.finished.disconnect(_on_overlay_tween_finished)
		_ov_tween.finished.connect(_on_overlay_tween_finished)


func _on_overlay_tween_finished() -> void:
	if confirm_overlay:
		confirm_overlay.visible = false
