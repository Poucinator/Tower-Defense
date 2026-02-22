extends Control
class_name LaboUI

const MK3_COST := 50
const MK3_TITLE_TEXT := "Amélioration max du niveau de la tour"
# =========================================================
#                 EXPORTS (références UI)
# =========================================================
# --- Boutons Tours ---
@export var barrack_btn_path: NodePath
@export var gun_btn_path: NodePath
@export var snipe_btn_path: NodePath
@export var missile_btn_path: NodePath

# --- Boutons Pouvoirs ---
@export var freeze_btn_path: NodePath
@export var summon_btn_path: NodePath
@export var heal_btn_path: NodePath

# Cadre commun
@export var upgrade_frame_path: NodePath

# --- Menus (optionnels) : un Control par item ---
@export var barracks_menu_path: NodePath
@export var gun_menu_path: NodePath
@export var snipe_menu_path: NodePath
@export var missile_menu_path: NodePath

@export var freeze_menu_path: NodePath
@export var summon_menu_path: NodePath
@export var heal_menu_path: NodePath

@export var upgrade_texts: UpgradeTexts

# --- Bouton "Next" / scene suivante ---
@export var next_btn_path: NodePath
@export_file("*.tscn") var next_scene_path: String



# =========================================================
#     CONFIRM OVERLAY (confirmation achat)
# =========================================================
@export var confirm_overlay_path: NodePath
@export var confirm_title_label_path: NodePath
@export var confirm_desc_label_path: NodePath
@export var confirm_cost_label_path: NodePath
@export var confirm_cancel_btn_path: NodePath
@export var confirm_confirm_btn_path: NodePath


# =========================================================
#                 EXPORTS (animation / feeling)
# =========================================================
@export_range(0.05, 1.0, 0.01) var open_duration: float = 0.28
@export_range(0.05, 1.0, 0.01) var open_fade_duration: float = 0.18
@export_range(0.05, 1.0, 0.01) var close_duration: float = 0.20
@export_range(0.05, 1.0, 0.01) var close_fade_duration: float = 0.14

@export var closed_scale: float = 0.85
@export_range(1.0, 1.2, 0.01) var pulse_scale: float = 1.02
@export_range(0.02, 0.3, 0.01) var pulse_in_duration: float = 0.06
@export_range(0.02, 0.4, 0.01) var pulse_out_duration: float = 0.10

# =========================================================
#     EXPORTS (bouton Buff Barracks : UI)
# =========================================================
@export var barracks_buff_btn_path: NodePath
@export var barracks_buff_label_path: NodePath # optionnel (Label)

# =========================================================
#     EXPORTS (bouton Slow Gun : UI)
# =========================================================
@export var gun_slow_btn_path: NodePath
@export var gun_slow_label_path: NodePath # optionnel (Label)

# =========================================================
#     EXPORTS (bouton Break Snipe : UI)
# =========================================================
@export var snipe_break_btn_path: NodePath
@export var snipe_break_label_path: NodePath # optionnel (Label)

# =========================================================
#     EXPORTS (bouton Fire Missile : UI) ✅
# =========================================================
@export var missile_fire_btn_path: NodePath
@export var missile_fire_label_path: NodePath # optionnel (Label)

# =========================================================
#     EXPORTS (FREEZE : 3 upgrades) ✅ NOUVEAU
# =========================================================
@export var freeze_cooldown_btn_path: NodePath
@export var freeze_cooldown_label_path: NodePath # optionnel

@export var freeze_level_btn_path: NodePath
@export var freeze_level_label_path: NodePath # optionnel

@export var freeze_number_btn_path: NodePath
@export var freeze_number_label_path: NodePath # optionnel

# =========================================================
#     EXPORTS (SUMMON : 3 upgrades) ✅ NOUVEAU
# =========================================================
@export var summon_cooldown_btn_path: NodePath
@export var summon_cooldown_label_path: NodePath 

@export var summon_marine_lvl_btn_path: NodePath
@export var summon_marine_lvl_label_path: NodePath 

@export var summon_number_btn_path: NodePath
@export var summon_number_label_path: NodePath 

# =========================================================
#     HEAL : 3 upgrades ✅
# =========================================================
@export var heal_cooldown_btn_path: NodePath
@export var heal_cooldown_label_path: NodePath

@export var heal_revive_btn_path: NodePath
@export var heal_revive_label_path: NodePath

@export var heal_inv_btn_path: NodePath
@export var heal_inv_label_path: NodePath


# =========================================================
#                 EXPORTS (icône item : tours + pouvoirs)
# =========================================================
@export var item_icon_path: NodePath

# --- Textures Tours ---
@export var barracks_icon: Texture2D
@export var gun_icon: Texture2D
@export var snipe_icon: Texture2D
@export var missile_icon: Texture2D

# --- Textures Pouvoirs ---
@export var freeze_icon: Texture2D
@export var summon_icon: Texture2D
@export var heal_icon: Texture2D

# =========================================================
#                 EXPORTS (bouton MK3 : UI)
# =========================================================
@export var mk3_btn_path: NodePath
@export var mk3_cost_label_path: NodePath 
@export var mk3_title_label_path: NodePath 

# Textures MK3 (une par tour) - au minimum "normal"
@export var mk3_barracks_normal: Texture2D
@export var mk3_gun_normal: Texture2D
@export var mk3_snipe_normal: Texture2D
@export var mk3_missile_normal: Texture2D

# (Optionnel) hover/pressed si tu as des variantes
@export var mk3_barracks_hover: Texture2D
@export var mk3_gun_hover: Texture2D
@export var mk3_snipe_hover: Texture2D
@export var mk3_missile_hover: Texture2D

@export var mk3_barracks_pressed: Texture2D
@export var mk3_gun_pressed: Texture2D
@export var mk3_snipe_pressed: Texture2D
@export var mk3_missile_pressed: Texture2D

# =========================================================
#                 INTERNES (nodes)
# =========================================================
@onready var barrack_btn: BaseButton = get_node_or_null(barrack_btn_path)
@onready var gun_btn: BaseButton = get_node_or_null(gun_btn_path)
@onready var snipe_btn: BaseButton = get_node_or_null(snipe_btn_path)
@onready var missile_btn: BaseButton = get_node_or_null(missile_btn_path)

@onready var freeze_btn: BaseButton = get_node_or_null(freeze_btn_path)
@onready var summon_btn: BaseButton = get_node_or_null(summon_btn_path)
@onready var heal_btn: BaseButton = get_node_or_null(heal_btn_path)

@onready var upgrade_frame: Control = get_node_or_null(upgrade_frame_path)

# Menus (optionnels)
@onready var barracks_menu: Control = get_node_or_null(barracks_menu_path)
@onready var gun_menu: Control = get_node_or_null(gun_menu_path)
@onready var snipe_menu: Control = get_node_or_null(snipe_menu_path)
@onready var missile_menu: Control = get_node_or_null(missile_menu_path)

@onready var freeze_menu: Control = get_node_or_null(freeze_menu_path)
@onready var summon_menu: Control = get_node_or_null(summon_menu_path)
@onready var heal_menu: Control = get_node_or_null(heal_menu_path)

# Icône + MK3 UI
@onready var item_icon: TextureRect = get_node_or_null(item_icon_path)
@onready var mk3_btn: TextureButton = get_node_or_null(mk3_btn_path)
@onready var mk3_cost_label: Label = get_node_or_null(mk3_cost_label_path)
@onready var mk3_title_label: Label = get_node_or_null(mk3_title_label_path) 

# Barracks Buff UI
@onready var barracks_buff_btn: BaseButton = get_node_or_null(barracks_buff_btn_path)
@onready var barracks_buff_label: Label = get_node_or_null(barracks_buff_label_path)

# Gun Slow UI
@onready var gun_slow_btn: BaseButton = get_node_or_null(gun_slow_btn_path)
@onready var gun_slow_label: Label = get_node_or_null(gun_slow_label_path)

# Snipe Break UI
@onready var snipe_break_btn: BaseButton = get_node_or_null(snipe_break_btn_path)
@onready var snipe_break_label: Label = get_node_or_null(snipe_break_label_path)

# Missile Fire UI ✅
@onready var missile_fire_btn: BaseButton = get_node_or_null(missile_fire_btn_path)
@onready var missile_fire_label: Label = get_node_or_null(missile_fire_label_path)

# Freeze UI ✅ NOUVEAU
@onready var freeze_cooldown_btn: BaseButton = get_node_or_null(freeze_cooldown_btn_path)
@onready var freeze_cooldown_label: Label = get_node_or_null(freeze_cooldown_label_path)

@onready var freeze_level_btn: BaseButton = get_node_or_null(freeze_level_btn_path)
@onready var freeze_level_label: Label = get_node_or_null(freeze_level_label_path)

@onready var freeze_number_btn: BaseButton = get_node_or_null(freeze_number_btn_path)
@onready var freeze_number_label: Label = get_node_or_null(freeze_number_label_path)

# Summon UI ✅ NOUVEAU
@onready var summon_cooldown_btn: BaseButton = get_node_or_null(summon_cooldown_btn_path)
@onready var summon_cooldown_label: Label = get_node_or_null(summon_cooldown_label_path)

@onready var summon_marine_lvl_btn: BaseButton = get_node_or_null(summon_marine_lvl_btn_path)
@onready var summon_marine_lvl_label: Label = get_node_or_null(summon_marine_lvl_label_path)

@onready var summon_number_btn: BaseButton = get_node_or_null(summon_number_btn_path)
@onready var summon_number_label: Label = get_node_or_null(summon_number_label_path)

@onready var heal_cooldown_btn: BaseButton = get_node_or_null(heal_cooldown_btn_path)
@onready var heal_cooldown_label: Label = get_node_or_null(heal_cooldown_label_path)

@onready var heal_revive_btn: BaseButton = get_node_or_null(heal_revive_btn_path)
@onready var heal_revive_label: Label = get_node_or_null(heal_revive_label_path)

@onready var heal_inv_btn: BaseButton = get_node_or_null(heal_inv_btn_path)
@onready var heal_inv_label: Label = get_node_or_null(heal_inv_label_path)

@onready var confirm_overlay: Control = get_node_or_null(confirm_overlay_path)
@onready var confirm_title_label: Label = get_node_or_null(confirm_title_label_path)
@onready var confirm_desc_label: Label = get_node_or_null(confirm_desc_label_path)
@onready var confirm_cost_label: Label = get_node_or_null(confirm_cost_label_path)
@onready var confirm_cancel_btn: BaseButton = get_node_or_null(confirm_cancel_btn_path)
@onready var confirm_confirm_btn: BaseButton = get_node_or_null(confirm_confirm_btn_path)

@onready var next_btn: BaseButton = get_node_or_null(next_btn_path) as BaseButton

# =========================================================
#                 ETAT
# =========================================================
var _tween: Tween
var _is_open := false

enum ItemId { BARRACKS, GUN, SNIPE, MISSILE, FREEZE, SUMMON, HEAL }
var _current_item: ItemId = ItemId.GUN

var _confirm_action: Callable = Callable()
var _confirm_is_open := false


# =========================================================
#   Fallbacks locaux (si Game n'expose pas les coûts/params
# =========================================================
const GUN_SLOW_MAX_LEVEL := 3
const GUN_SLOW_COST_BY_LEVEL := { 1: 20, 2: 35, 3: 50 }
const GUN_SLOW_FACTOR_BY_LEVEL := { 1: 0.85, 2: 0.75, 3: 0.65 }
const GUN_SLOW_DURATION_BY_LEVEL := { 1: 1.2, 2: 1.5, 3: 1.8 }

const SNIPE_BREAK_MAX_LEVEL := 3
const SNIPE_BREAK_COST_BY_LEVEL := { 1: 50, 2: 100, 3: 150 }
const SNIPE_BREAK_EXTRA_HITS_BY_LEVEL := { 0: 0, 1: 1, 2: 2, 3: 3 }


# Missile Fire (placeholder) ✅
const MISSILE_FIRE_MAX_LEVEL := 3
const MISSILE_FIRE_COST_BY_LEVEL := { 1: 60, 2: 120, 3: 220 }
const MISSILE_FIRE_CHANCE_BY_LEVEL := { 1: 0.10, 2: 0.18, 3: 0.25 } # 10% / 18% / 25%
const MISSILE_FIRE_DPS_PCT_BY_LEVEL := { 1: 0.10, 2: 0.14, 3: 0.18 } # % des dégâts tour / sec
const MISSILE_FIRE_DURATION_BY_LEVEL := { 1: 2.0, 2: 3.0, 3: 4.0 }   # sec

# Freeze (fallbacks) ✅
const FREEZE_CD_BASE := 20.0
const FREEZE_CD_MAX_LEVEL := 3
const FREEZE_CD_COST_BY_LEVEL := { 1: 50, 2: 200, 3: 1000 }
const FREEZE_CD_SECONDS_BY_LEVEL := { 1: 17.0, 2: 14.0, 3: 10.0 }

const FREEZE_STRENGTH_BASE := 0.8
const FREEZE_STRENGTH_MAX_LEVEL := 3
const FREEZE_STRENGTH_COST_BY_LEVEL := { 1: 50, 2: 200, 3: 1000 }
const FREEZE_STRENGTH_FACTOR_BY_LEVEL := { 1: 0.6, 2: 0.4, 3: 0.0 } # x0 = arrêt

const FREEZE_NUMBER_BASE := 1
const FREEZE_NUMBER_MAX_LEVEL := 3
const FREEZE_NUMBER_COST_BY_LEVEL := { 1: 200, 2: 1000, 3: 3000 }
const FREEZE_NUMBER_VALUE_BY_LEVEL := { 1: 2, 2: 3, 3: 4 }

# Summon (fallbacks) ✅
const SUMMON_CD_BASE := 20.0
const SUMMON_CD_MAX_LEVEL := 3
const SUMMON_CD_COST_BY_LEVEL := { 1: 50, 2: 200, 3: 1000 }
const SUMMON_CD_SECONDS_BY_LEVEL := { 1: 17.0, 2: 14.0, 3: 10.0 }

const SUMMON_MARINE_BASE_TIER := 1 # MK1
const SUMMON_MARINE_MAX_LEVEL := 4
const SUMMON_MARINE_COST_BY_LEVEL := { 1: 50, 2: 200, 3: 1000, 4: 3000 }
const SUMMON_MARINE_TIER_BY_LEVEL := { 1: 2, 2: 3, 3: 4, 4: 5 } # MK2..MK5

const SUMMON_NUMBER_BASE := 3
const SUMMON_NUMBER_MAX_LEVEL := 3
const SUMMON_NUMBER_COST_BY_LEVEL := { 1: 200, 2: 1000, 3: 3000 }
const SUMMON_NUMBER_VALUE_BY_LEVEL := { 1: 4, 2: 5, 3: 6 }


# =========================================================
#   Feeling "gris" comme MK3
# =========================================================
const DISABLED_ALPHA := 0.45

func _set_button_state(btn: BaseButton, disabled: bool, gray: bool) -> void:
	if btn == null:
		return
	btn.disabled = disabled
	btn.modulate = Color(1, 1, 1, DISABLED_ALPHA) if gray else Color(1, 1, 1, 1)

func _ready() -> void:
	if not upgrade_frame:
		push_warning("[LaboUI] upgrade_frame introuvable (upgrade_frame_path)")
		return

	upgrade_frame.visible = false
	upgrade_frame.scale = Vector2(closed_scale, closed_scale)
	upgrade_frame.modulate.a = 0.0

	_connect_btn(barrack_btn, func(): _on_item_button_pressed(ItemId.BARRACKS))
	_connect_btn(gun_btn,     func(): _on_item_button_pressed(ItemId.GUN))
	_connect_btn(snipe_btn,   func(): _on_item_button_pressed(ItemId.SNIPE))
	_connect_btn(missile_btn, func(): _on_item_button_pressed(ItemId.MISSILE))

	_connect_btn(freeze_btn, func(): _on_item_button_pressed(ItemId.FREEZE))
	_connect_btn(summon_btn, func(): _on_item_button_pressed(ItemId.SUMMON))
	_connect_btn(heal_btn,   func(): _on_item_button_pressed(ItemId.HEAL))

	_hide_all_menus()

	if item_icon:
		item_icon.visible = false
		item_icon.texture = null
	else:
		push_warning("[LaboUI] item_icon introuvable (item_icon_path)")

	if mk3_btn:
		mk3_btn.visible = false
		mk3_btn.pressed.connect(_on_mk3_pressed)
	else:
		push_warning("[LaboUI] mk3_btn introuvable (mk3_btn_path)")

	if mk3_cost_label:
		mk3_cost_label.visible = false

	if mk3_title_label:
		mk3_title_label.visible = false
	else:
		push_warning("[LaboUI] mk3_title_label introuvable (mk3_title_label_path)")


	if barracks_buff_btn:
		barracks_buff_btn.visible = false
		barracks_buff_btn.pressed.connect(_on_barracks_buff_pressed)
	else:
		push_warning("[LaboUI] barracks_buff_btn introuvable (barracks_buff_btn_path)")

	if barracks_buff_label:
		barracks_buff_label.visible = false

	if gun_slow_btn:
		gun_slow_btn.visible = false
		gun_slow_btn.pressed.connect(_on_gun_slow_pressed)
	else:
		push_warning("[LaboUI] gun_slow_btn introuvable (gun_slow_btn_path)")

	if gun_slow_label:
		gun_slow_label.visible = false

	if snipe_break_btn:
		snipe_break_btn.visible = false
		snipe_break_btn.pressed.connect(_on_snipe_break_pressed)
	else:
		push_warning("[LaboUI] snipe_break_btn introuvable (snipe_break_btn_path)")

	if snipe_break_label:
		snipe_break_label.visible = false

	# ✅ Missile Fire
	if missile_fire_btn:
		missile_fire_btn.visible = false
		missile_fire_btn.pressed.connect(_on_missile_fire_pressed)
	else:
		push_warning("[LaboUI] missile_fire_btn introuvable (missile_fire_btn_path)")

	if missile_fire_label:
		missile_fire_label.visible = false

	# ✅ FREEZE (3 upgrades)
	if freeze_cooldown_btn:
		freeze_cooldown_btn.visible = false
		freeze_cooldown_btn.pressed.connect(_on_freeze_cooldown_pressed)
	else:
		push_warning("[LaboUI] freeze_cooldown_btn introuvable (freeze_cooldown_btn_path)")

	if freeze_cooldown_label:
		freeze_cooldown_label.visible = false

	if freeze_level_btn:
		freeze_level_btn.visible = false
		freeze_level_btn.pressed.connect(_on_freeze_level_pressed)
	else:
		push_warning("[LaboUI] freeze_level_btn introuvable (freeze_level_btn_path)")

	if freeze_level_label:
		freeze_level_label.visible = false

	if freeze_number_btn:
		freeze_number_btn.visible = false
		freeze_number_btn.pressed.connect(_on_freeze_number_pressed)
	else:
		push_warning("[LaboUI] freeze_number_btn introuvable (freeze_number_btn_path)")

	if freeze_number_label:
		freeze_number_label.visible = false

	# ✅ HEAL (3 upgrades)
	if heal_cooldown_btn:
		heal_cooldown_btn.visible = false
		heal_cooldown_btn.pressed.connect(_on_heal_cooldown_pressed)
	if heal_cooldown_label:
		heal_cooldown_label.visible = false

	if heal_revive_btn:
		heal_revive_btn.visible = false
		heal_revive_btn.pressed.connect(_on_heal_revive_pressed)
	if heal_revive_label:
		heal_revive_label.visible = false

	if heal_inv_btn:
		heal_inv_btn.visible = false
		heal_inv_btn.pressed.connect(_on_heal_inv_pressed)
	if heal_inv_label:
		heal_inv_label.visible = false

	if confirm_overlay:
		confirm_overlay.visible = false

	if confirm_cancel_btn and not confirm_cancel_btn.pressed.is_connected(_on_confirm_cancel):
		confirm_cancel_btn.pressed.connect(_on_confirm_cancel)

	if confirm_confirm_btn and not confirm_confirm_btn.pressed.is_connected(_on_confirm_accept):
		confirm_confirm_btn.pressed.connect(_on_confirm_accept)

	# ✅ SUMMON (3 upgrades)
	if summon_cooldown_btn:
		summon_cooldown_btn.visible = false
		summon_cooldown_btn.pressed.connect(_on_summon_cooldown_pressed)
	else:
		push_warning("[LaboUI] summon_cooldown_btn introuvable (summon_cooldown_btn_path)")

	if summon_cooldown_label:
		summon_cooldown_label.visible = false

	if summon_marine_lvl_btn:
		summon_marine_lvl_btn.visible = false
		summon_marine_lvl_btn.pressed.connect(_on_summon_marine_lvl_pressed)
	else:
		push_warning("[LaboUI] summon_marine_lvl_btn introuvable (summon_marine_lvl_btn_path)")

	if summon_marine_lvl_label:
		summon_marine_lvl_label.visible = false

	if summon_number_btn:
		summon_number_btn.visible = false
		summon_number_btn.pressed.connect(_on_summon_number_pressed)
	else:
		push_warning("[LaboUI] summon_number_btn introuvable (summon_number_btn_path)")

	if summon_number_label:
		summon_number_label.visible = false

	if next_btn:
		if not next_btn.pressed.is_connected(_on_next_pressed):
			next_btn.pressed.connect(_on_next_pressed)
	else:
		push_warning("[LaboUI] next_btn introuvable (next_btn_path)")


	if Game and Game.has_signal("bank_crystals_changed"):
		if not Game.bank_crystals_changed.is_connected(_on_bank_crystals_changed):
			Game.bank_crystals_changed.connect(_on_bank_crystals_changed)

	_current_item = ItemId.GUN

func _connect_btn(btn: BaseButton, cb: Callable) -> void:
	if btn:
		btn.pressed.connect(cb)
	else:
		push_warning("[LaboUI] Un bouton est introuvable (NodePath export ?)")

# =========================================================
#                 LOGIQUE : click item
# =========================================================
func _on_item_button_pressed(item_id: ItemId) -> void:
	if _is_open and item_id == _current_item:
		close_frame()
		return
	open_item(item_id)

# =========================================================
#                 API : ouverture menu
# =========================================================
func open_item(item_id: ItemId) -> void:
		# ✅ si un confirm est ouvert, on le ferme comme Cancel
	if _confirm_is_open:
		_close_confirm()


	_current_item = item_id

	_show_menu_for(item_id)
	_update_item_icon(item_id)
	_update_mk3_button(item_id)
	_update_barracks_buff_ui(item_id)
	_update_gun_slow_ui(item_id)
	_update_snipe_break_ui(item_id)
	_update_missile_fire_ui(item_id)

	# ✅ Freeze (3 upgrades)
	_update_freeze_cooldown_ui(item_id)
	_update_freeze_level_ui(item_id)
	_update_freeze_number_ui(item_id)

	# ✅ Summon (3 upgrades)
	_update_summon_cooldown_ui(item_id)
	_update_summon_marine_lvl_ui(item_id)
	_update_summon_number_ui(item_id)

	# ✅ Heal (3 upgrades)
	_update_heal_cooldown_ui(item_id)
	_update_heal_revive_ui(item_id)
	_update_heal_inv_ui(item_id)

	if not _is_open:
		_open_frame_animated()
	else:
		_pulse_frame()

func _open_frame_animated() -> void:
	_is_open = true
	upgrade_frame.visible = true
	_kill_tween()

	upgrade_frame.scale = Vector2(closed_scale, closed_scale)
	upgrade_frame.modulate.a = 0.0

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(upgrade_frame, "scale", Vector2.ONE, open_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(upgrade_frame, "modulate:a", 1.0, open_fade_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func close_frame() -> void:
	if not _is_open:
		return
	_close_confirm()

	_is_open = false

	_kill_tween()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(upgrade_frame, "scale", Vector2(closed_scale, closed_scale), close_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(upgrade_frame, "modulate:a", 0.0, close_fade_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	_tween.finished.connect(func():
		upgrade_frame.visible = false
		_hide_all_menus()
		_reset_header_ui()
	)

func _pulse_frame() -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(upgrade_frame, "scale", Vector2(pulse_scale, pulse_scale), pulse_in_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(upgrade_frame, "scale", Vector2.ONE, pulse_out_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null

func _reset_header_ui() -> void:
	if item_icon:
		item_icon.visible = false
		item_icon.texture = null

	if mk3_title_label:
		mk3_title_label.visible = false
		# Optionnel : vider le texte pour éviter tout “flash”
		mk3_title_label.text = ""


	if mk3_btn:
		mk3_btn.visible = false
		mk3_btn.disabled = false
		mk3_btn.modulate = Color(1, 1, 1, 1)

	if mk3_cost_label:
		mk3_cost_label.visible = false

	if barracks_buff_btn:
		barracks_buff_btn.visible = false
		_set_button_state(barracks_buff_btn, false, false)
	if barracks_buff_label:
		barracks_buff_label.visible = false

	if gun_slow_btn:
		gun_slow_btn.visible = false
		_set_button_state(gun_slow_btn, false, false)
	if gun_slow_label:
		gun_slow_label.visible = false

	if snipe_break_btn:
		snipe_break_btn.visible = false
		_set_button_state(snipe_break_btn, false, false)
	if snipe_break_label:
		snipe_break_label.visible = false

	if missile_fire_btn:
		missile_fire_btn.visible = false
		_set_button_state(missile_fire_btn, false, false)
	if missile_fire_label:
		missile_fire_label.visible = false

	# ✅ FREEZE reset
	if freeze_cooldown_btn:
		freeze_cooldown_btn.visible = false
		_set_button_state(freeze_cooldown_btn, false, false)
	if freeze_cooldown_label:
		freeze_cooldown_label.visible = false

	if freeze_level_btn:
		freeze_level_btn.visible = false
		_set_button_state(freeze_level_btn, false, false)
	if freeze_level_label:
		freeze_level_label.visible = false

	if freeze_number_btn:
		freeze_number_btn.visible = false
		_set_button_state(freeze_number_btn, false, false)
	if freeze_number_label:
		freeze_number_label.visible = false

	# ✅ HEAL reset
	if heal_cooldown_btn:
		heal_cooldown_btn.visible = false
		_set_button_state(heal_cooldown_btn, false, false)
	if heal_cooldown_label:
		heal_cooldown_label.visible = false

	if heal_revive_btn:
		heal_revive_btn.visible = false
		_set_button_state(heal_revive_btn, false, false)
	if heal_revive_label:
		heal_revive_label.visible = false

	if heal_inv_btn:
		heal_inv_btn.visible = false
		_set_button_state(heal_inv_btn, false, false)
	if heal_inv_label:
		heal_inv_label.visible = false

	# ✅ SUMMON reset
	if summon_cooldown_btn:
		summon_cooldown_btn.visible = false
		_set_button_state(summon_cooldown_btn, false, false)
	if summon_cooldown_label:
		summon_cooldown_label.visible = false

	if summon_marine_lvl_btn:
		summon_marine_lvl_btn.visible = false
		_set_button_state(summon_marine_lvl_btn, false, false)
	if summon_marine_lvl_label:
		summon_marine_lvl_label.visible = false

	if summon_number_btn:
		summon_number_btn.visible = false
		_set_button_state(summon_number_btn, false, false)
	if summon_number_label:
		summon_number_label.visible = false


# =========================================================
#                 Menus
# =========================================================
func _hide_all_menus() -> void:
	if barracks_menu: barracks_menu.visible = false
	if gun_menu: gun_menu.visible = false
	if snipe_menu: snipe_menu.visible = false
	if missile_menu: missile_menu.visible = false
	if freeze_menu: freeze_menu.visible = false
	if summon_menu: summon_menu.visible = false
	if heal_menu: heal_menu.visible = false

func _show_menu_for(item_id: ItemId) -> void:
	_hide_all_menus()

	match item_id:
		ItemId.BARRACKS:
			if barracks_menu: barracks_menu.visible = true
		ItemId.GUN:
			if gun_menu: gun_menu.visible = true
		ItemId.SNIPE:
			if snipe_menu: snipe_menu.visible = true
		ItemId.MISSILE:
			if missile_menu: missile_menu.visible = true
		ItemId.FREEZE:
			if freeze_menu: freeze_menu.visible = true
		ItemId.SUMMON:
			if summon_menu: summon_menu.visible = true
		ItemId.HEAL:
			if heal_menu: heal_menu.visible = true

# =========================================================
#                 Icône (tours + pouvoirs)
# =========================================================
func _update_item_icon(item_id: ItemId) -> void:
	if not item_icon:
		return

	var tex: Texture2D = null
	match item_id:
		ItemId.BARRACKS: tex = barracks_icon
		ItemId.GUN:      tex = gun_icon
		ItemId.SNIPE:    tex = snipe_icon
		ItemId.MISSILE:  tex = missile_icon
		ItemId.FREEZE:   tex = freeze_icon
		ItemId.SUMMON:   tex = summon_icon
		ItemId.HEAL:     tex = heal_icon

	item_icon.texture = tex
	item_icon.visible = tex != null
# =========================================================
#                 MK3 : textures + état + achat
# =========================================================
func _update_mk3_button(item_id: ItemId) -> void:
	if not mk3_btn:
		return

	# --- Si ce n'est pas une tour : on cache tout ce qui est MK3 ---
	if not _is_tower(item_id):
		mk3_btn.visible = false
		if mk3_cost_label:
			mk3_cost_label.visible = false
		if mk3_title_label:
			mk3_title_label.visible = false
			mk3_title_label.text = ""
		return

	# --- C'est une tour : on affiche le titre MK3 ---
	if mk3_title_label:
		mk3_title_label.text = MK3_TITLE_TEXT
		mk3_title_label.visible = true

	var normal: Texture2D = null
	var hover: Texture2D = null
	var pressed: Texture2D = null

	match item_id:
		ItemId.BARRACKS:
			normal = mk3_barracks_normal
			hover = mk3_barracks_hover
			pressed = mk3_barracks_pressed
		ItemId.GUN:
			normal = mk3_gun_normal
			hover = mk3_gun_hover
			pressed = mk3_gun_pressed
		ItemId.SNIPE:
			normal = mk3_snipe_normal
			hover = mk3_snipe_hover
			pressed = mk3_snipe_pressed
		ItemId.MISSILE:
			normal = mk3_missile_normal
			hover = mk3_missile_hover
			pressed = mk3_missile_pressed

	if normal == null:
		push_warning("[LaboUI] Texture MK3 normal manquante pour %s" % str(item_id))
		mk3_btn.visible = false
		if mk3_cost_label:
			mk3_cost_label.visible = false
		if mk3_title_label:
			mk3_title_label.visible = false
			mk3_title_label.text = ""
		return

	mk3_btn.texture_normal = normal
	if hover: mk3_btn.texture_hover = hover
	if pressed: mk3_btn.texture_pressed = pressed
	mk3_btn.visible = true

	var tower_id := _tower_id_from_item(item_id)
	var unlocked := false
	var can_afford := false
	if Game:
		unlocked = Game.is_tower_mk3_unlocked(tower_id)
		can_afford = Game.can_spend_bank_crystals(MK3_COST)
	else:
		push_warning("[LaboUI] Autoload Game introuvable")

	if unlocked:
		_set_mk3_state(true, true)
		if mk3_cost_label:
			mk3_cost_label.text = "MK3 : Déjà acheté"
			mk3_cost_label.visible = true
	else:
		if can_afford:
			_set_mk3_state(false, false)
		else:
			_set_mk3_state(true, true)

		if mk3_cost_label:
			mk3_cost_label.text = "Coût : %d cristaux" % MK3_COST
			mk3_cost_label.visible = true
			
func _set_mk3_state(disabled: bool, gray: bool) -> void:
	mk3_btn.disabled = disabled
	mk3_btn.modulate = Color(1, 1, 1, DISABLED_ALPHA) if gray else Color(1, 1, 1, 1)

# ✅ MODIF : MK3 passe par la confirmation
func _on_mk3_pressed() -> void:
	if not _is_tower(_current_item):
		return

	var tower_id := _tower_id_from_item(_current_item)
	if not Game:
		push_warning("[LaboUI] Autoload Game introuvable, achat MK3 impossible")
		return

	# déjà acheté => rien
	if Game.is_tower_mk3_unlocked(tower_id):
		return

	var key := _mk3_key_from_item(_current_item)
	_open_confirm_for_key(key, MK3_COST, func():
		Game.try_unlock_tower_mk3(tower_id, MK3_COST)
		_update_mk3_button(_current_item)
	)

func _mk3_key_from_item(item_id: ItemId) -> StringName:
	match item_id:
		ItemId.BARRACKS: return &"Barrack_Upgrade"
		ItemId.GUN:      return &"Gun_Upgrade"
		ItemId.SNIPE:    return &"Snipe_Upgrade"
		ItemId.MISSILE:  return &"Missile_Upgrade"
		_:               return &""

# =========================================================
#     BARRACKS BUFF : UI + Achat
# =========================================================
func _update_barracks_buff_ui(item_id: ItemId) -> void:
	if not barracks_buff_btn:
		return

	if item_id != ItemId.BARRACKS:
		barracks_buff_btn.visible = false
		if barracks_buff_label: barracks_buff_label.visible = false
		return

	barracks_buff_btn.visible = true

	var level := 0
	var max_level := 0
	var next_cost := 0
	var next_bonus := 0.0
	var can_afford := false

	if Game:
		level = Game.get_barracks_aura_level()
		max_level = Game.get_barracks_aura_max_level()
		next_cost = Game.get_barracks_aura_next_cost()
		next_bonus = Game.get_barracks_aura_bonus(level + 1)
		can_afford = (next_cost > 0 and Game.can_spend_bank_crystals(next_cost))
	else:
		push_warning("[LaboUI] Autoload Game introuvable (buff barracks)")

	var is_maxed := (level >= max_level and max_level > 0)
	var disabled := is_maxed or not can_afford
	_set_button_state(barracks_buff_btn, disabled, disabled)

	if barracks_buff_label:
		barracks_buff_label.visible = true
		if is_maxed:
			var cur_bonus := Game.get_barracks_aura_bonus(level) if Game else 0.0
			barracks_buff_label.text = "Buff Barracks : MAX (Niv %d / +%d%%)" % [level, int(round(cur_bonus * 100.0))]
		else:
			barracks_buff_label.text = "Buff Barracks : Niv %d → %d  (Coût %d | +%d%%)" % [
				level, level + 1, next_cost, int(round(next_bonus * 100.0))
			]

# ✅ OK (déjà fait) : Barracks aura passe par confirmation
func _on_barracks_buff_pressed() -> void:
	if not Game:
		return

	var next_cost := Game.get_barracks_aura_next_cost()
	if next_cost <= 0:
		return

	_open_confirm_for_key(&"barracks_aura", next_cost, func():
		Game.try_upgrade_barracks_aura()
		_update_barracks_buff_ui(_current_item)
	)


# =========================================================
#     GUN SLOW : UI + Achat
# =========================================================
func _update_gun_slow_ui(item_id: ItemId) -> void:
	if not gun_slow_btn:
		return

	if item_id != ItemId.GUN:
		gun_slow_btn.visible = false
		if gun_slow_label: gun_slow_label.visible = false
		return

	gun_slow_btn.visible = true
	if gun_slow_label:
		gun_slow_label.visible = true

	var level := _get_gun_slow_level()
	var max_level := _get_gun_slow_max_level()
	var is_maxed := (level >= max_level and max_level > 0)

	var next_level := clampi(level + 1, 1, max_level)
	var next_cost := 0
	if not is_maxed:
		next_cost = _get_gun_slow_cost(next_level)

	var can_afford := true
	if Game and Game.has_method("can_spend_bank_crystals"):
		can_afford = (next_cost > 0 and Game.can_spend_bank_crystals(next_cost))

	var disabled := is_maxed or not can_afford
	_set_button_state(gun_slow_btn, disabled, disabled)

	if gun_slow_label:
		if is_maxed:
			var cur_factor := _get_gun_slow_factor(level)
			var cur_dur := _get_gun_slow_duration(level)
			gun_slow_label.text = "Slow Gun : MAX (Niv %d | -%d%% | %0.1fs)" % [
				level, int(round((1.0 - cur_factor) * 100.0)), cur_dur
			]
		else:
			var nf := _get_gun_slow_factor(next_level)
			var nd := _get_gun_slow_duration(next_level)
			gun_slow_label.text = "Slow Gun : Niv %d → %d (Coût %d | -%d%% | %0.1fs)" % [
				level, next_level, next_cost, int(round((1.0 - nf) * 100.0)), nd
			]

# ✅ MODIF : Gun slow passe par confirmation
func _on_gun_slow_pressed() -> void:
	if not Game:
		return

	var level := _get_gun_slow_level()
	var max_level := _get_gun_slow_max_level()
	if level >= max_level:
		return

	var next_level := clampi(level + 1, 1, max_level)
	var next_cost := _get_gun_slow_cost(next_level)
	if next_cost <= 0:
		return

	_open_confirm_for_key(&"gun_slow", next_cost, func():
		if Game.has_method("try_upgrade_gun_slow"):
			Game.try_upgrade_gun_slow()
		_update_gun_slow_ui(_current_item)
	)


# =========================================================
#     SNIPE BREAK : UI + Achat
# =========================================================
func _update_snipe_break_ui(item_id: ItemId) -> void:
	if not snipe_break_btn:
		return

	if item_id != ItemId.SNIPE:
		snipe_break_btn.visible = false
		if snipe_break_label: snipe_break_label.visible = false
		return

	snipe_break_btn.visible = true
	if snipe_break_label:
		snipe_break_label.visible = true

	var level := _get_snipe_break_level()
	var max_level := _get_snipe_break_max_level()
	var is_maxed := (level >= max_level and max_level > 0)

	var next_level := clampi(level + 1, 1, max_level)
	var next_cost := 0
	if not is_maxed:
		next_cost = _get_snipe_break_cost(next_level)

	var can_afford := true
	if Game and Game.has_method("can_spend_bank_crystals"):
		can_afford = (next_cost > 0 and Game.can_spend_bank_crystals(next_cost))

	var disabled := is_maxed or not can_afford
	_set_button_state(snipe_break_btn, disabled, disabled)

	var cur_extra := _get_snipe_break_extra_hits(level)
	var next_extra := _get_snipe_break_extra_hits(next_level)

	if snipe_break_label:
		if is_maxed:
			snipe_break_label.text = "Break Snipe : MAX (Niv %d | +%d cible%s)" % [
				level, cur_extra, "" if cur_extra <= 1 else "s"
			]
		else:
			snipe_break_label.text = "Break Snipe : Niv %d → %d (Coût %d | +%d cible%s)" % [
				level, next_level, next_cost, next_extra, "" if next_extra <= 1 else "s"
			]

# ✅ MODIF : Snipe break passe par confirmation (clé = "Snipe_break")
func _on_snipe_break_pressed() -> void:
	if not Game:
		return

	var level := _get_snipe_break_level()
	var max_level := _get_snipe_break_max_level()
	if level >= max_level:
		return

	var next_level := clampi(level + 1, 1, max_level)
	var next_cost := _get_snipe_break_cost(next_level)
	if next_cost <= 0:
		return

	_open_confirm_for_key(&"Snipe_break", next_cost, func():
		if Game.has_method("try_upgrade_snipe_break"):
			Game.try_upgrade_snipe_break()
		_update_snipe_break_ui(_current_item)
	)


# =========================================================
#     MISSILE FIRE : UI + Achat ✅
# =========================================================
func _update_missile_fire_ui(item_id: ItemId) -> void:
	if not missile_fire_btn:
		return

	if item_id != ItemId.MISSILE:
		missile_fire_btn.visible = false
		if missile_fire_label: missile_fire_label.visible = false
		return

	missile_fire_btn.visible = true
	if missile_fire_label:
		missile_fire_label.visible = true

	var level := _get_missile_fire_level()
	var max_level := _get_missile_fire_max_level()
	var is_maxed := (level >= max_level and max_level > 0)

	var next_level := clampi(level + 1, 1, max_level)
	var next_cost := 0
	if not is_maxed:
		next_cost = _get_missile_fire_cost(next_level)

	var can_afford := true
	if Game and Game.has_method("can_spend_bank_crystals"):
		can_afford = (next_cost > 0 and Game.can_spend_bank_crystals(next_cost))

	var disabled := is_maxed or not can_afford
	_set_button_state(missile_fire_btn, disabled, disabled)

	var cur_ch := _get_missile_fire_chance(level)
	var cur_pct := _get_missile_fire_dps_pct(level)
	var cur_dur := _get_missile_fire_duration(level)

	var nxt_ch := _get_missile_fire_chance(next_level)
	var nxt_pct := _get_missile_fire_dps_pct(next_level)
	var nxt_dur := _get_missile_fire_duration(next_level)

	if missile_fire_label:
		if is_maxed:
			missile_fire_label.text = "Fire Missile : MAX (Niv %d | %d%% | %d%%/s | %0.1fs)" % [
				level,
				int(round(cur_ch * 100.0)),
				int(round(cur_pct * 100.0)),
				cur_dur
			]
		else:
			missile_fire_label.text = "Fire Missile : Niv %d → %d (Coût %d | %d%% | %d%%/s | %0.1fs)" % [
				level,
				next_level,
				next_cost,
				int(round(nxt_ch * 100.0)),
				int(round(nxt_pct * 100.0)),
				nxt_dur
			]

# ✅ MODIF : Missile fire passe par confirmation (clé = "Missile_fire")
func _on_missile_fire_pressed() -> void:
	if not Game:
		return

	var level := _get_missile_fire_level()
	var max_level := _get_missile_fire_max_level()
	if level >= max_level:
		return

	var next_level := clampi(level + 1, 1, max_level)
	var next_cost := _get_missile_fire_cost(next_level)
	if next_cost <= 0:
		return

	_open_confirm_for_key(&"Missile_fire", next_cost, func():
		if Game.has_method("try_upgrade_missile_fire"):
			Game.try_upgrade_missile_fire()
		_update_missile_fire_ui(_current_item)
	)


# =========================================================
#     FREEZE : Cooldown ✅
# =========================================================
func _update_freeze_cooldown_ui(item_id: ItemId) -> void:
	if not freeze_cooldown_btn:
		return

	if item_id != ItemId.FREEZE:
		freeze_cooldown_btn.visible = false
		if freeze_cooldown_label: freeze_cooldown_label.visible = false
		return

	freeze_cooldown_btn.visible = true
	if freeze_cooldown_label:
		freeze_cooldown_label.visible = true

	var level := _get_freeze_cooldown_level()
	var max_level := _get_freeze_cooldown_max_level()
	var is_maxed := (level >= max_level and max_level > 0)

	var next_level := clampi(level + 1, 1, max_level)
	var next_cost := 0
	if not is_maxed:
		next_cost = _get_freeze_cooldown_cost(next_level)

	var can_afford := true
	if Game and Game.has_method("can_spend_bank_crystals"):
		can_afford = (next_cost > 0 and Game.can_spend_bank_crystals(next_cost))

	var disabled := is_maxed or not can_afford
	_set_button_state(freeze_cooldown_btn, disabled, disabled)

	var cur_sec := _get_freeze_cooldown_seconds(level)
	var nxt_sec := _get_freeze_cooldown_seconds(next_level)

	if freeze_cooldown_label:
		if is_maxed:
			freeze_cooldown_label.text = "Cooldown Freeze : MAX (Niv %d | %0.0fs)" % [level, cur_sec]
		else:
			freeze_cooldown_label.text = "Cooldown Freeze : Niv %d → %d (Coût %d | %0.0fs → %0.0fs)" % [
				level, next_level, next_cost, cur_sec, nxt_sec
			]

# ✅ MODIF : Freeze cooldown passe par confirmation
func _on_freeze_cooldown_pressed() -> void:
	if not Game:
		return

	var level := _get_freeze_cooldown_level()
	var max_level := _get_freeze_cooldown_max_level()
	if level >= max_level:
		return

	var next_level := clampi(level + 1, 1, max_level)
	var next_cost := _get_freeze_cooldown_cost(next_level)
	if next_cost <= 0:
		return

	_open_confirm_for_key(&"freeze_cooldown", next_cost, func():
		if Game.has_method("try_upgrade_freeze_cooldown"):
			Game.try_upgrade_freeze_cooldown()
		_update_freeze_cooldown_ui(_current_item)
	)


# =========================================================
#     FREEZE : Strength (vitesse x...) ✅
# =========================================================
func _update_freeze_level_ui(item_id: ItemId) -> void:
	if not freeze_level_btn:
		return

	if item_id != ItemId.FREEZE:
		freeze_level_btn.visible = false
		if freeze_level_label: freeze_level_label.visible = false
		return

	freeze_level_btn.visible = true
	if freeze_level_label:
		freeze_level_label.visible = true

	var level := _get_freeze_strength_level()
	var max_level := _get_freeze_strength_max_level()
	var is_maxed := (level >= max_level and max_level > 0)

	var next_level := clampi(level + 1, 1, max_level)
	var next_cost := 0
	if not is_maxed:
		next_cost = _get_freeze_strength_cost(next_level)

	var can_afford := true
	if Game and Game.has_method("can_spend_bank_crystals"):
		can_afford = (next_cost > 0 and Game.can_spend_bank_crystals(next_cost))

	var disabled := is_maxed or not can_afford
	_set_button_state(freeze_level_btn, disabled, disabled)

	var cur_fac := _get_freeze_strength_factor(level)
	var nxt_fac := _get_freeze_strength_factor(next_level)

	if freeze_level_label:
		if is_maxed:
			if cur_fac <= 0.0:
				freeze_level_label.text = "Freeze lvl : MAX (Niv %d | arrêt total)" % level
			else:
				freeze_level_label.text = "Freeze lvl : MAX (Niv %d | vitesse x%0.2f)" % [level, cur_fac]
		else:
			var cur_txt := "arrêt total" if cur_fac <= 0.0 else "vitesse x%0.2f" % cur_fac
			var nxt_txt := "arrêt total" if nxt_fac <= 0.0 else "vitesse x%0.2f" % nxt_fac
			freeze_level_label.text = "Freeze lvl : Niv %d → %d (Coût %d | %s → %s)" % [
				level, next_level, next_cost, cur_txt, nxt_txt
			]

# ✅ MODIF : Freeze strength passe par confirmation (clé = "freeze_strength")
func _on_freeze_level_pressed() -> void:
	if not Game:
		return

	var level := _get_freeze_strength_level()
	var max_level := _get_freeze_strength_max_level()
	if level >= max_level:
		return

	var next_level := clampi(level + 1, 1, max_level)
	var next_cost := _get_freeze_strength_cost(next_level)
	if next_cost <= 0:
		return

	_open_confirm_for_key(&"freeze_strength", next_cost, func():
		if Game.has_method("try_upgrade_freeze_strength"):
			Game.try_upgrade_freeze_strength()
		_update_freeze_level_ui(_current_item)
	)


# =========================================================
#     FREEZE : Number (instances simultanées) ✅
# =========================================================
func _update_freeze_number_ui(item_id: ItemId) -> void:
	if not freeze_number_btn:
		return

	if item_id != ItemId.FREEZE:
		freeze_number_btn.visible = false
		if freeze_number_label: freeze_number_label.visible = false
		return

	freeze_number_btn.visible = true
	if freeze_number_label:
		freeze_number_label.visible = true

	var level := _get_freeze_number_level()
	var max_level := _get_freeze_number_max_level()
	var is_maxed := (level >= max_level and max_level > 0)

	var next_level := clampi(level + 1, 1, max_level)
	var next_cost := 0
	if not is_maxed:
		next_cost = _get_freeze_number_cost(next_level)

	var can_afford := true
	if Game and Game.has_method("can_spend_bank_crystals"):
		can_afford = (next_cost > 0 and Game.can_spend_bank_crystals(next_cost))

	var disabled := is_maxed or not can_afford
	_set_button_state(freeze_number_btn, disabled, disabled)

	var cur_n := _get_freeze_number_value(level)
	var nxt_n := _get_freeze_number_value(next_level)

	if freeze_number_label:
		if is_maxed:
			freeze_number_label.text = "Freeze number : MAX (Niv %d | %d en même temps)" % [level, cur_n]
		else:
			freeze_number_label.text = "Freeze number : Niv %d → %d (Coût %d | %d → %d en même temps)" % [
				level, next_level, next_cost, cur_n, nxt_n
			]

# ✅ MODIF : Freeze number passe par confirmation (clé = "freeze_number")
func _on_freeze_number_pressed() -> void:
	if not Game:
		return

	var level := _get_freeze_number_level()
	var max_level := _get_freeze_number_max_level()
	if level >= max_level:
		return

	var next_level := clampi(level + 1, 1, max_level)
	var next_cost := _get_freeze_number_cost(next_level)
	if next_cost <= 0:
		return

	_open_confirm_for_key(&"freeze_number", next_cost, func():
		if Game.has_method("try_upgrade_freeze_number"):
			Game.try_upgrade_freeze_number()
		_update_freeze_number_ui(_current_item)
	)


# =========================================================
#                 Utils - Gun Slow getters
# =========================================================
func _get_gun_slow_level() -> int:
	if Game:
		if Game.has_method("get_gun_slow_level"):
			return int(Game.get_gun_slow_level())
		if "gun_slow_level" in Game:
			return int(Game.gun_slow_level)
	return 0

func _get_gun_slow_max_level() -> int:
	if Game and Game.has_method("get_gun_slow_max_level"):
		return int(Game.get_gun_slow_max_level())
	return GUN_SLOW_MAX_LEVEL

func _get_gun_slow_cost(level: int) -> int:
	if Game and Game.has_method("get_gun_slow_cost"):
		return int(Game.get_gun_slow_cost(level))
	if Game and Game.has_method("get_gun_slow_next_cost"):
		return int(Game.get_gun_slow_next_cost())
	return int(GUN_SLOW_COST_BY_LEVEL.get(level, 0))

func _get_gun_slow_factor(level: int) -> float:
	if Game and Game.has_method("get_gun_slow_factor_for_level"):
		return float(Game.get_gun_slow_factor_for_level(level))
	return float(GUN_SLOW_FACTOR_BY_LEVEL.get(level, 0.85))

func _get_gun_slow_duration(level: int) -> float:
	if Game and Game.has_method("get_gun_slow_duration_for_level"):
		return float(Game.get_gun_slow_duration_for_level(level))
	return float(GUN_SLOW_DURATION_BY_LEVEL.get(level, 1.2))

# =========================================================
#                 Utils - Snipe Break getters
# =========================================================
func _get_snipe_break_level() -> int:
	if Game:
		if Game.has_method("get_snipe_break_level"):
			return int(Game.get_snipe_break_level())
		if "snipe_break_level" in Game:
			return int(Game.snipe_break_level)
	return 0

func _get_snipe_break_max_level() -> int:
	if Game and Game.has_method("get_snipe_break_max_level"):
		return int(Game.get_snipe_break_max_level())
	return SNIPE_BREAK_MAX_LEVEL

func _get_snipe_break_cost(level: int) -> int:
	if Game and Game.has_method("get_snipe_break_cost"):
		return int(Game.get_snipe_break_cost(level))
	if Game and Game.has_method("get_snipe_break_next_cost"):
		return int(Game.get_snipe_break_next_cost())
	return int(SNIPE_BREAK_COST_BY_LEVEL.get(level, 0))

func _get_snipe_break_extra_hits(level: int) -> int:
	if Game and Game.has_method("get_snipe_break_extra_hits_for_level"):
		return int(Game.get_snipe_break_extra_hits_for_level(level))
	return int(SNIPE_BREAK_EXTRA_HITS_BY_LEVEL.get(level, 0))

# =========================================================
#                 Utils - Missile Fire getters ✅
# =========================================================
func _get_missile_fire_level() -> int:
	if Game:
		if Game.has_method("get_missile_fire_level"):
			return int(Game.get_missile_fire_level())
		if "missile_fire_level" in Game:
			return int(Game.missile_fire_level)
	return 0

func _get_missile_fire_max_level() -> int:
	if Game and Game.has_method("get_missile_fire_max_level"):
		return int(Game.get_missile_fire_max_level())
	return MISSILE_FIRE_MAX_LEVEL

func _get_missile_fire_cost(level: int) -> int:
	if Game and Game.has_method("get_missile_fire_cost"):
		return int(Game.get_missile_fire_cost(level))
	if Game and Game.has_method("get_missile_fire_next_cost"):
		return int(Game.get_missile_fire_next_cost())
	return int(MISSILE_FIRE_COST_BY_LEVEL.get(level, 0))

func _get_missile_fire_chance(level: int) -> float:
	if Game and Game.has_method("get_missile_fire_chance_for_level"):
		return float(Game.get_missile_fire_chance_for_level(level))
	return float(MISSILE_FIRE_CHANCE_BY_LEVEL.get(level, 0.0))

func _get_missile_fire_dps_pct(level: int) -> float:
	if Game and Game.has_method("get_missile_fire_dps_pct_for_level"):
		return float(Game.get_missile_fire_dps_pct_for_level(level))
	return float(MISSILE_FIRE_DPS_PCT_BY_LEVEL.get(level, 0.0))

func _get_missile_fire_duration(level: int) -> float:
	if Game and Game.has_method("get_missile_fire_duration_for_level"):
		return float(Game.get_missile_fire_duration_for_level(level))
	return float(MISSILE_FIRE_DURATION_BY_LEVEL.get(level, 0.0))

# =========================================================
#                 Utils - Freeze getters ✅
# =========================================================
func _get_freeze_cooldown_level() -> int:
	if Game and Game.has_method("get_freeze_cooldown_level"):
		return int(Game.get_freeze_cooldown_level())
	if Game and ("freeze_cooldown_level" in Game):
		return int(Game.freeze_cooldown_level)
	return 0

func _get_freeze_cooldown_max_level() -> int:
	if Game and Game.has_method("get_freeze_cooldown_max_level"):
		return int(Game.get_freeze_cooldown_max_level())
	return FREEZE_CD_MAX_LEVEL

func _get_freeze_cooldown_cost(level: int) -> int:
	if Game and Game.has_method("get_freeze_cooldown_cost"):
		return int(Game.get_freeze_cooldown_cost(level))
	if Game and Game.has_method("get_freeze_cooldown_next_cost"):
		return int(Game.get_freeze_cooldown_next_cost())
	return int(FREEZE_CD_COST_BY_LEVEL.get(level, 0))

func _get_freeze_cooldown_seconds(level: int) -> float:
	if Game and Game.has_method("get_freeze_cooldown_seconds_for_level"):
		return float(Game.get_freeze_cooldown_seconds_for_level(level))
	return float(FREEZE_CD_SECONDS_BY_LEVEL.get(level, FREEZE_CD_BASE))

func _get_freeze_strength_level() -> int:
	if Game and Game.has_method("get_freeze_strength_level"):
		return int(Game.get_freeze_strength_level())
	if Game and ("freeze_strength_level" in Game):
		return int(Game.freeze_strength_level)
	return 0

func _get_freeze_strength_max_level() -> int:
	if Game and Game.has_method("get_freeze_strength_max_level"):
		return int(Game.get_freeze_strength_max_level())
	return FREEZE_STRENGTH_MAX_LEVEL

func _get_freeze_strength_cost(level: int) -> int:
	if Game and Game.has_method("get_freeze_strength_cost"):
		return int(Game.get_freeze_strength_cost(level))
	if Game and Game.has_method("get_freeze_strength_next_cost"):
		return int(Game.get_freeze_strength_next_cost())
	return int(FREEZE_STRENGTH_COST_BY_LEVEL.get(level, 0))

func _get_freeze_strength_factor(level: int) -> float:
	if Game and Game.has_method("get_freeze_strength_factor_for_level"):
		return float(Game.get_freeze_strength_factor_for_level(level))
	return float(FREEZE_STRENGTH_FACTOR_BY_LEVEL.get(level, FREEZE_STRENGTH_BASE))

func _get_freeze_number_level() -> int:
	if Game and Game.has_method("get_freeze_number_level"):
		return int(Game.get_freeze_number_level())
	if Game and ("freeze_number_level" in Game):
		return int(Game.freeze_number_level)
	return 0

func _get_freeze_number_max_level() -> int:
	if Game and Game.has_method("get_freeze_number_max_level"):
		return int(Game.get_freeze_number_max_level())
	return FREEZE_NUMBER_MAX_LEVEL

func _get_freeze_number_cost(level: int) -> int:
	if Game and Game.has_method("get_freeze_number_cost"):
		return int(Game.get_freeze_number_cost(level))
	if Game and Game.has_method("get_freeze_number_next_cost"):
		return int(Game.get_freeze_number_next_cost())
	return int(FREEZE_NUMBER_COST_BY_LEVEL.get(level, 0))

func _get_freeze_number_value(level: int) -> int:
	if Game and Game.has_method("get_freeze_number_value_for_level"):
		return int(Game.get_freeze_number_value_for_level(level))
	return int(FREEZE_NUMBER_VALUE_BY_LEVEL.get(level, FREEZE_NUMBER_BASE))

# =========================================================
#                 Utils divers
# =========================================================
func _is_tower(item_id: ItemId) -> bool:
	return item_id == ItemId.BARRACKS or item_id == ItemId.GUN or item_id == ItemId.SNIPE or item_id == ItemId.MISSILE

func _tower_id_from_item(item_id: ItemId) -> StringName:
	match item_id:
		ItemId.BARRACKS: return &"barracks"
		ItemId.GUN:      return &"gun"
		ItemId.SNIPE:    return &"snipe"
		ItemId.MISSILE:  return &"missile"
		_:               return &""

func _on_bank_crystals_changed(_amount: int) -> void:
	if _is_open:
		_update_mk3_button(_current_item)
		_update_barracks_buff_ui(_current_item)
		_update_gun_slow_ui(_current_item)
		_update_snipe_break_ui(_current_item)
		_update_missile_fire_ui(_current_item)

		# ✅ Freeze refresh
		_update_freeze_cooldown_ui(_current_item)
		_update_freeze_level_ui(_current_item)
		_update_freeze_number_ui(_current_item)

		# ✅ Summon refresh
		_update_summon_cooldown_ui(_current_item)
		_update_summon_marine_lvl_ui(_current_item)
		_update_summon_number_ui(_current_item)

		# ✅ Heal refresh
		_update_heal_cooldown_ui(_current_item)
		_update_heal_revive_ui(_current_item)
		_update_heal_inv_ui(_current_item)


# =========================================================
#     SUMMON : Cooldown ✅
# =========================================================
func _update_summon_cooldown_ui(item_id: ItemId) -> void:
	if not summon_cooldown_btn:
		return

	if item_id != ItemId.SUMMON:
		summon_cooldown_btn.visible = false
		if summon_cooldown_label: summon_cooldown_label.visible = false
		return

	summon_cooldown_btn.visible = true
	if summon_cooldown_label:
		summon_cooldown_label.visible = true

	var level := _get_summon_cooldown_level()
	var max_level := _get_summon_cooldown_max_level()
	var is_maxed := (level >= max_level and max_level > 0)

	var next_level := clampi(level + 1, 1, max_level)
	var next_cost := 0
	if not is_maxed:
		next_cost = _get_summon_cooldown_cost(next_level)

	var can_afford := true
	if Game and Game.has_method("can_spend_bank_crystals"):
		can_afford = (next_cost > 0 and Game.can_spend_bank_crystals(next_cost))

	var disabled := is_maxed or not can_afford
	_set_button_state(summon_cooldown_btn, disabled, disabled)

	var cur_sec := _get_summon_cooldown_seconds(level)
	var nxt_sec := _get_summon_cooldown_seconds(next_level)

	if summon_cooldown_label:
		if is_maxed:
			summon_cooldown_label.text = "Cooldown Summon : MAX (Niv %d | %0.0fs)" % [level, cur_sec]
		else:
			summon_cooldown_label.text = "Cooldown Summon : Niv %d → %d (Coût %d | %0.0fs → %0.0fs)" % [
				level, next_level, next_cost, cur_sec, nxt_sec
			]

# ✅ MODIF : Summon cooldown passe par confirmation
func _on_summon_cooldown_pressed() -> void:
	if not Game:
		return

	var level := _get_summon_cooldown_level()
	var max_level := _get_summon_cooldown_max_level()
	if level >= max_level:
		return

	var next_level := clampi(level + 1, 1, max_level)
	var next_cost := _get_summon_cooldown_cost(next_level)
	if next_cost <= 0:
		return

	_open_confirm_for_key(&"summon_cooldown", next_cost, func():
		if Game.has_method("try_upgrade_summon_cooldown"):
			Game.try_upgrade_summon_cooldown()
		_update_summon_cooldown_ui(_current_item)
	)


# =========================================================
#     SUMMON : Marine Lvl (MK) ✅
# =========================================================
func _update_summon_marine_lvl_ui(item_id: ItemId) -> void:
	if not summon_marine_lvl_btn:
		return

	if item_id != ItemId.SUMMON:
		summon_marine_lvl_btn.visible = false
		if summon_marine_lvl_label: summon_marine_lvl_label.visible = false
		return

	summon_marine_lvl_btn.visible = true
	if summon_marine_lvl_label:
		summon_marine_lvl_label.visible = true

	var level := _get_summon_marine_level()
	var max_level := _get_summon_marine_max_level()
	var is_maxed := (level >= max_level and max_level > 0)

	var next_level := clampi(level + 1, 1, max_level)
	var next_cost := 0
	if not is_maxed:
		next_cost = _get_summon_marine_cost(next_level)

	var can_afford := true
	if Game and Game.has_method("can_spend_bank_crystals"):
		can_afford = (next_cost > 0 and Game.can_spend_bank_crystals(next_cost))

	var disabled := is_maxed or not can_afford
	_set_button_state(summon_marine_lvl_btn, disabled, disabled)

	var cur_tier := _get_summon_marine_tier(level)
	var nxt_tier := _get_summon_marine_tier(next_level)

	if summon_marine_lvl_label:
		if is_maxed:
			summon_marine_lvl_label.text = "Marine lvl : MAX (Niv %d | MK%d)" % [level, cur_tier]
		else:
			summon_marine_lvl_label.text = "Marine lvl : Niv %d → %d (Coût %d | MK%d → MK%d)" % [
				level, next_level, next_cost, cur_tier, nxt_tier
			]

# ✅ MODIF : Summon marine level passe par confirmation
func _on_summon_marine_lvl_pressed() -> void:
	if not Game:
		return

	var level := _get_summon_marine_level()
	var max_level := _get_summon_marine_max_level()
	if level >= max_level:
		return

	var next_level := clampi(level + 1, 1, max_level)
	var next_cost := _get_summon_marine_cost(next_level)
	if next_cost <= 0:
		return

	_open_confirm_for_key(&"summon_marine_level", next_cost, func():
		if Game.has_method("try_upgrade_summon_marine"):
			Game.try_upgrade_summon_marine()
		_update_summon_marine_lvl_ui(_current_item)
	)


# =========================================================
#     SUMMON : Number (nb marines) ✅
# =========================================================
func _update_summon_number_ui(item_id: ItemId) -> void:
	if not summon_number_btn:
		return

	if item_id != ItemId.SUMMON:
		summon_number_btn.visible = false
		if summon_number_label: summon_number_label.visible = false
		return

	summon_number_btn.visible = true
	if summon_number_label:
		summon_number_label.visible = true

	var level := _get_summon_number_level()
	var max_level := _get_summon_number_max_level()
	var is_maxed := (level >= max_level and max_level > 0)

	var next_level := clampi(level + 1, 1, max_level)
	var next_cost := 0
	if not is_maxed:
		next_cost = _get_summon_number_cost(next_level)

	var can_afford := true
	if Game and Game.has_method("can_spend_bank_crystals"):
		can_afford = (next_cost > 0 and Game.can_spend_bank_crystals(next_cost))

	var disabled := is_maxed or not can_afford
	_set_button_state(summon_number_btn, disabled, disabled)

	var cur_n := _get_summon_number_value(level)
	var nxt_n := _get_summon_number_value(next_level)

	if summon_number_label:
		if is_maxed:
			summon_number_label.text = "Marine number : MAX (Niv %d | %d invoqués)" % [level, cur_n]
		else:
			summon_number_label.text = "Marine number : Niv %d → %d (Coût %d | %d → %d invoqués)" % [
				level, next_level, next_cost, cur_n, nxt_n
			]

# ✅ MODIF : Summon number passe par confirmation
func _on_summon_number_pressed() -> void:
	if not Game:
		return

	var level := _get_summon_number_level()
	var max_level := _get_summon_number_max_level()
	if level >= max_level:
		return

	var next_level := clampi(level + 1, 1, max_level)
	var next_cost := _get_summon_number_cost(next_level)
	if next_cost <= 0:
		return

	_open_confirm_for_key(&"summon_number", next_cost, func():
		if Game.has_method("try_upgrade_summon_number"):
			Game.try_upgrade_summon_number()
		_update_summon_number_ui(_current_item)
	)


# =========================================================
#     Utils - Summon getters ✅
# =========================================================
func _get_summon_cooldown_level() -> int:
	if Game and Game.has_method("get_summon_cooldown_level"):
		return int(Game.get_summon_cooldown_level())
	if Game and ("summon_cooldown_level" in Game):
		return int(Game.summon_cooldown_level)
	return 0

func _get_summon_cooldown_max_level() -> int:
	if Game and Game.has_method("get_summon_cooldown_max_level"):
		return int(Game.get_summon_cooldown_max_level())
	return SUMMON_CD_MAX_LEVEL

func _get_summon_cooldown_cost(level: int) -> int:
	if Game and Game.has_method("get_summon_cooldown_cost"):
		return int(Game.get_summon_cooldown_cost(level))
	if Game and Game.has_method("get_summon_cooldown_next_cost"):
		return int(Game.get_summon_cooldown_next_cost())
	return int(SUMMON_CD_COST_BY_LEVEL.get(level, 0))

func _get_summon_cooldown_seconds(level: int) -> float:
	if Game and Game.has_method("get_summon_cooldown_seconds_for_level"):
		return float(Game.get_summon_cooldown_seconds_for_level(level))
	if level <= 0:
		return SUMMON_CD_BASE
	return float(SUMMON_CD_SECONDS_BY_LEVEL.get(level, SUMMON_CD_BASE))

func _get_summon_marine_level() -> int:
	if Game and Game.has_method("get_summon_marine_level"):
		return int(Game.get_summon_marine_level())
	if Game and ("summon_marine_level" in Game):
		return int(Game.summon_marine_level)
	return 0

func _get_summon_marine_max_level() -> int:
	if Game and Game.has_method("get_summon_marine_max_level"):
		return int(Game.get_summon_marine_max_level())
	return SUMMON_MARINE_MAX_LEVEL

func _get_summon_marine_cost(level: int) -> int:
	if Game and Game.has_method("get_summon_marine_cost"):
		return int(Game.get_summon_marine_cost(level))
	if Game and Game.has_method("get_summon_marine_next_cost"):
		return int(Game.get_summon_marine_next_cost())
	return int(SUMMON_MARINE_COST_BY_LEVEL.get(level, 0))

func _get_summon_marine_tier(level: int) -> int:
	if Game and Game.has_method("get_summon_marine_tier_for_level"):
		return int(Game.get_summon_marine_tier_for_level(level))
	if level <= 0:
		return SUMMON_MARINE_BASE_TIER
	return int(SUMMON_MARINE_TIER_BY_LEVEL.get(level, SUMMON_MARINE_BASE_TIER))

func _get_summon_number_level() -> int:
	if Game and Game.has_method("get_summon_number_level"):
		return int(Game.get_summon_number_level())
	if Game and ("summon_number_level" in Game):
		return int(Game.summon_number_level)
	return 0

func _get_summon_number_max_level() -> int:
	if Game and Game.has_method("get_summon_number_max_level"):
		return int(Game.get_summon_number_max_level())
	return SUMMON_NUMBER_MAX_LEVEL

func _get_summon_number_cost(level: int) -> int:
	if Game and Game.has_method("get_summon_number_cost"):
		return int(Game.get_summon_number_cost(level))
	if Game and Game.has_method("get_summon_number_next_cost"):
		return int(Game.get_summon_number_next_cost())
	return int(SUMMON_NUMBER_COST_BY_LEVEL.get(level, 0))

func _get_summon_number_value(level: int) -> int:
	if Game and Game.has_method("get_summon_marine_count_for_level"):
		return int(Game.get_summon_marine_count_for_level(level))
	if level <= 0:
		return SUMMON_NUMBER_BASE
	return int(SUMMON_NUMBER_VALUE_BY_LEVEL.get(level, SUMMON_NUMBER_BASE))


# =========================================================
#     HEAL : Cooldown ✅
# =========================================================
func _update_heal_cooldown_ui(item_id: ItemId) -> void:
	if not heal_cooldown_btn:
		return
	if item_id != ItemId.HEAL:
		heal_cooldown_btn.visible = false
		if heal_cooldown_label: heal_cooldown_label.visible = false
		return

	heal_cooldown_btn.visible = true
	if heal_cooldown_label: heal_cooldown_label.visible = true

	var level := (int(Game.get_heal_cooldown_level()) if Game and Game.has_method("get_heal_cooldown_level") else 0)
	var max_level := (int(Game.get_heal_cooldown_max_level()) if Game and Game.has_method("get_heal_cooldown_max_level") else 3)
	var is_maxed := (level >= max_level and max_level > 0)

	var next_level := clampi(level + 1, 1, max_level)
	var next_cost := 0
	if not is_maxed and Game and Game.has_method("get_heal_cooldown_cost"):
		next_cost = int(Game.get_heal_cooldown_cost(next_level))

	var can_afford := true
	if Game and Game.has_method("can_spend_bank_crystals"):
		can_afford = (next_cost > 0 and Game.can_spend_bank_crystals(next_cost))

	var disabled := is_maxed or not can_afford
	_set_button_state(heal_cooldown_btn, disabled, disabled)

	var cur_sec := (float(Game.get_heal_cooldown_seconds_for_level(level)) if Game and Game.has_method("get_heal_cooldown_seconds_for_level") else 20.0)
	var nxt_sec := (float(Game.get_heal_cooldown_seconds_for_level(next_level)) if Game and Game.has_method("get_heal_cooldown_seconds_for_level") else 20.0)

	if heal_cooldown_label:
		if is_maxed:
			heal_cooldown_label.text = "Cooldown Heal : MAX (Niv %d | %0.0fs)" % [level, cur_sec]
		else:
			heal_cooldown_label.text = "Cooldown Heal : Niv %d → %d (Coût %d | %0.0fs → %0.0fs)" % [level, next_level, next_cost, cur_sec, nxt_sec]

# ✅ MODIF : Heal cooldown passe par confirmation
func _on_heal_cooldown_pressed() -> void:
	if not Game:
		return

	var level := (int(Game.get_heal_cooldown_level()) if Game and Game.has_method("get_heal_cooldown_level") else 0)
	var max_level := (int(Game.get_heal_cooldown_max_level()) if Game and Game.has_method("get_heal_cooldown_max_level") else 3)
	if level >= max_level:
		return

	var next_level := clampi(level + 1, 1, max_level)
	var next_cost := (int(Game.get_heal_cooldown_cost(next_level)) if Game and Game.has_method("get_heal_cooldown_cost") else 0)
	if next_cost <= 0:
		return

	_open_confirm_for_key(&"heal_cooldown", next_cost, func():
		if Game.has_method("try_upgrade_heal_cooldown"):
			Game.try_upgrade_heal_cooldown()
		_update_heal_cooldown_ui(_current_item)
	)


# =========================================================
#     HEAL : Revive barracks ✅
# =========================================================
func _update_heal_revive_ui(item_id: ItemId) -> void:
	if not heal_revive_btn:
		return
	if item_id != ItemId.HEAL:
		heal_revive_btn.visible = false
		if heal_revive_label: heal_revive_label.visible = false
		return

	heal_revive_btn.visible = true
	if heal_revive_label: heal_revive_label.visible = true

	var level := (int(Game.get_heal_revive_level()) if Game and Game.has_method("get_heal_revive_level") else 0)
	var max_level := (int(Game.get_heal_revive_max_level()) if Game and Game.has_method("get_heal_revive_max_level") else 3)
	var is_maxed := (level >= max_level and max_level > 0)

	var next_level := clampi(level + 1, 1, max_level)
	var next_cost := 0
	if not is_maxed and Game and Game.has_method("get_heal_revive_cost"):
		next_cost = int(Game.get_heal_revive_cost(next_level))

	var can_afford := true
	if Game and Game.has_method("can_spend_bank_crystals"):
		can_afford = (next_cost > 0 and Game.can_spend_bank_crystals(next_cost))

	var disabled := is_maxed or not can_afford
	_set_button_state(heal_revive_btn, disabled, disabled)

	var cur_bonus := (int(Game.get_heal_revive_bonus_for_level(level)) if Game and Game.has_method("get_heal_revive_bonus_for_level") else 0)
	var nxt_bonus := (int(Game.get_heal_revive_bonus_for_level(next_level)) if Game and Game.has_method("get_heal_revive_bonus_for_level") else cur_bonus)

	if heal_revive_label:
		if is_maxed:
			heal_revive_label.text = "Revive Barracks : MAX (Niv %d | +%d)" % [level, cur_bonus]
		else:
			heal_revive_label.text = "Revive Barracks : Niv %d → %d (Coût %d | +%d → +%d)" % [level, next_level, next_cost, cur_bonus, nxt_bonus]

# ✅ MODIF : Heal revive passe par confirmation
func _on_heal_revive_pressed() -> void:
	if not Game:
		return

	var level := (int(Game.get_heal_revive_level()) if Game and Game.has_method("get_heal_revive_level") else 0)
	var max_level := (int(Game.get_heal_revive_max_level()) if Game and Game.has_method("get_heal_revive_max_level") else 3)
	if level >= max_level:
		return

	var next_level := clampi(level + 1, 1, max_level)
	var next_cost := (int(Game.get_heal_revive_cost(next_level)) if Game and Game.has_method("get_heal_revive_cost") else 0)
	if next_cost <= 0:
		return

	_open_confirm_for_key(&"heal_revive", next_cost, func():
		if Game.has_method("try_upgrade_heal_revive"):
			Game.try_upgrade_heal_revive()
		_update_heal_revive_ui(_current_item)
	)


# =========================================================
#     HEAL : Invincibilité ✅
# =========================================================
func _update_heal_inv_ui(item_id: ItemId) -> void:
	if not heal_inv_btn:
		return
	if item_id != ItemId.HEAL:
		heal_inv_btn.visible = false
		if heal_inv_label: heal_inv_label.visible = false
		return

	heal_inv_btn.visible = true
	if heal_inv_label: heal_inv_label.visible = true

	var level := (int(Game.get_heal_invincible_level()) if Game and Game.has_method("get_heal_invincible_level") else 0)
	var max_level := (int(Game.get_heal_invincible_max_level()) if Game and Game.has_method("get_heal_invincible_max_level") else 3)
	var is_maxed := (level >= max_level and max_level > 0)

	var next_level := clampi(level + 1, 1, max_level)
	var next_cost := 0
	if not is_maxed and Game and Game.has_method("get_heal_invincible_cost"):
		next_cost = int(Game.get_heal_invincible_cost(next_level))

	var can_afford := true
	if Game and Game.has_method("can_spend_bank_crystals"):
		can_afford = (next_cost > 0 and Game.can_spend_bank_crystals(next_cost))

	var disabled := is_maxed or not can_afford
	_set_button_state(heal_inv_btn, disabled, disabled)

	var cur_sec := (float(Game.get_heal_invincible_seconds_for_level(level)) if Game and Game.has_method("get_heal_invincible_seconds_for_level") else 5.0)
	var nxt_sec := (float(Game.get_heal_invincible_seconds_for_level(next_level)) if Game and Game.has_method("get_heal_invincible_seconds_for_level") else cur_sec)

	if heal_inv_label:
		if is_maxed:
			heal_inv_label.text = "Invincibilité : MAX (Niv %d | %0.0fs)" % [level, cur_sec]
		else:
			heal_inv_label.text = "Invincibilité : Niv %d → %d (Coût %d | %0.0fs → %0.0fs)" % [level, next_level, next_cost, cur_sec, nxt_sec]

# ✅ MODIF : Heal invincible passe par confirmation
func _on_heal_inv_pressed() -> void:
	if not Game:
		return

	var level := (int(Game.get_heal_invincible_level()) if Game and Game.has_method("get_heal_invincible_level") else 0)
	var max_level := (int(Game.get_heal_invincible_max_level()) if Game and Game.has_method("get_heal_invincible_max_level") else 3)
	if level >= max_level:
		return

	var next_level := clampi(level + 1, 1, max_level)
	var next_cost := (int(Game.get_heal_invincible_cost(next_level)) if Game and Game.has_method("get_heal_invincible_cost") else 0)
	if next_cost <= 0:
		return

	_open_confirm_for_key(&"heal_invincible", next_cost, func():
		if Game.has_method("try_upgrade_heal_invincible"):
			Game.try_upgrade_heal_invincible()
		_update_heal_inv_ui(_current_item)
	)


# =========================================================
#     CONFIRM OVERLAY : handlers
# =========================================================
func _on_confirm_cancel() -> void:
	_close_confirm()

func _on_confirm_accept() -> void:
	if _confirm_action.is_valid():
		_confirm_action.call()
	_close_confirm()

func _close_confirm() -> void:
	_confirm_is_open = false
	_confirm_action = Callable()
	if confirm_overlay:
		confirm_overlay.visible = false

func _open_confirm_for_key(key: StringName, cost: int, on_confirm: Callable) -> void:
	_confirm_is_open = true
	_confirm_action = on_confirm

	var data := _get_upgrade_title_desc(key)
	var title: String = data.title
	var desc: String = data.desc

	if confirm_title_label:
		confirm_title_label.text = title
	if confirm_desc_label:
		confirm_desc_label.text = desc
	if confirm_cost_label:
		confirm_cost_label.text = "Coût : %d cristaux" % cost

	var can_afford := true
	if Game and Game.has_method("can_spend_bank_crystals"):
		can_afford = Game.can_spend_bank_crystals(cost)

	if confirm_confirm_btn:
		confirm_confirm_btn.disabled = not can_afford

	if confirm_overlay:
		confirm_overlay.visible = true

func _get_upgrade_title_desc(key: StringName) -> Dictionary:
	var title := "Amélioration"
	var desc := ""

	if upgrade_texts:
		var info: UpgradeInfo = upgrade_texts.get_info(key)
		if info:
			title = info.title
			desc = info.description

	return {"title": title, "desc": desc}


func _on_next_pressed() -> void:
	if next_scene_path.is_empty():
		push_warning("[LaboUI] next_scene_path n'est pas assigné")
		return
	get_tree().change_scene_to_file(next_scene_path)
